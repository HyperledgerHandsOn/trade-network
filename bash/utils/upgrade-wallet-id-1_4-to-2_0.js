/*
SPDX-License-Identifier: Apache-2.0
*/
const fs = require('fs');

function createIdFile(userId, walletDir, targetDir) {
	const oldUser = JSON.parse(fs.readFileSync(walletDir + '/' + userId + '/' + userId).toString());
	let newUser = {};
	newUser.mspId = oldUser.mspid;
	newUser.type = 'X.509';
	newUser.version = 1;
	newUser.credentials = {};
	newUser.credentials.certificate = oldUser.enrollment.identity.certificate;
	const privKey = fs.readFileSync(walletDir + '/' + userId + '/' + oldUser.enrollment.signingIdentity + '-priv').toString().replace(/\r\n/g, '\n');
	newUser.credentials.privateKey = privKey;
	fs.writeFileSync(targetDir + '/' + userId + '.id', JSON.stringify(newUser));
}


if (process.argv.length < 5) {
	console.log('Usage: node js-id-to-java-id.js <id> <old-wallet-dir> <target-dir>');
	process.exit(1);
}

createIdFile(process.argv[2], process.argv[3], process.argv[4]);
