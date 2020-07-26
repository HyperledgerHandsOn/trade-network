#!/bin/bash
#
# SPDX-License-Identifier: Apache-2.0
#

# set global variables
CHANNEL_NAME=$CHANNEL_NAME
NUM_ORGS_IN_CHANNEL=$NUM_ORGS_IN_CHANNEL
NEW_PEER=$PEER
NEW_PEER_ORG=$ORG
DELAY=3
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/trade.com/orderers/orderer.trade.com/msp/tlscacerts/tlsca.trade.com-cert.pem

# verify the result of the end-to-end test
verifyResult() {
  if [ $1 -ne 0 ]; then
    echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo "========= ERROR !!! FAILED to execute Channel Create and Join Scenario ==========="
    echo
    exit 1
  fi
}

exporterorg_PORT=7051
importerorg_PORT=8051
carrierorg_PORT=9051
regulatororg_PORT=10051
exportingentityorg_PORT=12051

setEnvironment() {
  if [[ $# -lt 1 ]]
  then
    echo "Run: setEnvironments <org> [<peer>]"
    exit 1
  fi
  ORG=$1
  PEER=peer0
  if [[ $# -eq 2 ]]
  then
    PEER=$2
  fi
  MSP=
  if [[ "$ORG" == "exporterorg" ]]
  then
    MSP=ExporterOrgMSP
    PORT=$exporterorg_PORT
  elif [[ "$ORG" == "importerorg" ]]
  then
    MSP=ImporterOrgMSP
    PORT=$importerorg_PORT
    if [[ "$PEER" == "peer1" ]]
    then
      PORT=11051
    fi
  elif [[ "$ORG" == "carrierorg" ]]
  then
    MSP=CarrierOrgMSP
    PORT=$carrierorg_PORT
  elif [[ "$ORG" == "regulatororg" ]]
  then
    MSP=RegulatorOrgMSP
    PORT=$regulatororg_PORT
  elif [[ "$ORG" == "exportingentityorg" ]]
  then
    MSP=ExportingEntityOrgMSP
    PORT=$exportingentityorg_PORT
  else
    echo "Unknown Org: "$ORG
    exit 1
  fi
  CORE_PEER_LOCALMSPID=$MSP
  CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/$ORG.trade.com/peers/$PEER.$ORG.trade.com/tls/ca.crt
  CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/$ORG.trade.com/users/Admin@$ORG.trade.com/msp
  CORE_PEER_ADDRESS=$PEER.$ORG.trade.com:$PORT
  CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/$ORG.trade.com/peers/$PEER.$ORG.trade.com/tls/server.crt
  CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/$ORG.trade.com/peers/$PEER.$ORG.trade.com/tls/server.key
}

createChannel() {
  setEnvironment exporterorg

  set -x
  fetchChannelConfig
  set +x
  if [ -f $CHANNEL_NAME.block ]
  then
    echo "Channel already created"
    return
  fi

  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
    set -x
    peer channel create -o orderer.trade.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CHANNEL_NAME}/channel.tx --connTimeout 120s >&log.txt
    res=$?
    set +x
  else
    set -x
    peer channel create -o orderer.trade.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CHANNEL_NAME}/channel.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA --connTimeout 120s >&log.txt
    res=$?
    set +x
  fi
  cat log.txt
  verifyResult $res "Channel creation failed"
  echo "===================== Channel '$CHANNEL_NAME' created ===================== "
  echo
}

## Sometimes Join takes time hence RETRY at least 5 times
joinChannelWithRetry() {
  ORG=$1
  PEER=$2
  setEnvironment $ORG $PEER

  BLOCKFILE=$CHANNEL_NAME.block
  if [[ $# -eq 3 ]]
  then
    BLOCKFILE=$3
  fi

  set -x
  peer channel join -b $BLOCKFILE >&log.txt
  res=$?
  set +x
  cat log.txt
  if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
    COUNTER=$(expr $COUNTER + 1)
    echo "${PEER}.${ORG}.trade.com failed to join the channel, Retry after $DELAY seconds"
    sleep $DELAY
    joinChannelWithRetry $ORG
  else
    COUNTER=1
  fi
  verifyResult $res "After $MAX_RETRY attempts, ${PEER}.${ORG}.trade.com has failed to join channel '$CHANNEL_NAME' "
}

joinChannel() {
  if [ "$NUM_ORGS_IN_CHANNEL" == "3" ]
  then
    ORG_LIST="exporterorg importerorg regulatororg"
  else
    ORG_LIST="exporterorg importerorg carrierorg regulatororg"
  fi
  for org in $ORG_LIST; do
    joinChannelWithRetry $org
    echo "===================== peer0.${org}.trade.com joined channel '$CHANNEL_NAME' ===================== "
    sleep $DELAY
    echo
  done
}

joinNewPeerToChannel() {
  fetchOldestBlock
  joinChannelWithRetry $NEW_PEER_ORG $NEW_PEER ${CHANNEL_NAME}_oldest.block
  echo "===================== ${PEER}.${NEW_PEER_ORG}.trade.com joined channel '$CHANNEL_NAME' ===================== "
}

# fetchOldestBlock <channel_id> <output_json>
# Writes the oldest block for a given channel to a JSON file
fetchOldestBlock() {
  setEnvironment exporterorg

  echo "Fetching the most recent configuration block for the channel"
  set -x
  peer channel fetch oldest ${CHANNEL_NAME}_oldest.block -c $CHANNEL_NAME --connTimeout 120s >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Fetching oldest channel config block failed"
}

# fetchChannelConfig <channel_id> <output_json>
# Writes the current channel config for a given channel to a JSON file
fetchChannelConfig() {
  setEnvironment exporterorg

  BLOCKFILE=$CHANNEL_NAME.block
  if [[ $# -eq 1 ]]
  then
    BLOCKFILE=$1
  fi

  echo "Fetching the most recent configuration block for the channel"
  set -x
  peer channel fetch config $BLOCKFILE -c $CHANNEL_NAME --connTimeout 120s >&log.txt
  res=$?
  set +x
  cat log.txt
}

# Set anchor peers for org in channel
updateAnchorPeersForOrg() {
  ORG=$1
  setEnvironment $ORG

  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
    set -x
    peer channel update -o orderer.trade.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CHANNEL_NAME}/${CORE_PEER_LOCALMSPID}anchors.tx --connTimeout 120s >&log.txt
    res=$?
    set +x
  else
    set -x
    peer channel update -o orderer.trade.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CHANNEL_NAME}/${CORE_PEER_LOCALMSPID}anchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA --connTimeout 120s >&log.txt
    res=$?
    set +x
  fi
  cat log.txt
  verifyResult $res "Updating anchor peers for org '"$ORG"' failed"
}

# Set anchor peers for org in channel
updateAnchorPeers() {
  if [ "$NUM_ORGS_IN_CHANNEL" == "3" ]
  then
    ORG_LIST="exporterorg importerorg regulatororg"
  else
    ORG_LIST="exporterorg importerorg carrierorg regulatororg"
  fi
  for org in $ORG_LIST; do
    updateAnchorPeersForOrg $org
    echo "===================== peer0.${org}.trade.com set as anchor in ${org} in channel '$CHANNEL_NAME' ===================== "
    sleep $DELAY
    echo
  done
}

# signConfigTxAsPeerOrg <org> <update-tx-protobuf>
# Set the peerOrg admin of an org and signing the config update
signConfigtxAsPeerOrg() {
  ORG=$1
  UPDATE_TX=$2
  setEnvironment $ORG
  set -x
  peer channel signconfigtx -f $UPDATE_TX >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Updating anchor peers for org '"$ORG"' failed"
}

# Upgrade channel configuration
updateChannelConfiguration() {
  # Delete old temp folder if it exists
  TMPDIR=tmp_upgrade
  rm -rf $TMPDIR

  # Create temp folder for computations
  mkdir $TMPDIR
  cd $TMPDIR

  # Get latest channel configuration block
  fetchChannelConfig ${CHANNEL_NAME}_config_block.pb

  # Convert config block (in protobuf format) to JSON format and extract the embedded config into a JSON file
  configtxlator proto_decode --input ${CHANNEL_NAME}_config_block.pb --type common.Block | jq .data.data[0].payload.data.config > ${CHANNEL_NAME}_config.json

  # Append the configuration of our new org to the above config
  jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"ExportingEntityOrg":.[1]}}}}}' ${CHANNEL_NAME}_config.json ../channel-artifacts/$CHANNEL_NAME/exportingEntityOrg.json > ${CHANNEL_NAME}_modified_config.json

  # Convert config JSON to protobuf format
  configtxlator proto_encode --input ${CHANNEL_NAME}_config.json --type common.Config --output ${CHANNEL_NAME}_config.pb

  # Convert modified config JSON to protobuf format
  configtxlator proto_encode --input ${CHANNEL_NAME}_modified_config.json --type common.Config --output ${CHANNEL_NAME}_modified_config.pb

  # Compute delta (difference) between new config (with ExportingEntityOrg) and old config; this is the update we need to make to the channel
  configtxlator compute_update --channel_id $CHANNEL_NAME --original ${CHANNEL_NAME}_config.pb --updated ${CHANNEL_NAME}_modified_config.pb --output exportingEntityOrg_update.pb

  # Convert delta from protobuf to JSON format for ease of enveloping
  configtxlator proto_decode --input exportingEntityOrg_update.pb --type common.ConfigUpdate | jq . > exportingEntityOrg_update.json

  # Wrap the update in an envelope
  echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat exportingEntityOrg_update.json)'}}}' | jq . > exportingEntityOrg_update_in_envelope.json

  # Finally, convert this envelope into protobuf format for Fabric's consumption
  configtxlator proto_encode --input exportingEntityOrg_update_in_envelope.json --type common.Envelope --output exportingEntityOrg_update_in_envelope.pb

  # Get the config signed by a majority of orgs in the channel
  if [ "$NUM_ORGS_IN_CHANNEL" == "3" ]
  then
    ORG_LIST="exporterorg regulatororg"
  else
    ORG_LIST="exporterorg importerorg carrierorg"
  fi
  for org in $ORG_LIST; do
    signConfigtxAsPeerOrg $org exportingEntityOrg_update_in_envelope.pb
    echo "===================== peer0.${org}.trade.com signed update for channel '$CHANNEL_NAME' ===================== "
    echo
  done

  # Submit a channel configuration update transaction
  set -x
  peer channel update -f exportingEntityOrg_update_in_envelope.pb -c $CHANNEL_NAME -o orderer.trade.com:7050 --tls --cafile $ORDERER_CA --connTimeout 120s >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Updating configuration for channel '"$CHANNEL_NAME"' failed"
}

# Update anchor peer for new organization by pushing a channel configuration update
updateAnchorPeerForNewOrg() {
  # Delete old temp folder if it exists
  TMPDIR=tmp_upgrade
  rm -rf $TMPDIR

  # Create temp folder for computations
  mkdir $TMPDIR
  cd $TMPDIR

  # Get latest channel configuration block
  fetchChannelConfig ${CHANNEL_NAME}_config_block.pb

  # Convert config block (in protobuf format) to JSON format and extract the embedded config into a JSON file
  configtxlator proto_decode --input ${CHANNEL_NAME}_config_block.pb --type common.Block | jq .data.data[0].payload.data.config > ${CHANNEL_NAME}_config.json

  # Add anchor peer specification to the configuration of our new org
  jq '.channel_group.groups.Application.groups.ExportingEntityOrg.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "peer0.exportingentityorg.trade.com","port": 12051}]},"version": "0"}}' ${CHANNEL_NAME}_config.json > ${CHANNEL_NAME}_modified_config.json

  # Convert config JSON to protobuf format
  configtxlator proto_encode --input ${CHANNEL_NAME}_config.json --type common.Config --output ${CHANNEL_NAME}_config.pb

  # Convert modified config JSON to protobuf format
  configtxlator proto_encode --input ${CHANNEL_NAME}_modified_config.json --type common.Config --output ${CHANNEL_NAME}_modified_config.pb

  # Compute delta (difference) between new config (with ExportingEntityOrg anchor peer) and older config; this is the update we need to make to the channel
  configtxlator compute_update --channel_id $CHANNEL_NAME --original ${CHANNEL_NAME}_config.pb --updated ${CHANNEL_NAME}_modified_config.pb --output exportingEntityOrg_anchor_update.pb

  # Convert delta from protobuf to JSON format for ease of enveloping
  configtxlator proto_decode --input exportingEntityOrg_anchor_update.pb --type common.ConfigUpdate | jq . > exportingEntityOrg_anchor_update.json

  # Wrap the update in an envelope
  echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat exportingEntityOrg_anchor_update.json)'}}}' | jq . > exportingEntityOrg_anchor_update_in_envelope.json

  # Finally, convert this envelope into protobuf format for Fabric's consumption
  configtxlator proto_encode --input exportingEntityOrg_anchor_update_in_envelope.json --type common.Envelope --output exportingEntityOrg_anchor_update_in_envelope.pb

  # Get the config signed by an admin of the new org
  signConfigtxAsPeerOrg exportingentityorg exportingEntityOrg_anchor_update_in_envelope.pb
  echo "===================== peer0.exportingentityorg.trade.com signed update for channel '$CHANNEL_NAME' ===================== "
  echo

  # Submit a channel configuration update transaction
  set -x
  peer channel update -f exportingEntityOrg_anchor_update_in_envelope.pb -c $CHANNEL_NAME -o orderer.trade.com:7050 --tls --cafile $ORDERER_CA --connTimeout 120s >&log.txt
  res=$?
  set +x
  cat log.txt
  verifyResult $res "Updating configuration for channel '"$CHANNEL_NAME"' failed"
}


if [[ $# -ne 1 ]]
then
  echo "Run: channel.sh [create|join|fetch|anchor|joinnewpeer|update|anchorneworg]"
  exit 1
fi
echo $1
if [ "$1" == "create" ]
then
  ## Create channel
  echo "Creating channel..."
  createChannel
  echo "========= Channel creation completed =========== "
elif [ "$1" == "join" ]
  then
  ## Join all the peers to the channel
  echo "Having all peers join the channel..."
  joinChannel
  echo "========= Channel join completed =========== "
elif [ "$1" == "fetch" ]
  then
  ## Fetch channel config block
  echo "Fetch the channel configuration block..."
  fetchChannelConfig
  echo "========= Channel configuration fetched =========== "
elif [ "$1" == "anchor" ]
  then
  ## Set anchor peers
  echo "Set anchor peers..."
  updateAnchorPeers
  echo "========= Channel configuration updated with anchor peers =========== "
elif [ "$1" == "joinnewpeer" ]
  then
  ## Join the new peer to the channel
  echo "Having new peer join the channel..."
  joinNewPeerToChannel
  echo "========= Channel join completed for new peer =========== "
elif [ "$1" == "update" ]
  then
  ## Update the channel configuration to add a new organization
  echo "Updating the channel configuration to add ExportingEntityOrg..."
  updateChannelConfiguration
  echo "========= Channel update completed =========== "
elif [ "$1" == "anchorneworg" ]
  then
  ## Set anchor peer for new org
  echo "Set anchor peer for new org..."
  updateAnchorPeerForNewOrg
  echo "========= Channel configuration updated with anchor peer for new org =========== "
else
  echo "Unsupported channel operation: "$1
fi

echo

exit 0
