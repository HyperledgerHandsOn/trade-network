/*
SPDX-License-Identifier: Apache-2.0
*/
const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

const CONNECTION_PROFILE_TEMPLATE='./connection-profile.json.template';
const GATEWAY='gateways';
const CONNECTION_PROFILE='connection.json';

let CONFIG_TX_FILE_REL_PATH = '/configtx.yaml';
let CRYPTO_CONFIG_REL_PATH = '.';

function getOrgFromConfigTx(mspId, baseDir) {
	// Parse configtx.yaml
	const filename = baseDir + CONFIG_TX_FILE_REL_PATH;
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
	const matchedOrgs = configTxObj.Organizations.filter((org) => { return (org.ID === mspId); });
	if (matchedOrgs.length != 1) {
		throw new Error('Expected exactly one org with MSP ID "' + mspId + '". Found ' + matchedOrgs.length + '.');
	}
	return matchedOrgs[0];
}

function getCATlsCertFromMspId(mspId, caHostName, baseDir) {
	const matchedOrg = getOrgFromConfigTx(mspId, baseDir);
	return fs.readFileSync(`${baseDir}/${CRYPTO_CONFIG_REL_PATH}/${matchedOrg.MSPDir}/../ca/${caHostName}-cert.pem`).toString();
}

function getPeerTLSCertFromMspId(mspId, peerHostName, baseDir) {
	const matchedOrg = getOrgFromConfigTx(mspId, baseDir);
	const tlsDir = `${baseDir}/${CRYPTO_CONFIG_REL_PATH}/${matchedOrg.MSPDir}/../peers/${peerHostName}/msp/tlscacerts/`
	const pemfiles =  fs.readdirSync(tlsDir).filter(fn => fn.endsWith('.pem'));
	if (pemfiles.length != 1) {
		throw new Error(`Expected exactly one PEM file in ${tlsDir}. Found ${pemfiles.length}.`);
	}
	return fs.readFileSync(path.join(tlsDir, pemfiles[0])).toString();

}

function updateConnectionProfile(baseDir, connectionProfile, outputFile, caName) {
	let profileObj = JSON.parse(fs.readFileSync(connectionProfile).toString());

	// For each peer, add a hostname override attribute as the default attribute doesn't work with the Java Fabric SDK
	// Also replace 'localhost' in the URL with peer service name
	Object.keys(profileObj.peers).forEach(peer => {
		profileObj.peers[peer].grpcOptions.hostnameOverride = profileObj.peers[peer].grpcOptions['ssl-target-name-override'];
		profileObj.peers[peer].url = profileObj.peers[peer].url.replace('localhost', peer);
	});

	// For each CA, update URL, CA name, and import the CA TLS certificate
	Object.keys(profileObj.certificateAuthorities).forEach(ca => {
		profileObj.certificateAuthorities[ca].url = profileObj.certificateAuthorities[ca].url.replace('localhost', ca);
		profileObj.certificateAuthorities[ca].caName = caName;
		// Get org MSP ID
		Object.keys(profileObj.organizations).forEach((org) => {
			if (profileObj.organizations[org].certificateAuthorities.includes(ca)) {
				profileObj.certificateAuthorities[ca].tlsCACerts = {};
				const orgCATlsCert = getCATlsCertFromMspId(profileObj.organizations[org].mspid, ca, baseDir);
				profileObj.certificateAuthorities[ca].tlsCACerts.pem = orgCATlsCert;
			}
		});
	});
	fs.writeFileSync(outputFile, JSON.stringify(profileObj, null, 4));
}

function generateConnectionProfile(baseDir, orgName, mspid, peer_port, ca_port) {
	const profileObj = JSON.parse(fs.readFileSync(CONNECTION_PROFILE_TEMPLATE).toString());
	const outputPath = path.join(baseDir, '..', GATEWAY, orgName);
	const outputFile = path.join(outputPath, CONNECTION_PROFILE);
	if (!fs.existsSync(outputPath)){
		fs.mkdirSync(outputPath);
	}
	const peerName = `peer0.${orgName}.trade.com`;
	const caName = `ca.${orgName}.trade.com`
	profileObj.client.organization = mspid;
	profileObj.organizations[mspid] = { mspid: mspid, 
										peers: [ peerName ],
										certificateAuthorities: [ caName ]
									  };
	profileObj.peers[peerName] = { url: `grpcs://${peerName}:${peer_port}`,
													tlsCACerts: {
														pem: getPeerTLSCertFromMspId(mspid, peerName, baseDir)
													},
													grpcOptions: {
														hostnameOverride: peerName,
														'ssl-target-name-override': peerName
													}
												  };
	profileObj.certificateAuthorities[caName] = { url: `https://${caName}:${ca_port}`,
													caName: `ca-${orgName}`,
													tlsCACerts: {
														pem: getCATlsCertFromMspId(mspid, caName, baseDir)
													},
												  };
	fs.writeFileSync(outputFile, JSON.stringify(profileObj, null, 4));
}


if ((process.argv.includes('--generate') && process.argv.length < 7) ||
    (process.argv.includes('--update') && process.argv.length < 6) ||
    (!process.argv.includes('--update') && !process.argv.includes('--generate'))) {
	console.log('Usage: node manage-connection-profile.js --generate|--update');
	console.log('To generate a connection profile:');
	console.log('   node manage-connection-profile.js --generate org-name mspid peer-port ca-port [--add-org]');
	console.log('To update a connection profile:');
	console.log('   node manage-connection-profile.js --update <connection-profile> <output-file> <ca-name>');
	console.log('   where <ca-name> is the value of the environment variable FABRIC_CA_SERVER_CA_NAME in the container running this organization\'s Fabric CA');
	process.exit(1);
}

if (process.argv.includes('--generate')) {
	if (process.argv.includes('--add-org')) {
		CONFIG_TX_FILE_REL_PATH = '/add_org/configtx.yaml';
		CRYPTO_CONFIG_REL_PATH = 'add_org';
	}
	generateConnectionProfile('..', process.argv[3], process.argv[4], process.argv[5], process.argv[6]);
} else {
	updateConnectionProfile('..', process.argv[3], process.argv[4], process.argv[5]);
}
