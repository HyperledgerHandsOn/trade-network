/*
SPDX-License-Identifier: Apache-2.0
*/

'use strict';

var utils = require('fabric-client/lib/utils.js');
var logger = utils.getLogger('create-channel');

var Client = require('fabric-client');
var fs = require('fs');
var path = require('path');
var grpc = require('grpc');

var _commonProto = grpc.load(path.join(__dirname, 'node_modules/fabric-client/lib/protos/common/common.proto')).common;
var _configtxProto = grpc.load(path.join(__dirname, 'node_modules/fabric-client/lib/protos/common/configtx.proto')).common;

var Constants = require('./constants.js');
var ClientUtils = require('./clientUtils.js');

var ORGS, PEER_ORGS;

// Load/Enroll 'admin' user of an org and sign the channel configuration as that user (signing identity)
function getOrgAdminAndSignConfig(org, client, config, signatures, mode) {
	client._userContext = null;

	return ClientUtils.getSubmitter(client, true, org, null, mode === 'enroll')
	.then((admin) => {
		console.log('Successfully enrolled user \'admin\' for', org);

		// sign the config
		var signature = client.signChannelConfig(config);
		console.log('Successfully signed config as admin of', org);

		// collect signature from org admin
		signatures.push(signature);
	});
}

//
// Send a channel creation request to the orderer
//
function createChannel(mode, org_name = 'all', constants) {
	if (constants) {
		Constants = constants;
	}
	ClientUtils.init(Constants);
	Client.addConfigFile(path.join(__dirname, Constants.networkConfig));
	ORGS = Client.getConfigSetting(Constants.networkId);
	// Remove Carrier Org from list for tradechannel
	if (Constants.CHANNEL_NAME === 'tradechannel') {
	    delete ORGS.carrierorg;
	}
	PEER_ORGS = [];
	Object.keys(ORGS).forEach((org) => {
		if(org !== 'orderer') {
			PEER_ORGS.push(org);
		}
	})

	var channel_name = Client.getConfigSetting('E2E_CONFIGTX_CHANNEL_NAME', Constants.CHANNEL_NAME);
	console.log('Creating channel', channel_name);

	//
	// Create and configure the channel
	//
	var client = new Client();

	// Read the TLS certificates to establish a secure connection to the orderer
	var caRootsPath = ORGS.orderer.tls_cacerts;
	let data = fs.readFileSync(path.join(__dirname, caRootsPath));
	let caroots = Buffer.from(data).toString();
	let envelope_bytes;

	var orderer = client.newOrderer(
		ORGS.orderer.url,
		{
			'pem': caroots,
			'ssl-target-name-override': ORGS.orderer['server-hostname']
		}
	);

	var config = null;		// Network channel configuration
	var signatures = [];		// Collect signatures to submit to orderer for channel creation

	// Attempt to create the channel as a client of 'org_name'
	var org;
	if (org_name != 'all') {
		if (!ORGS[org_name]) {
			throw new Error('Cannot find org "' + org_name + '" in network configuration.');
		}
		org = ORGS[org_name].name;
	}

	return Promise.resolve().then(() => {
		// Load the channel configuration: for creation of update of a channel
		envelope_bytes = fs.readFileSync(path.join(__dirname, Constants.networkLocation, Constants.channelConfig));
		config = client.extractChannelConfig(envelope_bytes);
		console.log('Successfully extracted the config update from the configtx envelope');

		// We just need one org admin's signature to satisfy channel policy,
		// but we can provide more valid signatures regardless (for experimentation and testing)
		if (org) {
			// Get specified org's admin's signature and admin user object
			return getOrgAdminAndSignConfig(org_name, client, config, signatures, mode);
		} else {
			// Get signatures from all orgs' admins 
			var getAndSignPromises = [];
			PEER_ORGS.forEach((org) => {
				getAndSignPromises.push(getOrgAdminAndSignConfig);
			})
			// Load 'admin' user for each org (generated using 'cryptogen') and get their signatures on the channel config in sequence
			return getAndSignPromises.reduce(
				(promiseChain, currentFunction, currentIndex) =>
					promiseChain.then(() => {
						return currentFunction(PEER_ORGS[currentIndex], client, config, signatures, mode);
					}), Promise.resolve()
			);
		}
	}).then((org_admin) => {
		var orgStr = 'every org';
		if (org_name != 'all') {
			orgStr = org_name;
		}
		console.log('Successfully enrolled user \'admin\' for ' + orgStr + ' and obtained channel config signatures');

		// Now create a channel instance
		var channel = client.newChannel(channel_name);

		// Associate our network's orderer with this channel
		channel.addOrderer(
			client.newOrderer(
				ORGS.orderer.url,
				{
					'pem': caroots,
					'ssl-target-name-override': ORGS.orderer['server-hostname']
				}
			)
		);

		// Check if the channel already exists by querying orderer for the genesis block
		return channel.getGenesisBlock();
	}).then((genesis_block) => {
		console.log('Got genesis block. Channel', channel_name, 'already exists');
		return { status: 'SUCCESS' };
	}, (err) => {
		console.log('Channel', channel_name, 'does not exist yet (IGNORE ANY ORDERER ERROR MESSAGES YOU SEE ABOVE!!)');

		// build up the create request
		let tx_id = client.newTransactionID();
		var request = {
			config: config,
			signatures : signatures,
			name : channel_name,
			orderer : orderer,
			txId  : tx_id
		};

		// Send create request to orderer
		// At this point, the orderer admin is the client's signing identity
		// But we could have used any of the peer org admins for this purpose too
		return client.createChannel(request);
	})
	.then((result) => {
		logger.debug('Channel creation complete; response ::%j',result);
		if(result.status && result.status === 'SUCCESS') {
			console.log('Successfully created the channel.');
			return ClientUtils.sleep(5000);
		} else {
			console.log(result);
			throw new Error('Failed to create the channel. ');
		}
	}, (err) => {
		throw new Error('Failed to create the channel: ' + err.stack ? err.stack : err);
	})
	.then((nothing) => {
		console.log('Successfully waited to make sure new channel was created.');
	}, (err) => {
		throw new Error('Failed to sleep due to error: ' + err.stack ? err.stack : err);
	});
}

module.exports.createChannel = createChannel;
