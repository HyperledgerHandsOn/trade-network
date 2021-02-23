#!/bin/bash
#
# SPDX-License-Identifier: Apache-2.0
#
mkdir -p ../../gateways
node manage-connection-profile.js --generate exporterorg ExporterOrgMSP 7051 7054
node manage-connection-profile.js --generate importerorg ImporterOrgMSP 8051 8054
node manage-connection-profile.js --generate carrierorg CarrierOrgMSP 9051 9054
node manage-connection-profile.js --generate regulatororg RegulatorOrgMSP 10051 10054
