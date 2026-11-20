extends Node
## Net test node. Attached to a scene so _process runs.

var ws = WebSocketPeer.new()
var url: String = "ws://127.0.0.1:17785"
var started_ms: int = 0
var snapshots: int = 0
var connected: bool = false
var hello_sent: bool = false
var input_sent: bool = false
var finished: bool = false
const TIMEOUT_MS = 4000


func _ready() -> void:
	var env_url = OS.get_environment("GAME_SERVER_URL")
	if env_url != "":
		url = env_url
	started_ms = Time.get_ticks_msec()
	var err = ws.connect_to_url(url)
	if err != OK:
		print("FAIL: connect_to_url error ", err)
		get_tree().quit(1)
		return
	print("connecting to ", url)


func _process(_delta: float) -> void:
	if finished:
		return
	ws.poll()
	var state = ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN and not connected:
		connected = true
		print("connected")
		var hello = _enc_hello("gdscript-client")
		ws.send(hello)
		hello_sent = true
	if state == WebSocketPeer.STATE_OPEN:
		while ws.get_available_packet_count() > 0:
			var pkt = ws.get_packet()
			if pkt.size() == 0:
				continue
			var type = pkt[0]
			if type == 2:
				snapshots += 1
				if not input_sent:
					input_sent = true
					var inp = _enc_input(1, 0, 0, 1000, 0, 0, 16)
					ws.send(inp)
					print("sent INPUT")
			elif type == 7:
				print("received EDIT_ACK")
			elif type == 3:
				print("received VOXEL_OP broadcast")
	if state == WebSocketPeer.STATE_CLOSED:
		if not finished:
			finished = true
			_finish()
		return
	if Time.get_ticks_msec() - started_ms > TIMEOUT_MS:
		if not finished:
			finished = true
			_finish()


func _finish() -> void:
	print("snapshots received: ", snapshots)
	ws.close()
	if connected and snapshots > 0:
		print("RESULT: PASS")
		get_tree().quit(0)
	else:
		print("RESULT: FAIL")
		get_tree().quit(1)


func _enc_hello(name: String) -> PackedByteArray:
	var b = PackedByteArray()
	b.resize(1 + 2 + 2 + 4 + 2 + name.length())
	var o = 0
	b[o] = 6; o += 1
	b[o] = 1; b[o + 1] = 0; o += 2
	b[o] = 1; b[o + 1] = 0; o += 2
	for i in 4:
		b[o + i] = 0
	o += 4
	b[o] = name.length() & 0xFF; b[o + 1] = (name.length() >> 8) & 0xFF; o += 2
	var nb = name.to_utf8_buffer()
	for i in name.length():
		b[o + i] = nb[i]
	o += name.length()
	return b


func _enc_input(seq: int, buttons: int, mx: int, mz: int, yaw: int, pitch: int, dt: int) -> PackedByteArray:
	var b = PackedByteArray()
	b.resize(1 + 4 + 2 + 2 + 2 + 4 + 4 + 2)
	var o = 0
	b[o] = 1; o += 1
	for i in 4:
		b[o + i] = (seq >> (8 * i)) & 0xFF
	o += 4
	b[o] = buttons & 0xFF; b[o + 1] = (buttons >> 8) & 0xFF; o += 2
	b[o] = mx & 0xFF; b[o + 1] = (mx >> 8) & 0xFF; o += 2
	b[o] = mz & 0xFF; b[o + 1] = (mz >> 8) & 0xFF; o += 2
	for i in 4:
		b[o + i] = (yaw >> (8 * i)) & 0xFF
	o += 4
	for i in 4:
		b[o + i] = (pitch >> (8 * i)) & 0xFF
	o += 4
	b[o] = dt & 0xFF; b[o + 1] = (dt >> 8) & 0xFF; o += 2
	return b
