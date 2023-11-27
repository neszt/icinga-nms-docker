#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use XML::Simple;
use Getopt::Std;
use File::Basename;

sub VERSION_MESSAGE {#{{{
	print basename($0) . " 0.0.1\n";
}#}}}

sub HELP_MESSAGE {#{{{
	print "Usage: " . basename($0) . " [OPTIONS...]\n";
	print "\n";
	print "-d    debug level [ 1 .. 5 ]\n";
	print "-h    hostname of ganeti master node\n";
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
	foreach my $host ( keys %{$hosts} ) {
		my $ip = $hosts->{$host}->{ip} || "";
		my $type = $hosts->{$host}->{type} || "";

		push @res, { ip => $ip, host => $host, type => $type};
		if ( defined $hosts->{$host}->{host} ) {
			push @res, get_hosts($hosts->{$host}->{host});
		}
	}
	return @res;
}#}}}

sub main {#{{{
	my $opts = {};

	$Getopt::Std::STANDARD_HELP_VERSION = 1;
	getopts('vh:', $opts);

	my $ganeti_master_node = $opts->{h};
       	if ( !$ganeti_master_node ) {
		die "Must give ganeti master node!";
	}

	my $config = XMLin('/root/nagiosconfig/nag.xml', ForceArray => 1);

	my $hosts = {};

	foreach my $element ( get_hosts($config->{host}) ) {
		my $host = $element->{host};
		my $ip = $element->{ip} || $host;

		if ( $host =~ / / ) {
			die "Space not allowed in hostname: [$host]!";
		}

		$hosts->{$host}->{ip} = $ip;
	}

	open(my $ff, "ssh $ganeti_master_node gnt-instance list -o name,status |");

	while (<$ff>) {
		chomp;
		/^Instance/ and next;
		/^(.*?)[ ]+running$/ or next;
		my $host = $1;

		if ( !defined $hosts->{$host} ) {
			print "WARNING: Unknown ganeti host: [$host]\n";
		}
	}
	close($ff);

	return 0;
}#}}}

exit &main(@ARGV);
