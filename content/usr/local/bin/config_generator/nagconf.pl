#!/usr/bin/perl

use strict;
use warnings;
use XML::Simple;
$XML::Simple::PREFERRED_PARSER = 'XML::Parser';

my $map = {};
my $check_ping_cmd = $ENV{ICINGA_FORCE_PING4} ? 'check_ping_4' : 'check_ping';
my $check_host_alive_cmd = $ENV{ICINGA_FORCE_PING4} ? 'check-host-alive_4' : 'check-host-alive';

sub put {#{{{
	my $string = shift;

	print $string;
}#}}}

sub gen_contacts {#{{{
	my $cfg = shift;

	foreach my $e ( @{$cfg->{person} } ) {
		my $epager = $e->{epager} // '';
		my $epager_type;
		if ( $epager =~ /^http/ ) {
			$epager_type = 'mattermost';
		} elsif ( $epager =~ /@/ ) {
			$epager_type = 'email';
		} elsif ( $epager =~ /^[0-9+]$/ || 1 ) { # Temp solution to handle all remaining as phone number
			$epager_type = 'phone_number';
		};

		if ( $e->{alert} eq 'yes' && !$epager_type ) {
			die("Can not determine epager: [$epager] type!");
		}

		put("define contact{\n");
		put(" contact_name $e->{id}\n");
		if ( $e->{name} ) {
			put(" alias $e->{name}\n");
		}
		put(" service_notification_period 24x7\n");
		put(" host_notification_period 24x7\n");
		put(" service_notification_options c,r,w,u\n");
		put(" host_notification_options d,r\n");
		if ( $e->{alert} eq 'no' ) {
			put(" service_notification_commands nop\n");
			put(" host_notification_commands nop\n");
			put(" email dummy\n");
		} elsif ( $epager_type eq 'email' ) {
			put(" service_notification_commands notify-by-email\n");
			put(" host_notification_commands host-notify-by-email\n");
			put(" email $epager\n");
		} elsif ( $epager_type eq 'mattermost' ) {
			put(" service_notification_commands notify-by-mattermost\n");
			put(" host_notification_commands host-notify-by-mattermost\n");
			put(" pager $epager\n");
		} elsif ( $epager_type eq 'phone_number' ) {
			put(" service_notification_commands notify-by-sms\n");
			put(" host_notification_commands host-notify-by-sms\n");
			put(" pager $epager\n");
		}
		put(" }\n");
	}
}#}}}

sub gen_contactgroups {#{{{
	my $cfg = shift;

	foreach my $e ( @{$cfg->{alertgroup} } ) {
		put("define contactgroup{\n");
		put(" contactgroup_name $e->{id}\n");
		if ( $e->{name} ) {
			put(" alias $e->{name}\n");
		}
		put(" members " . join(',', split(' ', $e->{persons} )) . "\n");
		put(" }\n");
	}
}#}}}

sub gen_generic {#{{{

	put("define host{\n");
	put(" name generic-host\n");
	put(" active_checks_enabled 1\n");
	put(" notifications_enabled 1\n");
	put(" event_handler_enabled 1\n");
	put(" flap_detection_enabled 1\n");
	put(" process_perf_data 1\n");
	put(" retain_status_information 1\n");
	put(" retain_nonstatus_information 1\n");
	put(" register 0\n");
	put(" notification_interval 30\n");
	put(" check_period 24x7\n");
	put(" }\n");
	put("define service{\n");
	put(" name generic-service\n");
	put(" active_checks_enabled 1\n");
	put(" passive_checks_enabled 1\n");
	put(" parallelize_check 1\n");
	put(" obsess_over_service 1\n");
	put(" is_volatile 0\n");
	put(" check_freshness 0\n");
	put(" notifications_enabled 1\n");
	put(" event_handler_enabled 1\n");
	put(" flap_detection_enabled 1\n");
	put(" process_perf_data 1\n");
	put(" retain_status_information 1\n");
	put(" retain_nonstatus_information 1\n");
	put(" register 0\n");
	put(" check_interval 3\n");
	put(" retry_interval 3\n");
	put(" notification_interval 30\n");
	put(" check_period 24x7\n");
	put(" notification_period 24x7\n");
	put(" max_check_attempts 3\n");
	put(" }\n");

}#}}}

sub gen_httpservices {#{{{
	my $httpservices = shift;
	my $parent = shift;
	my $parent_company = shift;

	return if ref($httpservices) ne 'ARRAY';

	my $hostname = $parent->{id};

	foreach my $e ( @{$httpservices } ) {
		my $http_port = $e->{'http-port'} // 80;
		my $https_port = $e->{'http-port'} // 443;
		my $domain = $e->{'domain'} // $hostname;
		my $uri = $e->{'uri'} // '/';

		if ( $http_port ) {
			put("# http service for host $hostname on port $http_port for uri $uri\n");
			put("define service {\n");
			put(" use generic-service\n");
			put(" host_name $hostname\n");
			put(" service_description http_${domain}_${uri}\n");
			put(" check_command check_http_service!$http_port!$domain!$uri\n");
			put(" _company $parent_company\n");
			put("}\n");
			put(" \n"); # REMOVE WHEN DONE
		}
		if ( $https_port ) {
			put("# https service for host $hostname on port $https_port\n");
			put("define service {\n");
			put(" use generic-service\n");
			put(" host_name $hostname\n");
			put(" service_description https_${domain}_${uri}\n");
			put(" check_command check_https_service!$https_port!$domain!$uri\n");
			put(" _company $parent_company\n");
			put("}\n");
			put("\n"); # REMOVE WHEN DONE
		}

		put("# SSL Certificate check for host $hostname on port $https_port\n");
		put("define service {\n");
		put(" use generic-service\n");
		put(" host_name $hostname\n");
		put(" service_description https_ssl_cert_$domain\n");
		put(" check_command check_ssl_cert_sni_14d!$domain!$https_port\n");
		put(" _company $parent_company\n");
		put("}\n");
		put(" \n"); # REMOVE WHEN DONE
		put("\n"); # REMOVE WHEN DONE
	}
}#}}}

sub gen_services {#{{{
	my $services = shift;
	my $parent = shift;
	my $parent_hostgroup = shift;
	my $is_template_gen = shift;

	my $hostname = $parent->{id};
	my $pingservice = $parent->{pingservice};
	my $template = $parent->{template};
	my $template_count = $template ? scalar($map->{hosttemplate}->{$template}) : 0;

	my $services_count = ref($services) eq 'ARRAY' ? scalar(@{$services}) : 0;
	my $httpservices = $parent->{'http-service'};
	my $httpservices_count = ref($httpservices) eq 'ARRAY' ? scalar(@{$httpservices}) : 0;

	if (
		!$is_template_gen &&
		( $pingservice eq 'enabled' || $services_count + $template_count + $httpservices_count == 0 )
	) {
		put("define service{\n");
		put(" use generic-service\n");
		put(" host_name $hostname\n");
		put(" service_description PING\n");
		put(" active_checks_enabled 1\n");
		put(" passive_checks_enabled 0\n");
		put(" is_volatile 0\n");
		# if ( $e->{check_period} ) {
		#	put(" check_period $e->{check_period}\n");
		# }
		put(" contact_groups " . $map->{hostgroup_alerts}->{$parent_hostgroup}. "\n");
		put(" notification_period workhours\n");
		put(" notification_options c,w,r\n");
		put(" notifications_enabled " . ( $pingservice eq 'enabled' ? '1' : '0' ) . "\n");
		put(" check_command $check_ping_cmd!100,10%!500,30%\n");
		put(" }\n");
	}

	return if ref($services) ne 'ARRAY';

	foreach my $e ( @{$services } ) {
		my $hostgroup = $e->{hostgroup} || $parent_hostgroup;
		put("define service{\n");
		put(" use generic-service\n");
		put(" host_name $hostname\n");
		put(" service_description $e->{name}\n");
		put(" is_volatile 0\n");
		put(" check_interval " . ( $e->{check_interval} // 3 ) . "\n");
		put(" retry_interval 3\n");
		put(" contact_groups " . $map->{hostgroup_alerts}->{$hostgroup}. "\n");
		put(" notification_interval 120\n");
		put(" check_period 24x7\n");
		my $unknown = $e->{unknown} // 'yes';
		my $warnings = $e->{warnings} // 'yes';
		put(" notification_options c,r" . ( $unknown eq 'yes' ? ',u' : '' ) . ( $warnings eq 'yes' ? ',w' : '' ) . "\n");
		if ( !$e->{active} ) {
			put(" active_checks_enabled 0\n");
		}
		if ( $e->{check_period} ) {
			put(" notification_period $e->{check_period}\n");
		}
		put(" notifications_enabled 1\n");
		put(" check_command $e->{command}\n");
		put(" }\n");
	}
}#}}}

sub gen_hosts {#{{{
	my $hosts = shift;
	my $parent_id = shift;
	my $parent_hostgroup = shift;
	my $parent_company = shift;

	return if ref($hosts) ne 'ARRAY';

	foreach my $e ( @{$hosts } ) {
		next if $e->{ignore} eq 'yes';
		my $hostgroup = $e->{hostgroup} // $parent_hostgroup;
		push(@{$map->{hostgroup_members}->{$hostgroup}}, $e->{id});
		my $company = $e->{company} // $parent_company;

		put("define host{\n");
		put(" use generic-host\n");
		put(" host_name $e->{id}\n");
		put(" alias " . ( $e->{name} || $e->{id} ) . "\n");
		put(" address " . ( $e->{ip} || $e->{id} ) . "\n");
		if ( $parent_id ) {
			put(" parents $parent_id\n");
		}
		put(" max_check_attempts " . ( $e->{retires} // 3 ) . "\n");
		put(" check_period 24x7\n");
		put(" notification_options d,u,r\n");
		put(" check_command $check_host_alive_cmd\n");
		put(" contact_groups " . $map->{hostgroup_alerts}->{$hostgroup}. "\n");
		if ( $e->{check_period} ) {
			put(" notification_period $e->{check_period}\n");
		}
		put(" _company $company\n");
		put(" }\n");

		if ( $e->{template} ) {
			gen_services($map->{hosttemplate}->{$e->{template}}, $e, $hostgroup, 1);
		}
		gen_services($e->{service}, $e, $hostgroup, 0);
		gen_httpservices($e->{'http-service'}, $e, $company);
		gen_hosts($e->{host}, $e->{id}, $hostgroup, $company);
	}
}#}}}

sub gen_hostgroup {#{{{
	my $cfg = shift;

	foreach my $e ( @{$cfg->{hostgroup} } ) {
		my $id = $e->{id};
		next if !defined($map->{hostgroup_members}->{$id});

		put("define hostgroup{\n");
		put(" hostgroup_name $id\n");
		put(" alias $e->{name}\n");
		put(" members " . join(',', @{$map->{hostgroup_members}->{$id}}) . "\n");
		put(" }\n");
	}
}#}}}

sub main {#{{{

	my $cfg = XMLin('-', ForceArray => 1, KeyAttr => []);

	foreach my $e ( @{$cfg->{hostgroup}} ) {
		my $id = $e->{id};
		$map->{hostgroup_alerts}->{$id} = join(',', sort split(' ', $e->{alerts}));
	}
	foreach my $e ( @{$cfg->{hosttemplate}} ) {
		my $id = $e->{id};
		$map->{hosttemplate}->{$id} = $e->{service};
	}

	put("#\n");
	put("# Automatically generated Nagios configuration file\n");
	put("#\n");
	put("\n");

	gen_contacts($cfg);
	gen_contactgroups($cfg);
	gen_generic($cfg);
	gen_hosts($cfg->{host});
	gen_hostgroup($cfg);

	return 0;
}#}}}

exit main(@ARGV);
