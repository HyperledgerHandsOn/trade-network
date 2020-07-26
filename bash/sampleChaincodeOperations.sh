#!/bin/bash
#
# SPDX-License-Identifier: Apache-2.0
#

# Install 'trade' contract
./trade.sh installcontract -c tradechannel -p trade -o 3
./trade.sh initcontract -c tradechannel -p trade -t init

# Install 'letterOfCredit' contract
./trade.sh installcontract -c tradechannel -p letterOfCredit -o 3
./trade.sh initcontract -c tradechannel -p letterOfCredit -t init -a '"trade","shippingchannel","shipment","ExporterOrgMSP","LumberBank","100000","ImporterOrgMSP","ToyBank","200000"'

# Install 'exportLicense' contract
./trade.sh installcontract -c shippingchannel -p exportLicense -o 4
./trade.sh initcontract -c shippingchannel -p exportLicense -t init -a '"tradechannel","trade","CarrierOrgMSP","RegulatorOrgMSP"'

# Install 'shipment' contract
./trade.sh installcontract -c shippingchannel -p shipment -o 4
./trade.sh initcontract -c shippingchannel -p shipment -t init


# Invoke 'trade' contract (this requires user certificates with the right attributes, and won't work with cryptogen-generated certificates)
#./trade.sh invokecontract -c tradechannel -p trade -t requestTrade -a '"trade-78", "ExporterOrgMSP", "Teak for Furniture", "650000"' -g importerorg

# Query 'trade' contract (this requires user certificates with the right attributes, and won't work with cryptogen-generated certificates)
#./trade.sh querycontract -c tradechannel -p trade -t getTradeStatus -a '"trade-78"' -g importerorg
