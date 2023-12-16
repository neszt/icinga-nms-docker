# Icinga NMS

This is Icinga dockerized with smokeping and munin. All configuration is controlled by a single (nag.xml) file.

## FEATURES

 * notepad like web editor for configuration with xml syntax highlighting
 * nag.xml -> generate all configuration automatically (icinga, smokeping, munin)
 * many icinga plugins already added
 * custom smokeping config allowed
 * custom icinga plugins allowed
 * mattermost notification

## INSTALL
```bash
git clone https://github.com/neszt/icinga-nms-docker.git
```

### docker-compose
```bash
cd deploy/docker-compose
mkdir -p data/config
cp ../nag.xml.sample data/config/nag.xml
cp .env.sample .env
# edit .env and nag.xml file correctly
./start.sh
```

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

On config change need to trigger services to restart

### I dont like your built-in smokeping config ..

Just override with your own

### I got "It appears as though you do not have permission ..." error message

Just add your user to a\_icingaadmin alertgroup

## TODO
* online demo
* screenshots
* upgrade to icinga2
* upgrade to munin3
