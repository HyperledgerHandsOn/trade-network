ansible-role-blockchain-platform-manager
=========

[![Build Status](https://dev.azure.com/IBM-Blockchain/ansible-role-blockchain-platform-manager/_apis/build/status/IBM-Blockchain.ansible-role-blockchain-platform-manager?branchName=master)](https://dev.azure.com/IBM-Blockchain/ansible-role-blockchain-platform-manager/_build/latest?definitionId=1&branchName=master)

The IBM Blockchain Platform provides advanced tooling that allows you to quickly build, operate & govern and grow blockchain networks. It uses Hyperledger Fabric, the open source, industry standard for enterprise blockchain. It also helps you to deploy Hyperledger Fabric networks anywhere, either to cloud or on-premises, using Kubernetes.

This Ansible role, provided as part of the IBM Blockchain Platform, enables you to automate the building of Hyperledger Fabric networks.

You can install this role from [Ansible Galaxy](https://galaxy.ansible.com/ibm/blockchain_platform_manager):

`ansible-galaxy install ibm.blockchain_platform_manager`

You can find example playbooks on GitHub in the [ansible-examples](https://github.com/IBM-Blockchain/ansible-examples) repository. A good starting point for building your own Hyperledger Fabric networks is the [two-org-network](https://github.com/IBM-Blockchain/ansible-examples/tree/master/two-org-network) example.

Requirements
------------

This Ansible role requires the following pre-requisites:
- Python 3.7+
  - https://www.python.org/downloads/
- Ansible 2.8+
  - `pip install ansible`
- Hyperledger Fabric v1.4 binaries (`configtxgen`, `peer`, `fabric-ca-client`, etc)
  - https://hyperledger-fabric.readthedocs.io/en/release-1.4/install.html
- One of the following supported deployment targets:
  - IBM Blockchain Platform on IBM Cloud
  - IBM Blockchain Platform on Red Hat OpenShift
  - Docker 19.03+
- Docker SDK for Python (if using Docker)
  - `pip install docker`
- `jq`
  - https://stedolan.github.io/jq/download/
- `sponge`
  - `apt-get install moreutils` (Ubuntu)
  - `brew install moreutils` (macOS)

Role Variables
--------------

Coming soon!

Dependencies
------------

This Ansible role has no dependencies on any other Ansible roles.

Example Playbook
----------------

```yaml
---
- name: Deploy blockchain infrastructure and smart contracts
  hosts: localhost
  vars:
    # Desired state of all components (certificate authorities, peers,
    # and orderers). The default value is "present".
    # - "present" all components have been created, and are running
    # - "absent" all components have been stopped, and are removed
    state: present
    # Configuration for the target infrastructure.
    infrastructure:
      # Type of target infrastructure. The options are:
      # - "docker" deploy using Docker
      # - "saas" deploy using the IBM Blockchain Platform on IBM Cloud
      # - "software" deploy using the IBM Blockchain Platform software
      type: docker
      # Docker specific configuration.
      docker:
        # The name of the Docker network to use for all containers.
        network: ibp_network
        # The Docker object labels to apply to all containers and volumes.
        labels:
          org.example.label: example label value
      # IBM Blockchain Platform on IBM Cloud specific configuration.
      # In this example, service credentials are loaded from a JSON file.
      # You must supply both "api_endpoint" and "apikey" properties.
      saas: "{{ lookup('file', 'service-creds.json') | from_json }}"
      # IBM Blockchain Platform software specific configuration.
      software:
        # The API endpoint to use.
        api_endpoint: https://ibp-console.example.org:32000
        # The API key to use.
        api_key: xxxxxxxx
        # The API secret to use.
        api_secret: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    # The list of organizations.
    organizations:
      # The organization Org1.
      - &Org1
        # MSP configuration for this organization.
        msp:
          # The unique ID of this MSP.
          id: "Org1MSP"
          # The admin identity and secret to register and enroll for this MSP.
          # This user will be registered on the CA specified for this organization,
          # and used as the administrator for the MSP, and any peers or orderers
          # that belong to this organization.
          admin:
            identity: "org1Admin"
            secret: "org1Adminpw"
          # IBM Blockchain Platform on IBM Cloud specific configuration.
          ibp:
            # The display name of this MSP.
            display_name: "Org1 MSP"
        # CA configuration for this organization.
        ca: &Org1CA
          # The unique ID of this CA.
          id: "Org1CA"
          # The default admin identity and secret to set for this CA.
          admin_identity: "admin"
          admin_secret: "adminpw"
          # TLS configuration for this CA.
          tls:
            # Should TLS be enabled for this CA?
            enabled: true
          # Docker specific configuration.
          docker:
            # The name to use for this Docker container and associated Docker volumes.
            name: ca.org1.example.com
            # The hostname to use for this Docker container.
            hostname: ca.org1.example.com
            # The external port to use for this Docker container.
            port: 18050
          # IBM Blockchain Platform on IBM Cloud specific configuration.
          ibp:
            # The display name of this CA.
            display_name: "Org1 CA"
        # The list of peers for this organization.
        peers:
          # First peer for this organization.
          - &Org1Peer1
            # The unique ID of this peer.
            id: "Org1Peer1"
            # The identity and secret to register and enroll for this peer.
            # This user will be registered on the CA specified for this organization,
            # and will be used as the peers identity.
            identity: "org1peer1"
            secret: "org1peer1pw"
            # The database type to use to store this peers world state and private data
            # collections. The options are:
            # - "couchdb" use Apache CouchDB
            # - "leveldb" use LevelDB
            database_type: couchdb
            # TLS configuration for this peer.
            tls:
              # Should TLS be enabled for this peer?
              enabled: true
              # The TLS identity and secret to register and enroll for this peer.
              # This user will be registered on the CA specified for this organization,
              # and will be used as the peers TLS identity.
              identity: "org1peer1tls"
              secret: "org1peer1tlspw"
            # Docker specific configuration.
            docker:
              # The name to use for this Docker container and associated Docker volumes.
              name: peer0.org1.example.com
              # The hostname to use for this Docker container.
              hostname: peer0.org1.example.com
              # The external request port to use for this Docker container.
              port: 18051
              # The prefix to use for naming all chaincode Docker images and containers.
              chaincode_name_prefix: my_chaincode_prefix
              # The external chaincode port to use for this Docker container.
              chaincode_port: 18052
              # The external operations port to use for this Docker container.
              operations_port: 18053
              # CouchDB specific configuration.
              couchdb:
                # The name to use for the CouchDB Docker container and associated Docker volumes.
                name: couchdb0.org1.example.com
                # The hostname to use for the CouchDB Docker container.
                hostname: couchdb0.org1.example.com
                # The external CouchDB port to use for the CouchDB Docker container.
                port: 18054
            # IBM Blockchain Platform on IBM Cloud specific configuration.
            ibp:
              # The display name of this peer.
              display_name: "Org1 Peer1"
        # The directory to store generated JSON files for each CA, peer, and orderer in this organization.
        nodes: "{{ playbook_dir }}/nodes/Org1"
        # The directory to store all identities (certificate and private key pairs) for this organization.
        wallet: "{{ playbook_dir }}/wallets/Org1"
        # The directory to store all gateways for this organization.
        gateways: "{{ playbook_dir }}/gateways/Org1"
      # The organization that manages the ordering service.
      - &OrdererOrg
        # MSP configuration for this organization.
        msp:
          # The unique ID of this MSP.
          id: "OrdererMSP"
          # The admin identity and secret to register and enroll for this MSP.
          # This user will be registered on the CA specified for this organization,
          # and used as the administrator for the MSP, and any peers or orderers
          # that belong to this organization.
          admin:
            identity: "ordererAdmin"
            secret: "ordererAdminpw"
          # IBM Blockchain Platform on IBM Cloud specific configuration.
          ibp:
            display_name: "Orderer MSP"
        # CA configuration for this organization.
        ca: &OrdererCA
          # The unique ID of this CA.
          id: "OrdererCA"
          # The default admin identity and secret to set for this CA.
          admin_identity: "admin"
          admin_secret: "adminpw"
          # TLS configuration for this CA.
          tls:
            # Should TLS be enabled for this CA?
            enabled: true
          # Docker specific configuration.
          docker:
            # The name to use for this Docker container and associated Docker volumes.
            name: ca.orderer.example.com
            # The hostname to use for this Docker container.
            hostname: ca.orderer.example.com
            # The external port to use for this Docker container.
            port: 17050
          # IBM Blockchain Platform on IBM Cloud specific configuration.
          ibp:
            # The display name of this CA.
            display_name: "Orderer CA"
        # Orderer configuration for this organization.
        orderer: &Orderer
          # The unique ID of this orderer.
          id: "Orderer1"
          # The identity and secret to register and enroll for this orderer.
          # This user will be registered on the CA specified for this organization,
          # and will be used as the orderers identity.
          identity: "orderer1"
          secret: "orderer1pw"
          # TLS configuration for this orderer.
          tls:
            # Should TLS be enabled for this orderer?
            enabled: true
            # The TLS identity and secret to register and enroll for this orderer.
            # This user will be registered on the CA specified for this organization,
            # and will be used as the orderers TLS identity.
            identity: "orderer1tls"
            secret: "orderer1tlspw"
          # Consortium configuration for this orderer.
          consortium:
            # The list of consortium members.
            members:
              # Reference to the organization Org1.
              - *Org1
          # Block cutting configuration for this orderer.
          block_configuration:
            # The absolute maximum size of a block in bytes.
            absolute_max_bytes: 10485760
            # The maximum number of messages in a block.
            max_message_count: 500
            # The preferred maximum size of a block in bytes.
            preferred_max_bytes: 2097152.
            # The maximum time to wait before cutting a new block.
            timeout: 2s
          # Docker specific configuration.
          docker:
            # The name to use for this Docker container and associated Docker volumes.
            name: orderer.example.com
            # The hostname to use for this Docker container.
            hostname: orderer.example.com
            # The external port to use for this Docker container.
            port: 17051
            # The external operations port to use for this Docker container.
            operations_port: 17052
          # IBM Blockchain Platform on IBM Cloud specific configuration.
          ibp:
            # The display name of this orderer.
            display_name: "Orderer1"
            # The cluster name of this orderer.
            cluster_name: "OrdererCluster"
        # The directory to store generated JSON files for each CA, peer, and orderer in this organization.
        nodes: "{{ playbook_dir }}/nodes/Orderer"
        # The directory to store all identities (certificate and private key pairs) for this organization.
        wallet: "{{ playbook_dir }}/wallets/Orderer"
        # The directory to store all gateways for this organization.
        gateways: "{{ playbook_dir }}/gateways/Orderer"
    # The list of channels.
    channels:
      # The channel channel1.
      - &channel1
        # The name of the channel.
        name: channel1
        # The orderer to use for this channel.
        orderer: *Orderer
        # The list of channel members.
        members:
          # Reference to the organization Org1.
          - <<: *Org1
            # The list of committing peers for this organization.
            committing_peers:
              # Reference to the first peer for this organization.
              - *Org1Peer1
            # The list of anchor peers for this organization.
            anchor_peers:
              # Reference to the first peer for this organization.
              - *Org1Peer1
    # The list of contracts.
    contracts:
      # The contract fabcar.
      - &fabcar
        # The name of the contract.
        name: fabcar
        # The version of the contract.
        version: 1.0.0
        # The path to the file containing the packaged contract. This file can be created
        # using the "peer chaincode package" command, one of the Fabric SDKs, or the IBM
        # Blockchain Platform extension for Visual Studio Code.
        package: "{{ playbook_dir }}/fabcar@1.0.0.cds"
        # The list of channels to deploy this contract into.
        channels:
          # Reference to the channel channel1.
          - <<: *channel1
            # The endorsement policy for this contract on this channel.
            endorsement_policy: "AND('Org1MSP.peer')"
            # The list of endorsing members for this contract on this channel.
            endorsing_members:
              # Reference to the organization Org1.
              - <<: *Org1
                # The list of endorsing peers for this organization.
                endorsing_peers:
                  # Reference to the first peer for this organization.
                  - <<: *Org1Peer1
    # The list of gateways.
    gateways:
      # The gateway gateway1.
      - name: gateway1
        # The organization that owns the gateway.
        organization:
          # Reference to the organization Org1.
          <<: *Org1
          # The list of gateway peers for this organization.
          gateway_peers:
            # Reference to the first peer for this organization.
            - *Org1Peer1
  roles:
    - ibm.blockchain_platform_manager
```

License
-------

Apache-2.0

Author Information
------------------

This Ansible role is maintained by the IBM Blockchain Platform development team. For more information on the IBM Blockchain Platform, visit the following website: https://www.ibm.com/cloud/blockchain-platform
