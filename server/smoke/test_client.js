// Smoke client for the WSS server. Run with server up:
//   node server/smoke/test_client.mjs
const { WebSocket } = require('ws');

function encHello(name) {
	const b = Buffer.alloc(1 + 2 + 2 + 4 + 2 + name.length);
	let o = 0;
	b[o++] = 6;
	b[o++] = 1; b[o++] = 0; // proto v1
	b[o++] = 1; b[o++] = 0; // edit algo v1
	b[o++] = 0; b[o++] = 0; b[o++] = 0; b[o++] = 0; // build hash
	b[o++] = name.length & 0xFF; b[o++] = (name.length >> 8) & 0xFF;
	Buffer.from(name).copy(b, o);
	return b;
}
function encInput(seq, buttons, mx, mz, yaw, pitch, dt) {
	const b = Buffer.alloc(1 + 4 + 2 + 2 + 2 + 4 + 4 + 2);
	let o = 0;
	b[o++] = 1;
	b[o++] = seq & 0xFF; b[o++] = (seq >> 8) & 0xFF; b[o++] = (seq >> 16) & 0xFF; b[o++] = (seq >> 24) & 0xFF;
	b[o++] = buttons & 0xFF; b[o++] = (buttons >> 8) & 0xFF;
	b[o++] = mx & 0xFF; b[o++] = (mx >> 8) & 0xFF;
	b[o++] = mz & 0xFF; b[o++] = (mz >> 8) & 0xFF;
	for (let i = 0; i < 4; i++) b[o++] = (yaw >> (8 * i)) & 0xFF;
	for (let i = 0; i < 4; i++) b[o++] = (pitch >> (8 * i)) & 0xFF;
	b[o++] = dt & 0xFF; b[o++] = (dt >> 8) & 0xFF;
	return b;
}
function encVoxelOp(seq, type, gx, gy, gz, dx, dy, dz, radius, power) {
	const b = Buffer.alloc(1 + 4 + 1 + 4 * 9 + 2);
	let o = 0;
	b[o++] = 3;
	for (let i = 0; i < 4; i++) b[o++] = (seq >> (8 * i)) & 0xFF;
	b[o++] = type;
	for (const v of [gx, gy, gz, dx, dy, dz, radius, power]) {
		for (let i = 0; i < 4; i++) b[o++] = (v >> (8 * i)) & 0xFF;
	}
	b[o++] = 1; b[o++] = 0; // edit algo v1
	return b;
}

const PORT = process.env.GAME_SERVER_PORT || '17779';
const ws = new WebSocket('ws://127.0.0.1:' + PORT);
let step = 0;
ws.on('open', () => {
	console.log('[client] connected');
	ws.send(encHello('tester'));
});
ws.on('message', (data) => {
	const b = Buffer.from(data);
	const type = b[0];
	if (type === 6) { /* hello ack not sent by server; server doesn't reply hello. */ }
	if (type === 7) {
		console.log('[client] EDIT_ACK seq-ish, op_index present');
	}
	if (type === 8) {
		console.log('[client] EDIT_REJECT reason', b[5]);
	}
	if (type === 2) {
		if (step === 0) {
			step = 1;
			console.log('[client] got snapshot, sending INPUT');
			ws.send(encInput(1, 0, 0, 1000, 0, 0, 16));
			setTimeout(() => {
				console.log('[client] sending VOXEL_OP sphere');
				ws.send(encVoxelOp(2, 1, 1, 1, 1, 0, 0, 0, 2000, 1000));
			}, 200);
		}
	}
	if (type === 3) {
		console.log('[client] VOXEL_OP broadcast received');
	}
	if (type === 4) {
		console.log('[client] CHUNK_CHECKSUM received');
	}
});
ws.on('close', () => { console.log('[client] closed'); process.exit(0); });
ws.on('error', (e) => { console.error('[client] error', e.message); process.exit(1); });

setTimeout(() => {
	console.log('[client] timeout, closing');
	ws.close();
}, 2000);
