#!/usr/bin/perl
# nagios: -epn

use strict;
use warnings;
use DBI;
binmode(STDOUT, ":utf8");

$ENV{PGPASSFILE} = '/var/lib/nagios/pgpass';

sub main {
        my $host = shift // die "Must give host!";
        my $port = 5432;
        my $dbname = 'thermo';
        my $username = 'nagios'; # password in pgpass
        my $warn = 600;
        my $crit = 7200;

        my $errors = {};
        my $warnings = {};
        my $oks = {};

        my $dbh = DBI -> connect("dbi:Pg:dbname=$dbname;host=$host;port=$port", $username, undef, {AutoCommit => 0, RaiseError => 1} ) or die $DBI::errstr;

        my $sql = "SELECT id, name, last_tsf FROM center_sensor";
        my $res = $dbh->prepare($sql) or print $dbh->errstr;
        $res->execute() or print $dbh->errstr;
        my $now = time;
        while ( my $row = $res->fetchrow_hashref() ) {
                my $name = $row->{id} . '_' . $row->{name} . ':';
                my $diff = sprintf('%3.2f', $now - $row->{last_tsf});
                if ( $diff > $crit ) {
                        $errors->{$name . $diff} = 1;
                } elsif ( $diff > $warn ) {
                        $warnings->{$name . $diff} = 1;
                } else {
                        $oks->{$name . $diff} = 1;
                }
        }

        $dbh->disconnect();

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
}

exit main(@ARGV);
