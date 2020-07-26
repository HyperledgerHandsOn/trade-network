#!/usr/bin/env bash
#
# SPDX-License-Identifier: Apache-2.0
#
set -ex
ROOT=$(git rev-parse --show-toplevel)
cd ${ROOT}
git archive -o docker/ansible-role-blockchain-platform-manager.tar.gz HEAD
cd docker
docker build -t ibmblockchain/ansible:latest .