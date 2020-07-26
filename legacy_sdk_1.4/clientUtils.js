/*
SPDX-License-Identifier: Apache-2.0
*/

var utils = require('fabric-client/lib/utils.js');
var logger = utils.getLogger('ClientUtils');

var path = require('path');
var fs = require('fs-extra');
var util = require('util');

var Client = require('fabric-client');
var copService = require('fabric-ca-client/lib/FabricCAServices.js');
var User = require('fabric-client/lib/User.js');
var Constants = require('./constants.js');

// all temporary files and directories are created under here
var tempdir = Constants.tempdir;

logger.info(util.format(
	'\n\n*******************************************************************************' +
	'\n*******************************************************************************' +
	'\n*                                          ' +
	'\n* Using temp dir: %s' +
	'\n*                                          ' +
	'\n*******************************************************************************' +
	'\n*******************************************************************************\n', tempdir));

module.exports.getTempDir = function() {
	fs.ensureDirSync(tempdir);
	return tempdir;
};

// directory for file based KeyValueStore
module.exports.KVS = path.join(tempdir, 'hfc-test-kvs');
module.exports.storePathForOrg = function(org) {
	return module.exports.KVS + '_' + org;
};

module.exports.cleanupDir = function(keyValStorePath) {
	var absPath = path.join(process.cwd(), keyValStorePath);
	var exists = module.exports.existsSync(absPath);
	if (exists) {
		fs.removeSync(absPath);
	}
};

module.exports.getUniqueVersion = function(prefix) {
	if (!prefix) prefix = 'v';
	return prefix + Date.now();
};

// utility function to check if directory or file exists
// uses entire / absolute path from root
module.exports.existsSync = function(absolutePath /*string*/) {
	try  {
		var stat = fs.statSync(absolutePath);
		if (stat.isDirectory() || stat.isFile()) {
			return true;
		} else
			return false;
	}
	catch (e) {
		return false;
	}
};

module.exports.readFile = readFile;

var ORGS = {};

module.exports.init = function(constants) {
	if (constants) {
		Constants = constants;
	}
	Client.addConfigFile(path.join(__dirname, Constants.networkConfig));
	ORGS = Client.getConfigSetting(Constants.networkId);
};


var	tlsOptions = {
	trustedRoots: [],
	verify: true
};

// Enroll 'admin' user for the given org
function getRegistrarMember(username, password, client, userOrg) {
	var caUrl = ORGS[userOrg].ca.url;

	// Make sure client is associated with userOrg's keystore
	var cryptoSuite = Client.newCryptoSuite();
	cryptoSuite.setCryptoKeyStore(Client.newCryptoKeyStore({path: module.exports.storePathForOrg(ORGS[userOrg].name)}));
	client.setCryptoSuite(cryptoSuite);

	return Client.newDefaultKeyValueStore({		// Set the key-value store location
		path: module.exports.storePathForOrg(ORGS[userOrg].name)
	}).then((store) => {
		client.setStateStore(store);		// Set application state location on the file system
		return client.getUserContext(username, true);
	}).then((user) => {
		return new Promise((resolve, reject) => {
			if (user && user.isEnrolled()) {
				console.log('Successfully loaded member from persistence');
				return resolve(user);
			}

			var member = new User(username);
			member.setCryptoSuite(cryptoSuite);

			// need to enroll it with CA server
			var caCert = fs.readFileSync(path.join(__dirname, ORGS[userOrg].ca.tls_cacerts));
			tlsOptions.trustedRoots = [ caCert ];
			var cop = new copService(caUrl, tlsOptions, ORGS[userOrg].ca.name, cryptoSuite);

			return cop.enroll({
				enrollmentID: username,
				enrollmentSecret: password
			}).then((enrollment) => {
				console.log('Successfully enrolled user \'' + username + '\'');

				return member.setEnrollment(enrollment.key, enrollment.certificate, ORGS[userOrg].mspid);
			}).then(() => {
				var skipPersistence = false;
				if (!client.getStateStore()) {
					skipPersistence = true;
				}
				return client.setUserContext(member, skipPersistence);
			}).then(() => {
				return resolve(member);
			}).catch((err) => {
				throw new Error('Failed to enroll and persist user. Error: ' + err.stack ? err.stack : err);
			});
		});
	})
	.catch((err) => {
		throw new Error("Unable to get user context for", username);
	});
}

// Use default registrar ('admin') to enroll 'username'
// If 'username' ends with '-admin', enroll it as an admin, otherwise enroll it as a client
function registerAndEnrollUser(client, cop, admin, username, userOrg) {

	// Make sure client is associated with userOrg's keystore
	var cryptoSuite = Client.newCryptoSuite();
	cryptoSuite.setCryptoKeyStore(Client.newCryptoKeyStore({path: module.exports.storePathForOrg(ORGS[userOrg].name)}));
	client.setCryptoSuite(cryptoSuite);

	return new Promise((resolve, reject) => {
		console.log('Registering and enrolling user', username);
		var enrollUser = new User(username);
		var role = 'client';
		if (username.endsWith('-admin')) {
			role = 'admin';
		}

		return Client.newDefaultKeyValueStore({		// Set the key-value store location
			path: module.exports.storePathForOrg(ORGS[userOrg].name)
		}).then((store) => {
			client.setStateStore(store);		// Set application state location on the file system

			// register 'username' CA server
			return cop.register({
				enrollmentID: username,
				role: role,
				affiliation: 'org1.department1'
				}, admin);
		}).catch((err) => {
			throw err;
		}).then((userSecret) => {
			console.log('Successfully registered user \'' + username + '\'');
			userPassword = userSecret;

			// Now that 'username' is registered, try to enroll (login)
			return cop.enroll({
				enrollmentID: username,
				enrollmentSecret: userSecret
			});
		}).catch((err) => {
			console.log('Failed to register user. Error: ' + err.stack ? err.stack : err);
			throw err;
		}).then((enrollment) => {
			console.log('Successfully enrolled user \'' + username + '\'');

			return enrollUser.setEnrollment(enrollment.key, enrollment.certificate, ORGS[userOrg].mspid);
		}).catch((err) => {
			throw err;
		}).then(() => {
			console.log('Saving enrollment record for user \'' + username + '\'');
			return client.setUserContext(enrollUser, false);
		}).catch((err) => {
			throw err;
		}).then(() => {
			return client.saveUserToStateStore();
		}).then(() => {
			console.log('Saved enrollment record for user \'' + username + '\'');
			enrollUser._enrollmentSecret = userPassword;
			return resolve(enrollUser);
		}).catch((err) => {
			console.log('Failed to enroll and persist user. Error: ' + err.stack ? err.stack : err);
			reject(err);
		});
	});
}

function getMember(adminUser, adminPassword, client, userOrg, username) {
	var caUrl = ORGS[userOrg].ca.url;
	var userPassword = '';

	// Make sure client is associated with userOrg's keystore
	var cryptoSuite = Client.newCryptoSuite();
	cryptoSuite.setCryptoKeyStore(Client.newCryptoKeyStore({path: module.exports.storePathForOrg(ORGS[userOrg].name)}));
	client.setCryptoSuite(cryptoSuite);

	return Client.newDefaultKeyValueStore({		// Set the key-value store location
		path: module.exports.storePathForOrg(ORGS[userOrg].name)
	}).then((store) => {
		client.setStateStore(store);		// Set application state location on the file system
		return client.getUserContext(username, true);
	}).then((user) => {
		return new Promise((resolve, reject) => {
			if (user && user.isEnrolled()) {
				console.log('Successfully loaded user', username, 'from persistence');
				return resolve(user);
			}

			return client.getUserContext(adminUser, true)
			.then((admin) => {
					var caCert = fs.readFileSync(path.join(__dirname, ORGS[userOrg].ca.tls_cacerts));
					tlsOptions.trustedRoots = [ caCert ];
					var cop = new copService(caUrl, tlsOptions, ORGS[userOrg].ca.name, cryptoSuite);

					if (admin && admin.isEnrolled()) {
						console.log('Successfully loaded admin member from persistence');
						return registerAndEnrollUser(client, cop, admin, username, userOrg)
						.then((enrollUser) => {
							return resolve(enrollUser);
						}, (err) => {
							reject(err);
						});
					}

					var member = new User(adminUser);
					member.setCryptoSuite(cryptoSuite);

					// need to enroll admin user with CA server

					return cop.enroll({
						enrollmentID: adminUser,
						enrollmentSecret: adminPassword
					}).then((enrollment) => {
						console.log('Successfully enrolled admin user');

						return member.setEnrollment(enrollment.key, enrollment.certificate, ORGS[userOrg].mspid);
					}).then(() => {
						var skipPersistence = false;
						if (!client.getStateStore()) {
							skipPersistence = true;
						}
						return client.setUserContext(member, skipPersistence);
					}).then(() => {
						return registerAndEnrollUser(client, cop, member, username, userOrg)
						.then((enrollUser) => {
							return resolve(enrollUser);
						}, (err) => {
							reject(err);
						});
					}).catch((err) => {
						console.log('Failed to enroll and persist user. Error: ' + err.stack ? err.stack : err);
						throw err;
					});
			})
			.catch((err) => {
				console.log("Unable to get user context for", username);
				reject(err);
			});
		});
	}).catch((err) => {
		console.log('Error loading user context');
		throw err;
	});
}

function getAdmin(client, userOrg) {
	var keyPath = path.join(__dirname, util.format(Constants.networkLocation + '/crypto-config/peerOrganizations/%s.trade.com/users/Admin@%s.trade.com/msp/keystore', userOrg, userOrg));
	var keyPEM = Buffer.from(readAllFiles(keyPath)[0]).toString();
	var certPath = path.join(__dirname, util.format(Constants.networkLocation + '/crypto-config/peerOrganizations/%s.trade.com/users/Admin@%s.trade.com/msp/signcerts', userOrg, userOrg));
	var certPEM = readAllFiles(certPath)[0];

	return Promise.resolve(client.createUser({
		username: 'peer' + userOrg + 'Admin',
		mspid: ORGS[userOrg].mspid,
		cryptoContent: {
			privateKeyPEM: keyPEM.toString(),
			signedCertPEM: certPEM.toString()
		},
		skipPersistence: true
	}));
}

function getUser(client, userOrg, userName) {
	var keyPath = path.join(__dirname, util.format(Constants.networkLocation + '/crypto-config/peerOrganizations/%s.trade.com/users/%s@%s.trade.com/msp/keystore', userOrg, userName, userOrg));
	var keyPEM = Buffer.from(readAllFiles(keyPath)[0]).toString();
	var certPath = path.join(__dirname, util.format(Constants.networkLocation + '/crypto-config/peerOrganizations/%s.trade.com/users/%s@%s.trade.com/msp/signcerts', userOrg, userName, userOrg));
	var certPEM = readAllFiles(certPath)[0];

	return Promise.resolve(client.createUser({
		username: 'peer' + userOrg + userName,
		mspid: ORGS[userOrg].mspid,
		cryptoContent: {
			privateKeyPEM: keyPEM.toString(),
			signedCertPEM: certPEM.toString()
		},
		skipPersistence: true
	}));
}

function getOrdererMSPId() {
	Client.addConfigFile(path.join(__dirname, Constants.networkConfig));
	return ORGS['orderer'].mspid;
}

function getOrdererAdmin(client) {
	var keyPath = path.join(__dirname, Constants.networkLocation + '/crypto-config/ordererOrganizations/trade.com/users/Admin@trade.com/msp/keystore');
	var keyPEM = Buffer.from(readAllFiles(keyPath)[0]).toString();
	var certPath = path.join(__dirname, Constants.networkLocation + '/crypto-config/ordererOrganizations/trade.com/users/Admin@trade.com/msp/signcerts');
	var certPEM = readAllFiles(certPath)[0];

	return Promise.resolve(client.createUser({
		username: 'ordererAdmin',
		mspid: getOrdererMSPId(),
		cryptoContent: {
			privateKeyPEM: keyPEM.toString(),
			signedCertPEM: certPEM.toString()
		},
		skipPersistence: true
	}));
}

function readFile(path) {
	return new Promise((resolve, reject) => {
		fs.readFile(path, (err, data) => {
			if (!!err)
				reject(new Error('Failed to read file ' + path + ' due to error: ' + err));
			else
				resolve(data);
		});
	});
}

function readAllFiles(dir) {
	var files = fs.readdirSync(dir);
	var certs = [];
	files.forEach((file_name) => {
		let file_path = path.join(dir,file_name);
		logger.debug(' looking at file ::'+file_path);
		let data = fs.readFileSync(file_path);
		certs.push(data);
	});
	return certs;
}

module.exports.getOrdererAdminSubmitter = function(client, test) {
	return getOrdererAdmin(client, test);
};

module.exports.getSubmitter = function(client, isAdmin, org, username, enroll) {
	if (arguments.length < 3) throw new Error('Missing essential parameters. Need <client, isAdmin, org, [username, enroll]>.');

	if (enroll) {
		if (isAdmin) {
			if (!username || username.toLowerCase() === 'admin') {
				return getMember('admin', 'adminpw', client, org, org + '-admin');	// 'admin' is already reserved for the registrar
			} else {
				return getMember('admin', 'adminpw', client, org, username);
			}
		}
	} else {
		if (isAdmin) {
			return getAdmin(client, org);
		} else if (username) {
			return getUser(client, org, username);
		} else {
			throw new Error('Missing username to look up from credentials created using "cryptogen"');
		}
	}
};

var eventhubs = [];
module.exports.eventhubs = eventhubs;

function sleep(ms) {
	return new Promise(resolve => setTimeout(resolve, ms));
}

module.exports.sleep = sleep;

function cleanup() {
	for(var key in eventhubs) {
		var eventhub = eventhubs[key];
		if (eventhub && eventhub.isconnected()) {
			logger.debug('Disconnecting the event hub');
			eventhub.disconnect();
		}
	}
	eventhubs.splice(0, eventhubs.length);		// Clear the array
}

module.exports.txEventsCleanup = cleanup;
