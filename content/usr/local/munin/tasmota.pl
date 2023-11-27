#!/usr/bin/perl
# nagios: -epn

use strict;
use warnings;
use JSON::XS;
use Data::Dumper;

my $cache_filename = '/tmp/tasmota.cache';

sub read_file {#{{{
	my $filename = shift;
	my $encoding = shift;

	my $data;

	open(my $fh, '<', $filename) or die "cannot open file $filename";
	if ( $encoding ) {
		binmode($fh, ":encoding($encoding)");
	}

	{
		local $/;
		$data = <$fh>;
	}
	close($fh);

	return $data;
}#}}}

sub get_ds {#{{{
	my $ip = shift;
	my $type = shift;

	$ip =~ s/\./_/g;

	return "$type";
}#}}}

sub get_config {#{{{
	my $ip = shift;
	my $type = shift;

	my $label_map = {
		'Current' => 'Amper',
		'Today' => 'KWh',
		'Yesterday' => 'KWh',
		'Power' => 'Watt',
		'Factor' => '-',
		'ReactivePower' => 'VAr',
		'Voltage' => 'V',
		'ApparentPower' => 'VA',
		'WifiSignal' => 'dBm',
		'WifiRSSI' => 'unit',
		'Uptime' => 'day',
	};
	my $type_map = {
		'Current' => 'GAUGE',
		'Today' => 'GAUGE',
		'Yesterday' => 'GAUGE',
		'Power' => 'GAUGE',
		'Factor' => 'GAUGE',
		'ReactivePower' => 'GAUGE',
		'Voltage' => 'GAUGE',
		'ApparentPower' => 'GAUGE',
		'WifiSignal' => 'GAUGE',
		'WifiRSSI' => 'GAUGE',
		'Uptime' => 'GAUGE',
	};
	my $draw_map = {
		'Current' => 'AREA',
		'Today' => 'AREA',
		'Yesterday' => 'AREA',
		'Power' => 'AREA',
		'Factor' => 'AREA',
		'ReactivePower' => 'AREA',
		'Voltage' => 'AREA',
		'ApparentPower' => 'AREA',
		'WifiSignal' => 'LINE1',
		'WifiRSSI' => 'LINE2',
		'Uptime' => 'AREA',
	};
	my $info_map = {
		'Current' => 'Amper used',
		'Today' => 'KWh',
		'Yesterday' => 'KWh',
		'Power' => 'Watt used',
		'Factor' => '-',
		'ReactivePower' => 'VAr',
		'Voltage' => 'V',
		'ApparentPower' => 'VA',
		'WifiSignal' => 'dBm',
		'WifiRSSI' => 'unit',
		'Uptime' => 'day',
	};
	my $min_map = {
		'Current' => 0,
		'Today' => 0,
		'Yesterday' => 0,
		'Power' => 0,
		'Factor' => 0,
		'ReactivePower' => 0,
		'Voltage' => 0,
		'ApparentPower' => 0,
		'WifiSignal' => -100,
		'WifiRSSI' => 0,
		'Uptime' => 0,
	};
	my $category_map = {
		'Current' => 'power',
		'Today' => 'power',
		'Yesterday' => 'power',
		'Power' => 'power',
		'Factor' => 'power',
		'ReactivePower' => 'power',
		'Voltage' => 'power',
		'ApparentPower' => 'power',
		'WifiSignal' => 'network',
		'WifiRSSI' => 'network',
		'Uptime' => 'system',
	};

	my $ds = get_ds($ip, $type);
	my $o = '';
	$o .= "graph_title Tasmota $ip $type\n";
	$o .= "graph_vlabel $ip $type\n";
	$o .= "graph_category $category_map->{$type}\n";
	$o .= "${ds}.label $type ($label_map->{$type})\n";
	$o .= "${ds}.draw $draw_map->{$type}\n";
	$o .= "${ds}.min $min_map->{$type}\n";
	$o .= "${ds}.type $type_map->{$type}\n";
	$o .= "${ds}.info $info_map->{$type}\n";

	return $o;
}#}}}

sub curl_get_data {#{{{
	my $ip = shift;
	my $cmnd = shift;

	my $cmd = "curl -s -m 5 -X GET http://$ip/cm?cmnd=$cmnd";

	my $json_output = '';
	open(my $ff, "$cmd |");
	while (<$ff>) {
		$json_output .= $_;
	}
	close($ff);

	my $data = {};
	eval {
		$data = JSON::XS->new->decode($json_output);
	};

	return $data;
}#}}}

sub cache_data {#{{{
	my $ips = shift;

	my $data = {};

	foreach my $ip ( sort keys %{$ips} ) {
		# "ENERGY" : {
		#	'ReactivePower' => 12,
		#	'Voltage' => 235,
		#	'Today' => '0.062',
		#	'ApparentPower' => 13,
		#	'TotalStartTime' => '2001-01-01T00:00:00',
		#	'Current' => '0.054',
		#	'Power' => 4,
		#	'Factor' => '0.35',
		#	'Yesterday' => '0.119',
		#	'Total' => '3.159'
		# },

		my $data_status_2010 = curl_get_data($ip, 'status%2010');
		$data->{$ip} = $data_status_2010->{StatusSNS}->{ENERGY};

		# "Wifi" : {
		#	"AP" : 1,
		#	"BSSId" : "00:11:22:33:44:55",
		#	"Channel" : 9,
		#	"Downtime" : "0T03:30:58",
		#	"LinkCount" : 48,
		#	"RSSI" : 48,
		#	"SSId" : "***********",
		#	"Signal" : -76
		# },

		my $data_state = curl_get_data($ip, 'state');
		next if ! keys %{$data_state};
		$data->{$ip}->{Wifi} = $data_state->{Wifi};
		$data->{$ip}->{WifiSignal} = $data_state->{Wifi}->{Signal};
		$data->{$ip}->{WifiRSSI} = $data_state->{Wifi}->{RSSI};
		$data->{$ip}->{Uptime} = sprintf("%3.2f", $data_state->{UptimeSec} / 86400);
	}

	open(my $ff, ">$cache_filename");
	print $ff JSON::XS->new->canonical()->pretty()->encode($data);
	close($ff);
}#}}}

sub get_tasmota_list {#{{{
	my $dir = "/etc/munin/plugins/";

	my $r = {};
	opendir (DIR, $dir) or die $!;
	while (my $file = readdir(DIR)) {
		$file =~ /^_tasmota__(.*?)__(.*?)$/ or next;
		$r->{$1} = 1;
	}

	return $r;
}#}}}

sub main {#{{{
	my $arg = shift // '';

	if ( $arg eq 'cache' ) {
		my $tasmota_list = get_tasmota_list();
		cache_data($tasmota_list);
		return 0;
	}

	my $host;
	my $type;
	if ( $0 =~ /_tasmota__(.*?)__(.*?)$/ ) {
		$host = $1;
		$type = $2;
	} else {
		$host = shift // die 'Host not found!';
		$type = shift // die 'Type not found!';
	}

	if ( $arg eq 'config' ) {
		print "host_name $host\n";
		print get_config($host, $type);
	} elsif ( $arg eq 'check' ) {
		my $json = read_file($cache_filename);
		my $data = JSON::XS->new->decode($json);
		my $ds = get_ds($host, $type);
		my $value = $data->{$host}->{$type};
		while ( my $filter = shift ) {
			# check host type "warn<50" "crit:<30"
			$filter =~ /^(w|c):([lge]):(-?[0-9]+)$/ or die "Invalid filter: [$filter]";
			my $level = $1;
			my $return_level = $level eq 'warn' ? "WARNING" : "CRITICAL";
			my $return_value = $level eq 'warn' ? 1 : 2;

			my $op_map = {
				'g' => '>',
				'l' => '<',
				'e' => '=',
			};
			my $op = $2;
			my $filter_value = $3;
			if (
				( $op eq 'l' && $value < $filter_value ) ||
				( $op eq 'g' && $value > $filter_value ) ||
				( $op eq 'e' && $value == $filter_value )
			) {
				print "$return_level - [value: $value] ( $op_map->{$op} $filter_value )\n";
				return $return_value;
			}
		}
		print "OK: [value: $value]\n";
		return 0;
	} else {
		if ( -f $cache_filename ) {
			my $json = read_file($cache_filename);
			my $data = JSON::XS->new->decode($json);
			my $ds = get_ds($host, $type);
			print "${ds}.value $data->{$host}->{$type}\n";
		}
	}

	return 0;
}#}}}

exit main(@ARGV);
