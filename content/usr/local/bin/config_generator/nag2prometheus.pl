#!/usr/bin/perl

use strict;
use warnings;
use Digest::SHA qw(sha1_hex);
use File::Path qw(make_path);
use JSON::XS qw(encode_json);
use XML::Simple;

my $default_port = $ENV{PROMETHEUS_EXPORTER_PORT} || 9100;

sub as_list {
	my ($value) = @_;

	return () unless defined $value;
	return @{$value} if ref($value) eq 'ARRAY';
	return ($value);
}

sub yaml_quote {
	my ($value) = @_;

	$value = '' unless defined $value;
	$value =~ s/\\/\\\\/g;
	$value =~ s/"/\\"/g;
	$value =~ s/\r/\\r/g;
	$value =~ s/\n/\\n/g;
	return '"' . $value . '"';
}

sub is_exporter_service {
	my ($service) = @_;
	my $name = lc($service->{name} || '');
	my $command = lc($service->{command} || '');

	return $name =~ /(?:prometheus|node[-_]?exporter|exporter)/ ||
		$command =~ /(?:prometheus|node[-_]?exporter|exporter)/;
}

sub exporter_settings {
	my ($command) = @_;
	my @parts = split(/!/, $command || '', -1);
	my $port = $default_port;
	my $path = '/metrics';
	my $scheme = $command =~ /(?:https|ssl)/i ? 'https' : 'http';

	for (my $index = 1; $index < scalar(@parts); $index++) {
		if ($parts[$index] =~ /^\d+$/ && $parts[$index] >= 1 && $parts[$index] <= 65535) {
			$port = $parts[$index];
		} elsif ($parts[$index] =~ m{^/}) {
			$path = $parts[$index];
		}
	}

	return ($port, $path, $scheme);
}

sub target_address {
	my ($address, $port) = @_;

	$address = "[$address]" if $address =~ /:/ && $address !~ /^\[/;
	return "$address:$port";
}

sub collect_targets {
	my ($hosts, $templates, $targets) = @_;
	return unless ref($hosts) eq 'ARRAY';

	foreach my $host (@{$hosts}) {
		next if ($host->{ignore} || 'no') eq 'yes';

		my @services = as_list($host->{service});
		foreach my $template_id (as_list($host->{template})) {
			push @services, as_list($templates->{$template_id});
		}

		my ($service) = grep { is_exporter_service($_) } @services;
		if ($service) {
			my $address = $host->{ip} || $host->{id};
			my ($port, $path, $scheme) = exporter_settings($service->{command});
			push @{$targets}, {
				host => $host->{id},
				address => $address,
				port => 0 + $port,
				path => $path,
				scheme => $scheme,
				target => target_address($address, $port),
			};
		}

		collect_targets($host->{host}, $templates, $targets);
	}
}

sub main {
	my $config = XMLin('nag.xml', ForceArray => 1, KeyAttr => []);
	my $templates = {};
	my @targets;

	foreach my $template (as_list($config->{hosttemplate})) {
		$templates->{$template->{id}} = $template->{service};
	}
	collect_targets($config->{host}, $templates, \@targets);

	my %groups;
	my @group_order;
	foreach my $target (@targets) {
		my $key = "$target->{scheme}|$target->{path}";
		if (!exists $groups{$key}) {
			my $job = @group_order ? 'node-exporter-' . (scalar(@group_order) + 1) : 'node-exporter';
			$groups{$key} = {
				job => $job,
				scheme => $target->{scheme},
				path => $target->{path},
				targets => [],
			};
			push @group_order, $key;
		}
		$target->{job} = $groups{$key}->{job};
		push @{$groups{$key}->{targets}}, $target;
	}

	make_path('/etc/prometheus');
	open(my $metadata, '>', '/etc/prometheus/nms-targets.json') || die "can't write target metadata: $!";
	print {$metadata} encode_json(\@targets) . "\n";
	close($metadata) || die "can't close target metadata: $!";

	print "global:\n";
	print "  scrape_interval: 15s\n";
	print "  evaluation_interval: 15s\n";
	if (!@group_order) {
		print "scrape_configs: []\n";
		return 0;
	}

	print "scrape_configs:\n";
	foreach my $key (@group_order) {
		my $group = $groups{$key};
		print "  - job_name: " . yaml_quote($group->{job}) . "\n";
		print "    scheme: " . yaml_quote($group->{scheme}) . "\n";
		print "    metrics_path: " . yaml_quote($group->{path}) . "\n";
		print "    static_configs:\n";
		foreach my $target (@{$group->{targets}}) {
			print "      - targets:\n";
			print "          - " . yaml_quote($target->{target}) . "\n";
			print "        labels:\n";
			print "          nms_host: " . yaml_quote($target->{host}) . "\n";
		}
	}

	return 0;
}

exit main(@ARGV);
