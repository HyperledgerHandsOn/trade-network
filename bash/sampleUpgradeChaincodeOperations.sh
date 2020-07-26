# Upgrade 'trade' contract
./trade.sh upgradecontract -c tradechannel -p trade -o 3 -t init

# Upgrade 'letterOfCredit' contract
./trade.sh upgradecontract -c tradechannel -p letterOfCredit -o 3 -t init -a '"[\"ExportingEntityOrgMSP\",\"LumberBank\",\"700000\"]"'

# Upgrade 'exportLicense' contract
./trade.sh upgradecontract -c shippingchannel -p exportLicense -o 4 -t init

# Upgrade 'shipment' contract
./trade.sh upgradecontract -c shippingchannel -p shipment -t init -o 4
