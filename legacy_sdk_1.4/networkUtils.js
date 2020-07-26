/*
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';


const FabricCAServices = require('fabric-ca-client');
const { FileSystemWallet, Gateway, X509WalletMixin } = require('fabric-network');
const fs = require('fs');
const path = require('path');

const ccpPath = path.resolve(__dirname, 'connection_profile.json');
let ccpJSON = fs.readFileSync(ccpPath, 'utf8');
let ccp;

// Return contents of files in a directory as an array of byte buffers
function readAllFiles(dir) {
	var files = fs.readdirSync(dir);
	var certs = [];
	files.forEach((file_name) => {
		let file_path = path.join(dir,file_name);
		let data = fs.readFileSync(file_path);
		certs.push(data);
	});
	return certs;
}

// Enroll admin user with the Fabric CA of the org, obtain credentials, and populate the wallet
async function enrollRegistrar(orgName, orgMspId) {
    try {

        // Create a new CA client for interacting with the CA.
        const caInfo = ccp.certificateAuthorities[`ca.${orgName}.trade.com`];
        let caTLSCACerts;
        if (caInfo.tlsCACerts && caInfo.tlsCACerts.pem) {
            caTLSCACerts = [ caInfo.tlsCACerts.pem ];
        }
        const ca = new FabricCAServices(caInfo.url, { trustedRoots: caTLSCACerts, verify: true }, caInfo.caName);

        // Create a new file system based wallet for managing identities.
        const walletPath = path.join(process.cwd(), `trade_${orgName}_wallet`);
        const wallet = new FileSystemWallet(walletPath);
        console.log(`Wallet path: ${walletPath}`);

        // Check to see if we've already enrolled the admin user.
        const adminExists = await wallet.exists('admin');
        if (adminExists) {
            console.log(`An identity for the admin user "admin" of org ${orgName} already exists in the wallet`);
            return;
        }

        // Enroll the admin user, and import the new identity into the wallet.
        const enrollment = await ca.enroll({ enrollmentID: 'admin', enrollmentSecret: 'adminpw' });
        const identity = X509WalletMixin.createIdentity(orgMspId, enrollment.certificate, enrollment.key.toBytes());
        await wallet.import('admin', identity);
        console.log(`Successfully enrolled admin user "admin" of org ${orgName} and imported it into the wallet`);

    } catch (error) {
        console.error(`Failed to enroll admin user "admin" of org ${orgName}: ${error}`);
        process.exit(1);
    }
}

// Load admin credentials created using 'cryptogen' in the 'bash/crypto-config/' folder into the wallet
async function loadAdmin(orgName, orgMspId) {
    try {

        // Create a new file system based wallet for managing identities.
        const walletPath = path.join(process.cwd(), `trade_${orgName}_wallet`);
        const wallet = new FileSystemWallet(walletPath);
        console.log(`Wallet path: ${walletPath}`);

        const keyPath = `../bash/crypto-config/peerOrganizations/${orgName}.trade.com/users/admin@${orgName}.trade.com/msp/keystore`;
	const keyPEM = Buffer.from(readAllFiles(keyPath)[0]).toString();
	const certPath = `../bash/crypto-config/peerOrganizations/${orgName}.trade.com/users/admin@${orgName}.trade.com/msp/signcerts`;
	const certPEM = readAllFiles(certPath)[0];

        const identity = X509WalletMixin.createIdentity(orgMspId, certPEM, keyPEM);
        await wallet.import('admin', identity);
        console.log(`Successfully loaded admin user "admin" of org ${orgName} and imported it into the wallet`);

    } catch (error) {
        console.error(`Failed to load admin user "admin" of org ${orgName}: ${error}`);
        process.exit(1);
    }
}

// Register and enroll user with the Fabric CA of the org using the already enrolled admin user, obtain credentials, and populate the wallet
async function registerAndEnrollUser(orgName, orgMspId, userId, isAdmin) {
    const role = (isAdmin ? 'admin':'client');
    try {

        // Create a new file system based wallet for managing identities.
        const walletPath = path.join(process.cwd(), `trade_${orgName}_wallet`);
        const wallet = new FileSystemWallet(walletPath);
        console.log(`Wallet path: ${walletPath}`);

        // Check to see if we've already enrolled the user.
        const userExists = await wallet.exists(userId);
        if (userExists) {
            console.log(`An identity for the user "${userId}" already exists in the wallet`);
            return;
        }

        // Check to see if we've already enrolled the registrar ('admin') user.
        const adminExists = await wallet.exists('admin');
        if (!adminExists) {
            console.log(`An identity for the admin user "admin" does not exist in the wallet`);
            console.log(`Run enrollRegistrar(...) before retrying`);
            return;
        }

        // Create a new gateway for connecting to our peer node.
        const gateway = new Gateway();
        await gateway.connect(ccp, { wallet, identity: 'admin', discovery: { enabled: true, asLocalhost: true } });

        // Get the CA client object from the gateway for interacting with the CA.
        const ca = gateway.getClient().getCertificateAuthority();
        const adminIdentity = gateway.getCurrentIdentity();

        // Register the user, enroll the user, and import the new identity into the wallet.
        const secret = await ca.register({ affiliation: 'org1.department1', enrollmentID: userId, role: role }, adminIdentity);
        const enrollment = await ca.enroll({ enrollmentID: userId, enrollmentSecret: secret });
        const userIdentity = X509WalletMixin.createIdentity(orgMspId, enrollment.certificate, enrollment.key.toBytes());
        await wallet.import(userId, userIdentity);
        console.log(`Successfully registered and enrolled user "${userId}" with role ${role} of org ${orgName} and imported it into the wallet`);

    } catch (error) {
        console.error(`Failed to register user "${userId}" with role ${role} of org ${orgName}: ${error}`);
        process.exit(1);
    }
}

// Load user credentials created using 'cryptogen' in the 'bash/crypto-config/' folder into the wallet
async function loadUser(orgName, orgMspId, userId) {
    try {

        // Create a new file system based wallet for managing identities.
        const walletPath = path.join(process.cwd(), `trade_${orgName}_wallet`);
        const wallet = new FileSystemWallet(walletPath);
        console.log(`Wallet path: ${walletPath}`);

        const keyPath = `../bash/crypto-config/peerOrganizations/${orgName}.trade.com/users/${userId}@${orgName}.trade.com/msp/keystore`;
	const keyPEM = Buffer.from(readAllFiles(keyPath)[0]).toString();
	const certPath = `../bash/crypto-config/peerOrganizations/${orgName}.trade.com/users/${userId}@${orgName}.trade.com/msp/signcerts`;
	const certPEM = readAllFiles(certPath)[0];

        const identity = X509WalletMixin.createIdentity(orgMspId, certPEM, keyPEM);
        await wallet.import(userId, identity);
        console.log(`Successfully loaded user "${userId}" of org ${orgName} and imported it into the wallet`);

    } catch (error) {
        console.error(`Failed to load user "${userId}" of org ${orgName}: ${error}`);
        process.exit(1);
    }
}


if (process.argv.length < 8) {
	console.log('Usage: node networkUtils.js load|enroll <user-name> <is-admin> <org-name> <org-id> <org-msp-id>');
	process.exit(1);
}

// Update the 'client' section to specify which organization we need a gateway for
const orgId = process.argv[6];
const clientOrgStart = ccpJSON.indexOf('"organization":');
if (clientOrgStart < 0) {
	console.log('Unable to find "organization" attribute in connection profile');
	process.exit(1);
}
const clientOrgEnd = ccpJSON.indexOf(',', clientOrgStart);
if (clientOrgStart < 0) {
	console.log('Malformatted connection profile: unable to find end of "organization" attribute');
	process.exit(1);
}
const prefix = ccpJSON.substring(0, clientOrgStart);
const suffix = ccpJSON.substring(clientOrgEnd);
const org = '"organization": "' + orgId + '"';
ccpJSON = prefix + org + suffix;
ccp = JSON.parse(ccpJSON);

if (process.argv[2] === 'load') {
	if (process.argv[3].toLowerCase() === 'admin') {
		loadAdmin(process.argv[5], process.argv[7]);
	} else {
		loadUser(process.argv[5], process.argv[7], process.argv[3]);
	}
} else if (process.argv[2] === 'enroll') {
	enrollRegistrar(process.argv[5], process.argv[7])
	.then(() => {
		if (process.argv[4].toLowerCase() === 'true' || process.argv[4].toLowerCase() === 'yes') {
			registerAndEnrollUser(process.argv[5], process.argv[7], process.argv[3], true);
		} else {
			registerAndEnrollUser(process.argv[5], process.argv[7], process.argv[3], false);
		}
	});
} else {
	console.log('Unrecognized operation:', process.argv[2]);
}
