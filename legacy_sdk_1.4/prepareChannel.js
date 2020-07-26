/*
SPDX-License-Identifier: Apache-2.0
*/

'use strict';

var sprintf = require('sprintf-js').sprintf;
var Constants = require('./constants.js');
var ClientUtils = require('./clientUtils.js');
var createChannel = require('./create-channel.js');
var joinChannel = require('./join-channel.js');

// Get org name if specified in the command line
let orgName = 'all';
if (process.argv.length <= 3 || (process.argv[3] !== 'load' && process.argv[3] !== 'enroll')) {
	console.log('Usage: node prepare.js <channel-name> load|enroll [<org-name>]');
	process.exit(1);
}

Constants.CHANNEL_NAME = process.argv[2];
Constants.channelConfig = sprintf(Constants.channelConfig, Constants.CHANNEL_NAME);

const mode = process.argv[3];

if (process.argv.length > 4) {
	orgName = process.argv[4];
}

// Create a channel using the given network configuration
createChannel.createChannel(mode, orgName, Constants).then(() => {
	console.log('\n');
	console.log('--------------------------');
	console.log('CHANNEL CREATION COMPLETE');
	console.log('--------------------------');
	console.log('\n');

	return joinChannel.processJoinChannel(mode, Constants);
}, (err) => {
	console.log('\n');
	console.log('-------------------------');
	console.log('CHANNEL CREATION FAILED:', err);
	console.log('-------------------------');
	console.log('\n');
	process.exit(1);
})
// Join peers to the channel created above
.then(() => {
	console.log('\n');
	console.log('----------------------');
	console.log('CHANNEL JOIN COMPLETE');
	console.log('----------------------');
	console.log('\n');
	ClientUtils.txEventsCleanup();
}, (err) => {
	console.log('\n');
	console.log('---------------------');
	console.log('CHANNEL JOIN FAILED:', err);
	console.log('---------------------');
	console.log('\n');
	process.exit(1);
});

process.on('uncaughtException', err => {
	console.error(err);
	joinChannel.joinEventsCleanup();
});

process.on('unhandledRejection', err => {
	console.error(err);
	joinChannel.joinEventsCleanup();
});

process.on('exit', () => {
	joinChannel.joinEventsCleanup();
	ClientUtils.txEventsCleanup();
});
