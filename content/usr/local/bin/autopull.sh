#!/bin/sh

set -e

cd /config

git remote update

UPSTREAM=${1:-'@{u}'}
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse "$UPSTREAM")
BASE=$(git merge-base @ "$UPSTREAM")

TS=$(date)
echo -n "[$TS] "

if [ $LOCAL = $REMOTE ]; then
    echo "Autopull - Up-to-date"
elif [ $LOCAL = $BASE ]; then
    echo "Autopull - Need to pull"
    git pull
    /usr/local/bin/gen_config.sh
else
    echo "Autopull - Unknown case"
fi
