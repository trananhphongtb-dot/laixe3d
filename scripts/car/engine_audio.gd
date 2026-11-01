extends AudioStreamPlayer
## Tiếng động cơ tổng hợp: tiếng ù trầm, êm như nghe từ trong cabin đóng kín.
## Dùng bảng sóng (một chu kỳ) dựng từ các họa âm của tần số nổ, tập trung ở dải
## 120–450 Hz để loa điện thoại phát rõ mà không chói. Ga càng nhiều thì càng nhiều họa âm cao.

const MIX := 16000.0
const TABLE := 256
var rpm: float = 800.0
var throttle: float = 0.0
var running: bool = true

var _phase: float = 0.0
var _table := PackedFloat32Array()
var _next := PackedFloat32Array()
var _xfade: float = 1.0
var _built_rpm: float = -1.0
var _built_thr: float = -1.0
var _smooth_rpm: float = 800.0
var _smooth_thr: float = 0.0
var _gain: float = 0.0
var _wob: float = 0.0
var _wob_t: float = 1.0
var _lp: float = 0.0
var _noise: float = 0.0
var _playback: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX
	gen.buffer_length = 0.12
	stream = gen
	_table.resize(TABLE)
	_next.resize(TABLE)
	_build(_next, 800.0, 0.0)
	_table = _next.duplicate()
	play()
	_playback = get_stream_playback()


## Dựng một chu kỳ sóng: họa âm k của tần số nổ f, trọng số theo dải tần nghe êm
func _build(t: PackedFloat32Array, r: float, thr: float) -> void:
	var f := maxf(r, 300.0) / 60.0 * 2.0
	var center := 170.0 + thr * 180.0 + r * 0.02
	var bw := 140.0 + thr * 120.0
	var w: Array = []
	var total := 0.0
	for k in range(1, 25):
		var fk := f * k
		if fk > 1400.0:
			break
		var x := (fk - center) / bw
		var a := exp(-x * x) / sqrt(float(k))
		if fk < 90.0:
			a *= 0.2   # dưới 90 Hz loa điện thoại không phát được, bỏ bớt cho tiếng rõ
		w.append(a)
		total += a
	for i in TABLE:
		var p := float(i) / TABLE
		var v := 0.0
		for k in w.size():
			v += float(w[k]) * sin(TAU * (k + 1) * p + k * 0.7)
		t[i] = v / maxf(total, 0.001)


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var vol: float = Game.settings.get("engine_vol", 0.8)
	volume_db = linear_to_db(max(vol, 0.001)) - 6.0
	var target_rpm := rpm if running else 0.0
	# dựng lại bảng sóng khi vòng tua / ga đổi đủ nhiều, chuyển dần sang bảng mới
	if _xfade >= 1.0 and (absf(_smooth_rpm - _built_rpm) > _built_rpm * 0.04 + 20.0 or absf(_smooth_thr - _built_thr) > 0.06):
		_table = _mix_tables()
		_build(_next, _smooth_rpm, _smooth_thr)
		_built_rpm = _smooth_rpm
		_built_thr = _smooth_thr
		_xfade = 0.0
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	var inv := 1.0 / MIX
	var target_gain := 1.0 if running else 0.0
	for i in frames:
		_smooth_rpm += (target_rpm - _smooth_rpm) * 0.0012
		_smooth_thr += (throttle - _smooth_thr) * 0.0015
		_gain += (target_gain - _gain) * 0.0006
		_xfade = minf(_xfade + inv * 12.0, 1.0)
		var f := maxf(_smooth_rpm, 1.0) / 60.0 * 2.0
		_phase += f * inv
		if _phase >= 1.0:
			_phase -= 1.0
			# mỗi lần nổ hơi khác nhau một chút cho tự nhiên
			_wob_t = _rng.randf_range(0.9, 1.0)
		_wob += (_wob_t - _wob) * 0.01
		var fi := _phase * TABLE
		var i0 := int(fi) % TABLE
		var i1 := (i0 + 1) % TABLE
		var fr := fi - floorf(fi)
		var a := lerpf(_table[i0], _table[i1], fr)
		var b := lerpf(_next[i0], _next[i1], fr)
		var x := lerpf(a, b, _xfade) * _wob
		_noise += (_rng.randf_range(-1.0, 1.0) - _noise) * 0.08
		x += _noise * (0.04 + _smooth_thr * 0.08)
		_lp += (x - _lp) * (0.35 + _smooth_thr * 0.3)
		var amp := (0.45 + _smooth_thr * 0.4) * _gain
		var s := _lp * amp * 1.5
		s = s / (1.0 + absf(s))   # nén mềm, không vỡ tiếng
		_playback.push_frame(Vector2(s, s))


func _mix_tables() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(TABLE)
	for i in TABLE:
		out[i] = lerpf(_table[i], _next[i], _xfade)
	return out
