class_name LessonYard
extends Node3D
## Bãi tập: mỗi bài là một con đường dài, tình huống của bài lặp lại liên tiếp phía trước.
## 1 dừng xe · 2 rẽ phải/trái · 3 quay đầu 3 điểm · 4 lùi chuồng · 5 đề-pa lên cầu

const HW := 3.5          # nửa bề rộng đường 2 làn
const LANE_X := -1.75    # tâm làn bên phải khi đi theo +Z (trục X dương = bên trái)

var lesson: int = 1
var batch := MeshBatch.new()
var spawn_xf: Transform3D
var geo: Dictionary = {}
var instances: Array = []     # các tình huống lặp lại (vạch dừng, ngã tư, ô đỗ, cầu)
var _sb: StaticBody3D


func _init(id: int = 1) -> void:
	lesson = id


func _ready() -> void:
	MeshBatch.mat("asph", Color(0.2, 0.21, 0.23), 0.85)
	MeshBatch.mat("line", Color(0.95, 0.95, 0.95), 0.6)
	MeshBatch.mat("yline", Color(0.98, 0.8, 0.1), 0.6)
	MeshBatch.mat("guide", Color(0.2, 0.75, 1.0), 0.5, 0.8)
	MeshBatch.mat("curb", Color(0.78, 0.77, 0.73), 0.9)
	MeshBatch.mat("curb_r", Color(0.8, 0.15, 0.12), 0.8)
	MeshBatch.mat("wall", Color(0.85, 0.83, 0.78), 0.9)
	MeshBatch.mat("rail", Color(0.85, 0.85, 0.82), 0.6)
	_sb = StaticBody3D.new()
	add_child(_sb)
	var area := Rect2()
	match lesson:
		1:
			area = _build_stop()
		2:
			area = _build_turn()
		3:
			area = _build_uturn()
		4:
			area = _build_garage()
		5:
			area = _build_hill()
	Scenery.texturize("asph", 0.35, 0.3, 0.25)
	batch.commit(self)
	var c := Vector3(area.get_center().x, 0, area.get_center().y)
	EnvBuilder.ground(self, area.size + Vector2(60, 60), c, Color(0.3, 0.44, 0.22))
	Scenery.surround(self, c, area.grow(30), maxf(area.size.x, area.size.y) * 0.5 + 220.0, false, false, 40 + lesson)


func _yaw_xf(pos: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), pos + Vector3(0, 0.15, 0))


## Đường 2 làn thẳng từ a tới c (vạch mép + tim đường đứt)
func _road(a: Vector3, c: Vector3, hw: float = HW, center_line: bool = true) -> void:
	var d := (c - a)
	var l := d.length()
	var dn := d / l
	var r := dn.rotated(Vector3.UP, -PI * 0.5)
	batch.strip("asph", a, c, hw * 2.0 + 1.0, -0.005, 0.03)
	for sx: float in [-1.0, 1.0]:
		batch.strip("line", a + r * hw * sx, c + r * hw * sx, 0.18, 0.012, 0.02)
	if center_line:
		var u := 0.0
		while u < l - 1.0:
			batch.strip("line", a + dn * u, a + dn * minf(u + 3.0, l), 0.14, 0.012, 0.02)
			u += 8.0


## Bãi quay đầu tròn ở hai đầu đường (đường thông, đi quá có thể quay lại)
func _turnaround(c: Vector3) -> void:
	var seg := 24
	for k in seg:
		var a := TAU * k / seg
		batch.box("asph", c + Vector3(cos(a) * 7.0, -0.006, sin(a) * 7.0), Vector3(7.5, 0.03, 7.5), a)
	batch.box("asph", c + Vector3(0, -0.007, 0), Vector3(15, 0.03, 15))


func _arrow(p: Vector3, dir: Vector3, length: float = 3.0, key: String = "guide") -> void:
	dir = dir.normalized()
	var tip := p + dir * length * 0.5
	batch.strip(key, p - dir * length * 0.5, tip - dir * 0.3, 0.35, 0.016, 0.02)
	var l := dir.rotated(Vector3.UP, PI * 0.5)
	batch.strip(key, tip, tip - dir * 1.0 + l * 0.7, 0.3, 0.016, 0.02)
	batch.strip(key, tip, tip - dir * 1.0 - l * 0.7, 0.3, 0.016, 0.02)


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


func _collider(basis: Basis, pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = Transform3D(basis, pos)
	_sb.add_child(cs)


# ------------------------------------------------------------------ 1. dừng xe: vạch STOP lặp lại
func _build_stop() -> Rect2:
	var z_end := 1240.0
	_road(Vector3(0, 0, -20), Vector3(0, 0, z_end))
	_turnaround(Vector3(0, 0, -26))
	_turnaround(Vector3(0, 0, z_end + 6))
	var z := 110.0
	while z < z_end - 40:
		batch.strip("line", Vector3(0, 0, z + 0.15), Vector3(-HW, 0, z + 0.15), 0.35, 0.014, 0.02)
		_label("STOP", Vector3(LANE_X, 0, z + 3.2), PI, 80, Color.WHITE)
		for w in [15.0, 10.0, 6.0, 3.0]:
			batch.strip("yline", Vector3(-0.3, 0, z - w), Vector3(-HW + 0.3, 0, z - w), 0.14, 0.014, 0.02)
		_arrow(Vector3(LANE_X, 0, z - 30), Vector3(0, 0, 1))
		instances.append({"line_z": z})
		z += 120.0
	spawn_xf = _yaw_xf(Vector3(LANE_X, 0, 0), 0.0)
	return Rect2(-30, -50, 60, z_end + 80)


# ------------------------------------------------------------------ 2. rẽ: đường bậc thang, ngã tư rẽ phải/trái xen kẽ
func _build_turn() -> Rect2:
	var d := Vector3(0, 0, 1)
	var p := Vector3(0, 0, -20)
	var minx := 0.0
	var maxx := 0.0
	var minz := -20.0
	var maxz := 0.0
	var seg := 95.0
	var turn := -1.0     # -1 rẽ phải, +1 rẽ trái
	_turnaround(p - d * 6.0)
	for k in 10:
		var c := p + d * seg
		var dout := d.rotated(Vector3.UP, PI * 0.5 * turn)
		# đoạn đường tới ngã tư (dừng trước mép ngã tư)
		_road(p + d * (HW + 1.0 if k > 0 else 0.0), c - d * (HW + 1.0))
		# mặt ngã tư + 2 nhánh cụt hai bên để giống ngã tư thật
		batch.box("asph", c + Vector3(0, -0.006, 0), Vector3(HW * 2 + 2, 0.03, HW * 2 + 2))
		var side := d.rotated(Vector3.UP, PI * 0.5)
		var stub := -dout if absf(dout.dot(side)) > 0.5 else side
		_road(c + stub * (HW + 1.0), c + stub * 22.0)
		_road(c + d * (HW + 1.0), c + d * 18.0)
		# vạch dừng làn phải
		var r := d.rotated(Vector3.UP, -PI * 0.5)
		var stop_c := c - d * (HW + 2.0)
		batch.strip("line", stop_c, stop_c + r * HW, 0.4, 0.014, 0.02)
		# mũi tên chỉ hướng rẽ trên làn
		_arrow(c - d * 30.0 + r * 1.75, d)
		var rad := 1.75 + HW if turn > 0 else HW - 1.75
		_curve_arrow(c - d * (HW + 1.0) + r * 1.75, d, turn, rad if turn > 0 else 2.5)
		instances.append({"c": c, "d_in": d, "d_out": dout, "turn": turn})
		for q in [c + stub * 22.0, c + d * 18.0]:
			minx = minf(minx, q.x)
			maxx = maxf(maxx, q.x)
			minz = minf(minz, q.z)
			maxz = maxf(maxz, q.z)
		p = c
		d = dout
		turn = -turn
	_road(p + d * (HW + 1.0), p + d * 60.0)
	_turnaround(p + d * 66.0)
	var e := p + d * 66.0
	minx = minf(minx, e.x)
	maxx = maxf(maxx, e.x)
	maxz = maxf(maxz, e.z)
	spawn_xf = _yaw_xf(Vector3(LANE_X, 0, 0), 0.0)
	return Rect2(minx - 30, minz - 30, maxx - minx + 60, maxz - minz + 60)


# ------------------------------------------------------------------ 3. quay đầu 3 điểm: đường hẹp có lề dài
func _build_uturn() -> Rect2:
	var hw := 3.3
	var z0 := -150.0
	var z1 := 400.0
	batch.strip("asph", Vector3(0, 0, z0), Vector3(0, 0, z1), hw * 2, -0.005, 0.03)
	for sx: float in [-1.0, 1.0]:
		var cx := sx * (hw + 0.15)
		var z := z0
		var k := 0
		while z < z1:
			batch.box("curb" if k % 2 == 0 else "curb_r", Vector3(cx, 0.08, z + 1.0), Vector3(0.3, 0.16, 2.0))
			z += 2.0
			k += 1
		_collider(Basis(), Vector3(cx, 0.08, (z0 + z1) * 0.5), Vector3(0.3, 0.16, z1 - z0))
		batch.box("wall", Vector3(sx * (hw + 4.0), 2.5, (z0 + z1) * 0.5), Vector3(4.0, 5.0, z1 - z0))
	var z2 := z0
	while z2 < z1:
		batch.strip("line", Vector3(0, 0, z2), Vector3(0, 0, z2 + 3), 0.15, 0.012, 0.02)
		z2 += 7.0
	for zz in [z0, z1]:
		batch.box("wall", Vector3(0, 1.0, zz), Vector3(hw * 2, 2.0, 0.4))
		_collider(Basis(), Vector3(0, 1.0, zz), Vector3(hw * 2, 2.0, 0.4))
	geo = {"hw": hw}
	spawn_xf = _yaw_xf(Vector3(-hw + 1.4, 0, 10), 0.0)
	_arrow(Vector3(-hw + 1.4, 0, 18), Vector3(0, 0, 1))
	return Rect2(-30, z0 - 20, 60, z1 - z0 + 40)


# ------------------------------------------------------------------ 4. lùi chuồng: ô đỗ bên phải lặp lại
func _build_garage() -> Rect2:
	var z_end := 1000.0
	_road(Vector3(0, 0, -20), Vector3(0, 0, z_end))
	_turnaround(Vector3(0, 0, -26))
	_turnaround(Vector3(0, 0, z_end + 6))
	var bay_w := 2.8
	var bay_d := 5.6
	var z := 70.0
	while z < z_end - 40:
		var back := -HW - bay_d
		batch.strip("asph", Vector3(-HW - bay_d * 0.5, 0, z - bay_w * 0.5 - 0.8), Vector3(-HW - bay_d * 0.5, 0, z + bay_w * 0.5 + 0.8), bay_d + 1.6, -0.004, 0.03)
		batch.strip("asph", Vector3(-HW, 0, z - bay_w * 0.5), Vector3(-HW, 0, z + bay_w * 0.5), 0.3, 0.02, 0.02)
		for s: float in [-1.0, 1.0]:
			var ez: float = z + s * (bay_w * 0.5 + 0.1)
			batch.strip("yline", Vector3(-HW, 0, ez), Vector3(back, 0, ez), 0.2, 0.014, 0.02)
		batch.strip("yline", Vector3(back - 0.1, 0, z - bay_w * 0.5), Vector3(back - 0.1, 0, z + bay_w * 0.5), 0.2, 0.014, 0.02)
		var mark_z := z + 5.5
		batch.strip("guide", Vector3(-HW, 0, mark_z), Vector3(-HW + 1.6, 0, mark_z), 0.3, 0.016, 0.02)
		batch.box("yline", Vector3(-HW - 0.6, 0.5, mark_z), Vector3(0.12, 1.0, 0.12))
		_label("MỐC" if Game.lang == "vi" else "MARK", Vector3(-HW + 0.9, 0, mark_z + 1.2), PI, 64)
		_arrow(Vector3(-HW - 2.2, 0, z), Vector3(-1, 0, 0), 2.6)
		instances.append({"bay": [Vector2(-HW - bay_d * 0.5, z), Vector2(1, 0), bay_d * 0.5, bay_w * 0.5], "bay_z": z, "mark_z": mark_z})
		z += 45.0
	spawn_xf = _yaw_xf(Vector3(-1.0, 0, 2), 0.0)
	return Rect2(-30, -50, 60, z_end + 80)


# ------------------------------------------------------------------ 5. đề-pa lên cầu: cầu vồng lặp lại
func _build_hill() -> Rect2:
	var z_end := 1300.0
	var hw := 2.6
	var ramp := 12.0
	var topl := 7.0
	var h := 1.6
	var z := -20.0
	_turnaround(Vector3(0, 0, -26))
	var bz := 90.0
	var width := hw * 2.0 + 1.0
	while bz < z_end - 60:
		_road(Vector3(0, 0, z), Vector3(0, 0, bz), hw)
		var a := Vector3(0, 0, bz)
		var thick := 0.6
		for part in [[0.0, 1.0], [ramp + topl, -1.0]]:
			var u0: float = part[0]
			var s: float = part[1]
			var zaxis := (Vector3(0, 0, ramp) + Vector3.UP * h * s).normalized()
			var yaxis := zaxis.cross(Vector3(1, 0, 0)).normalized()
			if yaxis.y < 0:
				yaxis = -yaxis
			var basis := Basis(zaxis.cross(yaxis).normalized() * -1.0, yaxis, zaxis)
			basis = Basis(Vector3(1, 0, 0), yaxis, zaxis)
			var slope_len := sqrt(ramp * ramp + h * h)
			var surf_mid := a + Vector3(0, h * 0.5, u0 + ramp * 0.5)
			var center := surf_mid - yaxis * thick * 0.5
			batch.box_basis("asph", basis, center, Vector3(width, thick, slope_len + 0.1))
			_collider(basis, center, Vector3(width + 1.0, thick, slope_len + 0.1))
			for sx: float in [-1.0, 1.0]:
				batch.box_basis("line", basis, surf_mid + yaxis * 0.012 + Vector3(sx * hw, 0, 0), Vector3(0.18, 0.02, slope_len))
				batch.box_basis("rail", basis, surf_mid + yaxis * 0.6 + Vector3(sx * (hw + 0.45), 0, 0), Vector3(0.15, 1.0, slope_len))
			if s > 0:
				# vạch dừng trên dốc: 8 m tính từ chân dốc
				var uu := 8.0
				var lp := a + Vector3(0, h * uu / ramp, uu + 0.15) + yaxis * 0.015
				batch.box_basis("line", basis, lp + Vector3(-hw * 0.5, 0, 0), Vector3(hw, 0.02, 0.3))
		var top_c := a + Vector3(0, h - thick * 0.5, ramp + topl * 0.5)
		batch.box("asph", top_c, Vector3(width, thick, topl + 0.2))
		_collider(Basis(), top_c, Vector3(width + 1.0, thick, topl + 0.2))
		for sx: float in [-1.0, 1.0]:
			batch.box("rail", top_c + Vector3(sx * (hw + 0.45), 0.9, 0), Vector3(0.15, 1.0, topl))
			_collider(Basis(), Vector3(sx * (hw + 0.45), h + 0.5, bz + ramp + topl * 0.5), Vector3(0.3, 1.0, ramp * 2 + topl))
		_arrow(Vector3(-hw * 0.5, 0, bz - 25), Vector3(0, 0, 1))
		instances.append({"z0": bz, "line_z": bz + 8.0, "top_z": bz + ramp, "end_z": bz + ramp * 2 + topl})
		z = bz + ramp * 2 + topl
		bz += 120.0
	_road(Vector3(0, 0, z), Vector3(0, 0, z_end), hw)
	_turnaround(Vector3(0, 0, z_end + 6))
	geo = {"hw": hw, "ramp": ramp, "h": h}
	spawn_xf = _yaw_xf(Vector3(-hw * 0.5, 0, 0), 0.0)
	return Rect2(-30, -50, 60, z_end + 80)
