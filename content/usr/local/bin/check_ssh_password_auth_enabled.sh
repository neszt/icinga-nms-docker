#!/bin/bash

HOST=$1
PORT=$2
USER=$3

ssh -v -n -o Batchmode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p $PORT $USER@$HOST 2>&1 | grep password
