#!/bin/bash
#
# SPDX-License-Identifier: Apache-2.0
#

# Create the 3-org 'tradechannel'
./trade.sh createchannel -c tradechannel

# Join peers of 3 orgs to 'tradechannel'
./trade.sh joinchannel -c tradechannel -o 3

# Set anchor peer for each of the 3 orgs in 'tradechannel'
./trade.sh updateanchorpeers -c tradechannel -o 3

# Create the 4-org 'shippingchannel'
./trade.sh createchannel -c shippingchannel

# Join peers of 4 orgs to 'shippingchannel'
./trade.sh joinchannel -c shippingchannel -o 4

# Set anchor peer for each of the 4 orgs in 'shippingchannel'
./trade.sh updateanchorpeers -c shippingchannel -o 4
