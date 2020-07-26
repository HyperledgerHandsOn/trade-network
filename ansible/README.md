# ansible trade network

This folder contains an Ansible playbook for standing up a IBM Blockchain Platform network with four organizations, `ImporterOrg`, `ExporterOrg`, `CarrierOrg` and `RegulatorOrg`. Each organization have one peer. The organizations are configured with a the following channels:  
  
* `tradechannel`: `ImporterOrg`, `ExporterOrg` and `RegulatorOrg`  
* `shippingchannel`: `ImporterOrg`, `ExporterOrg`, `CarrierOrg` and `RegulatorOrg`

The playbook will also deploy all four smart contracts on the respective channels and will generate all required artefacts.  
  

Getting Started
----------------
  
To run this Ansible playbook, follow these steps:

1. Ensure that you have all of the [pre-requisites](./roles/ibm.blockchain_platform_manager/README.md) installed.

3. (Optional) This Ansible playbook defaults to deploying to Docker. To configure the Ansible playbook to deploy to the IBM Blockchain Platform on IBM Cloud, follow these steps:

    1. Edit the playbook such that the `infrastructure.type` variable is set to `saas`:

        ```yaml
        infrastructure:
          type: saas
          saas: "{{ lookup('file', 'service-creds.json') | from_json }}"
        ```

    2. Create a file named `service-creds.json` that contains valid service credentials for an IBM Blockchain Platform service instance on IBM Cloud. These service credentials should be of the format:

        ```json
        {
          "api_endpoint": "https://xxxxxx-optools.uss02.blockchain.cloud.ibm.com",
          "apikey": "xxxxxx",
          "configtxlator": "https://xxxxxx-configtxlator.uss02.blockchain.cloud.ibm.com",
          "iam_apikey_description": "Auto-generated for key xxxxxx",
          "iam_apikey_name": "xxxxxx",
          "iam_role_crn": "crn:v1:bluemix:public:iam::::serviceRole:Manager",
          "iam_serviceid_crn": "crn:v1:bluemix:public:iam-identity::a/xxxxxx::serviceid:ServiceId-xxxxxx"
        }
        ```

4. Run the Ansible playbook:

    `ansible-playbook playbook.yml`

    **Note:** A convenience script called `trade.sh` has been provided. `./trade.sh up` will start the network, while `./trade.sh down` will teardown the network and remove all docker containers, volumes and network created by the script.  

5. Information on the available nodes (peers, orderers, and certificate authorities) will be created under the `nodes` subdirectory.

    1. If you wish to use this network for development purposes, you can import these JSON files into a Fabric Environment using the IBM Blockchain Platform extension for Visual Studio Code.

        For more information on this task, follow the process to create a new Fabric Environment documented here: https://github.com/IBM-Blockchain/blockchain-vscode-extension#connecting-to-another-instance-of-hyperledger-fabric

    2. If you are using the IBM Blockchain Platform on IBM Cloud, you do not need to import these JSON files. All of the nodes will already be present in your web console.

6. The `wallets` subdirectory will contain all of the identities (certificates and private keys) enrolled by this playbook. You must be careful to persist all of these files for the next time you run this playbook, otherwise you will be unable to administer your IBM Blockchain Platform network.

    1. If you wish to use this network for development purposes, you can import these JSON files into a wallet using the IBM Blockchain Platform extension for Visual Studio Code.

        For more information on this task, follow the process to create a new Fabric Environment documented here: https://github.com/IBM-Blockchain/blockchain-vscode-extension#connecting-to-another-instance-of-hyperledger-fabric

    2. If you are using the IBM Blockchain Platform on IBM Cloud, you do need to import these JSON files into your wallet using the web console. You will then need to assiociate each node with the correct identity. If you do not do this, then you will be unable to administer the nodes using the web console.

7. The gateways subdirectory contains the connection profile required for application using the Fabric SDK to connect to the network.  
  
License
-------

Apache-2.0