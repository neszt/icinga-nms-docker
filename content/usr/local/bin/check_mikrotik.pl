#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Std;
use Data::Dumper;

sub VERSION_MESSAGE {#{{{
	print "$0 v0.1\n";
}#}}}

sub HELP_MESSAGE {#{{{
	print "Usage: $0 [OPTIONS...]\n";
	print "\n";
	print "-h   this help\n";
	print "-U   user\n";
	print "-H   host\n";
	print "-C   cmd\n";
	print "-R   expected regexp in cmd output\n";
	print "-P   predefined cmds [dhcp-lease-mac]\n";
	print "-X   predefined cmds expectation [mac]\n";
}#}}}

sub main {

	$Getopt::Std::STANDARD_HELP_VERSION = 1;
	my $opts = {};
	getopts("U:H:C:X:P:", $opts);

	my $errors = {};
	my $warnings = {};
	my $oks = {};

	my $dst = "$opts->{U}\@$opts->{H}";

	if ( $opts->{C} ) {
		$dst .= " $opts->{C}";
	} elsif ( $opts->{P} ) {
		if ( $opts->{P} eq 'dhcp-lease-mac' ) {
			$dst .= " ip dhcp-server lease print without-paging terse";
		} else {
			die "Unknown predefined command: [$opts->{C}]!";
		}
	} else {
		die "One of [cmd] or [predefined cmd] must give!";
	}

	my $data;
	open(my $ff, "ssh $dst |");
	while (<$ff>) {
		if ( $opts->{P} ) {
			if ( $opts->{P} eq 'dhcp-lease-mac' ) {
				if ( /address=(.*?) .*mac-address=(.*?) .*host-name=(.*)/ ) {
					$data->{$2} = {};
					my $i = $data->{$2};
					$i->{ip} = $1;
					$i->{hostname} = $3;
				}
			}
		} else {
			if ( /$opts->{R}/ ) {
				$data->{res} = 1;
			}
		}
	}
	close($ff);

	if ( $opts->{P} ) {
		if ( $opts->{P} eq 'dhcp-lease-mac' ) {
			if ( defined $data->{ $opts->{X} } ) {
				$oks->{MAC_FOUND} = 1;
			} else {
				$errors->{MAC_NOT_FOUND} = 1;
			}
		}
	} else {
		if ( $data->{res} ) {
			$oks->{REGEXP_FOUND} = 1;
		} else {
			$errors->{REGEXP_NOT_FOUND} = 1;
		}
	}

	if ( keys %{$errors} ) {
		print "CRITICAL: " . join(' ', sort keys %{$errors} ) . "\n";
		return 2;
	} elsif ( keys %{$warnings} ) {
		print "WARNING: " . join(' ', sort keys %{$warnings} ) . "\n";
		return 1;
	} else {
		print "OK: " . join(' ', sort keys %{$oks} ) . "\n";
		return 0;
	}

	print Dumper($data);
}

exit main(@ARGV);
