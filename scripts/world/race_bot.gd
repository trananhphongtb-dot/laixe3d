class_name RaceBot
extends AnimatableBody3D
## Xe đối thủ chạy theo đường đua: vào cua chậm lại, giữ khoảng cách, bám đuôi người chơi nhờ "dây chun".

var track: RaceTrack
var s: float = 0.0              # quãng đã đi (mét, tính từ vạch xuất phát)
var speed: float = 0.0
var cruise: float = 12.0
var lane: float = 0.0
var lane_t: float = 0.0
var length: float = 4.4
var active: bool = false
var ref_s: float = 0.0          # quãng người chơi đã đi (RaceMode cập nhật)
var others: Array = []          # các xe khác cần giữ khoảng cách (cả người chơi)
var band: float = 1.0           # độ mạnh của dây chun (0 = tắt)
var _blocked: float = 0.0
var _snd: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()


func setup(p_track: RaceTrack, spec: Dictionary, color: Color, start_s: float, lane_off: float, cruise_ms: float, night: bool, with_sound: bool) -> void:
	track = p_track
	_rng.randomize()
	length = spec["len"]
	cruise = cruise_ms
	s = start_s
	lane = lane_off
	lane_t = lane_off
	sync_to_physics = true
	var r := CarModel.build_simple(spec, color)
	add_child(r["exterior"])
	if night:
		var hm: StandardMaterial3D = r["head_mat"]
		hm.emission_energy_multiplier = 3.0
		var tm: StandardMaterial3D = r["tail_mat"]
		tm.emission_energy_multiplier = 1.2
	var dm: Dictionary = r["dims"]
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(float(dm["W"]), float(dm["H"]) - 0.25, float(dm["L"]))
	cs.shape = bs
	cs.position = Vector3(0, 0.25 + (float(dm["H"]) - 0.25) * 0.5, 0)
	add_child(cs)
	if with_sound:
		_snd = Sfx.make_loop_player_3d("engine_ai")
		add_child(_snd)
		_snd.position.y = 0.6
	_pose()


func _ready() -> void:
	if _snd:
		_snd.volume_db = Sfx.vol_db(-4.0)
		_snd.play(_rng.randf_range(0.0, 0.9))


func _pose() -> void:
	global_transform = track.transform_at(s, lane)


func _physics_process(delta: float) -> void:
	if track == null:
		return
	var target := 0.0
	if active:
		target = cruise
		var k := track.curv_ahead(s, 8.0 + speed * 1.8)
		if k > 0.002:
			target = minf(target, sqrt(RaceTrack.LAT_G / k))
		var d := s - ref_s
		var mult := 1.0 - clampf((d - 30.0) / 300.0, 0.0, 1.0) * 0.16 * band + clampf((-30.0 - d) / 200.0, 0.0, 1.0) * 0.12 * band
		target *= mult
		var fwd := global_transform.basis.z
		var right := Vector3(-fwd.z, 0, fwd.x)
		var blocked := false
		for o in others:
			if o == self or not is_instance_valid(o):
				continue
			var on: Node3D = o
			var rel := on.global_position - global_position
			var ahead := rel.dot(fwd)
			if ahead > 0.0 and ahead < 24.0 and absf(rel.dot(right)) < 2.3:
				var gap := ahead - length - 1.6
				target = minf(target, maxf(gap, 0.0) * 0.9 + 1.0)
				blocked = true
		if blocked:
			_blocked += delta
			if _blocked > 2.0:
				_blocked = 0.0
				lane_t = -2.3 if lane_t > 0.0 else 2.3
		else:
			_blocked = maxf(0.0, _blocked - delta)
	speed = move_toward(speed, target, (2.8 if target > speed else 6.5) * delta)
	lane = move_toward(lane, lane_t, 1.4 * delta)
	s += speed * delta
	_pose()
	if _snd:
		_snd.pitch_scale = 0.7 + speed / 16.0
