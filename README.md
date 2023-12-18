# Icinga NMS

This is Icinga dockerized with smokeping and munin. All configuration is controlled by a single (nag.xml) file.

## FEATURES

 * notepad like web editor for configuration with xml syntax highlighting
 * nag.xml -> generate all configuration automatically (icinga, smokeping, munin)
 * many icinga plugins already added
 * custom smokeping config allowed
 * custom icinga plugins allowed
 * mattermost notification
 * sms notification

## INSTALL
```bash
git clone https://github.com/neszt/icinga-nms-docker.git
```

### docker-compose
```bash
cd deploy/docker-compose
mkdir data
cp -va ../../content/usr/local/config.sample data/config
cp .env.sample .env
# edit .env and data/config/* files correctly
./start.sh
```

### Available Multi-Arch Images

[CI/CD](https://github.com/neszt/icinga-nms-docker/actions) will automatically build, test and push new images to container registries. Currently, the following registries are supported:

- [DockerHub](https://hub.docker.com/r/neszt/icinga-nms-docker)
- [GitHub Container Registry](https://github.com/users/neszt/packages/container/package/icinga-nms-docker)

## HOWTO USE

### Modify network hosts, services, topolgy
* just edit nag.xml (on server side or at NMS\_URL)

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
