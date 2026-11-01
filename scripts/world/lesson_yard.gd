class_name LessonYard
extends Node3D
## Bãi tập cho các bài học lái: 1 dừng xe, 2 rẽ, 3 quay đầu, 4 lùi chuồng.

var lesson: int = 1
var batch := MeshBatch.new()
var spawn_xf: Transform3D
var geo: Dictionary = {}


func _init(id: int = 1) -> void:
	lesson = id


func _ready() -> void:
	MeshBatch.mat("asph", Color(0.2, 0.21, 0.23), 0.85)
	MeshBatch.mat("line", Color(0.95, 0.95, 0.95), 0.6)
	MeshBatch.mat("yline", Color(0.98, 0.8, 0.1), 0.6)
	MeshBatch.mat("guide", Color(0.2, 0.75, 1.0), 0.5, 0.8)
	MeshBatch.mat("curb", Color(0.78, 0.77, 0.73), 0.9)
	MeshBatch.mat("curb_r", Color(0.8, 0.15, 0.12), 0.8)
	MeshBatch.mat("trunk", Color(0.36, 0.25, 0.16), 0.9)
	MeshBatch.mat("leaf", Color(0.2, 0.45, 0.18), 0.9)
	MeshBatch.mat("wall", Color(0.85, 0.83, 0.78), 0.9)
	EnvBuilder.ground(self, Vector2(300, 300), Vector3(0, 0, 40), Color(0.36, 0.52, 0.27))
	match lesson:
		1:
			_build_stop()
		2:
			_build_turn()
		3:
			_build_uturn()
		4:
			_build_garage()
	_trees()
	batch.commit(self)


func _yaw_xf(pos: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), pos + Vector3(0, 0.15, 0))


func _lane_lines(x0: float, x1: float, z0: float, z1: float) -> void:
	batch.strip("asph", Vector3((x0 + x1) * 0.5, 0, z0), Vector3((x0 + x1) * 0.5, 0, z1), x1 - x0 + 1.0, -0.005, 0.03)
	batch.strip("line", Vector3(x0, 0, z0), Vector3(x0, 0, z1), 0.18, 0.012, 0.02)
	batch.strip("line", Vector3(x1, 0, z0), Vector3(x1, 0, z1), 0.18, 0.012, 0.02)


## Mũi tên vẽ trên mặt đường. dir: hướng mũi tên trên mặt phẳng.
func _arrow(p: Vector3, dir: Vector3, length: float = 3.0, key: String = "guide") -> void:
	dir = dir.normalized()
	var tip := p + dir * length * 0.5
	batch.strip(key, p - dir * length * 0.5, tip - dir * 0.3, 0.35, 0.016, 0.02)
	var l := dir.rotated(Vector3.UP, PI * 0.5)
	batch.strip(key, tip, tip - dir * 1.0 + l * 0.7, 0.3, 0.016, 0.02)
	batch.strip(key, tip, tip - dir * 1.0 - l * 0.7, 0.3, 0.016, 0.02)


## Mũi tên rẽ cong: điểm đầu a, hướng đầu d0, rẽ sang `sgn` (+1 trái, -1 phải), bán kính r.
func _curve_arrow(a: Vector3, d0: Vector3, sgn: float, r: float) -> void:
	var l := d0.rotated(Vector3.UP, PI * 0.5)
	var c := a + l * r * sgn
	var prev := a
	for i in range(1, 9):
		var t := PI * 0.5 * sgn * i / 8.0
		var p := c + (a - c).rotated(Vector3.UP, t)
		if i < 8:
			batch.strip("guide", prev, p, 0.3, 0.016, 0.02)
		else:
			_arrow((prev + p) * 0.5, p - prev, 1.6)
		prev = p


func _label(text: String, p: Vector3, yaw: float, size: int = 64, col: Color = Color(1, 0.85, 0.2)) -> void:
	var lb := Label3D.new()
	lb.text = text
	lb.font_size = size
	lb.pixel_size = 0.012
	lb.modulate = col
	lb.position = p + Vector3(0, 0.03, 0)
	lb.rotation = Vector3(-PI * 0.5, yaw, 0)
	add_child(lb)


func _trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 24:
		var a := rng.randf() * TAU
		var r := rng.randf_range(70.0, 120.0)
		var p := Vector3(cos(a) * r, 0, 40 + sin(a) * r)
		batch.cyl("trunk", p + Vector3(0, 1, 0), 0.15, 2.0)
		batch.sphere("leaf", p + Vector3(0, 2.8, 0), Vector3(2.4, 2.2, 2.4))


# ---------------------------------------------------------------- 1. dừng xe
func _build_stop() -> void:
	_lane_lines(-2.0, 2.0, -6.0, 75.0)
	var line_z := 50.0
	batch.strip("line", Vector3(-2, 0, line_z + 0.15), Vector3(2, 0, line_z + 0.15), 0.3, 0.014, 0.02)
	_label("STOP", Vector3(0, 0, line_z + 3.0), PI, 96, Color.WHITE)
	# vạch báo giảm tốc
	for z in [line_z - 15.0, line_z - 10.0, line_z - 6.0, line_z - 3.0]:
		batch.strip("yline", Vector3(-1.6, 0, z), Vector3(1.6, 0, z), 0.12, 0.014, 0.02)
	_arrow(Vector3(0, 0, 14), Vector3(0, 0, 1))
	spawn_xf = _yaw_xf(Vector3(0, 0, 0), 0.0)
	geo = {"line_z": line_z}


# ---------------------------------------------------------------- 2. rẽ
func _build_turn() -> void:
	var cz := 60.0
	var hw := 3.5
	# đường chính (dọc) hai làn
	batch.strip("asph", Vector3(0, 0, -10), Vector3(0, 0, cz + 40), hw * 2 + 1.0, -0.005, 0.03)
	# đường ngang
	batch.strip("asph", Vector3(-60, 0, cz), Vector3(60, 0, cz), hw * 2 + 1.0, -0.004, 0.03)
	# mép đường
	for sx in [-1.0, 1.0]:
		batch.strip("line", Vector3(sx * hw, 0, -10), Vector3(sx * hw, 0, cz - hw), 0.18, 0.012, 0.02)
		batch.strip("line", Vector3(sx * hw, 0, cz + hw), Vector3(sx * hw, 0, cz + 40), 0.18, 0.012, 0.02)
		batch.strip("line", Vector3(-60, 0, cz + sx * hw), Vector3(-hw, 0, cz + sx * hw), 0.18, 0.012, 0.02)
		batch.strip("line", Vector3(hw, 0, cz + sx * hw), Vector3(60, 0, cz + sx * hw), 0.18, 0.012, 0.02)
	# tim đường đứt đoạn
	var z := -10.0
	while z < cz - 8:
		batch.strip("line", Vector3(0, 0, z), Vector3(0, 0, z + 3), 0.15, 0.012, 0.02)
		z += 7.0
	var x := 8.0
	while x < 60:
		batch.strip("line", Vector3(x, 0, cz), Vector3(x + 3, 0, cz), 0.15, 0.012, 0.02)
		batch.strip("line", Vector3(-x, 0, cz), Vector3(-x - 3, 0, cz), 0.15, 0.012, 0.02)
		x += 7.0
	# vạch dừng làn phải
	var stop_z := cz - hw - 2.0
	batch.strip("line", Vector3(0, 0, stop_z), Vector3(-hw, 0, stop_z), 0.4, 0.014, 0.02)
	geo = {"cz": cz, "hw": hw, "stop_z": stop_z, "lane": -hw * 0.5}
	spawn_xf = _yaw_xf(Vector3(-hw * 0.5, 0, 0), 0.0)
	# mũi tên hướng rẽ phải và rẽ trái
	_arrow(Vector3(-hw * 0.5, 0, stop_z - 8), Vector3(0, 0, 1))
	_curve_arrow(Vector3(-hw * 0.5, 0, stop_z + 0.5), Vector3(0, 0, 1), -1.0, 3.5)
	_curve_arrow(Vector3(-hw * 0.5, 0, stop_z + 0.5), Vector3(0, 0, 1), 1.0, 5.25 + 0.5)


# ---------------------------------------------------------------- 3. quay đầu 3 điểm
func _build_uturn() -> void:
	var hw := 3.3
	batch.strip("asph", Vector3(0, 0, -10), Vector3(0, 0, 90), hw * 2, -0.005, 0.03)
	var sb := StaticBody3D.new()
	add_child(sb)
	for sx in [-1.0, 1.0]:
		var cx: float = sx * (hw + 0.15)
		var z := -10.0
		var k := 0
		while z < 90.0:
			batch.box("curb" if k % 2 == 0 else "curb_r", Vector3(cx, 0.08, z + 1.0), Vector3(0.3, 0.16, 2.0))
			z += 2.0
			k += 1
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.3, 0.16, 100.0)
		cs.shape = bs
		cs.position = Vector3(cx, 0.08, 40.0)
		sb.add_child(cs)
		# tường nhà hai bên
		batch.box("wall", Vector3(sx * (hw + 4.0), 2.5, 40.0), Vector3(4.0, 5.0, 100.0))
	var z2 := -10.0
	while z2 < 90.0:
		batch.strip("line", Vector3(0, 0, z2), Vector3(0, 0, z2 + 3), 0.15, 0.012, 0.02)
		z2 += 7.0
	geo = {"hw": hw}
	spawn_xf = _yaw_xf(Vector3(-hw + 1.4, 0, 10), 0.0)
	_arrow(Vector3(-hw + 1.4, 0, 18), Vector3(0, 0, 1))


# ---------------------------------------------------------------- 4. lùi chuồng
func _build_garage() -> void:
	var hw := 3.5
	_lane_lines(-hw, hw, -6.0, 70.0)
	var bay_z := 30.0
	var bay_w := 2.8
	var bay_d := 5.6
	# mở mép phải tại ô đỗ: vẽ lại mép phải thành 2 đoạn
	batch.strip("asph", Vector3(-hw - bay_d * 0.5, 0, bay_z - bay_w * 0.5 - 0.8), Vector3(-hw - bay_d * 0.5, 0, bay_z + bay_w * 0.5 + 0.8), bay_d + 1.6, -0.004, 0.03)
	batch.strip("asph", Vector3(-hw, 0, bay_z - bay_w * 0.5), Vector3(-hw, 0, bay_z + bay_w * 0.5), 0.3, 0.02, 0.02)
	var back := -hw - bay_d
	for s in [-1.0, 1.0]:
		var ez: float = bay_z + s * (bay_w * 0.5 + 0.1)
		batch.strip("yline", Vector3(-hw, 0, ez), Vector3(back, 0, ez), 0.2, 0.014, 0.02)
	batch.strip("yline", Vector3(back - 0.1, 0, bay_z - bay_w * 0.5), Vector3(back - 0.1, 0, bay_z + bay_w * 0.5), 0.2, 0.014, 0.02)
	# vạch MỐC: dừng khi ghế lái ngang vạch này
	var mark_z := 35.5
	batch.strip("guide", Vector3(-hw, 0, mark_z), Vector3(-hw + 1.6, 0, mark_z), 0.3, 0.016, 0.02)
	batch.box("yline", Vector3(-hw - 0.6, 0.5, mark_z), Vector3(0.12, 1.0, 0.12))
	_label("MỐC", Vector3(-hw + 0.9, 0, mark_z + 1.2), PI, 64)
	# mũi tên lùi vào ô
	_arrow(Vector3(-hw - 2.2, 0, bay_z), Vector3(-1, 0, 0), 2.6)
	_arrow(Vector3(-1.0, 0, 12), Vector3(0, 0, 1))
	geo = {"hw": hw, "bay": [Vector2(-hw - bay_d * 0.5, bay_z), Vector2(1, 0), bay_d * 0.5, bay_w * 0.5],
		"bay_z": bay_z, "mark_z": mark_z, "back": back}
	spawn_xf = _yaw_xf(Vector3(-1.0, 0, 2), 0.0)
