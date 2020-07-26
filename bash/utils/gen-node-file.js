/*
SPDX-License-Identifier: Apache-2.0
*/
const fs = require('fs');
const yaml = require('js-yaml');

function getBase64TLSCert(filename) {
	if(!fs.existsSync(filename)) {
		throw new Error('File ' + filename + ' not found');
	}
	return fs.readFileSync(filename).toString('base64');
}

function parseConfigtxYaml(path) {
	const defaultParamsFile = path + '/network_defaults.json';
	if(!fs.existsSync(defaultParamsFile)) {
		throw new Error('File ' + defaultParamsFile + ' not found');
	}
	// Extract network defaults
	const defaultParams = JSON.parse(fs.readFileSync(defaultParamsFile).toString());
	const filename = path + '/configtx.yaml';
	if(!fs.existsSync(filename)) {
		throw new Error('File ' + filename + ' not found');
	}
	// Extract network config
	const configTxYaml = fs.readFileSync(filename);
	let configTxObj = {};
	try {
		configTxObj = yaml.safeLoad(configTxYaml);
	} catch(err) {
		throw err;
	}
	if(!configTxObj.Organizations) {
		throw new Error('No Organizations in config YAML');
	}
	let orgsJSON = [];
	configTxObj.Organizations.forEach(org => {
		if(!org.AnchorPeers) {
			// This is an orderer org
			let orgJSON = {};
			if(configTxObj.Orderer.Addresses.length === 0) {
				throw new Error('No orderer addresses found');
			}
			const oname = configTxObj.Orderer.Addresses[0];
			const colon = oname.indexOf(':');
			if(colon < 0) {
				throw new Error('Invalid hostname; contains no colon separator');
			}
			orgJSON.name = oname.substr(0,colon);
			orgJSON.msp_id = org.ID;
			orgJSON.api_url = 'grpcs://localhost:' + oname.substr(colon + 1);
			orgJSON.type = 'fabric-orderer';
			orgJSON.ssl_target_name_override = orgJSON.name;
			const period = orgJSON.name.indexOf('.');
			if(period < 0) {
				throw new Error('Invalid hostname; contains no period separator');
			}
			const domain = orgJSON.name.substr(period + 1);
			orgJSON.pem = getBase64TLSCert(path + '/' + org.MSPDir + '/tlscacerts/tlsca.' + domain + '-cert.pem');
			orgsJSON.push(orgJSON);
		} else {
			// This is a peer org
			if(org.AnchorPeers.length === 0) {
				throw new Error('No peer addresses found');
			}
			const orgAnchorPeer = org.AnchorPeers[0].Host;
			const period = orgAnchorPeer.indexOf('.');
			if(period < 0) {
				throw new Error('Invalid hostname; contains no period separator');
			}
			const domain = orgAnchorPeer.substr(period + 1);
			const orgPem = getBase64TLSCert(path + '/' + org.MSPDir + '/tlscacerts/tlsca.' + domain + '-cert.pem');
			orgDefaultParams = defaultParams[org.Name];
			if(!orgDefaultParams) {
				throw new Error('No default parameters found for org ' + orgJSON.Name);
			}
			orgDefaultParams.peer_ports.forEach(peer_port => {
				const peerNames = Object.keys(peer_port);
				if (peerNames.length != 1) {
					throw new Error('Expected exactly one peer name in structure for ' + domain + ', found ' + peerNames.length);
				}
				let orgJSON = {};
				orgJSON.name = peerNames[0] + '.' + domain;
				orgJSON.msp_id = org.ID;
				orgJSON.api_url = 'grpcs://localhost:' + peer_port[peerNames[0]];
				orgJSON.type = 'fabric-peer';
				orgJSON.ssl_target_name_override = orgJSON.name;
				orgJSON.pem = orgPem;
				orgsJSON.push(orgJSON);
			});

			// Add a CA configuration for this org
			orgDefaultParams.cas.forEach(ca => {
				let caJSON = {};
				caJSON.name = "ca." + domain;
				caJSON.ca_name = "ca." + domain;
				caJSON.api_url = 'https://localhost:' + ca.port;
				caJSON.type = 'fabric-ca';
				caJSON.enroll_id = ca.admin_user;
				caJSON.enroll_secret = ca.admin_password;
				orgsJSON.push(caJSON);
			});
		}
	});
	return orgsJSON;
}

console.log(JSON.stringify(parseConfigtxYaml('..'), null, 4));
