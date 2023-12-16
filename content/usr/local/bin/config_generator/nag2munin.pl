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

sub get_hosts_munininfo {#{{{
	my $hosts = shift;
	my $hosttemplates = shift;

	my @res;
	foreach my $host ( sort keys %{$hosts} ) {
		my $data = {};
		$data->{host} = $host;
		$data->{ip} = $hosts->{$host}->{ip} || "";
		$data->{type} = $hosts->{$host}->{type} || "";
		if ( defined $hosts->{$host}->{service} && defined $hosts->{$host}->{service}->{munin} ) {
			$data->{munin} = 1;
		}
		if ( my $hosttemplate = $hosts->{$host}->{template} ) {
			if ( defined $hosttemplates->{$hosttemplate} && defined $hosttemplates->{$hosttemplate}->{service}->{munin} ) {
				$data->{munin} = 1;
			}
		}
		push @res, $data;
		if ( defined $hosts->{$host}->{host} ) {
			push @res, get_hosts_munininfo($hosts->{$host}->{host}, $hosttemplates);
		}
	}
	return @res;
}#}}}

sub main {#{{{
	my $opts = {};

	$Getopt::Std::STANDARD_HELP_VERSION = 1;
	getopts('v', $opts);

	my $config = XMLin('nag.xml', ForceArray => 1);

	my $tasmota_pow_r2_map = {
		'Current' => 1,
		'Today' => 1,
		'Yesterday' => 1,
		'Power' => 1,
		'Factor' => 1,
		'ReactivePower' => 1,
		'Voltage' => 1,
		'ApparentPower' => 1,
		'WifiSignal' => 1,
		'WifiRSSI' => 1,
		'Uptime' => 1,
	};

	system("rm -rf /etc/munin/plugins/_tasmota__*");

	foreach my $element ( get_hosts_munininfo($config->{host}, $config->{hosttemplate}) ) {
		if ( $element->{munin} ) {
			my $host = $element->{host};
			my $ip = $element->{ip} || $host;
			$host =~ /\.(.+?\..+?)$/;
			my $base = $1 || $host;

			my $address = $host || $ip;
			print "[$base;$host]\n";
			print "\taddress $ip\n\n";
		}
		if ( $element->{type} eq 'Sonoff-POW-R2' ) {
			my $host = $element->{host};
			my $ip = $element->{ip} || $host;
			$host =~ /\.(.+?\..+?)$/;
			my $base = $1 || $host;

			my $address = $host || $ip;
			print "[$base;$host]\n";
			print "\taddress 127.0.0.1\n\n";

			foreach my $e ( sort keys %{$tasmota_pow_r2_map} ) {
				my $dst = "/etc/munin/plugins/_tasmota__${host}__$e";
				system("ln -sf /usr/local/munin/tasmota.pl $dst");
			}
		}
	}

	return 0;
}#}}}

exit main(@ARGV);
