FROM debian:bookworm

MAINTAINER Neszt Tibor <tibor@neszt.hu>
LABEL org.opencontainers.image.source https://github.com/neszt/icinga-nms-docker

ENV ACEJS=v1.36.5
ENV CHECK_SSL_CERT_VERSION=v2.84.5
ENV CHECK_RBL_VERSION=52183405778a95c224652bc261216c9a749288dc
ENV CHECK_LIBRENMS_ALERTS_VERSION=1.0.1
ENV CHECK_IPMI_SENSOR_VERSION=v3.14
ENV CHECK_TRUENAS_EXTENDED_PLAY_VERSION=ebae18bc20fbebd512294fbdbf3fb8b2b64794c9

RUN export DEBIAN_FRONTEND=noninteractive && \
	# buster needed for older icinga
	echo deb http://deb.debian.org/debian buster main >> /etc/apt/sources.list && \
	apt-get update && apt-get -y dist-upgrade && \
	apt-get install -y --install-recommends vim telnet tcpdump less acl runit cron git nginx icinga nagios-nrpe-plugin curl smokeping munin fcgiwrap spawn-fcgi php-fpm make xalan xsltproc python3 python3-urllib3 python3-requests libxml2-utils libxml-simple-perl libjson-xs-perl libnet-openssh-perl libdbi-perl libdbd-pg-perl libfrontier-rpc-perl liburi-encode-perl libdata-uuid-perl libcapture-tiny-perl libdata-validate-domain-perl libdata-validate-ip-perl libnet-dns-perl libnet-ip-perl libmonitoring-plugin-perl libcpanel-json-xs-perl bc freeipmi-tools nagios-plugins-contrib && \
	# ace.js min
	curl https://raw.githubusercontent.com/ajaxorg/ace-builds/refs/tags/${ACEJS}/src-min/ace.js > /var/www/html/ace.js && \
	# nagios-plugins-contrib upgrades
	curl https://raw.githubusercontent.com/matteocorti/check_ssl_cert/${CHECK_SSL_CERT_VERSION}/check_ssl_cert > /usr/lib/nagios/plugins/check_ssl_cert && \
	curl https://raw.githubusercontent.com/matteocorti/check_rbl/${CHECK_RBL_VERSION}/check_rbl | sed '1 s/^.*$/#!\/usr\/bin\/perl/' > /usr/lib/nagios/plugins/check_rbl && \
	curl https://raw.githubusercontent.com/thomas-krenn/check_ipmi_sensor_v3/${CHECK_IPMI_SENSOR_VERSION}/check_ipmi_sensor > /usr/lib/nagios/plugins/check_ipmi_sensor && \
	# outer check scripts
	curl https://raw.githubusercontent.com/neszt/check-librenms-alerts/${CHECK_LIBRENMS_ALERTS_VERSION}/check_librenms_alerts.pl > /usr/local/bin/check_librenms_alerts.pl && chmod +x /usr/local/bin/check_librenms_alerts.pl && \
	curl https://raw.githubusercontent.com/StewLG/check_truenas_extended_play/${CHECK_TRUENAS_EXTENDED_PLAY_VERSION}/check_truenas_extended_play.py > /usr/local/bin/check_truenas_extended_play.py && chmod +x /usr/local/bin/check_truenas_extended_play.py && \
	# conf php-fpm to not clear env variables
	sed -i '/clear_env/s/^;//' /etc/php/8.2/fpm/pool.d/www.conf && \
	# conf php-fpm to enable root user and group
	sed -i '/^user/s/www-data/root/' /etc/php/8.2/fpm/pool.d/www.conf && \
	sed -i '/^group/s/www-data/root/' /etc/php/8.2/fpm/pool.d/www.conf && \
	# remove nginx default site
	rm /etc/nginx/sites-enabled/default && \
	# icinga
	sed -i 's/^check_external_commands.*$/check_external_commands=1/' /etc/icinga/icinga.cfg && \
	touch /var/cache/icinga/objects.cache && chown nagios:www-data /var/cache/icinga/objects.cache && chmod 766 /var/cache/icinga/objects.cache && \
	find /etc/icinga/objects/*.cfg | grep -Ev "contacts|timeperiods" | xargs rm && \
	# include our custom smokeping config
	echo "@include /etc/smokeping/config.d/Nagios" >> /etc/smokeping/config && \
	# fix smokeping SSH probe code
	sed -i 's/^.*SERVER_SOFTWARE.*$/if (0) {/' /usr/share/perl5/Smokeping/probes/SSH.pm && \
	# munin
	mkdir -p /var/run/munin && chown munin:root /var/run/munin && \
	sed -i '/^#graph_strategy/a graph_strategy cgi' /etc/munin/munin.conf && \
	sed -i 's/^background/# backround/;s/^setsid 1/setsid 0/' /etc/munin/munin-node.conf && \
	# munin-node bug: Can't connect to TCP port 4949 on :: [Invalid argument]
	sed -i 's/^host \*/host 0.0.0.0/' /etc/munin/munin-node.conf && \
	# fontconfig cache permission fix
	chmod -R 777 /var/cache/fontconfig && \
	# COPY content / fix, see: https://github.com/docker/buildx/issues/150
	rm -rf /etc/service

COPY content /

CMD ["/run.sh"]
