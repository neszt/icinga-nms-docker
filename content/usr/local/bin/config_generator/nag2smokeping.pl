#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use XML::Simple;
use Getopt::Std;
use File::Basename;

use vars qw($types $dstdir);

sub VERSION_MESSAGE {#{{{
	print basename($0) . " 0.0.1\n";
}#}}}

sub HELP_MESSAGE {#{{{
	print "Usage: " . basename($0) . " [OPTIONS...]\n";
	print "\n";
	print "-d    debug level [ 1 .. 5 ]\n";
}#}}}

sub dir_dirs_to_hash {#{{{
	my $dir = shift || return {};

	my $r = {};

	opendir(DIR, $dir) || die "can't opendir $dir: $!";
	while (my $file = readdir(DIR)) {
		next unless (-d "$dir/$file");
		next if ($file =~ /^\./);
		$r->{$file} = 1;
	}
	closedir(DIR);

	return $r;
}#}}}

sub get_hosts {#{{{
	my $hosts = shift;

	my @res;
	foreach my $host ( sort keys %{$hosts} ) {
		my $data = {};
		$data->{host} = $host;
		$data->{ip} = $hosts->{$host}->{ip} || "";
		$data->{type} = $hosts->{$host}->{type} || "";
		foreach my $service ( keys %{$hosts->{$host}->{service}} ) {
			my $command = $hosts->{$host}->{service}->{$service}->{command};
			$data->{services}->{$command} = 1;
		}
		push @res, $data;

		if ( defined $hosts->{$host}->{host} ) {
			push @res, get_hosts($hosts->{$host}->{host});
		}
	}

	return @res;
}#}}}

sub main {#{{{
	my $opts = {};

	$Getopt::Std::STANDARD_HELP_VERSION = 1;
	getopts('v', $opts);

	my $config = XMLin('nag.xml', ForceArray => 1);

	print "+ Nagios\n\n";
	print "probe = FPing\n\n";
	print "menu = Nagios\n";
	print "title = Nagios\n\n";

	my $probes = {
		ping => {
			0 => 'FPing',
			1 => 'FPing2',
			2 => 'FPing3',
			3 => 'FPing4',
		},
	};
	my $check_map = {
		'check_ssh' => {
			probe => 'SSH',
			probe_postfix => 'ssh',
			menu_postfix => 'SSH',
		},
		'check_ssh_port' => {
			probe => 'SSH',
			probe_postfix => 'ssh',
			menu_postfix => 'SSH',
			arg1 => 'port',
		},
		'check_http' => {
			probe => 'EchoPingHttp',
			probe_postfix => 'http',
			menu_postfix => 'Http',
		},
		'check_https' => {
			probe => 'EchoPingHttps',
			probe_postfix => 'https',
			menu_postfix => 'Https',
		},
		'check_dig' => {
			probe => 'DNS',
			probe_postfix => 'dns',
			menu_postfix => 'DNS',
		},
	};

	my $hosts = {};

	my $i = 0;
	my $mod = keys %{$probes->{ping}};
	foreach my $e ( get_hosts($config->{host}) ) {
		my $host = $e->{host};
		my $ip = $e->{ip} || $host;

		if ( $host =~ / / ) {
			die "Space not allowed in hostname: [$host]!";
		}

		my $host_az = $host;
		$host_az =~ s/\./-/g;
		$host_az =~ s/\//-/g;

		my $rem = $i % $mod;
		my $probe = $probes->{ping}->{$rem};
		print "++ $host_az\n";
		print "probe = $probe\n";
		print "menu = $host\n";
		print "title = $host" . ($e->{ip} ? " ($e->{ip})" : '') . "\n";
		print "host = $ip\n\n";
		foreach my $service ( keys %{$e->{services}} ) {
			my @args = split('!', $service);
			my $command = shift @args;
			if ( defined $check_map->{$command} ) {
				my $ci = $check_map->{$command};
				my $probe_service = $ci->{probe};
				my $probe_postfix = $ci->{probe_postfix};
				my $menu_postfix = $ci->{menu_postfix};
				if ( defined $ci->{arg1} ) {
					$probe_postfix .= $args[0];
					$menu_postfix .= " ($args[0])";
				}
				print "+++ $host_az-$probe_postfix\n";
				print "probe = $probe_service\n";
				print "menu = $host $menu_postfix\n";
				print "title = $host $menu_postfix\n";
				if ( defined $ci->{arg1} ) {
					print "$ci->{arg1} = $args[0]\n";
				}
				print "host = $ip\n\n";
			}
		}
		$i++;
	}

	return 0;
}#}}}

exit main(@ARGV);
