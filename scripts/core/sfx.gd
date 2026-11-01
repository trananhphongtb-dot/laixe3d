extends Node
## Toàn bộ âm thanh được tạo bằng code (không dùng file âm thanh).

const RATE := 22050
var streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 12345
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_build_all()


func vol_db(extra: float = 0.0) -> float:
	var v: float = Game.settings.get("sfx_vol", 0.9)
	return linear_to_db(max(v, 0.001)) + extra


func play(name: String, extra_db: float = 0.0, pitch: float = 1.0) -> void:
	if not streams.has(name):
		return
	var v: float = Game.settings.get("sfx_vol", 0.9)
	if v <= 0.01:
		return
	var player: AudioStreamPlayer = null
	for p in _pool:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _pool[0]
	player.stream = streams[name]
	player.volume_db = vol_db(extra_db)
	player.pitch_scale = pitch
	player.play()


## Tạo một player lặp (còi, rít lốp, mưa...). Người gọi tự add_child.
func make_loop_player(name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = streams.get(name)
	p.volume_db = -80.0
	return p


func make_loop_player_3d(name: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = streams.get(name)
	p.unit_size = 5.0
	p.max_distance = 55.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	return p


# ---------------------------------------------------------------- tạo âm thanh

func _wav(s: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w


func _buf(sec: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(sec * RATE))
	return a


func _build_all() -> void:
	# Xi nhan: "tách" và "tạch"
	streams["tick"] = _wav(_tick(2600.0, 0.035))
	streams["tock"] = _wav(_tick(1700.0, 0.04))
	# Nút giao diện
	streams["ui"] = _wav(_tick(1200.0, 0.03, 0.5))
	# Còi (lặp) — tần số nguyên để vòng lặp liền mạch
	var h := _buf(1.0)
	for i in h.size():
		var tt := float(i) / RATE
		var v := _sq(tt * 370.0) * 0.5 + _sq(tt * 466.0) * 0.45
		h[i] = tanh(v * 1.4) * 0.55
	streams["horn"] = _wav(h, true)
	# Ting: qua bài
	streams["ding"] = _wav(_bell([1047.0, 1568.0, 2093.0], 0.9, 4.0))
	# Xu/tiền
	var c := _buf(0.32)
	for i in c.size():
		var tt := float(i) / RATE
		var f := 988.0 if tt < 0.08 else 1319.0
		var env := exp(-(tt if tt < 0.08 else tt - 0.08) * 12.0)
		c[i] = sin(TAU * f * tt) * env * 0.5
	streams["coin"] = _wav(c)
	# Tèn: bị trừ điểm
	var b := _buf(0.55)
	for i in b.size():
		var tt := float(i) / RATE
		var f := 392.0 if tt < 0.22 else 262.0
		var lt := tt if tt < 0.22 else tt - 0.22
		var env := clampf(1.0 - lt / 0.33, 0.0, 1.0) * clampf(lt * 60.0, 0.0, 1.0)
		b[i] = (_sq(tt * f) * 0.35 + sin(TAU * f * 0.5 * tt) * 0.25) * env
	streams["fail"] = _wav(b)
	# Trượt / truất quyền
	var o := _buf(1.2)
	for i in o.size():
		var tt := float(i) / RATE
		var f := 220.0 * exp(-tt * 0.6)
		o[i] = _saw(tt * f) * 0.4 * clampf(1.2 - tt, 0.0, 1.0)
	streams["over"] = _wav(o)
	# Đạt bài thi
	var w := _buf(1.3)
	var notes := [523.0, 659.0, 784.0, 1047.0]
	for i in w.size():
		var tt := float(i) / RATE
		var idx := mini(int(tt / 0.16), 3)
		var lt := tt - idx * 0.16
		var f: float = notes[idx]
		w[i] = (sin(TAU * f * tt) * 0.4 + sin(TAU * f * 2.0 * tt) * 0.12) * exp(-lt * (3.0 if idx == 3 else 9.0))
	streams["win"] = _wav(w)
	# Chuông nhắc dây an toàn
	streams["chime"] = _wav(_bell([740.0, 1480.0], 0.35, 10.0))
	# Báo động tình huống bất ngờ
	var a := _buf(1.2)
	for i in a.size():
		var tt := float(i) / RATE
		var f := 920.0 if int(tt / 0.15) % 2 == 0 else 690.0
		a[i] = _sq(tt * f) * 0.3
	streams["alarm"] = _wav(a, true)
	# Va chạm
	var cr := _buf(0.7)
	var lp := 0.0
	for i in cr.size():
		var tt := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.35
		cr[i] = (lp * 1.6 + sin(TAU * 55.0 * tt) * 0.7) * exp(-tt * 7.0)
	streams["crash"] = _wav(cr)
	# Rít lốp (lặp)
	var sk := _buf(1.0)
	var l1 := 0.0
	var l2 := 0.0
	for i in sk.size():
		var n := _rng.randf_range(-1.0, 1.0)
		l1 += (n - l1) * 0.5
		l2 += (l1 - l2) * 0.08
		var tt := float(i) / RATE
		sk[i] = ((l1 - l2) * 1.4 + sin(TAU * 1100.0 * tt) * 0.12) * 0.6
	streams["skid"] = _wav(sk, true)
	# Mưa (lặp)
	var r := _buf(2.0)
	var rl := 0.0
	for i in r.size():
		rl += (_rng.randf_range(-1.0, 1.0) - rl) * 0.22
		var drop := 0.0
		if _rng.randf() < 0.002:
			drop = _rng.randf_range(0.3, 0.7)
		r[i] = rl * 0.5 + drop
	streams["rain"] = _wav(r, true)
	# Động cơ xe AI (lặp) — họa âm nguyên của 40Hz
	var e := _buf(1.0)
	var el := 0.0
	for i in e.size():
		var tt := float(i) / RATE
		var ph := fmod(tt * 40.0, 1.0)
		var pulse := pow(1.0 - ph, 3.0) * 2.0 - 0.5
		el += (_rng.randf_range(-1.0, 1.0) - el) * 0.1
		e[i] = (pulse * 0.45 + sin(TAU * 80.0 * tt) * 0.2 + el * 0.15) * 0.7
	streams["engine_ai"] = _wav(e, true)
	# Đề máy
	var st := _buf(0.9)
	for i in st.size():
		var tt := float(i) / RATE
		var crank := 0.5 + 0.5 * sin(TAU * 9.0 * tt)
		var ph := fmod(tt * 28.0, 1.0)
		st[i] = (pow(1.0 - ph, 4.0) - 0.2) * crank * 0.6 * clampf((0.9 - tt) * 4.0, 0.0, 1.0)
	streams["crank"] = _wav(st)
	# Vào số
	streams["shift"] = _wav(_thump(0.08, 140.0))
	# Kêu hộp số khi không đạp côn
	var gr := _buf(0.35)
	for i in gr.size():
		var tt := float(i) / RATE
		gr[i] = (_saw(tt * 310.0) * 0.3 + _rng.randf_range(-0.3, 0.3)) * clampf(1.0 - tt / 0.35, 0.0, 1.0)
	streams["grind"] = _wav(gr)
	# Chuông tàu hỏa
	streams["bell"] = _wav(_bell([1200.0, 1810.0], 0.5, 7.0))
	# Chết máy
	var sl := _buf(0.6)
	for i in sl.size():
		var tt := float(i) / RATE
		var f := 30.0 * (1.0 - tt)
		var ph := fmod(tt * f, 1.0)
		sl[i] = (pow(1.0 - ph, 3.0) - 0.25) * 0.6 * (1.0 - tt / 0.6)
	streams["stall"] = _wav(sl)


func _sq(phase: float) -> float:
	return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0


func _saw(phase: float) -> float:
	return fmod(phase, 1.0) * 2.0 - 1.0


func _tick(freq: float, dur: float, amp: float = 0.8) -> PackedFloat32Array:
	var s := _buf(dur)
	for i in s.size():
		var tt := float(i) / RATE
		s[i] = (sin(TAU * freq * tt) * 0.6 + _rng.randf_range(-0.4, 0.4)) * exp(-tt * 140.0) * amp
	return s


func _bell(freqs: Array, dur: float, decay: float) -> PackedFloat32Array:
	var s := _buf(dur)
	for i in s.size():
		var tt := float(i) / RATE
		var v := 0.0
		var k := 1.0
		for f in freqs:
			v += sin(TAU * float(f) * tt) * k
			k *= 0.5
		s[i] = v * 0.35 * exp(-tt * decay) * clampf(tt * 400.0, 0.0, 1.0)
	return s


func _thump(dur: float, f: float) -> PackedFloat32Array:
	var s := _buf(dur)
	for i in s.size():
		var tt := float(i) / RATE
		s[i] = (sin(TAU * f * tt) * 0.7 + _rng.randf_range(-0.3, 0.3)) * exp(-tt * 40.0)
	return s
