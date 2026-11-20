extends SceneTree
## Phase 0 protocol smoke test. Run:
##   godot --headless --path . --script res://tests/protocol_smoke.gd

const Proto = preload("res://shared/protocol/net_protocol.gd")

var failures: int = 0


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[ok]   ", message)
	else:
		failures += 1
		push_error("[fail] " + message)


func _init() -> void:
	var hello := Proto.encode_hello("tester", 0x12345678)
	_check(hello.size() == 1 + 2 + 2 + 4 + 2 + 6, "HELLO length")
	_check(Proto.message_type(hello) == Proto.MsgType.HELLO, "HELLO type")

	var input := Proto.encode_input(42, Proto.Buttons.FIRE, 0, 1000, 32768, -100, 16)
	_check(input.size() == 1 + 4 + 2 + 2 + 2 + 4 + 4 + 2, "INPUT length")
	_check(Proto.message_type(input) == Proto.MsgType.INPUT, "INPUT type")

	var op := Proto.encode_voxel_op(
		7,
		Proto.VoxelOpType.SPHERE_SUBTRACT,
		1, 2, 3,
		Proto.to_q16(0.0), Proto.to_q16(-1.0), Proto.to_q16(0.0),
		2000,
		100
	)
	_check(op.size() == 1 + 4 + 1 + 12 + 12 + 4 + 4 + 2, "VOXEL_OP length")
	_check(Proto.message_type(op) == Proto.MsgType.VOXEL_OP, "VOXEL_OP type")

	var ack := Proto.encode_edit_ack(7, 1001, 555)
	_check(ack.size() == 1 + 4 + 4 + 4, "EDIT_ACK length")

	var reject := Proto.encode_edit_reject(7, Proto.RejectReason.BEDROCK)
	_check(reject.size() == 1 + 4 + 1, "EDIT_REJECT length")

	var sum1 := Proto.encode_chunk_checksum(1, -2, 3, -4, 0xDEADBEEF)
	_check(sum1.size() == 1 + 4 + 12 + 4 + 2, "CHUNK_CHECKSUM length")

	# CRC32C known-answer test: "123456789" -> 0xE3069283
	var check_value := Proto.crc32c("123456789".to_utf8_buffer())
	_check(check_value == 0xE3069283, "CRC32C known answer (got %08x)" % check_value)

	# Determinism and sensitivity.
	_check(Proto.crc32c(input) == Proto.crc32c(input), "CRC32C deterministic")
	_check(Proto.crc32c(input) != Proto.crc32c(op), "CRC32C sensitive to data")

	# Fixed-point and angle helpers.
	_check(Proto.to_q16(1.0) == Proto.Q16_ONE, "to_q16(1.0)")
	_check(Proto.from_q16(Proto.Q16_ONE) == 1.0, "from_q16(1.0)")
	_check(Proto.wrap_angle_units(-1) == Proto.ANGLE_UNITS - 1, "wrap_angle_units(-1)")

	if failures > 0:
		print("RESULT: FAIL (", failures, ")")
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)
