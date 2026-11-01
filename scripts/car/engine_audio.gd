extends AudioStreamPlayer
## Tiếng động cơ tổng hợp theo thời gian thực: cao độ theo vòng tua, gầm khi nhấn ga.

const MIX := 16000.0
var rpm: float = 800.0
var throttle: float = 0.0
var running: bool = true

var _phase: float = 0.0
var _sub: float = 0.0
var _lp: float = 0.0
var _hp_prev_in: float = 0.0
var _hp_prev_out: float = 0.0
var _noise: float = 0.0
var _smooth_rpm: float = 800.0
var _smooth_thr: float = 0.0
var _gain: float = 0.0
var _playback: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX
	gen.buffer_length = 0.12
	stream = gen
	play()
	_playback = get_stream_playback()


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var vol: float = Game.settings.get("engine_vol", 0.8)
	volume_db = linear_to_db(max(vol, 0.001)) - 2.0
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	var target_rpm := rpm if running else 0.0
	var target_gain := 1.0 if running else 0.0
	var inv := 1.0 / MIX
	for i in frames:
		_smooth_rpm += (target_rpm - _smooth_rpm) * 0.0015
		_smooth_thr += (throttle - _smooth_thr) * 0.002
		_gain += (target_gain - _gain) * 0.0008
		var f := _smooth_rpm / 60.0 * 2.0  # 4 xi lanh: 2 lần nổ mỗi vòng
		_phase += f * inv
		if _phase >= 1.0:
			_phase -= 1.0
			_sub = _rng.randf_range(0.85, 1.0)
		var pulse := pow(1.0 - _phase, 3.5) * _sub
		_noise += (_rng.randf_range(-1.0, 1.0) - _noise) * 0.3
		var x := pulse * (0.9 + _smooth_thr * 0.5) + _noise * (0.05 + _smooth_thr * 0.18)
		# lọc thông thấp: sáng hơn khi nhấn ga / vòng tua cao
		var cut := 0.06 + _smooth_thr * 0.18 + clampf(_smooth_rpm / 7000.0, 0.0, 1.0) * 0.2
		_lp += (x - _lp) * cut
		# lọc thông cao để bỏ thành phần DC
		var y := _lp - _hp_prev_in + 0.995 * _hp_prev_out
		_hp_prev_in = _lp
		_hp_prev_out = y
		var amp := (0.55 + _smooth_thr * 0.45) * _gain
		var s := clampf(y * 1.6 * amp, -1.0, 1.0)
		_playback.push_frame(Vector2(s, s))
