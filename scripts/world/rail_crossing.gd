class_name RailCrossing
extends Node3D
## Đường ngang đường sắt có đèn đỏ nhấp nháy, chuông, thanh chắn và đoàn tàu chạy qua.
## `trigger()` bắt đầu một chu kỳ ~10 giây: đèn + chuông → hạ barie → tàu qua → nâng barie.

const T_TRAIN := 3.5
const T_UP := 8.3
const T_END := 9.8
const TRAIN_SPEED := 55.0
const TRAIN_LEN := 46.0

var state: String = "idle"          # idle | active | done
var t: float = 0.0
var hw: float = 3.5
var _arms: Array = []               # [{node, dir}]
var _lamps: Array = []
var _lamp_mats: Array = []
var _train: Node3D
var _bell_t: float = 0.0


func build(p_hw: float) -> void:
	hw = p_hw
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.95, 0.95)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.1, 0.08)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.3, 0.3, 0.32)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.25, 0.2)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.55, 0.55, 0.6)
	steel.metallic = 0.6
	# nền đường ray: tà vẹt + 2 thanh ray chạy theo trục X
	for k in 40:
		_box(wood, Vector3(-hw - 12.0 + k * ((hw * 2.0 + 24.0) / 39.0), 0.02, 0), Vector3(0.35, 0.06, 2.4))
	for zz in [-0.72, 0.72]:
		_box(steel, Vector3(0, 0.1, zz), Vector3(hw * 2.0 + 26.0, 0.1, 0.1))
	# hai bên đường: cột đèn + chữ thập + thanh chắn
	for side in [-1.0, 1.0]:
		var px: float = side * (hw + 0.7)
		var pz: float = side * 1.6
		_box(grey, Vector3(px, 1.6, pz), Vector3(0.14, 3.2, 0.14))
		_box(white, Vector3(px, 2.9, pz), Vector3(0.9, 0.12, 0.05), 0.0, PI * 0.25)
		_box(white, Vector3(px, 2.9, pz), Vector3(0.9, 0.12, 0.05), 0.0, -PI * 0.25)
		for lamp_k in 2:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.25, 0.03, 0.03)
			m.emission_enabled = true
			m.emission = Color(1, 0.05, 0.03)
			m.emission_energy_multiplier = 0.0
			_lamp_mats.append(m)
			var lm := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.15
			sm.height = 0.3
			lm.mesh = sm
			lm.material_override = m
			lm.position = Vector3(px + (lamp_k - 0.5) * 0.5, 2.4, pz)
			add_child(lm)
			_lamps.append(lm)
		# thanh chắn: bản lề ở cột, vươn vào mặt đường
		var pivot := Node3D.new()
		pivot.position = Vector3(px, 1.0, pz)
		pivot.rotation = Vector3(0, 0 if side < 0.0 else PI, 1.4)
		add_child(pivot)
		var segs := 7
		var arm_len: float = hw + 0.7 + 0.1
		for s in segs:
			var seg := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(arm_len / segs, 0.12, 0.08)
			seg.mesh = bm
			seg.material_override = red if s % 2 == 0 else white
			seg.position = Vector3((s + 0.5) * arm_len / segs, 0, 0)
			pivot.add_child(seg)
		_arms.append(pivot)
	# đoàn tàu (đầu tàu + toa), đứng chờ ngoài tầm nhìn
	_train = Node3D.new()
	add_child(_train)
	var tc := [Color(0.15, 0.3, 0.6), Color(0.7, 0.2, 0.15), Color(0.7, 0.2, 0.15), Color(0.7, 0.2, 0.15)]
	for k in 4:
		var m2 := StandardMaterial3D.new()
		m2.albedo_color = tc[k]
		var seg2 := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(TRAIN_LEN / 4.0 - 0.6, 3.4, 2.7)
		seg2.mesh = bm2
		seg2.material_override = m2
		seg2.position = Vector3(k * TRAIN_LEN / 4.0, 2.1, 0)
		_train.add_child(seg2)
	_set_train(false)
	reset()


func _box(mat: Material, pos: Vector3, size: Vector3, yaw: float = 0.0, roll: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = Vector3(0, yaw, roll)
	add_child(mi)


func _set_train(on: bool) -> void:
	_train.visible = on


func reset() -> void:
	state = "idle"
	t = 0.0
	_apply(0.0)


func get_state() -> Array:
	return [state, t]


func set_state(a: Array) -> void:
	state = String(a[0])
	t = float(a[1])
	if state == "active" and t >= T_TRAIN and t < T_UP:
		_set_train(true)
		_train.position = Vector3(-hw - 60.0 + (t - T_TRAIN) * TRAIN_SPEED, 0, 0)
	else:
		_set_train(false)
	_apply(0.0)


func trigger() -> void:
	if state == "idle":
		state = "active"
		t = 0.0


## Còn đèn/barie hoạt động (cấm qua)
func is_closed() -> bool:
	return state == "active"


## Thanh chắn: 0 = nâng đứng, 1 = hạ ngang
func _apply(_dt: float) -> void:
	var down := 0.0
	if state == "active":
		if t < 1.0:
			down = 0.0
		elif t < 2.5:
			down = (t - 1.0) / 1.5
		elif t < T_UP:
			down = 1.0
		else:
			down = 1.0 - clampf((t - T_UP) / 1.5, 0.0, 1.0)
	for a in _arms:
		(a as Node3D).rotation.z = lerpf(1.4, 0.0, down)
	var flash := state == "active"
	for k in _lamp_mats.size():
		var on := flash and (int(t * 2.0) + k) % 2 == 0
		(_lamp_mats[k] as StandardMaterial3D).emission_energy_multiplier = 3.0 if on else 0.0


func _physics_process(delta: float) -> void:
	if state != "active":
		return
	t += delta
	_bell_t += delta
	if _bell_t > 0.5:
		_bell_t = 0.0
		Sfx.play("bell", -9.0)
	if t >= T_TRAIN and t < T_UP:
		_set_train(true)
		var x := -hw - 60.0 + (t - T_TRAIN) * TRAIN_SPEED
		_train.position = Vector3(x, 0, 0)
	else:
		_set_train(false)
	_apply(delta)
	if t >= T_END:
		state = "done"
		_apply(0.0)
