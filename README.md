# Trade Network

## Use Case Description
See the [Use Case Document](USE-CASE.md) for a full description of the use case driving the Fabric network and application.

## Overview  
  
The diagram below depicts the network that will be deployed by the scripts in this repository:  
  
  ![network-overview](./images/network-overview.png)  

The trade network includes 4 organizations on the network which will all have their peers, REST servers and User interfaces:
  
  * ImporterOrg - Includes the importer and it's bank 
  * ExporterOrg - Includes the exporter and it's bank  
  * RegulatorOrg
  * CarrierOrg 

Note that for the ImporterOrg and ExporterOrg organization we are also include their respective bank.  In a full fledge production network these would be separate organization.  They were kept together to keep the deployment size of this network reasonable.  

In terms of channel, the trade network relies on a separation of concerns, distinguishing the domain surrounding a trade (trade & letter of credit contracts) from the concern of shipping(export license and shipment contracts).  

Also worth mentioning that we are mixing Java and Typescript as smart contracts. While we are using different programming language, they are able to invoke each other where appropriate.  

With regards to the REST servers, the same approach has been taken and some servers have been implemented in Java (Regulator and Importer) while the other two have been implemented in JavaScript.  

We intend on eventually releasing the command line interfaces, while they make a nice addition, allowing people to view the interactions, the integration tests and the curl scripts from the trade-apps allow you to easily generate transactions on the network.  

This repository contains two submodules:  
  
  * `apps` - references the trade-apps repo
  * `contracts` - references the trade-contract repo

These have been included to make it easy to reference components from these repo using relative path.  As you clone this repo, make sure to include the option `--recurse-submodules` to ensure that it also loads the submodules.

Here is the complete command:
  
```
git clone --recurse-submodules git@github.com/Hyperledger-Book-2nd-Edition/trade-network.git
```  
  
## Starting up the network 
This repository contains various scripts to stand up the trade network. Here are the links to each one:

1. [Ansible](./ansible/)
2. [Bash](./bash/)

Follow the instructions for each option to properly start it.

All scripts create the following:
  
### TradeOrdererOrg  
  
MSP ID: TradeOrdererOrgMSP  
CA URL: ca.orderer.example.com:6054 (Only provisioned by Ansible)  
CA Admin/Password: admin/adminpw  
Organization Admin/Password: ordererOrgAdmin/ordererOrgAdminpw  
Orderer: orderer.trade.com:7050 (port, chaincode port, operation)  

### ExporterOrg  

MSP ID: ExporterOrgMSP  
CA URL: ca.exporterorg.example.com:7054  
CA Admin/Password: admin/adminpw  
Organization Admin/Password: exporterOrgAdmin/exporterOrgAdminpw  
Peer: peer0.exporterorg.example.com:7051

### ImporterOrg  
  
MSP ID: ImporterOrgMSP  
CA URL: ca.importerorg.example.com:8054  
CA Admin/Password: admin/adminpw  
Organization Admin/Password: importerOrgAdmin/importerOrgAdminpw  
Peer: peer0.importerorg.example.com:8051  
 
### CarrierOrg  
  
MSP ID: CarrierOrgMSP  
CA URL: ca.carrierorg.example.com:9054  
CA Admin/Password: admin/adminpw  
Organization Admin/Password: carrierOrgAdmin/carrierOrgAdminpw  
Peer: peer0.carrierorg.example.com:9051  
   
### RegulatorOrg  
  
MSP ID: RegulatorOrgMSP  
CA URL: ca.regulatororg.example.com:10054    
CA Admin/Password: admin/adminpw  
Organization Admin/Password: regulatorOrgAdmin/regulatorOrgAdminpw  
Peer: peer0.regulatororg.example.com:10051  
