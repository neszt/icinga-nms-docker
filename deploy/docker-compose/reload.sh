#!/bin/sh

cd "$(dirname "$0")"

docker exec -it `docker inspect -f '{{.Name}}' $(docker-compose ps -q)` sh -c "gen_config.sh"
