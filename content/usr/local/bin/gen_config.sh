#!/bin/bash

#
# Icinga, Smokeping, Munin config generator
#

set -e
cd "$(dirname "$0")"

IS_GIT_FORCE=$1

INPUT=nag.xml
OUTPUT=nagios_generated.cfg

#
# Icinga
#

getfacl -p /config/${INPUT} > /tmp/permissions.facl

cd config_generator
cp /config/${INPUT} .
./nagconf.pl < ${INPUT} > ${OUTPUT}.tmp
mv ${OUTPUT}.tmp /etc/icinga/objects/${OUTPUT}
xsltproc reindent.xsl ${INPUT} > ${INPUT}.tmp1
xsltproc comment.xsl ${INPUT}.tmp1 > ${INPUT}.tmp2
xmllint --noout --dtdvalid nag.dtd ${INPUT}
mv ${INPUT}.tmp2 /config/${INPUT}
rm ${INPUT}.tmp1

setfacl --restore=/tmp/permissions.facl

sed -i -E "s/(authorized_for.*=).*/\1icingaadmin,`grep alertgroup.id..a_icingaadmin /config/${INPUT} | cut -d'"' -f 6 | sed 's/ /,/g'`/" /etc/icinga/cgi.cfg

test -f /config/pgpass && cp /config/pgpass /var/lib/nagios && chown nagios: /var/lib/nagios/pgpass && chmod 600 /var/lib/nagios/pgpass

#
# SSH
#

#
# no error if no file
#

cp -a /config/ssh/* /root/.ssh/ 2>/dev/null || true

#
# Certs
#

cp /config/ssl.certs.conf.d/* /usr/local/share/ca-certificates/ 2>/dev/null && /usr/sbin/update-ca-certificates || true

#
# Icinga plugins
#

cp /config/icinga_plugins_config/* /etc/nagios-plugins/config/ 2>/dev/null || true

#
# Icinga config
#

cp /config/icinga.conf.d/* /etc/icinga/objects/ 2>/dev/null || true

#
# Smokeping
#

cp /config/smokeping.conf.d/* /etc/smokeping/config.d/ 2>/dev/null || true
for i in `find /etc/smokeping/config.d/ -type f | grep -v pathnames` ; do grep $i /etc/smokeping/config >/dev/null || echo @include $i ; done >> /etc/smokeping/config
./nag2smokeping.pl > /etc/smokeping/config.d/Nagios

#
# Munin
#

./nag2munin.pl > /etc/munin/munin-conf.d/nagios

#
# Radcli
#

cp /config/radcli/* /etc/radcli/ 2>/dev/null || true

#
# Restart services if runsvdir running
#

pidof runsvdir >/dev/null && sv restart smokeping && sv restart fcgi-smokeping && sv restart icinga && sv restart munin-node

git.pl $IS_GIT_FORCE
