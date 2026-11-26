#!/usr/bin/perl

use strict;
use warnings;
use Digest::SHA qw(sha1_hex);
use File::Path qw(make_path);
use JSON::XS;
use XML::Simple;

my $default_port = $ENV{PROMETHEUS_EXPORTER_PORT} || 9100;
my $source_file = $ENV{GRAFANA_DASHBOARD_SOURCE} || '/usr/local/share/grafana/dashboards/linux-servers.json';
my $datasource_dir = '/etc/grafana/provisioning/datasources';
my $dashboard_dir = '/etc/grafana/provisioning/dashboards/generated';
my $home_dashboard_dir = '/etc/grafana/dashboards';
my $home_dashboard_file = "$home_dashboard_dir/home.json";

sub as_list {
	my ($value) = @_;

	return () unless defined $value;
	return @{$value} if ref($value) eq 'ARRAY';
	return values %{$value} if ref($value) eq 'HASH';
	return ($value);
}

sub get_service_entries {
	my ($services) = @_;
	my @res;

	return @res unless ref($services);
	if (ref($services) eq 'HASH') {
		foreach my $name (keys %{$services}) {
			push @res, [$name, $services->{$name}];
		}
	} elsif (ref($services) eq 'ARRAY') {
		foreach my $service (@{$services}) {
			push @res, [$service->{name} || '', $service];
		}
	}

	return @res;
}

sub is_exporter_service {
	my ($name, $service) = @_;
	my $service_name = lc($name || $service->{name} || '');
	my $command = lc($service->{command} || '');

	return $service_name =~ /(?:prometheus|node[-_]?exporter|exporter)/ ||
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

sub get_hosts_prometheusinfo {
	my ($hosts, $hosttemplates) = @_;
	my @res;

	return @res unless ref($hosts) eq 'HASH';

	foreach my $host (sort keys %{$hosts}) {
		my $hi = $hosts->{$host};
		next if ($hi->{ignore} || 'no') eq 'yes';

		my @services = get_service_entries($hi->{service});
		foreach my $template_id (as_list($hi->{template})) {
			my $template = $hosttemplates->{$template_id};
			push @services, get_service_entries($template->{service}) if ref($template) eq 'HASH';
		}

		my ($service_entry) = grep { is_exporter_service($_->[0], $_->[1]) } @services;
		if ($service_entry) {
			my $address = $hi->{ip} || $host;
			my ($port, $path, $scheme) = exporter_settings($service_entry->[1]->{command});
			push @res, {
				host => $host,
				address => $address,
				port => 0 + $port,
				path => $path,
				scheme => $scheme,
				target => target_address($address, $port),
			};
		}

		if (defined $hi->{host}) {
			push @res, get_hosts_prometheusinfo($hi->{host}, $hosttemplates);
		}
	}

	return @res;
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

sub replace_dashboard_values {
	my ($node, $datasource_name) = @_;

	if (ref($node) eq 'HASH') {
		foreach my $key (keys %{$node}) {
			if ($key eq 'datasource' && !ref($node->{$key}) && defined($node->{$key}) && $node->{$key} eq '${DS_PROMETHEUS}') {
				$node->{$key} = $datasource_name;
			} else {
				replace_dashboard_values($node->{$key}, $datasource_name);
			}
		}
	} elsif (ref($node) eq 'ARRAY') {
		replace_dashboard_values($_, $datasource_name) foreach @{$node};
	}
}

sub clean_legacy_targets {
	my ($node) = @_;

	if (ref($node) eq 'HASH') {
		if (ref($node->{targets}) eq 'ARRAY') {
			foreach my $target (@{$node->{targets}}) {
				next unless ref($target) eq 'HASH';
				delete @{$target}{qw(bucketAggs dsType metrics query timeField)};
			}
		}
		clean_legacy_targets($_) foreach values %{$node};
	} elsif (ref($node) eq 'ARRAY') {
		clean_legacy_targets($_) foreach @{$node};
	}
}

sub configure_host_variable {
	my ($dashboard, $instance) = @_;
	my $templating = $dashboard->{templating} ||= {};
	my $host_variable;

	foreach my $variable (@{ref($templating->{list}) eq 'ARRAY' ? $templating->{list} : []}) {
		if (ref($variable) eq 'HASH' && ($variable->{name} || '') eq 'host') {
			$host_variable = $variable;
			last;
		}
	}

	$host_variable ||= {};
	$host_variable->{name} = 'host';
	$host_variable->{label} = 'host';
	$host_variable->{type} = 'query';
	$host_variable->{query} = 'label_values(up, instance)';
	$host_variable->{refresh} = 1;
	$host_variable->{hide} = 0;
	$host_variable->{includeAll} = JSON::XS::false;
	$host_variable->{multi} = JSON::XS::false;
	$host_variable->{current} = {
		selected => JSON::XS::true,
		text => $instance,
		value => $instance,
	};
	$host_variable->{options} = [{
		selected => JSON::XS::true,
		text => $instance,
		value => $instance,
	}];
	$templating->{list} = [$host_variable];
}

sub load_json {
	my ($filename) = @_;
	open(my $file, '<', $filename) || die "can't read $filename: $!";
	local $/;
	my $json = <$file>;
	close($file) || die "can't close $filename: $!";
	return decode_json($json);
}

sub write_json {
	my ($filename, $value) = @_;
	open(my $file, '>', $filename) || die "can't write $filename: $!";
	binmode($file, ':encoding(UTF-8)');
	my $encoder = JSON::XS->new->canonical(1)->pretty(1);
	print {$file} $encoder->encode($value);
	close($file) || die "can't close $filename: $!";
}

sub write_datasources {
	my ($targets) = @_;
	my $filename = "$datasource_dir/datasources.yaml";

	make_path($datasource_dir);
	open(my $file, '>', $filename) || die "can't write $filename: $!";
	binmode($file, ':encoding(UTF-8)');
	print {$file} "apiVersion: 1\n";
	print {$file} "prune: true\n";
	if (!@{$targets}) {
		print {$file} "datasources: []\n";
		close($file) || die "can't close $filename: $!";
		return;
	}

	print {$file} "datasources:\n";
	my $index = 0;
	foreach my $target (@{$targets}) {
		my $hash = substr(sha1_hex($target->{host}), 0, 24);
		my $name = 'Prometheus - ' . $target->{host};
		my $uid = 'prometheus-' . $hash;
		$target->{datasource_name} = $name;
		$target->{datasource_uid} = $uid;
		print {$file} "  - name: " . yaml_quote($name) . "\n";
		print {$file} "    uid: " . yaml_quote($uid) . "\n";
		print {$file} "    type: prometheus\n";
		print {$file} "    access: proxy\n";
		print {$file} "    url: http://127.0.0.1:9090\n";
		print {$file} "    orgId: 1\n";
		print {$file} "    isDefault: " . ($index++ ? 'false' : 'true') . "\n";
		print {$file} "    editable: false\n";
		print {$file} "    jsonData:\n";
		print {$file} "      httpMethod: POST\n";
		print {$file} "      manageAlerts: false\n";
	}
	close($file) || die "can't close $filename: $!";
}

sub write_dashboards {
	my ($targets) = @_;

	make_path($dashboard_dir);
	make_path($home_dashboard_dir);
	unlink glob("$dashboard_dir/*.json");
	unlink $home_dashboard_file;
	return unless @{$targets};
	return unless -f $source_file;

	my $source = load_json($source_file);
	my $is_first = 1;
	foreach my $target (@{$targets}) {
		my $dashboard = decode_json(encode_json($source));
		my $hash = substr(sha1_hex($target->{host}), 0, 24);
		$dashboard->{id} = undef;
		$dashboard->{uid} = 'linux-' . $hash;
		$dashboard->{title} = 'Linux Servers - ' . $target->{host};
		delete $dashboard->{__inputs};
		configure_host_variable($dashboard, $target->{target});
		clean_legacy_targets($dashboard);
		replace_dashboard_values($dashboard, $target->{datasource_name});
		write_json("$dashboard_dir/linux-servers-$hash.json", $dashboard);
		write_json($home_dashboard_file, $dashboard) if $is_first;
		$is_first = 0;
	}
}

sub main {
	my $config = XMLin('nag.xml', ForceArray => 1);
	my $hosttemplates = $config->{hosttemplate} || {};
	my @targets = get_hosts_prometheusinfo($config->{host}, $hosttemplates);

	warn "No Prometheus exporter service found in nag.xml\n" unless @targets;
	warn "Grafana dashboard source is missing: $source_file\n" unless -f $source_file;

	write_datasources(\@targets);
	write_dashboards(\@targets);
	return 0;
}

exit main(@ARGV);