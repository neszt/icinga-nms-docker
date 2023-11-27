#!/bin/sh

cd "$(dirname "$0")"

docker exec -it `docker inspect -f '{{.Name}}' $(docker-compose ps -q)` /bin/bash
