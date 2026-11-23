// WSS smoke server for Phase 0 (G4/G5).
// Run: node server/smoke/ws_server.js
// Env: GAME_SERVER_PORT (default 7777), GAME_PROTOCOL_VERSION (default 1),
//      GAME_EDIT_ALGO_VERSION (default 1).
//
// Implements (see docs/PROTOCOL.md):
//   HELLO handshake with version check
//   INPUT -> movement simulation (64 Hz) + snapshot broadcast (20 Hz)
//   VOXEL_OP (sphere/box/ray) server-authoritative, broadcast confirmed op
//   CHUNK_CHECKSUM / CHUNK_RESYNC
//
// This is a smoke server, not production. See docs/RISKS.md.

const { WebSocketServer } = require('ws');

const PORT = parseInt(process.env.GAME_SERVER_PORT || '7777', 10);
const PROTOCOL_VERSION = parseInt(process.env.GAME_PROTOCOL_VERSION || '1', 10);
const EDIT_ALGO_VERSION = parseInt(process.env.GAME_EDIT_ALGO_VERSION || '1', 10);
const TICK_HZ = 64;
const SNAPSHOT_HZ = 20;
const MAX_CLIENTS = 16;

// ---- Voxel store (mirrors shared/voxel/voxel_world.gd) ----
const CHUNK_SIZE = 32;
const VOXEL_SIZE_MM = 200;
const SDF_SCALE = 10;
const SDF_MAX = 32767;
const SDF_MIN = -32768;
const SOLID_THRESHOLD = 0;
const BEDROCK_SHELL = 2;
const BOUNDS = { min: { x: -256, y: -8, z: -256 }, max: { x: 256, y: 64, z: 256 } };

function chunkKey(vx, vy, vz) {
	return `${Math.floor(vx / CHUNK_SIZE)},${Math.floor(vy / CHUNK_SIZE)},${Math.floor(vz / CHUNK_SIZE)}`;
}
function localIndex(lx, ly, lz) {
	const x = ((lx % CHUNK_SIZE) + CHUNK_SIZE) % CHUNK_SIZE;
	const y = ((ly % CHUNK_SIZE) + CHUNK_SIZE) % CHUNK_SIZE;
	const z = ((lz % CHUNK_SIZE) + CHUNK_SIZE) % CHUNK_SIZE;
	return x + y * CHUNK_SIZE + z * CHUNK_SIZE * CHUNK_SIZE;
}
function isBedrockVoxel(vx, vy, vz) {
	if (vx < BOUNDS.min.x + BEDROCK_SHELL || vx >= BOUNDS.max.x - BEDROCK_SHELL) return true;
	if (vz < BOUNDS.min.z + BEDROCK_SHELL || vz >= BOUNDS.max.z - BEDROCK_SHELL) return true;
	if (vy < BOUNDS.min.y + BEDROCK_SHELL) return true;
	return false;
}
function inBoundsVoxel(vx, vy, vz) {
	return vx >= BOUNDS.min.x && vy >= BOUNDS.min.y && vz >= BOUNDS.min.z &&
		vx < BOUNDS.max.x && vy < BOUNDS.max.y && vz < BOUNDS.max.z;
}
function worldMmToVoxel(p) {
	return {
		x: Math.floor(p.x / VOXEL_SIZE_MM),
		y: Math.floor(p.y / VOXEL_SIZE_MM),
		z: Math.floor(p.z / VOXEL_SIZE_MM),
	};
}

const chunks = new Map(); // key -> Int32Array(size^3)
function getChunk(key, create) {
	if (chunks.has(key)) return chunks.get(key);
	if (!create) return null;
	const arr = new Int32Array(CHUNK_SIZE ** 3);
	arr.fill(SDF_MAX);
	chunks.set(key, arr);
	return arr;
}
function getSdfVoxel(vx, vy, vz) {
	if (!inBoundsVoxel(vx, vy, vz)) return SDF_MIN;
	if (isBedrockVoxel(vx, vy, vz)) return SDF_MIN;
	const key = chunkKey(vx, vy, vz);
	const c = getChunk(key, false);
	if (!c) return SDF_MAX;
	return c[localIndex(vx, vy, vz)];
}
function setSdfVoxel(vx, vy, vz, value, allowBedrock) {
	if (!inBoundsVoxel(vx, vy, vz)) return false;
	if (isBedrockVoxel(vx, vy, vz) && !allowBedrock) return false;
	const key = chunkKey(vx, vy, vz);
	const c = getChunk(key, true);
	const i = localIndex(vx, vy, vz);
	if (c[i] <= SDF_MIN && !allowBedrock) {
		// bedrock already solid; skip (bedrock mask not stored separately here)
	}
	c[i] = Math.max(SDF_MIN, Math.min(SDF_MAX, value));
	return true;
}

function crc32c(data) {
	let crc = 0xFFFFFFFF;
	for (let i = 0; i < data.length; i++) {
		crc ^= data[i];
		for (let b = 0; b < 8; b++) {
			if (crc & 1) crc = (crc >>> 1) ^ 0x82F63B78;
			else crc = crc >>> 1;
		}
	}
	return (crc ^ 0xFFFFFFFF) >>> 0;
}
function chunkChecksum(key) {
	const c = getChunk(key, false);
	if (!c) return 0;
	const buf = Buffer.alloc(c.length * 4);
	for (let i = 0; i < c.length; i++) {
		buf.writeInt32LE(c[i], i * 4);
	}
	return crc32c(buf);
}
function serializeChunk(key) {
	const c = getChunk(key, false);
	if (!c) return null;
	const buf = Buffer.alloc(c.length * 4);
	for (let i = 0; i < c.length; i++) buf.writeInt32LE(c[i], i * 4);
	return buf;
}

let opCounter = 0;
function editSphere(centerMm, radiusMm, power) {
	const centerV = worldMmToVoxel(centerMm);
	const radiusV = Math.ceil(radiusMm / VOXEL_SIZE_MM) + 1;
	const affected = new Set();
	let changed = 0;
	for (let z = centerV.z - radiusV; z <= centerV.z + radiusV; z++) {
		for (let y = centerV.y - radiusV; y <= centerV.y + radiusV; y++) {
			for (let x = centerV.x - radiusV; x <= centerV.x + radiusV; x++) {
				if (!inBoundsVoxel(x, y, z) || isBedrockVoxel(x, y, z)) continue;
				const dx = x - centerV.x, dy = y - centerV.y, dz = z - centerV.z;
				const d2 = dx * dx + dy * dy + dz * dz;
				if (d2 > radiusV * radiusV) continue;
				const dist = Math.sqrt(d2);
				const falloff = 1.0 - (dist / radiusV);
				const delta = Math.trunc(power * falloff);
				const cur = getSdfVoxel(x, y, z);
				if (setSdfVoxel(x, y, z, cur - delta, false)) {
					changed++;
					affected.add(chunkKey(x, y, z));
				}
			}
		}
	}
	opCounter++;
	return { opIndex: opCounter, affected: [...affected], changed };
}
function editBox(minMm, maxMm, power) {
	const vmin = worldMmToVoxel(minMm);
	const vmax = worldMmToVoxel(maxMm);
	const affected = new Set();
	let changed = 0;
	for (let z = vmin.z; z <= vmax.z; z++) {
		for (let y = vmin.y; y <= vmax.y; y++) {
			for (let x = vmin.x; x <= vmax.x; x++) {
				if (!inBoundsVoxel(x, y, z) || isBedrockVoxel(x, y, z)) continue;
				const cur = getSdfVoxel(x, y, z);
				if (setSdfVoxel(x, y, z, cur - power, false)) {
					changed++;
					affected.add(chunkKey(x, y, z));
				}
			}
		}
	}
	opCounter++;
	return { opIndex: opCounter, affected: [...affected], changed };
}
function editRay(originMm, dir, radiusMm, lengthMm, power) {
	const len = Math.sqrt(dir.x * dir.x + dir.y * dir.y + dir.z * dir.z) || 1;
	const dx = dir.x / len, dy = dir.y / len, dz = dir.z / len;
	const steps = Math.ceil(lengthMm / VOXEL_SIZE_MM) + 1;
	const affected = new Set();
	let changed = 0;
	for (let s = 0; s < steps; s++) {
		const p = { x: originMm.x + dx * s * VOXEL_SIZE_MM, y: originMm.y + dy * s * VOXEL_SIZE_MM, z: originMm.z + dz * s * VOXEL_SIZE_MM };
		const r = editSphere(p, radiusMm, power);
		changed += r.changed;
		for (const k of r.affected) affected.add(k);
	}
	opCounter++;
	return { opIndex: opCounter, affected: [...affected], changed };
}

// ---- Binary protocol helpers (little-endian) ----
function readU8(b, o) { return b[o]; }
function readU16(b, o) { return b[o] | (b[o + 1] << 8); }
function readI16(b, o) { const v = b[o] | (b[o + 1] << 8); return v > 32767 ? v - 65536 : v; }
function readU32(b, o) { return (b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)) >>> 0; }
function readI32(b, o) { return b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24); }
function writeU8(b, o, v) { b[o] = v & 0xFF; }
function writeU16(b, o, v) { b[o] = v & 0xFF; b[o + 1] = (v >> 8) & 0xFF; }
function writeI16(b, o, v) { writeU16(b, o, v & 0xFFFF); }
function writeU32(b, o, v) { b[o] = v & 0xFF; b[o + 1] = (v >> 8) & 0xFF; b[o + 2] = (v >> 16) & 0xFF; b[o + 3] = (v >>> 24) & 0xFF; }
function writeI32(b, o, v) { writeU32(b, o, v >>> 0); }

const MSG = { INPUT: 1, SNAPSHOT: 2, VOXEL_OP: 3, CHUNK_CHECKSUM: 4, CHUNK_RESYNC: 5, HELLO: 6, EDIT_ACK: 7, EDIT_REJECT: 8, DAMAGE: 9 };
const VOXEL_OP_TYPE = { SPHERE_SUBTRACT: 1, RAY_SUBTRACT: 2, BOX_SUBTRACT: 3 };
const REJECT = { BEDROCK: 1, RATE_LIMIT: 2, INVALID: 3, OUT_OF_RANGE: 4 };

// ---- Clients ----
const clients = new Map(); // ws -> { id, name, x,y,z, yaw, pitch, vx,vy,vz, onGround, lastInputSeq, lastEditTime, editsThisSec, editsWindowStart }
let nextClientId = 1;

function makeClient(ws) {
	return {
		id: nextClientId++,
		ws,
		name: 'player',
		helloed: false,
		hp: 100, armor: 0, helmet: false, alive: true, next_fire_ms: 0,
		x: 0, y: 1.6 * 1000, z: 0, // mm
		vx: 0, vy: 0, vz: 0,
		yaw: 0, pitch: 0,
		onGround: false,
		lastInputSeq: 0,
		buttons: 0,
		moveX: 0, moveZ: 0,
		lastEditTime: 0,
		editsThisSec: 0,
		editsWindowStart: 0,
	};
}

function send(ws, buf) {
	if (ws.readyState === ws.OPEN) ws.send(buf, { binary: true });
}

function handleHello(ws, c, buf) {
	let o = 1;
	const proto = readU16(buf, o); o += 2;
	const editAlgo = readU16(buf, o); o += 2;
	const buildHash = readU32(buf, o); o += 4;
	const nameLen = readU16(buf, o); o += 2;
	const nameBytes = buf.slice(o, o + nameLen);
	c.name = Buffer.from(nameBytes).toString('utf8') || c.name;
	if (proto !== PROTOCOL_VERSION) {
		// reject by closing
		ws.close(4000, 'protocol mismatch');
		return;
	}
	if (editAlgo !== EDIT_ALGO_VERSION) {
		ws.close(4001, 'edit algo mismatch');
		return;
	}
	c.helloed = true;
	console.log(`client ${c.id} hello: ${c.name} (build ${buildHash})`);
}

function handleInput(c, buf) {
	let o = 1;
	const seq = readU32(buf, o); o += 4;
	const buttons = readU16(buf, o); o += 2;
	const moveX = readI16(buf, o); o += 2;
	const moveZ = readI16(buf, o); o += 2;
	const yaw = readI32(buf, o); o += 4;
	const pitch = readI32(buf, o); o += 4;
	const dt = readU16(buf, o); o += 2;
	c.lastInputSeq = seq;
	c.buttons = buttons;
	c.moveX = moveX;
	c.moveZ = moveZ;
	c.yaw = yaw;
	c.pitch = pitch;
	if ((buttons & 4) !== 0) tryFire(c);
}

function tryFire(c) {
	const now = Date.now();
	if (now < c.next_fire_ms) return;
	c.next_fire_ms = now + 100;
	let target = null;
	let best = 3000 * 3000; // 30 m in mm^2
	for (const [ws2, other] of clients) {
		if (other === c || !other.helloed || !other.alive) continue;
		const dx = other.x - c.x, dy = other.y - c.y, dz = other.z - c.z;
		const d2 = dx * dx + dy * dy + dz * dz;
		const yawRad = (c.yaw / 65536) * Math.PI * 2;
		const fx = -Math.sin(yawRad), fz = -Math.cos(yawRad);
		const len = Math.sqrt(dx * dx + dz * dz) || 1;
		const dot = (dx / len) * fx + (dz / len) * fz;
		if (d2 < best && dot > 0.85) { best = d2; target = other; }
	}
	if (!target) return;
	let dmg = 36;
	if (target.armor > 0) {
		dmg = Math.round(dmg * 0.775);
		target.armor = Math.max(0, target.armor - 3);
	}
	target.hp = Math.max(0, target.hp - dmg);
	if (target.hp === 0) target.alive = false;
	const out = Buffer.alloc(1 + 4 + 4 + 2 + 2);
	let o = 0;
	out[o++] = MSG.DAMAGE;
	writeU32(out, o, c.id); o += 4;
	writeU32(out, o, target.id); o += 4;
	writeU16(out, o, target.hp); o += 2;
	writeU16(out, o, target.armor); o += 2;
	send(target.ws, out);
}

function handleVoxelOp(ws, c, buf) {
	let o = 1;
	const seq = readU32(buf, o); o += 4;
	const opType = buf[o++];
	const gx = readI32(buf, o); o += 4;
	const gy = readI32(buf, o); o += 4;
	const gz = readI32(buf, o); o += 4;
	const dx = readI32(buf, o); o += 4;
	const dy = readI32(buf, o); o += 4;
	const dz = readI32(buf, o); o += 4;
	const radiusMm = readI32(buf, o); o += 4;
	const power = readI32(buf, o); o += 4;
	const algo = readU16(buf, o); o += 2;

	if (!c.helloed) { sendReject(ws, seq, REJECT.INVALID); return; }
	if (algo !== EDIT_ALGO_VERSION) { sendReject(ws, seq, REJECT.INVALID); return; }

	// rate limit
	const now = Date.now();
	if (now - c.editsWindowStart > 1000) {
		c.editsWindowStart = now;
		c.editsThisSec = 0;
	}
	if (c.editsThisSec >= 10) {
		sendReject(ws, seq, REJECT.RATE_LIMIT);
		return;
	}
	c.editsThisSec++;

	// distance check: op center must be within ~5m of player
	const cx = gx * VOXEL_SIZE_MM; // approx; gx is voxel index already? protocol sends voxel grid coords. Treat as mm? 
	// Protocol VOXEL_OP uses grid coords (gx,gy,gz) as voxel indices. Convert to mm center.
	const centerMm = { x: gx * VOXEL_SIZE_MM + VOXEL_SIZE_MM / 2, y: gy * VOXEL_SIZE_MM + VOXEL_SIZE_MM / 2, z: gz * VOXEL_SIZE_MM + VOXEL_SIZE_MM / 2 };
	const pdx = centerMm.x - c.x, pdy = centerMm.y - c.y, pdz = centerMm.z - c.z;
	const pdist = Math.sqrt(pdx * pdx + pdy * pdy + pdz * pdz);
	if (pdist > 10000) { sendReject(ws, seq, REJECT.OUT_OF_RANGE); return; }

	let result;
	if (opType === VOXEL_OP_TYPE.SPHERE_SUBTRACT) {
		result = editSphere(centerMm, radiusMm, power);
	} else if (opType === VOXEL_OP_TYPE.BOX_SUBTRACT) {
		// box: gx..dx? We treat dx,dy,dz as extent in voxels for simplicity; here min..max mm
		const minMm = centerMm;
		const maxMm = { x: centerMm.x + dx * VOXEL_SIZE_MM, y: centerMm.y + dy * VOXEL_SIZE_MM, z: centerMm.z + dz * VOXEL_SIZE_MM };
		result = editBox(minMm, maxMm, power);
	} else if (opType === VOXEL_OP_TYPE.RAY_SUBTRACT) {
		const dir = { x: dx, y: dy, z: dz };
		result = editRay(centerMm, dir, radiusMm, 3000, power);
	} else {
		sendReject(ws, seq, REJECT.INVALID);
		return;
	}

	// bedrock check: if no voxels changed, possibly all bedrock
	if (result.changed === 0) {
		// not necessarily reject; accept but noop
	}

	// Broadcast confirmed op to all clients (including sender) with op_index
	const out = Buffer.alloc(1 + 4 + 1 + 12 + 12 + 4 + 4 + 2);
	o = 0;
	out[o++] = MSG.VOXEL_OP;
	writeU32(out, o, seq); o += 4;
	out[o++] = opType;
	writeI32(out, o, gx); o += 4;
	writeI32(out, o, gy); o += 4;
	writeI32(out, o, gz); o += 4;
	writeI32(out, o, dx); o += 4;
	writeI32(out, o, dy); o += 4;
	writeI32(out, o, dz); o += 4;
	writeI32(out, o, radiusMm); o += 4;
	writeI32(out, o, power); o += 4;
	writeU16(out, o, EDIT_ALGO_VERSION); o += 2;
	for (const [ws2] of clients) {
		send(ws2, out);
	}

	// EDIT_ACK to sender
	const ack = Buffer.alloc(1 + 4 + 4 + 4);
	let a = 0;
	ack[a++] = MSG.EDIT_ACK;
	writeU32(ack, a, seq); a += 4;
	writeU32(ack, a, result.opIndex); a += 4;
	writeU32(ack, a, tickCount); a += 4;
	send(ws, ack);
}

function sendReject(ws, seq, reason) {
	const buf = Buffer.alloc(1 + 4 + 1);
	let o = 0;
	buf[o++] = MSG.EDIT_REJECT;
	writeU32(buf, o, seq); o += 4;
	buf[o++] = reason;
	send(ws, buf);
}

function handleChunkChecksum(ws, c, buf) {
	let o = 1;
	const serverTick = readU32(buf, o); o += 4;
	const cx = readI32(buf, o); o += 4;
	const cy = readI32(buf, o); o += 4;
	const cz = readI32(buf, o); o += 4;
	const key = `${cx},${cy},${cz}`;
	const cs = chunkChecksum(key);
	const out = Buffer.alloc(1 + 4 + 12 + 4 + 2);
	let k = 0;
	out[k++] = MSG.CHUNK_CHECKSUM;
	writeU32(out, k, tickCount); k += 4;
	writeI32(out, k, cx); k += 4;
	writeI32(out, k, cy); k += 4;
	writeI32(out, k, cz); k += 4;
	writeU32(out, k, cs); k += 4;
	writeU16(out, k, EDIT_ALGO_VERSION); k += 2;
	send(ws, out);
}

function handleChunkResyncRequest(ws, cx, cy, cz) {
	const key = `${cx},${cy},${cz}`;
	const data = serializeChunk(key);
	if (!data) return;
	const out = Buffer.alloc(1 + 12 + 4 + 4 + data.length);
	let o = 0;
	out[o++] = MSG.CHUNK_RESYNC;
	writeI32(out, o, cx); o += 4;
	writeI32(out, o, cy); o += 4;
	writeI32(out, o, cz); o += 4;
	writeU32(out, o, data.length); o += 4;
	writeU32(out, o, data.length); o += 4;
	data.copy(out, o);
	send(ws, out);
}

// ---- Movement sim ----
const GRAVITY_MM_S2 = -9800 * 1000; // mm/s^2 (scaled)
const MOVE_SPEED_MM_S = 4500 * 10; // mm/s
const JUMP_VEL_MM_S = 4000 * 10;

function stepClient(c, dt) {
	if (!c.helloed) return;
	// movement direction from yaw + moveX/moveZ
	const yawRad = (c.yaw / 65536.0) * Math.PI * 2;
	const fx = Math.sin(yawRad);
	const fz = Math.cos(yawRad);
	const rx = Math.cos(yawRad);
	const rz = -Math.sin(yawRad);
	const mx = (c.moveX / 32767.0);
	const mz = (c.moveZ / 32767.0);
	const wx = (fx * mz + rx * mx) * MOVE_SPEED_MM_S;
	const wz = (fz * mz + rz * mx) * MOVE_SPEED_MM_S;
	c.vx = wx;
	c.vz = wz;
	// gravity
	c.vy += GRAVITY_MM_S2 * dt;
	// jump
	if ((c.buttons & 1) && c.onGround) {
		c.vy = JUMP_VEL_MM_S;
		c.onGround = false;
	}
	// integrate
	c.x += c.vx * dt;
	c.y += c.vy * dt;
	c.z += c.vz * dt;
	// clamp to bounds
	const minY = BOUNDS.min.y * VOXEL_SIZE_MM;
	const maxY = (BOUNDS.max.y - 1) * VOXEL_SIZE_MM;
	if (c.y < minY) { c.y = minY; c.vy = 0; c.onGround = true; }
	if (c.y > maxY) { c.y = maxY; c.vy = 0; }
	if (c.x < BOUNDS.min.x * VOXEL_SIZE_MM) c.x = BOUNDS.min.x * VOXEL_SIZE_MM;
	if (c.x > (BOUNDS.max.x - 1) * VOXEL_SIZE_MM) c.x = (BOUNDS.max.x - 1) * VOXEL_SIZE_MM;
	if (c.z < BOUNDS.min.z * VOXEL_SIZE_MM) c.z = BOUNDS.min.z * VOXEL_SIZE_MM;
	if (c.z > (BOUNDS.max.z - 1) * VOXEL_SIZE_MM) c.z = (BOUNDS.max.z - 1) * VOXEL_SIZE_MM;
	// ground check: voxel below feet
	const footV = worldMmToVoxel({ x: c.x, y: c.y - 10, z: c.z });
	const below = getSdfVoxel(footV.x, footV.y, footV.z);
	if (below <= SOLID_THRESHOLD) {
		const topMm = (footV.y + 1) * VOXEL_SIZE_MM;
		if (c.y < topMm) {
			c.y = topMm;
			c.vy = 0;
			c.onGround = true;
		}
	} else {
		c.onGround = false;
	}
	// crouch reduces height (not modeled fully here)
}

function buildSnapshot() {
	const buf = Buffer.alloc(1 + 4 + 2 + clients.size * (4 + 4 * 3 + 4 + 2 + 2));
	let o = 0;
	buf[o++] = MSG.SNAPSHOT;
	writeU32(buf, o, tickCount); o += 4;
	writeU16(buf, o, clients.size); o += 2;
	for (const [ws, c] of clients) {
		if (!c.helloed) continue;
		writeU32(buf, o, c.id); o += 4;
		writeI32(buf, o, Math.round(c.x)); o += 4;
		writeI32(buf, o, Math.round(c.y)); o += 4;
		writeI32(buf, o, Math.round(c.z)); o += 4;
		writeI32(buf, o, c.yaw); o += 4;
		writeI32(buf, o, c.pitch); o += 4;
		writeU16(buf, o, c.onGround ? 1 : 0); o += 2;
		writeU16(buf, o, c.hp); o += 2; // health
	}
	return buf;
}

let tickCount = 0;
const TICK_DT = 1 / TICK_HZ;
const SNAPSHOT_INTERVAL = Math.round(TICK_HZ / SNAPSHOT_HZ);

// ---- Server ----
const wss = new WebSocketServer({ port: PORT });
console.log(`WSS smoke server listening on ${PORT}`);

wss.on('connection', (ws) => {
	if (clients.size >= MAX_CLIENTS) { ws.close(4002, 'server full'); return; }
	const c = makeClient(ws);
	clients.set(ws, c);
	console.log(`client ${c.id} connected`);

	ws.on('message', (data) => {
		const buf = Buffer.from(data);
		if (buf.length === 0) return;
		const type = buf[0];
		if (type === MSG.HELLO) handleHello(ws, c, buf);
		else if (type === MSG.INPUT) handleInput(c, buf);
		else if (type === MSG.VOXEL_OP) handleVoxelOp(ws, c, buf);
		else if (type === MSG.CHUNK_CHECKSUM) handleChunkChecksum(ws, c, buf);
	});

	ws.on('close', () => {
		clients.delete(ws);
		console.log(`client ${c.id} disconnected`);
	});
	ws.on('error', (e) => console.error('ws error', e.message));
});

// Tick loop
setInterval(() => {
	tickCount++;
	const dt = TICK_DT;
	for (const [ws, c] of clients) {
		stepClient(c, dt);
	}
	if (tickCount % SNAPSHOT_INTERVAL === 0) {
		const snap = buildSnapshot();
		for (const [ws] of clients) send(ws, snap);
	}
}, 1000 / TICK_HZ);

// Keep process alive
process.on('SIGINT', () => { console.log('shutting down'); process.exit(0); });
