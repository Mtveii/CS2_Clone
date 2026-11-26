class_name NetProtocol
extends RefCounted
## Integer-only wire protocol (see docs/PROTOCOL.md).
##
## Determinism rules:
## - No float fields in gameplay/deterministic paths.
## - Little-endian, fixed field order.
## - Units: world = mm (int32), grid = int32 indices, angles = 0..65535 per turn,
##   direction = Q16.16 (int32), dt = uint16 ms.
##
## Full canonical serialization + CRC32C over voxel fields is implemented in the
## voxel core (Phase 2). This file is the Phase 0 baseline.

const PROTOCOL_VERSION := 1
const EDIT_ALGO_VERSION := 1
const ANGLE_UNITS := 65536
const Q16_ONE := 65536

enum MsgType {
	INPUT = 1,
	SNAPSHOT = 2,
	VOXEL_OP = 3,
	CHUNK_CHECKSUM = 4,
	CHUNK_RESYNC = 5,
	HELLO = 6,
	EDIT_ACK = 7,
	EDIT_REJECT = 8,
	DAMAGE = 9,
}

enum VoxelOpType {
	SPHERE_SUBTRACT = 1,
	RAY_SUBTRACT = 2,
	BOX_SUBTRACT = 3,
}

enum RejectReason {
	BEDROCK = 1,
	RATE_LIMIT = 2,
	INVALID = 3,
	OUT_OF_RANGE = 4,
}

enum Buttons {
	JUMP = 1 << 0,
	CROUCH = 1 << 1,
	FIRE = 1 << 2,
	RELOAD = 1 << 3,
	USE = 1 << 4,
}


static func encode_hello(name: String, client_build_hash: int) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	var name_bytes := name.to_utf8_buffer()
	buf.put_u8(MsgType.HELLO)
	buf.put_u16(PROTOCOL_VERSION)
	buf.put_u16(EDIT_ALGO_VERSION)
	buf.put_u32(client_build_hash)
	buf.put_u16(name_bytes.size())
	buf.put_data(name_bytes)
	return buf.data_array


static func encode_input(
	seq: int,
	buttons: int,
	move_x: int,
	move_z: int,
	yaw_units: int,
	pitch_units: int,
	dt_ms: int
) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(MsgType.INPUT)
	buf.put_u32(seq)
	buf.put_u16(buttons)
	buf.put_16(move_x)
	buf.put_16(move_z)
	buf.put_32(yaw_units)
	buf.put_32(pitch_units)
	buf.put_u16(dt_ms)
	return buf.data_array


static func encode_voxel_op(
	seq: int,
	op_type: int,
	gx: int, gy: int, gz: int,
	dx_q16: int, dy_q16: int, dz_q16: int,
	radius_mm: int,
	power: int
) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(MsgType.VOXEL_OP)
	buf.put_u32(seq)
	buf.put_u8(op_type)
	buf.put_32(gx)
	buf.put_32(gy)
	buf.put_32(gz)
	buf.put_32(dx_q16)
	buf.put_32(dy_q16)
	buf.put_32(dz_q16)
	buf.put_32(radius_mm)
	buf.put_32(power)
	buf.put_u16(EDIT_ALGO_VERSION)
	return buf.data_array


static func encode_edit_ack(seq: int, op_index: int, server_tick: int) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(MsgType.EDIT_ACK)
	buf.put_u32(seq)
	buf.put_u32(op_index)
	buf.put_u32(server_tick)
	return buf.data_array


static func encode_edit_reject(seq: int, reason: int) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(MsgType.EDIT_REJECT)
	buf.put_u32(seq)
	buf.put_u8(reason)
	return buf.data_array


static func encode_chunk_checksum(
	server_tick: int,
	cx: int, cy: int, cz: int,
	checksum: int
) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(MsgType.CHUNK_CHECKSUM)
	buf.put_u32(server_tick)
	buf.put_32(cx)
	buf.put_32(cy)
	buf.put_32(cz)
	buf.put_u32(checksum)
	buf.put_u16(EDIT_ALGO_VERSION)
	return buf.data_array


static func message_type(data: PackedByteArray) -> int:
	if data.is_empty():
		return -1
	return data[0]


## CRC32C (Castagnoli) over canonical bytes. Detects drift only, not security.
## Polynomial 0x82F63B78 (reflected). Phase 0 baseline: bitwise, no table.
static func crc32c(data: PackedByteArray) -> int:
	var crc: int = 0xFFFFFFFF
	for byte in data:
		crc = crc ^ byte
		for _bit in 8:
			if (crc & 1) != 0:
				crc = (crc >> 1) ^ 0x82F63B78
			else:
				crc = crc >> 1
			crc = crc & 0xFFFFFFFF
	return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF


## Clamp helper for Q16.16 direction components.
static func to_q16(value: float) -> int:
	return int(round(clampf(value, -1.0, 1.0) * float(Q16_ONE)))


static func from_q16(value: int) -> float:
	return float(value) / float(Q16_ONE)


## Normalize yaw/pitch into 0..65535 (per full turn).
static func wrap_angle_units(value: int) -> int:
	return posmod(value, ANGLE_UNITS)
