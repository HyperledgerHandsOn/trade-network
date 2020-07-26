#!/bin/bash
#
# SPDX-License-Identifier: Apache-2.0
#

if [ ! -z "$1" ]  && [ "$1" != "all" ] ; then
    echo './stopAll.sh [all]  - all parameter will also remove the crypto material';
    exit 255;
else 
    echo '>> Stopping and cleaning the network.  To remove crypto material pass parameter "all"'
fi


CLEAN="clean$1"
./trade.sh down
./trade.sh stoprest
./trade.sh $CLEAN

docker rm $(docker ps -aq)
docker image ls --format "{{.Repository}}" | grep "dev-" | xargs docker rmi

if [ "$1" != "all" ] ; then 
    rm ./logs/*.log
    rm -rf ../wallets/*
    rm -rf ../gateways/*
fi