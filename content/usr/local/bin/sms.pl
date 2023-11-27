#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Getopt::Std;
use Frontier::Client;
use LWP::UserAgent;
use URI::Encode;
use Encode;
use JSON::XS;
use Data::UUID;
use LWP;
use URI;

#
# SMS_TYPE
#
# SMS_RPC_HOST
# SMS_RPC_PORT
# SMS_RPC_URI
# SMS_RPC_FUNC
#
# SMS_GOIP_URL
# SMS_GOIP_USER
# SMS_GOIP_PASS
# SMS_GOIP_PROVIDER
# SMS_GOIP_METHOD
#
# SMS_GW_URL
# SMS_GW_USER
# SMS_GW_APIKEY
#

sub VERSION_MESSAGE {#{{{
	print "$0 v0.1\n";
}#}}}

sub HELP_MESSAGE {#{{{
	print "Usage: $0 [OPTIONS...]\n";
	print "\n";
	print "-h   this help\n";
	print "-t   type (RPC, GOIP, GW)\n";
	print "-r   recipient (sms phone number)\n";
	print "-m   message\n";
}#}}}

sub sms_rpc {#{{{
	my $input = shift;

	my $dest = $input->{recipient};
	my $msg = $input->{message};
	my $class = $input->{class} // 'ALERT';

	my $host = $ENV{SMS_RPC_HOST};
	my $port = $ENV{SMS_RPC_PORT};
	my $uri = $ENV{SMS_RPC_URI};
	my $func = $ENV{SMS_RPC_FUNC};

	my $server_url = 'http://' . $host . ':' . $port . '/' . $uri;
	my $server = Frontier::Client->new(url => $server_url, encoding => 'UTF-8');

	my $result = $server->call($func, $dest, $msg, 3, '', {});
}#}}}

sub sms_goip {#{{{
	my $input = shift;

	my $smsnum = $input->{recipient};
	my $memo = $input->{message};

	my $url = $ENV{SMS_GOIP_URL};
	my $user = $ENV{SMS_GOIP_USER};
	my $pass = $ENV{SMS_GOIP_PASS};
	my $provider = $ENV{SMS_GOIP_PROVIDER};
	my $method = $ENV{SMS_GOIP_METHOD};

	my $args = {
		username => $user,
		password => $pass,
		smsprovider => $provider,
		method => $method,
		smsnum => $smsnum,
		Memo => Encode::decode('UTF-8', $memo),
	};

	my $ua = LWP::UserAgent->new();
	my $req = HTTP::Request->new(POST => $url);
	$req->content_type('application/x-www-form-urlencoded');
	$req->content(join('&', map { "$_=" . URI::Encode::uri_encode($args->{$_}) } keys %$args));

	my $resp = $ua->request($req);
	die $resp->status_line unless $resp->is_success();
}#}}}

sub sms_gw {#{{{
	my $input = shift;

	my $recip = $input->{recipient};
	my $msg = Encode::decode('UTF-8', $input->{message});
	my $class = $input->{class} // 'ALERT';

	my $sms_gw_url = $ENV{SMS_GW_URL} // die "SMS_GW_URL env variable is not set!";
	my $sms_gw_user = $ENV{SMS_GW_USER} // die "SMS_GW_USER env variable is not set!";
	my $sms_gw_apikey = $ENV{SMS_GW_APIKEY} // die "SMS_GW_APIKEY env variable is not set!";

	my $url = URI->new($sms_gw_url);
	$url->query_form(
		username => $sms_gw_user,
		api_key => $sms_gw_apikey,
	);

	my $om = {
		message_id => Data::UUID->new()->create_str(),
		number => $recip,
		message => $msg,
		message_class => $class,
	};

	my $ua = LWP::UserAgent->new();
	my $req = HTTP::Request->new(POST => $url->as_string());
	$req->content_type('application/json');
	$req->content(JSON::XS->new()->utf8(1)->encode($om));

	my $resp = $ua->request($req);
	die $resp->status_line unless $resp->is_success();

	print "URI: " . $resp->header('Location') . "\n";
}#}}}

sub main {#{{{

	$Getopt::Std::STANDARD_HELP_VERSION = 1;
	my $opts = {};
	getopts("t:r:m:", $opts);

	my $type = $opts->{t} // $ENV{SMS_TYPE} // die 'Must give type for SMS send!';
	my $input = {};
	$input->{recipient} = $opts->{r} // die 'Must give recipient for SMS send!';
	$input->{message} = $opts->{m} // die 'Must give message for SMS send!';

	if ( $type eq 'RPC' ) {
		sms_rpc($input);
	} elsif ( $type eq 'GOIP' ) {
		sms_goip($input);
	} elsif ( $type eq 'GW' ) {
		sms_gw($input);
	}
}#}}}

exit main(@ARGV);
