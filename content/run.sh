#!/bin/bash

#
# Default config, sample files, account: admin / admin
#

test -f /config/nag.xml || cp -a /usr/local/config.sample/* /config/

#
# Icinga
#

chown nagios:adm /var/log/icinga
touch /var/log/icinga/icinga.log
chmod 644 /var/log/icinga/icinga.log
mkdir -p /var/lib/icinga/rw # && mkfifo -m 777 /var/lib/icinga/rw/icinga.cmd
chown nagios:www-data /var/cache/icinga && chmod 2750 /var/cache/icinga
mkdir -p /var/lib/icinga/spool/checkresults && chown -R nagios: /var/lib/icinga
mkdir -p /var/log/icinga/archives && chown nagios:adm /var/log/icinga/archives

cp -a /config/icinga_plugins/* /usr/local/sbin/ >/dev/null 2>/dev/null || true
sed -i "s,__ICINGA_EXTINFO__,$ICINGA_EXTINFO,g" /etc/nagios-plugins/config/mattermost.cfg
sed -i "s,__MATTERMOST_HOOK__,$MATTERMOST_HOOK,g" /etc/nagios-plugins/config/mattermost.cfg
sed -i "s,__MATTERMOST_USERNAME__,$MATTERMOST_USERNAME,g" /etc/nagios-plugins/config/mattermost.cfg

[ -z "${ICINGA_EXTINFO}" ] && rf -rf etc/service/icinga

#
# SSH / SSL
#

KEY_DIR=/root/.ssh
mkdir -p $KEY_DIR
echo -e $SSH_RSA_KEY_BASE > $KEY_DIR/id_rsa_base
echo -e $SSH_RSA_KEY_BASE_PUB > $KEY_DIR/id_rsa_base.pub
chmod 600 $KEY_DIR/id_rsa*
sed -i 's/^CipherString = DEFAULT@SECLEVEL=2/CipherString = DEFAULT@SECLEVEL=1/' /etc/ssl/openssl.cnf
echo "Host *" >> $KEY_DIR/config
echo "  IdentityFile ~/.ssh/id_rsa_base" >> $KEY_DIR/config

#
# Smokeping
#

chown -R smokeping: /var/lib/smokeping
sed -i '/^cgiurl/d' /etc/smokeping/config.d/General
echo cgiurl = $SMOKEPING_URL \# Autgenereated >> /etc/smokeping/config.d/General
mkdir -p /var/run/smokeping /var/lib/smokeping/__cgi && chown smokeping: /var/lib/smokeping/__cgi

[ -z "${SMOKEPING_URL}" ] && rf -rf etc/service/smokeping

#
# Munin
#

mkdir -p /var/lib/munin /var/lib/munin/cgi-tmp/munin-cgi-graph
chown -R munin: /var/lib/munin
chown -R www-data: /var/lib/munin/cgi-tmp

[ -z "${MUNIN_URL}" ] && rf -rf etc/service/munin

#
# Php-fpm
#

mkdir -p --mode=07500 /run/php
chown www-data:www-data /run/php

#
# Git
#

git config --global pull.rebase false

#
# Prepare
#

cd /config && touch nag.xml && gen_config.sh 1

#
# Hosts
#

cat hosts 2>/dev/null >> /etc/hosts

runsvdir /etc/service
