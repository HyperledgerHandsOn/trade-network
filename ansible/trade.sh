#!/bin/bash
#
# SPDX-License-Identifier: Apache-2.0
#


# Print the usage message
function printHelp () {
  echo "Usage: "
  echo "  trade.sh up|down"
  echo "  trade.sh -h|--help (print this message)"
  echo "    <mode> - one of 'up', 'down'"
  echo "      - 'up' - bring up the network with ansible and state=present"
  echo "      - 'down' - clear the network with ansible and state=absent"
}

MODE=$1;shift
#Create the network using ansible
if [ "${MODE}" == "up" ]; then
  echo "Starting network"
  ansible-playbook playbook.yaml 
elif [ "${MODE}" == "down" ]; then ## Clear the network
  echo "Stopping network"
  ansible-playbook playbook.yaml --extra-vars "state=absent"
  docker rm $(docker ps -aq)
  docker volume rm $(docker volume ls -q)
  docker network rm ibp_network
  docker image ls --format "{{.Repository}}" | grep "dev-" | xargs docker rmi
else
  printHelp
  exit 1
fi
