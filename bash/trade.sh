#!/bin/bash
#
# SPDX-License-Identifier: Apache-2.0
#

# This script will orchestrate a sample end-to-end execution of the Hyperledger
# Fabric network.
#
# The end-to-end verification provisions a sample Fabric network consisting of
# two organizations, each maintaining two peers, and a “solo” ordering service.
#
# This verification makes use of two fundamental tools, which are necessary to
# create a functioning transactional network with digital signature validation
# and access control:
#
# * cryptogen - generates the x509 certificates used to identify and
#   authenticate the various components in the network.
# * configtxgen - generates the requisite configuration artifacts for orderer
#   bootstrap and channel creation.
#
# Each tool consumes a configuration yaml file, within which we specify the topology
# of our network (cryptogen) and the location of our certificates for various
# configuration operations (configtxgen).  Once the tools have been successfully run,
# we are able to launch our network.  More detail on the tools and the structure of
# the network will be provided later in this document.  For now, let's get going...

# prepending $PWD/../bin to PATH to ensure we are picking up the correct binaries
# this may be commented out to resolve installed version of tools if desired

export PATH=${PWD}/../bin:${PWD}:$PATH
export FABRIC_CFG_PATH=${PWD}

# By default we standup a full network.
DEV_MODE=false

# Print the usage message
function printHelp () {
  echo "Usage: "
  echo "  trade.sh up|down|restart|generate|reset|clean|cleanall|createchannel|joinchannel|fetchconfig|updateanchorpeers|updatechannel|installcontract|initcontract|upgradecontract|invokecontract|querycontract|upgrade|createnewpeer|startnewpeer|stopnewpeer|joinnewpeer|createneworg|startneworg|stopneworg|joinneworg|updateneworganchorpeer|startrest|stoprest [-c <channel name>] [-p <contract name] [-f <docker-compose-file>] [-l <logfile>] [-b <block-file>] [-o <number-of-orgs>] [-d <true|false>] [-t <contract init-func>] [-a <contract init-args>] [-m <mode>] [-g <org-name>] [-s <db-type>] [-r]"
  echo "  trade.sh -h|--help (print this message)"
  echo "    <command> - select one from the list below'"
  echo "      - 'up' - bring up the network with docker-compose up"
  echo "      - 'down' - clear the network with docker-compose down"
  echo "      - 'restart' - restart the network"
  echo "      - 'generate' - generate required certificates and genesis block"
  echo "      - 'reset' - delete chaincode containers while keeping network artifacts"
  echo "      - 'clean' - delete network and channel artifacts"
  echo "      - 'cleanall' - delete network, channel, and crypto artifacts"
  echo "      - 'createchannel' - create a channel through the ordering service"
  echo "      - 'joinchannel' - join orgs' peers to this channel"
  echo "      - 'fetchconfig' - fetch latest channel configuration block"
  echo "      - 'updateanchorpeers' - update (set) anchor peers for all orgs"
  echo "      - 'updatechannel' - update a channel configuration through the ordering service"
  echo "      - 'installcontract' - package and install contract on peers, and commit definition"
  echo "      - 'initcontract' - initialize contract state"
  echo "      - 'upgradecontract' - upgrade contract code after addition of new org"
  echo "      - 'invokecontract' - invoke contract transaction"
  echo "      - 'querycontract' - query contract function"
  echo "      - 'upgrade' - upgrade the network from one version to another (new Fabric and Fabric-CA versions specified in .env)"
  echo "      - 'createnewpeer' - create cryptographic artifacts for a new peer for an org"
  echo "      - 'startnewpeer' - start new peer in a separate container"
  echo "      - 'stopnewpeer' - stop new peer"
  echo "      - 'joinnewpeer' - join new peer to existing channels"
  echo "      - 'createneworg' - create channel and crypto artifacts for new org"
  echo "      - 'startneworg' - start peers and CAs for new org in containers"
  echo "      - 'stopneworg' - stop peers and CAs of new org"
  echo "      - 'joinneworg' - join peer of new org to existing channels"
  echo "      - 'startrest' - start all rest servers (importer, exporter, regulator)"
  echo "      - 'stoprest' - stop all rest servers (importer, exporter, regulator)"
  echo "    -c <channel name> - channel name to use"
  echo "    -l <logfile> - log file path"
  echo "    -o <number-of-orgs> - number of organizations in a channel's configuration (either 3 or 4 in this application)"
  echo "    -p <contract name> - contract name to use"
  echo "    -f <docker-compose-file> - specify which docker-compose file use (defaults to docker-compose-e2e.yaml)"
  echo "    -d <true|false> - Apply command to the network in dev mode if value is 'true'"
  echo "    -b <block-file> - defaults to '<channel name>.block'"
  echo "    -t <contract init-func> - contract initialization function (defaults to \'init\')"
  echo "    -a <contract init-args> - contract initialization arguments: comma separated strings within single quotes, each string within double quotes (defaults to blank string). Example: '\"abcd\",\"xyz 123\", \"234\"'"
  echo "    -m <mode> - development mode: either 'test' (solo orderer) or 'prod' (Raft ordering service). Defaults to 'test'"
  echo "    -g <org-name> - organization name: e.g., 'exporterorg', 'importerorg'"
  echo "    -s <db-type> - either 'leveldb' or 'couchdb' (defaults to 'couchdb')"
  echo "    -r - indicates that volumes ought to be retained when containers are brought down"
  echo
  echo "Typically, one would first generate the required certificates and "
  echo "genesis block, then bring up the network. e.g.:"
  echo
  echo "	./trade.sh generate -c tradechannel -o 3"
  echo "	./trade.sh up -l logs/network.log"
  echo "	./trade.sh down"
  echo "	./trade.sh reset"
  echo "	./trade.sh clean"
  echo "	./trade.sh cleanall"
  echo
  echo "Taking all defaults:"
  echo "	trade.sh generate"
  echo "	trade.sh up"
  echo "	trade.sh down"
}

function verifyChannelName () {
  if [ "$CHANNEL_NAME" == "" ]
  then
    echo "Channel name must be specified for this action"
    exit 1
  fi
}

function verifyNumOrgsInChannel () {
  if [ "$NUM_ORGS_IN_CHANNEL" == "" ]
  then
    echo "Number of orgs in channel must be specified for this action"
    exit 1
  fi
}

function verifyContractName () {
  if [ "$CONTRACT_NAME" == "" ]
  then
    echo "Contract name must be specified for this action"
    exit 1
  fi
}

function verifyContractFunc () {
  if [ "$CONTRACT_FUNC" == "" ]
  then
    echo "Contract function must be specified for this action"
    exit 1
  fi
}

function verifyOrganization () {
  if [ "$ORGANIZATION" == "" ]
  then
    echo "Organization name must be specified for this action"
    exit 1
  fi
}

# Keeps pushd silent
pushd () {
    command pushd "$@" > /dev/null
}

# Keeps popd silent
popd () {
    command popd "$@" > /dev/null
}

# Ask user for confirmation to proceed
function askProceed () {
  read -p "Continue? [Y/n] " ans
  case "$ans" in
    y|Y|"" )
      echo "proceeding ..."
    ;;
    n|N )
      echo "exiting..."
      exit 1
    ;;
    * )
      echo "invalid response"
      askProceed
    ;;
  esac
}

# Delete any images that were generated as a part of this setup
# specifically the following images are often left behind:
# TODO list generated image naming patterns
function removeUnwantedImages() {
  DOCKER_IMAGE_IDS=$(docker images | grep "dev\|none\|test-vp\|peer[0-9]-" | awk '{print $3}')
  if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" == " " ]; then
    echo "---- No images available for deletion ----"
  else
    docker rmi -f $DOCKER_IMAGE_IDS
  fi
}

# Do some basic sanity checking to make sure that the appropriate versions of fabric
# binaries/images are available.  In the future, additional checking for the presence
# of go or other items could be added.
function checkPrereqs() {
  # Note, we check configtxlator externally because it does not require a config file, and peer in the
  # docker image because of FAB-8551 that makes configtxlator return 'development version' in docker
  LOCAL_VERSION=$(configtxlator version | sed -ne 's/ Version: //p')
  DOCKER_IMAGE_VERSION=$(docker run --platform $PLATFORM --rm hyperledger/fabric-tools:$IMAGE_TAG peer version | sed -ne 's/ Version: //p'|head -1)

  echo "LOCAL_VERSION=$LOCAL_VERSION"
  echo "DOCKER_IMAGE_VERSION=$DOCKER_IMAGE_VERSION"

  IMAGE_MAJOR_VERSION=${DOCKER_IMAGE_VERSION:0:3}
  if [ "$IMAGE_MAJOR_VERSION" != "$FABRIC_VERSION" ]
  then
    echo "=========================== VERSION ERROR ==========================="
    echo "  Expected peer image version ${FABRIC_VERSION}.x"
    echo "  Found peer image version ${DOCKER_IMAGE_VERSION}"
    echo "  Build or download Fabric images ${FABRIC_VERSION}.x"
    echo "  Use the 'release-${FABRIC_VERSION}' branch of Fabric for building from source"
    echo "====================================================================="
    exit 1
  fi

  if [ "$LOCAL_VERSION" != "$DOCKER_IMAGE_VERSION" ] ; then
    echo "=================== WARNING ==================="
    echo "  Local fabric binaries and docker images are  "
    echo "  out of sync. This may cause problems.       "
    echo "==============================================="
  fi
}

# Generate all the network configuration files for bootstrap and operation
function generateConfig () {
  PUSHED=false
  # Check if we are already in the 'devmode' folder
  if [ "$DEV_MODE" = true -a -d "devmode" ] ; then
    pushd ./devmode
    export FABRIC_CFG_PATH=${PWD}
    PUSHED=true
  fi

  # Create credentials for network nodes only if they don't currently exist
  generateCerts

  # Create credentials for multiple Raft ordering nodes only if they don't currently exist
  if [ "$ORDERER_MODE" = "prod" ]
  then
    generateCertsForRaftOrderingNodes
  fi

  # We will overwrite channel artifacts if they already exist
  generateChannelArtifacts
  if [ "$PUSHED" = true ] ; then
    popd
    export FABRIC_CFG_PATH=${PWD}
  fi
}

# Generate the needed certificates, the genesis block and start the network.
function networkUp () {
  checkPrereqs
  # If we are in dev mode, we move to the devmode directory
  if [ "$DEV_MODE" = true ] ; then
    pushd ./devmode
    export FABRIC_CFG_PATH=${PWD}
  fi
  # generate artifacts if they don't exist
  if [ ! -d "crypto-config" -o ! -f "channel-artifacts/genesis.block" -o ! -f "docker-compose-e2e.yaml" ]; then
    echo "Network artifacts or configuration missing. Run './trade.sh generate -c <channel_name>' to recreate them."
    exit 1
  fi
  # Create folder for docker network logs
  LOG_DIR=$(dirname $LOG_FILE)
  if [ ! -d $LOG_DIR ]
  then
    mkdir -p $LOG_DIR
  fi
  COMPOSE_FILE_DB=
  NUM_CONTAINERS=0
  if [ "$DB_TYPE" = "couchdb" -a "$DEV_MODE" != true ]
  then
    COMPOSE_FILE_DB="-f "$COMPOSE_FILE_COUCHDB
    NUM_CONTAINERS=3
  fi
  if [ "$ORDERER_MODE" = "prod" ]
  then
    docker-compose -f $COMPOSE_FILE_RAFT $COMPOSE_FILE_DB up >$LOG_FILE 2>&1 &
    NUM_CONTAINERS=$(($NUM_CONTAINERS + 13))
  else
    docker-compose -f $COMPOSE_FILE $COMPOSE_FILE_DB up >$LOG_FILE 2>&1 &
    NUM_CONTAINERS=$(($NUM_CONTAINERS + 9))
  fi

  if [ "$DEV_MODE" = true ] ; then
    popd
    export FABRIC_CFG_PATH=${PWD}
  fi

  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to start network"
    exit 1
  fi

  sleep 2
  if [ "$DEV_MODE" = true ] ; then
    NUM_CONTAINERS=6
  fi
  # Below check assumes there are no container running other than in our network
  NETWORK_CONTAINERS=$(docker ps -a | grep "hyperledger/\|couchdb" | wc -l)
  while [ $NETWORK_CONTAINERS -ne $NUM_CONTAINERS ]
  do
    sleep 2
    NETWORK_CONTAINERS=$(docker ps -a | grep "hyperledger/\|couchdb" | wc -l)
  done
  echo "Network containers started"
}

# Start the container for the new peer.
function newPeerUp () {
  checkPrereqs
  # generate artifacts if they don't exist
  if [ ! -d "crypto-config/peerOrganizations/importerorg.trade.com/peers/peer1.importerorg.trade.com" ]; then
    echo "Peer artifacts or configuration missing. Run './trade.sh createnewpeer' to recreate them."
    exit 1
  fi
  # Create folder for docker network logs
  LOG_DIR=$(dirname $LOG_FILE_NEW_PEER)
  if [ ! -d $LOG_DIR ]
  then
    mkdir -p $LOG_DIR
  fi
  docker-compose -f $COMPOSE_FILE_NEW_PEER up >$LOG_FILE_NEW_PEER 2>&1 &
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to start peer"
    exit 1
  fi
}

# Start the network components for the new org.
function newOrgNetworkUp () {
  checkPrereqs
  # generate artifacts if they don't exist
  if [ ! -d "crypto-config/peerOrganizations/exportingentityorg.trade.com" ]; then
    echo "New org crypto artifacts missing. Run './trade.sh createneworg -c <channel_name>' to create them."
    exit 1
  fi
  for dir in ./channel-artifacts/*
  do
    if [ -d $dir ]
    then
      if [ ! -f $dir/exportingEntityOrg.json ]
      then
        echo "New org channel configuration missing in "$dir". Run './trade.sh createneworg -c "$(basename $dir)"' to create it."
        exit 1
      fi
    fi
  done
  # Create folder for docker network logs
  LOG_DIR=$(dirname $LOG_FILE_NEW_ORG)
  if [ ! -d $LOG_DIR ]
  then
    mkdir -p $LOG_DIR
  fi
  docker-compose -f $COMPOSE_FILE_NEW_ORG up >$LOG_FILE_NEW_ORG 2>&1 &
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to start org network"
    exit 1
  fi
}

# Check if CLI container is running, and start it if it isn't
function checkAndStartCliContainer() {
  CLI_CONTAINERS=$(docker ps | grep $CONTAINER_CLI)
  if [ -z "$CLI_CONTAINERS" ] ; then
    echo "No CLI container running"
    # Start the container
    docker-compose -f $COMPOSE_FILE_CLI up >$LOG_FILE_CLI 2>&1 &
    if [ $? -ne 0 ]; then
      echo "ERROR !!!! Unable to start cli"
      exit 1
    fi
    sleep 2
    CLI_CONTAINERS=$(docker ps | grep $CONTAINER_CLI | wc -l)
    while [ $CLI_CONTAINERS -ne 1 ]
    do
      sleep 2
      CLI_CONTAINERS=$(docker ps | grep $CONTAINER_CLI | wc -l)
    done
    echo "CLI container started"
  fi
  echo "CLI container running"
}

# Create a channel using the generated genesis block.
function createChannel () {
  checkPrereqs

  # check presence of channel transaction file
  if [ ! -f "channel-artifacts/"${CHANNEL_NAME}"/channel.tx" ]; then
    echo "ERROR !!!! No 'channel.tx' found in folder 'channel-artifacts/"${CHANNEL_NAME}"'"
    echo "ERROR !!!! Run './trade.sh generate -c "$CHANNEL_NAME"' to create this transaction file"
    exit 1
  fi

  # Create folder for docker network logs
  LOG_DIR=$(dirname $LOG_FILE_CLI)
  if [ ! -d $LOG_DIR ]
  then
    mkdir -p $LOG_DIR
  fi

  # Check if the cli container is already running
  checkAndStartCliContainer

  # Create the channel
  docker exec -e CHANNEL_NAME=$CHANNEL_NAME $CONTAINER_CLI scripts/channel.sh create >>$LOG_FILE_CLI 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to create channel"
    echo "ERROR !!!! See "$LOG_FILE_CLI" for details"
    exit 1
  fi
  echo "Channel "$CHANNEL_NAME" created"
}

# Join peers to the channel with the given name.
function joinPeersToChannel () {
  checkPrereqs

  # Create folder for docker network logs
  LOG_DIR=$(dirname $LOG_FILE_CLI)
  if [ ! -d $LOG_DIR ]
  then
    mkdir -p $LOG_DIR
  fi

  # Check if the cli container is already running
  checkAndStartCliContainer

  # Join peers to the channel
  docker exec -e CHANNEL_NAME=$CHANNEL_NAME -e NUM_ORGS_IN_CHANNEL=$NUM_ORGS_IN_CHANNEL $CONTAINER_CLI scripts/channel.sh join >>$LOG_FILE_CLI 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to join channel"
    echo "ERROR !!!! See "$LOG_FILE_CLI" for details"
    exit 1
  fi
  echo "Joined peers to channel "$CHANNEL_NAME
}

# Join new peer to the channel with the given name.
function joinNewPeerToChannel () {
  checkPrereqs

  # Create folder for docker network logs
  LOG_DIR=$(dirname $LOG_FILE_CLI)
  if [ ! -d $LOG_DIR ]
  then
    mkdir -p $LOG_DIR
  fi

  # Restart the cli container to sync new peer's artifacts
  docker kill $CONTAINER_CLI
  docker rm $CONTAINER_CLI
  checkAndStartCliContainer

  # Join new peer to the channel
  docker exec -e CHANNEL_NAME=$CHANNEL_NAME -e PEER=peer1 -e ORG=importerorg $CONTAINER_CLI scripts/channel.sh joinnewpeer >>$LOG_FILE_CLI 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to join new peer to channel"
    echo "ERROR !!!! See "$LOG_FILE_CLI" for details"
    exit 1
  fi
  echo "Joined peer to channel "$CHANNEL_NAME
}

# Join peer of new org to the channel with the given name.
function joinNewOrgPeerToChannel () {
  checkPrereqs

  # Create folder for docker network logs
  LOG_DIR=$(dirname $LOG_FILE_CLI)
  if [ ! -d $LOG_DIR ]
  then
    mkdir -p $LOG_DIR
  fi

  # Restart the cli container to sync new peer's artifacts
  docker kill $CONTAINER_CLI
  docker rm $CONTAINER_CLI
  checkAndStartCliContainer

  # Join peer of new org to the channel
  docker exec -e CHANNEL_NAME=$CHANNEL_NAME -e PEER=peer0 -e ORG=exportingentityorg $CONTAINER_CLI scripts/channel.sh joinnewpeer >>$LOG_FILE_CLI 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to join peer of new org to channel"
    echo "ERROR !!!! See "$LOG_FILE_CLI" for details"
    exit 1
  fi
  echo "Joined peer of new org to channel "$CHANNEL_NAME
}

# Fetch latest channel configuration block
function fetchChannelConfig () {
  checkPrereqs

  # Create folder for docker network logs
  LOG_DIR=$(dirname $LOG_FILE_CLI)
  if [ ! -d $LOG_DIR ]
  then
    mkdir -p $LOG_DIR
  fi

  # Check if the cli container is already running
  checkAndStartCliContainer

  # Fetch channel config block
  docker exec -e CHANNEL_NAME=$CHANNEL_NAME $CONTAINER_CLI scripts/channel.sh fetch >>$LOG_FILE_CLI 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to join channel"
    echo "ERROR !!!! See "$LOG_FILE_CLI" for details"
    exit 1
  fi
  CLI_WORKING_DIR=$(docker exec $CONTAINER_CLI pwd)
  docker cp $CONTAINER_CLI:$CLI_WORKING_DIR/$CHANNEL_NAME.block $BLOCK_FILE
  echo "Fetched latest configuration block of channel "$CHANNEL_NAME
}

# Update anchor peers for all orgs.
function updateAnchorPeers () {
  checkPrereqs

  # Create folder for docker network logs
  LOG_DIR=$(dirname $LOG_FILE_CLI)
  if [ ! -d $LOG_DIR ]
  then
    mkdir -p $LOG_DIR
  fi

  # Check if the cli container is already running
  checkAndStartCliContainer

  # Set anchor peers on the channel
  docker exec -e CHANNEL_NAME=$CHANNEL_NAME -e NUM_ORGS_IN_CHANNEL=$NUM_ORGS_IN_CHANNEL $CONTAINER_CLI scripts/channel.sh anchor >>$LOG_FILE_CLI 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to set anchor peers in channel"
    echo "ERROR !!!! See "$LOG_FILE_CLI" for details"
    exit 1
  fi
  echo "Updated anchor peers in channel "$CHANNEL_NAME
}

# Update anchor peers for all orgs.
function updateNewOrgAnchorPeer () {
  checkPrereqs

  # Create folder for docker network logs
  LOG_DIR=$(dirname $LOG_FILE_CLI)
  if [ ! -d $LOG_DIR ]
  then
    mkdir -p $LOG_DIR
  fi

  # Check if the cli container is already running
  checkAndStartCliContainer

  # Set anchor peer for the new org on the channel
  docker exec -e CHANNEL_NAME=$CHANNEL_NAME $CONTAINER_CLI scripts/channel.sh anchorneworg >>$LOG_FILE_CLI 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to set anchor peer for new org in channel"
    echo "ERROR !!!! See "$LOG_FILE_CLI" for details"
    exit 1
  fi
  echo "Updated anchor peer for new org in channel "$CHANNEL_NAME
}

# Update a channel using the new organization's configuration JSON.
function updateChannel () {
  checkPrereqs

  # check presence of new organization's configuration JSON file
  if [ ! -f "channel-artifacts/"${CHANNEL_NAME}"/exportingEntityOrg.json" ]; then
    echo "ERROR !!!! No 'exportingEntityOrg.json' found in folder 'channel-artifacts/"${CHANNEL_NAME}"'"
    echo "ERROR !!!! Run './trade.sh createneworg -c "$CHANNEL_NAME"' to create this transaction file"
    exit 1
  fi

  # Create folder for docker network logs
  LOG_DIR=$(dirname $LOG_FILE_CLI)
  if [ ! -d $LOG_DIR ]
  then
    mkdir -p $LOG_DIR
  fi

  # Restart the cli container to sync new peer's artifacts
  docker kill $CONTAINER_CLI
  docker rm $CONTAINER_CLI
  checkAndStartCliContainer

  # Update the channel
  docker exec -e CHANNEL_NAME=$CHANNEL_NAME -e NUM_ORGS_IN_CHANNEL=$NUM_ORGS_IN_CHANNEL $CONTAINER_CLI scripts/channel.sh update >>$LOG_FILE_CLI 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to update channel"
    echo "ERROR !!!! See "$LOG_FILE_CLI" for details"
    exit 1
  fi
  echo "Channel "$CHANNEL_NAME" updated"
}

# Install contract on channel.
function installContract () {
  checkPrereqs

  # Create folder for docker network logs
  LOG_DIR=$(dirname $LOG_FILE_CLI)
  if [ ! -d $LOG_DIR ]
  then
    mkdir -p $LOG_DIR
  fi

  # Check if the cli container is already running
  checkAndStartCliContainer

  # Package contract
  if [ "$CONTRACT_NAME" == "trade" ]
  then
    CC_LANGUAGE=node
    PEERORGLIST="exporterorg importerorg regulatororg"
  elif [ "$CONTRACT_NAME" == "letterOfCredit" ]
  then
    CC_LANGUAGE=java
    PEERORGLIST="exporterorg importerorg"
  elif [ "$CONTRACT_NAME" == "exportLicense" ]
  then
    CC_LANGUAGE=java
    PEERORGLIST="exporterorg regulatororg"
  elif [ "$CONTRACT_NAME" == "shipment" ]
  then
    CC_LANGUAGE=node
    PEERORGLIST="exporterorg importerorg carrierorg"
  else
    echo "ERROR !!!! Unknown contract: "$CONTRACT_NAME
    exit 1
  fi
  docker exec -e CHANNEL_NAME=$CHANNEL_NAME -e CC_LANGUAGE=$CC_LANGUAGE -e CC_LABEL=$CONTRACT_NAME -e CC_VERSION=v1 trade_cli scripts/chaincode.sh package >>$LOG_FILE_CLI 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to package contract"
    echo "ERROR !!!! See "$LOG_FILE_CLI" for details"
    exit 1
  fi
  echo "Packaged contract "$CONTRACT_NAME" in channel "$CHANNEL_NAME

  # Install contract on peers
  docker exec -e CHANNEL_NAME=$CHANNEL_NAME -e PEERORGLIST="$PEERORGLIST" -e CC_LABEL=$CONTRACT_NAME -e CC_VERSION=v1 trade_cli scripts/chaincode.sh install >>$LOG_FILE_CLI 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to install contract on peers"
    echo "ERROR !!!! See "$LOG_FILE_CLI" for details"
    exit 1
  fi
  echo "Installed contract "$CONTRACT_NAME" in channel "$CHANNEL_NAME

  # Approve contract definition from each peer on channel
  docker exec -e CHANNEL_NAME=$CHANNEL_NAME -e NUM_ORGS_IN_CHANNEL=$NUM_ORGS_IN_CHANNEL -e PEERORGLIST="$PEERORGLIST" -e CC_LABEL=$CONTRACT_NAME -e CC_VERSION=v1 trade_cli scripts/chaincode.sh approve >>$LOG_FILE_CLI 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to approve contract definitions on channel"
    echo "ERROR !!!! See "$LOG_FILE_CLI" for details"
    exit 1
  fi
  echo "Approved contract "$CONTRACT_NAME" definitions in channel "$CHANNEL_NAME

  # Commit chaincode definition on channel
  docker exec -e CHANNEL_NAME=$CHANNEL_NAME -e NUM_ORGS_IN_CHANNEL=$NUM_ORGS_IN_CHANNEL -e PEERORGLIST="$PEERORGLIST" -e CC_LABEL=$CONTRACT_NAME -e CC_VERSION=v1 trade_cli scripts/chaincode.sh commit >>$LOG_FILE_CLI 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to commit contract definition on channel"
    echo "ERROR !!!! See "$LOG_FILE_CLI" for details"
    exit 1
  fi
  echo "Committed contract "$CONTRACT_NAME" definition in channel "$CHANNEL_NAME
}

# Initialize contract on channel.
function initContract () {
  checkPrereqs

  # Create folder for docker network logs
  LOG_DIR=$(dirname $LOG_FILE_CLI)
  if [ ! -d $LOG_DIR ]
  then
    mkdir -p $LOG_DIR
  fi

  # Check if the cli container is already running
  checkAndStartCliContainer

  # Initialize contract state on ledger
  if [ "$CONTRACT_NAME" == "trade" ]
  then
    PEERORGLIST="exporterorg importerorg regulatororg"
  elif [ "$CONTRACT_NAME" == "letterOfCredit" ]
  then
    PEERORGLIST="exporterorg importerorg"
  elif [ "$CONTRACT_NAME" == "exportLicense" ]
  then
    PEERORGLIST="exporterorg regulatororg"
  elif [ "$CONTRACT_NAME" == "shipment" ]
  then
    PEERORGLIST="exporterorg importerorg carrierorg"
  else
    echo "ERROR !!!! Unknown contract: "$CONTRACT_NAME
    exit 1
  fi
  docker exec -e CHANNEL_NAME=$CHANNEL_NAME -e PEERORGLIST="$PEERORGLIST" -e CC_LABEL=$CONTRACT_NAME -e CC_FUNC=$CONTRACT_FUNC -e CC_ARGS="$CONTRACT_ARGS" trade_cli scripts/chaincode.sh init >>$LOG_FILE_CLI 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to initialize contract"
    echo "ERROR !!!! See "$LOG_FILE_CLI" for details"
    exit 1
  fi
  echo "Initialized contract "$CONTRACT_NAME" state on ledger in channel "$CHANNEL_NAME
}

# Upgrade contract on channel.
function upgradeContract () {
  checkPrereqs

  # Create folder for docker network logs
  LOG_DIR=$(dirname $LOG_FILE_CLI)
  if [ ! -d $LOG_DIR ]
  then
    mkdir -p $LOG_DIR
  fi

  # Check if the cli container is already running
  docker kill $CONTAINER_CLI
  docker rm $CONTAINER_CLI
  checkAndStartCliContainer

  # Upgrade contract state on ledger
  if [ "$CONTRACT_NAME" == "trade" ]
  then
    CC_LANGUAGE=node
    PEERORGLIST="exporterorg importerorg regulatororg"
  elif [ "$CONTRACT_NAME" == "letterOfCredit" ]
  then
    CC_LANGUAGE=java
    PEERORGLIST="exporterorg importerorg"
  elif [ "$CONTRACT_NAME" == "exportLicense" ]
  then
    CC_LANGUAGE=java
    PEERORGLIST="exporterorg regulatororg"
  elif [ "$CONTRACT_NAME" == "shipment" ]
  then
    CC_LANGUAGE=node
    PEERORGLIST="exporterorg importerorg carrierorg"
  else
    echo "ERROR !!!! Unknown contract: "$CONTRACT_NAME
    exit 1
  fi
  docker exec -e CHANNEL_NAME=$CHANNEL_NAME -e NUM_ORGS_IN_CHANNEL=$NUM_ORGS_IN_CHANNEL -e PEERORGLIST="$PEERORGLIST" -e CC_LANGUAGE=$CC_LANGUAGE -e CC_LABEL=$CONTRACT_NAME -e CC_VERSION=v2 -e OLD_CC_VERSION=v1 -e CC_FUNC=$CONTRACT_FUNC -e CC_ARGS="$CONTRACT_ARGS" trade_cli scripts/chaincode.sh upgrade >>$LOG_FILE_CLI 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to upgrade contract"
    echo "ERROR !!!! See "$LOG_FILE_CLI" for details"
    exit 1
  fi
  echo "Upgraded contract "$CONTRACT_NAME" state on ledger in channel "$CHANNEL_NAME
}

# Invoke contract transaction on channel.
function invokeContract () {
  checkPrereqs

  # Create folder for docker network logs
  LOG_DIR=$(dirname $LOG_FILE_CLI)
  if [ ! -d $LOG_DIR ]
  then
    mkdir -p $LOG_DIR
  fi

  # Check if the cli container is already running
  checkAndStartCliContainer

  # Invoke contract transaction
  if [ "$CONTRACT_NAME" == "trade" ]
  then
    PEERORGLIST="exporterorg importerorg regulatororg"
  elif [ "$CONTRACT_NAME" == "letterOfCredit" ]
  then
    PEERORGLIST="exporterorg importerorg"
  elif [ "$CONTRACT_NAME" == "exportLicense" ]
  then
    PEERORGLIST="exporterorg regulatororg"
  elif [ "$CONTRACT_NAME" == "shipment" ]
  then
    PEERORGLIST="exporterorg importerorg carrierorg"
  else
    echo "ERROR !!!! Unknown contract: "$CONTRACT_NAME
    exit 1
  fi
  docker exec -e CHANNEL_NAME=$CHANNEL_NAME -e PEERORGLIST="$PEERORGLIST" -e CC_LABEL=$CONTRACT_NAME -e CC_FUNC=$CONTRACT_FUNC -e CC_ARGS="$CONTRACT_ARGS" -e ORGANIZATION=$ORGANIZATION trade_cli scripts/chaincode.sh invoke >>$LOG_FILE_CLI 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to invoke contract"
    echo "ERROR !!!! See "$LOG_FILE_CLI" for details"
    exit 1
  fi
  echo "Invoked contract "$CONTRACT_NAME" transaction in channel "$CHANNEL_NAME" using org "$ORGANIZATION
}

# Query contract function on channel.
function queryContract () {
  checkPrereqs

  # Create folder for docker network logs
  LOG_DIR=$(dirname $LOG_FILE_CLI)
  if [ ! -d $LOG_DIR ]
  then
    mkdir -p $LOG_DIR
  fi

  # Check if the cli container is already running
  checkAndStartCliContainer

  # Query contract function
  docker exec -e CHANNEL_NAME=$CHANNEL_NAME -e CC_LABEL=$CONTRACT_NAME -e CC_FUNC=$CONTRACT_FUNC -e CC_ARGS="$CONTRACT_ARGS" -e ORGANIZATION=$ORGANIZATION trade_cli scripts/chaincode.sh query >>$LOG_FILE_CLI 2>&1
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to query contract"
    echo "ERROR !!!! See "$LOG_FILE_CLI" for details"
    exit 1
  fi
  echo "Queried contract "$CONTRACT_NAME" function in channel "$CHANNEL_NAME" using org "$ORGANIZATION
}

# Upgrade the network from one version to another
# The new image tag is looked up from the .env file
# Stop the orderer and peers, backup the ledger from orderer and peers, cleanup chaincode containers and images
# and relaunch the orderer and peers with latest tag
function upgradeNetwork () {
  docker inspect  -f '{{.Config.Volumes}}' orderer.trade.com |grep -q '/var/hyperledger/production/orderer'
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! This network does not appear to be using volumes for its ledgers, did you start from fabric-samples >= v1.0.6?"
    exit 1
  fi

  LEDGERS_BACKUP=./ledgers-backup

  # create ledger-backup directory
  mkdir -p $LEDGERS_BACKUP
  if [ "$ORDERER_MODE" = "prod" ]
  then
    COMPOSE_FILES="-f $COMPOSE_FILE_RAFT"
    ORDERERS="orderer.trade.com orderer2.trade.com orderer3.trade.com orderer4.trade.com orderer5.trade.com"
  else
    COMPOSE_FILES="-f $COMPOSE_FILE"
    ORDERERS="orderer.trade.com"
  fi

  for ORDERER in $ORDERERS; do
    echo "Upgrading orderer $ORDERER"
    docker-compose $COMPOSE_FILES stop $ORDERER
    mkdir -p $LEDGERS_BACKUP/$ORDERER
    docker cp -a $ORDERER:/var/hyperledger/production/orderer $LEDGERS_BACKUP/$ORDERER/
    docker-compose $COMPOSE_FILES up --no-deps $ORDERER >$LOG_FILE 2>&1 &
  done

  for PEER in peer0.exporterorg.trade.com peer0.importerorg.trade.com peer0.carrierorg.trade.com peer0.regulatororg.trade.com; do
    echo "Upgrading peer $PEER"

    # Stop the peer and backup its ledger
    docker-compose $COMPOSE_FILES stop $PEER
    mkdir -p $LEDGERS_BACKUP/$PEER
    docker cp -a $PEER:/var/hyperledger/production $LEDGERS_BACKUP/$PEER/

    # Remove any old containers and images for this peer
    CC_CONTAINERS=$(docker ps | grep dev-$PEER | awk '{print $1}')
    if [ -n "$CC_CONTAINERS" ] ; then
        docker rm -f $CC_CONTAINERS
    fi
    CC_IMAGES=$(docker images | grep dev-$PEER | awk '{print $1}')
    if [ -n "$CC_IMAGES" ] ; then
        docker rmi -f $CC_IMAGES
    fi

    # Start the peer again
    docker-compose $COMPOSE_FILES up --no-deps $PEER >$LOG_FILE 2>&1 &
  done

  for CA in exporter importer carrier regulator; do
    echo "Upgrading CA ${CA}-ca"

    # Stop the CA and backup its database
    docker-compose $COMPOSE_FILES stop ${CA}-ca
    mkdir -p $LEDGERS_BACKUP/${CA}-ca
    docker cp -a ca.${CA}org.trade.com:/etc/hyperledger/fabric-ca-server $LEDGERS_BACKUP/${CA}-ca/

    # Start the CA again
    docker-compose $COMPOSE_FILES up --no-deps ${CA}-ca >$LOG_FILE 2>&1 &
  done
}

# Bring down running network
function networkDown () {
  if [ "$ORDERER_MODE" = "prod" ]
  then
    COMPOSE_FILES="-f "$COMPOSE_FILE_RAFT
  else
    COMPOSE_FILES="-f "$COMPOSE_FILE
  fi
  # If we are in dev mode, we move to the devmode directory
  if [ "$DEV_MODE" = true ] ; then
     pushd ./devmode
  else
     COMPOSE_FILES=$COMPOSE_FILES" -f "$COMPOSE_FILE_CLI" -f "$COMPOSE_FILE_NEW_PEER" -f "$COMPOSE_FILE_NEW_ORG" -f "$COMPOSE_FILE_REST" -f "$COMPOSE_FILE_COUCHDB
  fi

  # Stop network containers, and also the CLI container if it is running
  if [ "$RETAIN_VOLUMES" == "true" ]
  then
    docker-compose $COMPOSE_FILES down
  else
    docker-compose $COMPOSE_FILES down --volumes
  fi
  echo "Network containers stopped"

  for PEER in peer0.exporterorg.trade.com peer0.importerorg.trade.com peer0.carrierorg.trade.com peer0.regulatororg.trade.com peer1.importerorg.trade.com peer0.exportingentityorg.trade.com; do
    # Remove any old containers and images for this peer
    CC_CONTAINERS=$(docker ps -a | grep dev-$PEER | awk '{print $1}')
    if [ -n "$CC_CONTAINERS" ] ; then
      docker rm -f $CC_CONTAINERS
    fi
  done
  echo "Chaincode containers stopped"

  if [ "$DEV_MODE" = true ] ; then
     popd
  fi

  if [ "$RETAIN_VOLUMES" == "false" ]
  then
    echo "Pruning remaining local volumes"
    # Prune any remaining local volumes
    docker volume prune -f
  fi
}

# Bring down new peer
function newPeerDown () {
  docker-compose -f $COMPOSE_FILE_NEW_PEER down --volumes
  echo "Ignore any error messages of the form 'error while removing network' you see above!!!"
  docker volume rm ${COMPOSE_PROJECT_NAME}_peer1.importerorg.trade.com
}

# Bring down running network components of the new org
function newOrgNetworkDown () {
  docker-compose -f $COMPOSE_FILE_NEW_ORG down --volumes
  echo "Ignore any error messages of the form 'error while removing network' you see above!!!"

  for PEER in peer0.exportingentityorg.trade.com; do
    # Remove any old containers and images for this peer
    CC_CONTAINERS=$(docker ps -a | grep dev-$PEER | awk '{print $1}')
    if [ -n "$CC_CONTAINERS" ] ; then
      docker rm -f $CC_CONTAINERS
    fi
  done

  docker volume rm ${COMPOSE_PROJECT_NAME}_peer0.exportingentityorg.trade.com
}

# Delete dynamically created credentials, like wallet identities
function cleanDynamicIdentities () {
  # remove wallet identities
  rm -rf ../wallets/exporterorg/*
  rm -rf ../wallets/importerorg/*
  rm -rf ../wallets/carrierorg/*
  rm -rf ../wallets/regulatororg/*

  # remove client certs (this is a holdover from the legacy first-edition code)
  rm -rf client-certs
}

# Stop network, and delete dynamically created credentials and channel artifacts
function networkClean () {
  #Cleanup the chaincode containers and volumes
  NETWORK_CONTAINERS=$(docker ps -a | grep -v CONT | wc -l)
  if [ $NETWORK_CONTAINERS -gt 0 ]
  then
    networkDown
  fi
  # If we are in dev mode, we move to the devmode directory
  if [ "$DEV_MODE" = true ] ; then
     pushd ./devmode
  else
    # remove dynamic identities
    cleanDynamicIdentities
    # remove images created for contracts
    removeUnwantedImages
  fi
  # remove orderer block and other channel configuration transactions and certs
  rm -rf channel-artifacts
  if [ "$DEV_MODE" = true ] ; then
     popd
  fi
}

# Stop network, and delete dynamically created credentials, channel artifacts, and all crypto material
function networkCleanAll () {
  networkClean
  # If we are in dev mode, we move to the devmode directory
  if [ "$DEV_MODE" = true ] ; then
     pushd ./devmode
  fi
  rm -rf crypto-config
  if [ "$DEV_MODE" = true ] ; then
     popd
  fi
}

# We will use the cryptogen tool to generate the cryptographic material (x509 certs)
# for our various network entities.  The certificates are based on a standard PKI
# implementation where validation is achieved by reaching a common trust anchor.
#
# Cryptogen consumes a file - ``crypto-config.yaml`` - that contains the network
# topology and allows us to generate a library of certificates for both the
# Organizations and the components that belong to those Organizations.  Each
# Organization is provisioned a unique root certificate (``ca-cert``), that binds
# specific components (peers and orderers) to that Org.  Transactions and communications
# within Fabric are signed by an entity's private key (``keystore``), and then verified
# by means of a public key (``signcerts``).  You will notice a "count" variable within
# this file.  We use this to specify the number of peers per Organization; in our
# case it's two peers per Org.  The rest of this template is extremely
# self-explanatory.
#
# After we run the tool, the certs will be parked in a folder titled ``crypto-config``.

# Generates Org certs using cryptogen tool
function generateCerts () {
  which cryptogen
  if [ "$?" -ne 0 ]; then
    echo "cryptogen tool not found. exiting"
    exit 1
  fi
  echo
  echo "##########################################################"
  echo "##### Generate certificates using cryptogen tool #########"
  echo "##########################################################"

  if [ -d "crypto-config" ]; then
    echo "'crypto-config' folder already exists. Run 'rm -rf crypto-config' to delete existing credentials or './trade.sh -cleanall' to delete all existing artifacts if you wish to start from a clean slate."
    return
  fi
  set -x
  cryptogen generate --config=./crypto-config.yaml
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate certificates..."
    exit 1
  fi
  echo
}

function generateCertsForRaftOrderingNodes () {
  which cryptogen
  if [ "$?" -ne 0 ]; then
    echo "cryptogen tool not found. exiting"
    exit 1
  fi
  echo
  echo "##################################################################################"
  echo "###### Generate certificates for Raft ordering nodes using cryptogen tool ########"
  echo "##################################################################################"

  if [ -d "crypto-config/ordererOrganizations/trade.com/orderers/orderer2.trade.com/" ]; then
    echo "'crypto-config' already contains credentials for multiple ordering nodes. Run 'rm -rf crypto-config' to delete existing credentials or './trade.sh -cleanall' to delete all old artifacts if you wish to start from a clean slate."
    return
  fi
  set -x
  cryptogen extend --input=crypto-config --config=./multiple_orderers/crypto-config.yaml
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate certificates for new peer..."
    exit 1
  fi
  echo
}

function generateCertsForNewPeer () {
  which cryptogen
  if [ "$?" -ne 0 ]; then
    echo "cryptogen tool not found. exiting"
    exit 1
  fi
  echo
  echo "#######################################################################"
  echo "###### Generate certificates for new peer using cryptogen tool ########"
  echo "#######################################################################"

  if [ ! -d "crypto-config/peerOrganizations/importerorg.trade.com" ]; then
    echo "No crypto artifacts found for importer org. Please generate that first before trying to add a new peer."
    exit 1
  fi
  set -x
  cryptogen extend --input=crypto-config --config=./add_peer_importer/crypto-config.yaml
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate certificates for new peer..."
    exit 1
  fi
  echo
}

function generateCertsForNewOrg () {
  which cryptogen
  if [ "$?" -ne 0 ]; then
    echo "cryptogen tool not found. exiting"
    exit 1
  fi
  echo
  echo "######################################################################"
  echo "##### Generate certificates for new org using cryptogen tool #########"
  echo "######################################################################"

  if [ -d "crypto-config/peerOrganizations/exportingentityorg.trade.com" ]; then
    echo "Crypto artifacts already exist for 'exportingentityorg.trade.com'. Delete the folder 'crypto-config/peerOrganizations/exportingentityorg.trade.com' and re-run this operation if you wish to generate fresh artifacts."
    return
  fi
  set -x
  cryptogen extend --input=crypto-config --config=./add_org/crypto-config.yaml
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate certificates for new org..."
    exit 1
  fi
  echo
}

# The `configtxgen tool is used to create four artifacts: orderer **bootstrap
# block**, fabric **channel configuration transaction**, and an **anchor
# peer transaction** - one for each Peer Org.
#
# The orderer block is the genesis block for the ordering service, and the
# channel transaction file is broadcast to the orderer at channel creation
# time.  The anchor peer transactions, as the name might suggest, specify each
# Org's anchor peer on this channel.
#
# Configtxgen consumes a file - ``configtx.yaml`` - that contains the definitions
# for the sample network. This file also contains two additional specifications that are worth
# noting.  Firstly, we specify the anchor peers for each Peer Org
# (``peer0.exporterorg.trade.com`` & ``peer0.importerorg.trade.com``).  Secondly, we point to
# the location of the MSP directory for each member, in turn allowing us to store the
# root certificates for each Org in the orderer genesis block.  This is a critical
# concept. Now any network entity communicating with the ordering service can have
# its digital signature verified.
#
# This function will generate the crypto material and our four configuration
# artifacts, and subsequently output these files into the ``channel-artifacts/<channel_name>``
# folder.
#
# If you receive the following warning, it can be safely ignored:
#
# [bccsp] GetDefault -> WARN 001 Before using BCCSP, please call InitFactories(). Falling back to bootBCCSP.
#
# You can ignore the logs regarding intermediate certs, we are not using them in
# this crypto implementation.

# Generate orderer genesis block, channel configuration transaction and
# anchor peer update transactions
function generateChannelArtifacts() {
  which configtxgen
  if [ "$?" -ne 0 ]; then
    echo "configtxgen tool not found. exiting"
    exit 1
  fi

  mkdir -p channel-artifacts/${CHANNEL_NAME}

  if [ "$DEV_MODE" = true ] ; then
    PROFILE=OneOrgTradeOrdererGenesis
    CHANNEL_PROFILE=OneOrgTradeChannel
  elif [ "$ORDERER_MODE" = "prod" ]
  then
    PROFILE=TradeMultiNodeEtcdRaft
    if [ "$NUM_ORGS_IN_CHANNEL" == "3" ]
    then
      CHANNEL_PROFILE=ThreeOrgsTradeChannel
    elif [ "$NUM_ORGS_IN_CHANNEL" == "4" ]
    then
      CHANNEL_PROFILE=FourOrgsShippingChannel
    else
      echo "Invalid number of orgs (in channel) requested: ${NUM_ORGS_IN_CHANNEL}. Only supported values: {3,4}"
      exit 1
    fi
    FABRIC_CFG_PATH=${PWD}/multiple_orderers
  else
    PROFILE=FourOrgsTradeOrdererGenesis
    if [ "$NUM_ORGS_IN_CHANNEL" == "3" ]
    then
      CHANNEL_PROFILE=ThreeOrgsTradeChannel
    elif [ "$NUM_ORGS_IN_CHANNEL" == "4" ]
    then
      CHANNEL_PROFILE=FourOrgsShippingChannel
    else
      echo "Invalid number of orgs (in channel) requested: ${NUM_ORGS_IN_CHANNEL}. Only supported values: {3,4}"
      exit 1
    fi
  fi

  # Overwrite genesis block if it exists
  echo "###########################################################"
  echo "#########  Generating Orderer Genesis block  ##############"
  echo "###########################################################"

  # Note: For some unknown reason (at least for now) the block file can't be
  # named orderer.genesis.block or the orderer will fail to launch!
  set -x
  configtxgen -profile $PROFILE -channelID $SYS_CHANNEL -outputBlock ./channel-artifacts/genesis.block
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate orderer genesis block..."
    exit 1
  fi
  echo

  echo "###################################################################"
  echo "###  Generating channel configuration transaction  'channel.tx' ###"
  echo "###################################################################"
  set -x
  configtxgen -profile $CHANNEL_PROFILE -outputCreateChannelTx ./channel-artifacts/${CHANNEL_NAME}/channel.tx -channelID $CHANNEL_NAME
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate channel configuration transaction..."
    exit 1
  fi

  if [ "$DEV_MODE" = false ] ; then
    echo
    echo "#####################################################################"
    echo "#######   Generating anchor peer update for ExporterOrg    ##########"
    echo "#####################################################################"
    set -x
    configtxgen -profile $CHANNEL_PROFILE -outputAnchorPeersUpdate ./channel-artifacts/${CHANNEL_NAME}/ExporterOrgMSPanchors.tx -asOrg ExporterOrg -channelID $CHANNEL_NAME
    res=$?
    set +x
    if [ $res -ne 0 ]; then
      echo "Failed to generate anchor peer update for ExporterOrg..."
      exit 1
    fi

    echo
    echo "#####################################################################"
    echo "#######   Generating anchor peer update for ImporterOrg    ##########"
    echo "#####################################################################"
    set -x
    configtxgen -profile $CHANNEL_PROFILE -outputAnchorPeersUpdate ./channel-artifacts/${CHANNEL_NAME}/ImporterOrgMSPanchors.tx -asOrg ImporterOrg -channelID $CHANNEL_NAME
    res=$?
    set +x
    if [ $res -ne 0 ]; then
      echo "Failed to generate anchor peer update for ImporterOrg..."
      exit 1
    fi

    if [ "$NUM_ORGS_IN_CHANNEL" == "4" ]
    then
      echo
      echo "####################################################################"
      echo "#######   Generating anchor peer update for CarrierOrg    ##########"
      echo "####################################################################"
      set -x
      configtxgen -profile $CHANNEL_PROFILE -outputAnchorPeersUpdate ./channel-artifacts/${CHANNEL_NAME}/CarrierOrgMSPanchors.tx -asOrg CarrierOrg -channelID $CHANNEL_NAME
      res=$?
      set +x
      if [ $res -ne 0 ]; then
        echo "Failed to generate anchor peer update for CarrierOrg..."
        exit 1
      fi
    fi

    echo
    echo "######################################################################"
    echo "#######   Generating anchor peer update for RegulatorOrg    ##########"
    echo "######################################################################"
    set -x
    configtxgen -profile $CHANNEL_PROFILE -outputAnchorPeersUpdate ./channel-artifacts/${CHANNEL_NAME}/RegulatorOrgMSPanchors.tx -asOrg RegulatorOrg -channelID $CHANNEL_NAME
    res=$?
    set +x
    if [ $res -ne 0 ]; then
      echo "Failed to generate anchor peer update for RegulatorOrg..."
      exit 1
    fi
    echo
  fi
}

# Generate configuration (policies, certificates) for new org in JSON format
function generateChannelConfigForNewOrg() {
  which configtxgen
  if [ "$?" -ne 0 ]; then
    echo "configtxgen tool not found. exiting"
    exit 1
  fi

  mkdir -p channel-artifacts/${CHANNEL_NAME}

  echo "####################################################################################"
  echo "#########  Generating Channel Configuration for Exporting Entity Org  ##############"
  echo "####################################################################################"
  set -x
  FABRIC_CFG_PATH=${PWD}/add_org/ && configtxgen -printOrg ExportingEntityOrg -channelID $CHANNEL_NAME > ./channel-artifacts/${CHANNEL_NAME}/exportingEntityOrg.json
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate channel configuration for exportingentity org..."
    exit 1
  fi
  echo
}

function startRestServers() {
  # Create folder for docker network logs
  LOG_DIR=$(dirname $LOG_FILE_REST)
  if [ ! -d $LOG_DIR ]
  then
    mkdir -p $LOG_DIR
  fi

  docker-compose -f $COMPOSE_FILE_REST up >$LOG_FILE_REST 2>&1 &

  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to start the rest servers"
    exit 1
  fi
  echo "REST containers started"
}

function stopRestServers() {
  docker-compose -f $COMPOSE_FILE_REST down --volumes
  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to stop the rest servers"
    exit 1
  fi
  echo "REST containers stopped"
}

# use this as the default docker-compose yaml definition
CHANNEL_NAME_DEV_MODE=trade-dev-channel
COMPOSE_FILE=docker-compose-e2e.yaml
COMPOSE_FILE_NEW_PEER=docker-compose-another-importer-peer.yaml
COMPOSE_FILE_NEW_ORG=docker-compose-exportingEntityOrg.yaml
COMPOSE_FILE_RAFT=docker-compose-raft-orderer.yaml
COMPOSE_FILE_CLI=docker-compose-cli.yaml
COMPOSE_FILE_REST=docker-compose-rest.yaml
COMPOSE_FILE_COUCHDB=docker-compose-couchdb.yaml
# default container names
CONTAINER_CLI=trade_cli
FABRIC_VERSION="2.2"
# default log file
LOG_FILE="logs/network.log"
LOG_FILE_NEW_PEER="logs/network-newpeer.log"
LOG_FILE_NEW_ORG="logs/network-neworg.log"
LOG_FILE_CLI="logs/network-cli.log"
LOG_FILE_REST="logs/network-rest.log"
ORDERER_MODE=test
CONTRACT_ARGS=
DB_TYPE=couchdb
RETAIN_VOLUMES=false


# Parse commandline args

MODE=$1;shift
# Determine whether starting, stopping, restarting or generating for announce
if [ "$MODE" == "up" ]; then
  EXPMODE="Starting network"
elif [ "$MODE" == "down" ]; then
  EXPMODE="Stopping network"
elif [ "$MODE" == "restart" ]; then
  EXPMODE="Restarting network"
elif [ "$MODE" == "clean" ]; then
  EXPMODE="Cleaning network and channel configurations"
elif [ "$MODE" == "cleanall" ]; then
  EXPMODE="Cleaning network, channel configurations, and crypto artifacts"
elif [ "$MODE" == "generate" ]; then
  EXPMODE="Generating certs and genesis block"
elif [ "$MODE" == "createchannel" ]; then
  EXPMODE="Creating channel through ordering service using channel transaction"
elif [ "$MODE" == "joinchannel" ]; then
  EXPMODE="Joining peers to channel"
elif [ "$MODE" == "fetchconfig" ]; then
  EXPMODE="Fetching latest channel configuration block"
elif [ "$MODE" == "updateanchorpeers" ]; then
  EXPMODE="Updating anchor peers for orgs"
elif [ "$MODE" == "updatechannel" ]; then
  EXPMODE="Updating channel configuration through ordering service to add a new org"
elif [ "$MODE" == "installcontract" ]; then
  EXPMODE="Installing contract on channel"
elif [ "$MODE" == "initcontract" ]; then
  EXPMODE="Initializing contract on channel"
elif [ "$MODE" == "upgradecontract" ]; then
  EXPMODE="Upgrading contract on channel after addition of new org"
elif [ "$MODE" == "invokecontract" ]; then
  EXPMODE="Invoking contract on channel"
elif [ "$MODE" == "querycontract" ]; then
  EXPMODE="Querying contract on channel"
elif [ "$MODE" == "upgrade" ]; then
  EXPMODE="Upgrading the network"
elif [ "$MODE" == "createnewpeer" ]; then
  EXPMODE="Generating certs for new peer"
elif [ "$MODE" == "startnewpeer" ]; then
  EXPMODE="Starting new peer"
elif [ "$MODE" == "stopnewpeer" ]; then
  EXPMODE="Stopping new peer"
elif [ "$MODE" == "joinnewpeer" ]; then
  EXPMODE="Joining new peer to existing channels"
elif [ "$MODE" == "createneworg" ]; then
  EXPMODE="Generating certs and configuration for new org"
elif [ "$MODE" == "startneworg" ]; then
  EXPMODE="Starting peer and CA for new org"
elif [ "$MODE" == "stopneworg" ]; then
  EXPMODE="Stopping peer and CA for new org"
elif [ "$MODE" == "joinneworg" ]; then
  EXPMODE="Joining peer of new org to existing channels"
elif [ "$MODE" == "updateneworganchorpeer" ]; then
  EXPMODE="Updating anchor peer for new org"
elif [ "$MODE" == "startrest" ]; then
  EXPMODE="Starting REST servers"
elif [ "$MODE" == "stoprest" ]; then
  EXPMODE="Stopping REST servers"
else
  printHelp
  exit 1
fi

while getopts "h?c:p:f:g:l:b:o:d:t:a:m:s:r" opt; do
  case "$opt" in
    h|\?)
      printHelp
      exit 0
    ;;
    c)  CHANNEL_NAME=$OPTARG
    ;;
    p)  CONTRACT_NAME=$OPTARG
    ;;
    f)  COMPOSE_FILE=$OPTARG
    ;;
    g)  ORGANIZATION=$OPTARG
    ;;
    l)  LOG_FILE=$OPTARG
    ;;
    b)  BLOCK_FILE=$OPTARG
    ;;
    o)  NUM_ORGS_IN_CHANNEL=$OPTARG
    ;;
    d)  DEV_MODE=$OPTARG 
    ;;
    t)  CONTRACT_FUNC=$OPTARG
    ;;
    a)  CONTRACT_ARGS=$OPTARG
    ;;
    m)  ORDERER_MODE=$OPTARG
    ;;
    s)  DB_TYPE=$OPTARG
    ;;
    r)  RETAIN_VOLUMES=true
    ;;
  esac
done

if [ "$BLOCK_FILE" == "" ]
then
  BLOCK_FILE=$CHANNEL_NAME.block
fi

# Load default environment variables
source .env

#Create the network using docker compose
if [ "${MODE}" == "up" ]; then
  echo "${EXPMODE}"
  networkUp
elif [ "${MODE}" == "down" ]; then ## Clear the network
  echo "${EXPMODE}"
  networkDown
elif [ "${MODE}" == "generate" ]; then ## Generate Artifacts
  if [ "$DEV_MODE" = "true" ] ; then
    CHANNEL_NAME=$CHANNEL_NAME_DEV_MODE
  else
    verifyChannelName
    verifyNumOrgsInChannel
  fi
  echo "${EXPMODE} for channel '${CHANNEL_NAME}'"
  generateConfig
elif [ "${MODE}" == "restart" ]; then ## Restart the network
  echo "${EXPMODE}"
  networkDown
  networkUp
elif [ "${MODE}" == "reset" ]; then ## Delete chaincode containers and dynamically created user credentials while keeping network artifacts
  echo "${EXPMODE}"
  cleanDynamicIdentities
  removeUnwantedImages
elif [ "${MODE}" == "clean" ]; then ## Delete network artifacts, chaincode containers, contract images, and dynamically created user credentials
  echo "${EXPMODE}"
  networkClean
elif [ "${MODE}" == "cleanall" ]; then ## Delete network artifacts, chaincode containers, contract images, statically and dynamically created user credentials
  echo "${EXPMODE}"
  networkCleanAll
elif [ "${MODE}" == "createchannel" ]; then ## Create a channel with the given name
  verifyChannelName
  echo "${EXPMODE} for channel '${CHANNEL_NAME}'"
  createChannel
elif [ "${MODE}" == "joinchannel" ]; then ## Join all orgs' peers to a channel with the given name
  verifyChannelName
  verifyNumOrgsInChannel
  echo "${EXPMODE} for channel '${CHANNEL_NAME}'"
  joinPeersToChannel
elif [ "${MODE}" == "fetchconfig" ]; then ## Fetch latest configuration block of channel with the given name
  verifyChannelName
  echo "${EXPMODE} for channel '${CHANNEL_NAME}'"
  fetchChannelConfig
elif [ "${MODE}" == "updateanchorpeers" ]; then ## Update anchor peers of orgs in channel with the given name
  verifyChannelName
  verifyNumOrgsInChannel
  echo "${EXPMODE} for channel '${CHANNEL_NAME}'"
  updateAnchorPeers
elif [ "${MODE}" == "updatechannel" ]; then ## Update a channel with the given name to add a new org
  verifyChannelName
  verifyNumOrgsInChannel
  echo "${EXPMODE} for channel '${CHANNEL_NAME}'"
  updateChannel
elif [ "${MODE}" == "installcontract" ]; then ## Install contract on channel
  verifyChannelName
  verifyNumOrgsInChannel
  verifyContractName
  echo "${EXPMODE} for contract '${CONTRACT_NAME}' on channel '${CHANNEL_NAME}'"
  installContract
elif [ "${MODE}" == "initcontract" ]; then ## Initialize contract ledger state using designated function and arguments
  verifyChannelName
  verifyContractName
  verifyContractFunc
  echo "${EXPMODE} for contract '${CONTRACT_NAME}' on channel '${CHANNEL_NAME}'"
  initContract
elif [ "${MODE}" == "upgradecontract" ]; then ## Upgrade contract code after addition of new org
  verifyChannelName
  verifyNumOrgsInChannel
  verifyContractName
  verifyContractFunc
  echo "${EXPMODE} for contract '${CONTRACT_NAME}' on channel '${CHANNEL_NAME}'"
  upgradeContract
elif [ "${MODE}" == "invokecontract" ]; then ## Invoke contract transaction
  verifyChannelName
  verifyContractName
  verifyContractFunc
  verifyOrganization
  echo "${EXPMODE} for contract '${CONTRACT_NAME}' on channel '${CHANNEL_NAME}' using organization '${ORGANIZATION}'"
  invokeContract
elif [ "${MODE}" == "querycontract" ]; then ## Query contract function
  verifyChannelName
  verifyContractName
  verifyContractFunc
  verifyOrganization
  echo "${EXPMODE} for contract '${CONTRACT_NAME}' on channel '${CHANNEL_NAME}' using organization '${ORGANIZATION}'"
  queryContract
elif [ "${MODE}" == "upgrade" ]; then ## Upgrade the network from one version to another (new Fabric and Fabric-CA versions specified in .env)
  echo "${EXPMODE}"
  upgradeNetwork
elif [ "${MODE}" == "createnewpeer" ]; then ## Create crypto artifacts for new peer
  echo "${EXPMODE}"
  generateCertsForNewPeer
elif [ "${MODE}" == "startnewpeer" ]; then ## Start new peer
  echo "${EXPMODE}"
  newPeerUp
elif [ "${MODE}" == "stopnewpeer" ]; then ## Start new peer
  echo "${EXPMODE}"
  newPeerDown
elif [ "${MODE}" == "joinnewpeer" ]; then ## Join new peer to channel
  verifyChannelName
  echo "${EXPMODE} for channel '${CHANNEL_NAME}'"
  joinNewPeerToChannel
elif [ "${MODE}" == "createneworg" ]; then ## Generate artifacts for new org
  verifyChannelName
  echo "${EXPMODE} for channel '${CHANNEL_NAME}'"
  generateCertsForNewOrg
  generateChannelConfigForNewOrg
elif [ "${MODE}" == "startneworg" ]; then ## Start the network components for the new org
  echo "${EXPMODE}"
  newOrgNetworkUp
elif [ "${MODE}" == "stopneworg" ]; then ## Stop the network components for the new org
  echo "${EXPMODE}"
  newOrgNetworkDown
elif [ "${MODE}" == "joinneworg" ]; then ## Join peer of new org to channel
  verifyChannelName
  echo "${EXPMODE} for channel '${CHANNEL_NAME}'"
  joinNewOrgPeerToChannel
elif [ "$MODE" == "updateneworganchorpeer" ]; then ## Update anchor peer for new org on channel
  verifyChannelName
  echo "${EXPMODE} for channel '${CHANNEL_NAME}'"
  updateNewOrgAnchorPeer
elif [ "${MODE}" == "startrest" ]; then ## Start rest servers
  echo "${EXPMODE}"
  startRestServers
elif [ "${MODE}" == "stoprest" ]; then ## Stop rest servers
  echo "${EXPMODE}"
  stopRestServers
else
  printHelp
  exit 1
fi
