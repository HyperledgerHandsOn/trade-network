#!/bin/bash
#
# SPDX-License-Identifier: Apache-2.0
#

# Keeps pushd silent
pushd () {
    command pushd "$@" > /dev/null
}

# Keeps popd silent
popd () {
    command popd "$@" > /dev/null
}
DIR='./crypto-config'
if [ ! "$(ls -A $DIR)" ]; then
    ./trade.sh generate -c tradechannel -o 3
    ./trade.sh generate -c shippingchannel -o 4
fi
./trade.sh up
./startAndJoinChannels.sh
pushd utils
./generateAllProfiles.sh
popd
./sampleChaincodeOperations.sh
./trade.sh startrest
