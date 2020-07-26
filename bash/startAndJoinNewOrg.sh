# Submit channel configuration update to add 'exportingentityorg' to 'tradechannel'
./trade.sh updatechannel -c tradechannel -o 3

# Submit channel configuration update to add 'exportingentityorg' to 'shippingchannel'
./trade.sh updatechannel -c shippingchannel -o 4

# Start CA, peer, CouchDB for 'exportingentityorg'
./trade.sh startneworg
# Wait for the peer to be ready
sleep 5

# Join peer0.exportingentityorg.trade.com to 'tradechannel'
./trade.sh joinneworg -c tradechannel

# Join peer0.exportingentityorg.trade.com to 'shippingchannel'
./trade.sh joinneworg -c shippingchannel

# Set peer0.exportingentityorg.trade.com as anchor peer for exportingentityorg in 'tradechannel'
./trade.sh updateneworganchorpeer -c tradechannel

# Set peer0.exportingentityorg.trade.com as anchor peer for exportingentityorg in 'shippingchannel'
./trade.sh updateneworganchorpeer -c shippingchannel
