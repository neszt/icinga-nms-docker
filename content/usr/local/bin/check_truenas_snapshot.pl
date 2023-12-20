#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Std;
use LWP;
use JSON::XS;

sub VERSION_MESSAGE {#{{{
	print "$0 v0.1\n";
}#}}}

sub HELP_MESSAGE {#{{{
	print "Usage: $0 [OPTIONS...]\n";
	print "\n";
	print "-h    this help\n";
	print "-s    server name\n";
	print "-a    api key\n";
	print "-d    dataset name\n";
	print "-m    snapshot mask, default: auto-YMD.H00-2w\n";
}#}}}

sub truenas_api_call {#{{{
	my $ua = shift;
	my $url = shift;

	my $req = HTTP::Request->new(GET => $url);
	my $resp = $ua->request($req);

	if ( !$resp->is_success() ) {
		return { error_code => $resp->code() };
	}

	my $content_json = $resp->content;
	my $data = JSON::XS->new->decode($content_json);

	return $data;
}#}}}

sub build_url {#{{{
	my $server_name = shift;
	my $dataset_name = shift;
	my $snapshot_mask = shift;

	my $snapshot_id = $dataset_name . '@' . $snapshot_mask;

	my @ido = localtime(time);
	my $year = $ido[5] + 1900;
	my $month = sprintf("%02d", $ido[4] + 1);
	my $day = sprintf("%02d", $ido[3]);
	my $hour = sprintf("%02d", $ido[2]);

	$snapshot_id =~ s/Y/$year/g;
	$snapshot_id =~ s/M/$month/g;
	$snapshot_id =~ s/D/$day/g;
	$snapshot_id =~ s/H/$hour/g;
	my $snapshot_id_info = $snapshot_id;
	$snapshot_id =~ s/\//%2F/g;
	$snapshot_id =~ s/\@/%40/g;

	return ("https://$server_name/api/v2.0/zfs/snapshot/id/$snapshot_id", $snapshot_id_info);
}#}}}

sub main {#{{{

	my $options = {};
	$Getopt::Std::STANDARD_HELP_VERSION = 1;
	getopts('hs:a:d:m:', $options);

	my $server_name = $options->{s};
	my $api_key = $options->{a};
	my $dataset_name = $options->{d};
	my $snapshot_mask = $options->{m};

	if ( !$server_name || !$api_key || !$dataset_name ) {
		HELP_MESSAGE();
		return 0;
	}

	my $ua = LWP::UserAgent->new();
	$ua->ssl_opts( verify_hostname => 0, SSL_verify_mode => 0x00 );

	my $headers = HTTP::Headers->new(
		'Authorization' => "Bearer $api_key",
	);
	$ua->default_headers($headers);
	$ua->env_proxy();

	my ($url, $snapshot_id_info) = build_url($server_name, $dataset_name, $snapshot_mask);
	my $data = truenas_api_call($ua, $url);

	my $r;
	my $output_string;

	if ( my $code = $data->{error_code} ) {
		if ( $code == 404 ) {
			$r = 1;
			$output_string = "No snapshot found. [$snapshot_id_info]";
		} else {
			$r = 2;
			$output_string = "Http code: $code";
		}
	} elsif ( $data->{type} && $data->{type} eq 'SNAPSHOT' ) {
		$r = 0;
		$output_string = "Snapshot id [$data->{id}]";
	} else {
		$r = 1;
		$output_string = "No snapshot found. [$snapshot_id_info]";
	}

	if ( $r == 2 ) {
		print "CRITICAL: $output_string\n";
	} elsif ( $r == 1 ) {
		print "WARNING: $output_string\n";
	} else {
		print "OK: $output_string\n";
	}

	return $r;
}#}}}

exit main(@ARGV);
