# Icinga NMS

This is Icinga dockerized with smokeping, munin, Prometheus, and Grafana. All configuration is controlled by a single (nag.xml) file.

## FEATURES

 * notepad like web editor for configuration with xml syntax highlighting
 * nag.xml -> generate all configuration automatically (icinga, smokeping, munin, Prometheus, Grafana)
 * many icinga plugins already added
 * custom smokeping config allowed
 * custom icinga plugins allowed
 * mattermost notification
 * sms notification

## INSTALL
```bash
$ git clone https://github.com/neszt/icinga-nms-docker.git
```

### docker-compose
```bash
$ cd deploy/docker-compose
$ mkdir data
$ cp -va ../../content/usr/local/config.sample data/config
$ cp .env.sample .env
# edit .env and data/config/* files correctly
$ ./start.sh
```

### Available Multi-Arch Images

[CI/CD](https://github.com/neszt/icinga-nms-docker/actions) will automatically build, test and push new images to container registries. Currently, the following registries are supported:

- [DockerHub](https://hub.docker.com/r/neszt/icinga-nms-docker)
- [GitHub Container Registry](https://github.com/users/neszt/packages/container/package/icinga-nms-docker)

## HOWTO USE

### Modify network hosts, services, topolgy
* just edit nag.xml (on server side or at NMS\_URL)

### Prometheus and Grafana

Add a service named `prometheus`, `node_exporter`, or `exporter` to a host or host template. The first numeric argument in its command is used as the exporter port; without one, port `9100` is used.

```xml
<service name="node_exporter" command="check_prometheus!9100" warnings="yes" active="yes" unknown="no"/>
```

The container runs a local Prometheus instance, scrapes the matching `/metrics` endpoints every 15 seconds, and provisions one Grafana Prometheus datasource and Linux dashboard for every matching host. The default retention is 30 days and can be changed with `PROMETHEUS_RETENTION_TIME` using Prometheus duration units such as `30d` or `1y`. The dashboard is based on [Grafana dashboard 24467](https://grafana.com/api/dashboards/24467/revisions/1/download) and is downloaded during the image build.

Grafana is available at `${NMS_URL}/grafana/`. The internal Grafana upstream remains HTTP; the externally visible protocol and hostname are derived from `NMS_URL`, so an HTTPS `NMS_URL` must be used together with the TLS-terminating nginx proxy. nginx protects Grafana with the existing `htpasswd.users` Basic Auth file and forwards the authenticated username to Grafana's auth proxy. Grafana creates that user automatically with the Viewer role.

Prometheus is available for authenticated manual queries at `${NMS_URL}/prometheus/`, for example `${NMS_URL}/prometheus/api/v1/query?query=up`. The endpoint is proxied to the local Prometheus listener and is protected by the same Basic Auth file.

### Account
* htpasswd.users

Default account: admin / admin

#### Add user
```bash
htpasswd -m htpasswd.users [username]
```

#### Delete user
```bash
htpasswd -D htpasswd.users [username]
```

### SPECIAL CHECKS
* [TASMOTA power](https://github.com/arendst/Tasmota)
* [THERMO sensor](https://github.com/rkojedzinszky/thermo-center)

### SPECIAL TYPES
* TASMOTA: Munin graph

### SPECIAL SERVICES
* MUNIN -> Munin graph
* HTTP -> Smokeping graph
* HTTPS -> Smokeping graph
* DNS -> Smokeping graph
* SSH -> Smokeping graph

### Custom config
* hosts
* htpasswd.users
* icinga.conf.d/
* icinga\_plugins/
* icinga\_plugins\_config/
* smokeping.conf.d/
* ssh/
* ssl.certs.conf.d/
* pgpass

### Example using custom config

## Third party software
* [Ace syntax highlight](https://github.com/ajaxorg/ace)

## FAQ

### Why not separate docker?

On config change need to trigger services to restart.

### I dont like your built-in smokeping config ..

Just override with your own.

### I got "It appears as though you do not have permission ..." error message

Just add your user to a\_icingaadmin alertgroup.

## TODO
* online demo
* screenshots
* upgrade to icinga2
* upgrade to munin3
* host config backup
