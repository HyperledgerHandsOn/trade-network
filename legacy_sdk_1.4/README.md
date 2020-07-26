# Specifying a Fabric Network's Configuration
We use two equivalent configuration files:
- To maintain continuity with the first edition of the book, we will continue to use and work with a `config.json` file that contains the list and attributes of each network node. This file is read and parsed by code exercising the library functions in `clientUtils.js`, which are implemented using the lower-level `fabric-client` API (part of `fabric-sdk-node`).
- We will use a connection profile (`connection_profile.json`), which is currently the canonical way of representing a Fabric network and can be used interoperably with various tools and applications. This file is read and parsed by code exercising the library functions in `networkUtils.js`, which are implemented using the higher-level `fabric-network` API (part of `fabric-sdk-node`).

Note that the hostnames in the various URLs (`grpcs` or `https`) in both these configuration files are names of the docker containers that represent our Fabric network's nodes. For communication between our application client and any of the CA nodes, TLS server certificate verification is enabled, as can be seen in the library function code, and such verification relies on the hostname in pre-created TLS certificates matching the hostname of the endpoint. If TLS server certificate verification is disabled, we can instead simply use `localhost` in the addresses.

To enable client-CA communication using these configuration files and with TLS server certificate verification enabled, we need to make appropriate settings in our machine's `hosts` file. On a typical Linux machine, this is `/etc/hosts` and we should add the following `<IP address, hostname>` mappings.
```
127.0.0.1 peer0.exporterorg.trade.com
127.0.0.1 peer0.importerorg.trade.com
127.0.0.1 peer0.carrierorg.trade.com
127.0.0.1 peer0.regulatororg.trade.com
127.0.0.1 ca.exporterorg.trade.com
127.0.0.1 ca.importerorg.trade.com
127.0.0.1 ca.carrierorg.trade.com
127.0.0.1 ca.regulatororg.trade.com
127.0.0.1 orderer.trade.com
```
