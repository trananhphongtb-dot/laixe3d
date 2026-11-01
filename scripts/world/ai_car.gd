class_name AiCar
extends AnimatableBody3D
## Xe AI chạy theo làn, dừng đèn đỏ, giữ khoảng cách với xe phía trước.

var city: City
var from_n: Vector2i
var d1: Vector3
var to_n: Vector2i
var d2: Vector3
var pts := PackedVector3Array()
var cum := PackedFloat32Array()
var dist: float = 0.0
var straight_len: float = 0.0
var speed: float = 0.0
var cruise: float = 10.0
var turning: bool = false
var length: float = 4.4
var _stuck: float = 0.0
var _ghost: float = 0.0
var _snd: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()


func setup(p_city: City, spec: Dictionary, color: Color, n: Vector2i, d: Vector3, start_frac: float) -> void:
	city = p_city
	_rng.randomize()
	cruise = _rng.randf_range(8.5, 12.0)
	length = spec["len"]
	sync_to_physics = true
	var r := CarModel.build_simple(spec, color)
	add_child(r["exterior"])
	if city.night:
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
	if city.ai_cars.size() < 6:
		_snd = Sfx.make_loop_player_3d("engine_ai")
		add_child(_snd)
		_snd.position.y = 0.6
	_new_leg(n, d)
	dist = straight_len * start_frac
	speed = cruise * 0.5
	_apply_pose()


func _ready() -> void:
	if _snd:
		_snd.volume_db = Sfx.vol_db(-6.0)
		_snd.play(_rng.randf_range(0.0, 0.9))


func _new_leg(n: Vector2i, d: Vector3) -> void:
	from_n = n
	d1 = d
	to_n = n + Vector2i(int(d.x), int(d.z))
	# chọn hướng tiếp theo tại nút tới
	var opts: Array = []
	for nd: Vector3 in City.DIRS:
		var v: Vector3 = nd
		if v.dot(d) < -0.5:
			continue
		var nb := to_n + Vector2i(int(v.x), int(v.z))
		if city.node_ok(nb.x, nb.y):
			opts.append(v)
	if opts.is_empty():
		opts.append(-d)
	# ưu tiên đi thẳng một chút
	d2 = opts[_rng.randi_range(0, opts.size() - 1)]
	for v in opts:
		var vv: Vector3 = v
		if vv.dot(d) > 0.5 and _rng.randf() < 0.35:
			d2 = vv
	turning = d2.dot(d1) < 0.5
	pts = PackedVector3Array()
	var p0 := city.lane_point(n, d, City.STOP_D)
	var p1 := city.lane_point(n, d, City.B - City.STOP_D)
	pts.append(p0)
	pts.append(p1)
	var tn := city.node_pos(to_n.x, to_n.y)
	var p2 := tn + d2 * City.STOP_D + City.right_of(d2) * City.LANE
	var ctrl := tn + City.right_of(d1) * City.LANE + City.right_of(d2) * City.LANE
	if not turning:
		ctrl = (p1 + p2) * 0.5
	if d2.dot(d1) < -0.5:
		ctrl = tn + d1 * 4.0
	for k in range(1, 9):
		var t := k / 8.0
		var a := p1.lerp(ctrl, t)
		var b := ctrl.lerp(p2, t)
		pts.append(a.lerp(b, t))
	cum = PackedFloat32Array()
	cum.append(0.0)
	for k in range(1, pts.size()):
		cum.append(cum[k - 1] + pts[k].distance_to(pts[k - 1]))
	straight_len = cum[1]
	dist = 0.0


func _sample(s: float) -> Array:
	var n := cum.size()
	for k in range(1, n):
		if s <= cum[k] or k == n - 1:
			var seg := cum[k] - cum[k - 1]
			var t := 0.0 if seg < 0.001 else clampf((s - cum[k - 1]) / seg, 0.0, 1.0)
			var p := pts[k - 1].lerp(pts[k], t)
			var dir := (pts[k] - pts[k - 1]).normalized()
			return [p, dir]
	return [pts[n - 1], d1]


func _apply_pose() -> void:
	var r := _sample(dist)
	var p: Vector3 = r[0]
	var dir: Vector3 = r[1]
	var yaw := atan2(dir.x, dir.z)
	global_transform = Transform3D(Basis(Vector3.UP, yaw), p)


func _physics_process(delta: float) -> void:
	if city == null or pts.size() < 2:
		return
	var target := cruise
	var to_stop := straight_len - dist
	if turning and to_stop < 18.0:
		target = minf(target, 5.0 + maxf(to_stop, 0.0) * 0.3)
	if dist > straight_len:
		target = minf(target, 5.5 if turning else cruise)
	# đèn tín hiệu
	if to_stop > -0.5:
		var st := city.light_for(to_n, d1)
		if st == "R" or (st == "Y" and to_stop > 5.0):
			target = minf(target, sqrt(maxf(to_stop - 0.8, 0.0) * 6.0))
	var light_hold := target < 0.5
	# xe phía trước
	var fwd := global_transform.basis.z
	var right := City.right_of(fwd)
	var others: Array = city.ai_cars.duplicate()
	if city.player:
		others.append(city.player)
	others.append_array(city.obstacles)
	for o in others:
		if o == self:
			continue
		if _ghost > 0.0 and o is AiCar:
			continue
		var on: Node3D = o
		var rel := on.global_position - global_position
		var ahead := rel.dot(fwd)
		if ahead > 0.0 and ahead < 26.0 and absf(rel.dot(right)) < 2.2:
			var gap := ahead - length - 1.8
			target = minf(target, maxf(gap, 0.0) * 0.8)
	# tránh kẹt cứng giữa các xe AI
	_ghost = maxf(0.0, _ghost - delta)
	if target < 0.1 and not light_hold:
		_stuck += delta
		if _stuck > 5.0:
			_stuck = 0.0
			_ghost = 2.5
	else:
		_stuck = 0.0
	var acc := 3.0 if target > speed else 7.0
	speed = move_toward(speed, target, acc * delta)
	if speed < 0.05 and target < 0.05:
		speed = 0.0
	dist += speed * delta
	if dist >= cum[cum.size() - 1]:
		_new_leg(to_n, d2)
	_apply_pose()
	if _snd:
		_snd.pitch_scale = 0.7 + speed / 14.0
