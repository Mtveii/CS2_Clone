const { WebSocket } = require('ws');

function encHello(name) {
	const b = Buffer.alloc(1 + 2 + 2 + 4 + 2 + name.length);
	let o = 0;
	b[o++] = 6;
	b[o++] = 1; b[o++] = 0;
	b[o++] = 1; b[o++] = 0;
	b[o++] = 0; b[o++] = 0; b[o++] = 0; b[o++] = 0;
	b[o++] = name.length & 0xFF; b[o++] = (name.length >> 8) & 0xFF;
	Buffer.from(name).copy(b, o);
	return b;
}
function encVoxelOp(seq, type, gx, gy, gz, dx, dy, dz, radius, power) {
	const b = Buffer.alloc(1 + 4 + 1 + 4 * 8 + 2);
	let o = 0;
	b[o++] = 3;
	for (let i = 0; i < 4; i++) b[o++] = (seq >> (8 * i)) & 0xFF;
	b[o++] = type;
	for (const v of [gx, gy, gz, dx, dy, dz, radius, power]) {
		for (let i = 0; i < 4; i++) b[o++] = (v >> (8 * i)) & 0xFF;
	}
	b[o++] = 1; b[o++] = 0;
	return b;
}
function encChecksum(cx, cy, cz) {
	const b = Buffer.alloc(1 + 4 + 12 + 4 + 2);
	let o = 0;
	b[o++] = 4;
	for (let i = 0; i < 4; i++) b[o++] = 0; // serverTick placeholder (ignored by server)
	for (const v of [cx, cy, cz]) {
		for (let i = 0; i < 4; i++) b[o++] = (v >> (8 * i)) & 0xFF;
	}
	for (let i = 0; i < 4; i++) b[o++] = 0;
	b[o++] = 1; b[o++] = 0;
	return b;
}

const PORT = process.env.GAME_SERVER_PORT || '17783';
let received = { a: [], b: [] };
let done = false;

function makeClient(label, store) {
	const ws = new WebSocket('ws://127.0.0.1:' + PORT);
	ws.on('open', () => {
		ws.send(encHello(label));
		setTimeout(() => {
			if (label === 'A') {
				ws.send(encVoxelOp(5, 1, 2, 2, 2, 0, 0, 0, 1500, 800));
			}
		}, 300);
		setTimeout(() => {
			ws.send(encChecksum(0, 0, 0));
		}, 700);
	});
	ws.on('message', (data) => {
		const b = Buffer.from(data);
		store.push(b[0]);
		if (b[0] === 3) {
			// store the op bytes for comparison
			store.opBytes = Buffer.from(b);
		}
		if (b[0] === 4) {
			store.checksum = (b[16] | (b[17] << 8) | (b[18] << 16) | (b[19] << 24)) >>> 0;
		}
	});
	ws.on('close', () => {});
	return ws;
}

const wa = makeClient('A', received.a);
const wb = makeClient('B', received.b);

setTimeout(() => {
	// compare: both should have received a VOXEL_OP broadcast (type 3)
	const aHasOp = received.a.includes(3);
	const bHasOp = received.b.includes(3);
	console.log('A received VOXEL_OP:', aHasOp);
	console.log('B received VOXEL_OP:', bHasOp);
	console.log('A checksum:', received.a.checksum);
	console.log('B checksum:', received.b.checksum);
	if (aHasOp && bHasOp) {
		console.log('RESULT: PASS (both clients received op broadcast)');
	} else {
		console.log('RESULT: FAIL');
	}
	process.exit(0);
}, 1500);
