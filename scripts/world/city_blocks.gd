class_name CityBlocks
extends RefCounted
## Các loại khu phố: nhà ở, công viên có hồ, trường học, chợ, cây xăng, nhà máy, chùa.
## Mỗi khu là một ô vuông giữa 4 con đường; có hàng rào/bờ cây thấp chặn xe đi lên.

const KINDS := {
	Vector2i(0, 0): "res", Vector2i(1, 0): "school", Vector2i(2, 0): "res",
	Vector2i(0, 1): "market", Vector2i(1, 1): "park", Vector2i(2, 1): "gas",
	Vector2i(0, 2): "temple", Vector2i(1, 2): "res", Vector2i(2, 2): "factory",
}


static func mats() -> void:
	Scenery._mats()
	MeshBatch.mat("cb_grass", Color(0.3, 0.5, 0.22), 1.0)
	MeshBatch.mat("cb_path", Color(0.72, 0.66, 0.55), 1.0)
	MeshBatch.mat("cb_hedge", Color(0.17, 0.38, 0.15), 1.0)
	MeshBatch.mat("cb_fence", Color(0.22, 0.24, 0.26), 0.6, 0.0, 0.5)
	MeshBatch.mat("cb_white", Color(0.93, 0.93, 0.9), 0.8)
	MeshBatch.mat("cb_yellow", Color(0.96, 0.82, 0.38), 0.9)
	MeshBatch.mat("cb_roof_red", Color(0.62, 0.2, 0.13), 0.85)
	MeshBatch.mat("cb_field", Color(0.25, 0.55, 0.22), 1.0)
	MeshBatch.mat("cb_flag", Color(0.85, 0.1, 0.08), 0.8)
	MeshBatch.mat("cb_lake", Color(0.12, 0.3, 0.36), 0.08, 0.0, 0.3)
	MeshBatch.mat("cb_bench", Color(0.45, 0.3, 0.18), 0.8)
	MeshBatch.mat("cb_market", Color(0.82, 0.75, 0.62), 0.9)
	MeshBatch.mat("cb_roof_metal", Color(0.45, 0.5, 0.55), 0.5, 0.0, 0.6)
	MeshBatch.mat("cb_aw0", Color(0.9, 0.25, 0.2), 0.9)
	MeshBatch.mat("cb_aw1", Color(0.2, 0.5, 0.85), 0.9)
	MeshBatch.mat("cb_aw2", Color(0.95, 0.7, 0.15), 0.9)
	MeshBatch.mat("cb_aw3", Color(0.25, 0.65, 0.35), 0.9)
	MeshBatch.mat("cb_crate", Color(0.6, 0.45, 0.25), 0.9)
	MeshBatch.mat("cb_canopy", Color(0.95, 0.95, 0.95), 0.5)
	MeshBatch.mat("cb_green", Color(0.1, 0.55, 0.3), 0.6)
	MeshBatch.mat("cb_pump", Color(0.85, 0.15, 0.12), 0.5)
	MeshBatch.mat("cb_fac", Color(0.62, 0.64, 0.66), 0.8)
	MeshBatch.mat("cb_fac_roof", Color(0.38, 0.42, 0.48), 0.5, 0.0, 0.5)
	MeshBatch.mat("cb_tank", Color(0.8, 0.82, 0.84), 0.3, 0.0, 0.8)
	MeshBatch.mat("cb_brick", Color(0.6, 0.3, 0.22), 0.9)
	MeshBatch.mat("cb_t_red", Color(0.62, 0.12, 0.08), 0.8)
	MeshBatch.mat("cb_t_yel", Color(0.95, 0.75, 0.3), 0.8)
	MeshBatch.mat("cb_t_roof", Color(0.28, 0.2, 0.15), 0.85)
	MeshBatch.mat("cb_stone", Color(0.62, 0.6, 0.55), 0.95)
	MeshBatch.mat("cb_pave", Color(0.47, 0.46, 0.43), 0.95)
	MeshBatch.mat("cb_balc", Color(0.3, 0.3, 0.32), 0.7)


static func build(kind: String, parent: Node3D, b: MeshBatch, sb: StaticBody3D, x0: float, x1: float, z0: float, z1: float, rng: RandomNumberGenerator) -> void:
	mats()
	var c := Vector3((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5)
	var hx := (x1 - x0) * 0.5
	var hz := (z1 - z0) * 0.5
	match kind:
		"field":
			Scenery.rice_fields(b, Rect2(x0, z0, hx * 2.0, hz * 2.0), [], rng.randi())
			_edge_trees(b, c, hx, hz, rng)
			return
		"hill":
			Scenery.tea_hills(b, Rect2(x0, z0, hx * 2.0, hz * 2.0), [], rng.randi())
			return
		"forest":
			_forest(b, c, hx, hz, rng)
			return
		"village":
			_village(b, c, hx, hz, rng)
			return
		"res":
			_residential(b, sb, c, hx, hz, rng)
			return
	# Công trình đặc biệt có cỡ cố định: khối lớn hơn thì đặt giữa, phần thừa trồng cây
	var ex := minf(hx, 58.0)
	var ez := minf(hz, 58.0)
	match kind:
		"park":
			_park(parent, b, sb, c, ex, ez, rng)
		"school":
			_school(parent, b, sb, c, ex, ez, rng)
		"market":
			_market(parent, b, sb, c, ex, ez, rng)
		"gas":
			_gas(parent, b, sb, c, ex, ez, rng)
		"factory":
			_factory(parent, b, sb, c, ex, ez, rng)
		"temple":
			_temple(parent, b, sb, c, ex, ez, rng)
		_:
			_residential(b, sb, c, hx, hz, rng)
	if hx > ex + 4.0 or hz > ez + 4.0:
		_scatter_outside(b, c, hx, hz, ex, ez, rng)


## Cây rải ở phần khối nằm ngoài công trình ở giữa
static func _scatter_outside(b: MeshBatch, c: Vector3, hx: float, hz: float, ex: float, ez: float, rng: RandomNumberGenerator) -> void:
	var cnt := int((hx * hz * 4.0 - ex * ez * 4.0) / 700.0)
	for k in cnt:
		var p := Vector3(rng.randf_range(-hx + 4.0, hx - 4.0), 0, rng.randf_range(-hz + 4.0, hz - 4.0))
		if absf(p.x) < ex + 4.0 and absf(p.z) < ez + 4.0:
			continue
		Scenery.tree(b, c + p, rng.randf_range(0.9, 1.4))


static func _edge_trees(b: MeshBatch, c: Vector3, hx: float, hz: float, rng: RandomNumberGenerator) -> void:
	var cnt := int(hx * hz / 2600.0)
	for k in cnt:
		var side := rng.randi_range(0, 3)
		var p := Vector3(rng.randf_range(-hx, hx), 0, rng.randf_range(-hz, hz))
		match side:
			0:
				p.x = -hx + 2.0
			1:
				p.x = hx - 2.0
			2:
				p.z = -hz + 2.0
			_:
				p.z = hz - 2.0
		Scenery.tree(b, c + p, rng.randf_range(0.9, 1.3))


## Rừng: cây dày, lát nền tối. Mật độ giảm theo mức đồ họa để máy yếu vẫn mượt.
static func _forest(b: MeshBatch, c: Vector3, hx: float, hz: float, rng: RandomNumberGenerator) -> void:
	Scenery._theme_mats()
	MeshBatch.mat("forest_floor", Color(0.15, 0.28, 0.13), 1.0)
	b.box("forest_floor", c + Vector3(0, 0.03, 0), Vector3(hx * 2.0, 0.06, hz * 2.0))
	var cell: float = [17.0, 13.0, 11.0][clampi(Scenery.gfx(), 0, 2)]
	var x := -hx + 4.0
	while x < hx - 3.0:
		var z := -hz + 4.0
		while z < hz - 3.0:
			if rng.randf() < 0.78:
				var p := c + Vector3(x + rng.randf_range(-cell * 0.4, cell * 0.4), 0, z + rng.randf_range(-cell * 0.4, cell * 0.4))
				if rng.randf() < 0.65:
					Scenery.pine(b, p, rng.randf_range(0.9, 1.7))
				else:
					Scenery.tree(b, p, rng.randf_range(1.0, 1.6))
			z += cell
		x += cell


## Làng: hai dãy nhà mái ngói quay ra đường, phía sau là ruộng
static func _village(b: MeshBatch, c: Vector3, hx: float, hz: float, rng: RandomNumberGenerator) -> void:
	var cnt := clampi(int(hx * 2.0 / 15.0), 3, 14)
	var rows: Array = []
	for s: float in [-1.0, 1.0]:
		var zc := c.z + s * (hz - 16.0)
		Scenery.village(b, Vector3(c.x, 0, zc), cnt, Vector3(0, 0, -s), rng.randi())
		rows.append(Rect2(c.x - hx, zc - 14.0, hx * 2.0, 28.0))
	Scenery.rice_fields(b, Rect2(c.x - hx, c.z - hz, hx * 2.0, hz * 2.0), rows, rng.randi())


# ------------------------------------------------------------------ tiện ích

static func col(sb: StaticBody3D, pos: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	cs.rotation.y = yaw
	sb.add_child(cs)


## Khối nhà có các dải cửa sổ, kèm va chạm. `base` là tâm đáy.
static func building(b: MeshBatch, sb: StaticBody3D, key: String, base: Vector3, size: Vector3, yaw: float = 0.0, floor_h: float = 3.2) -> void:
	var c := base + Vector3(0, size.y * 0.5, 0)
	b.box(key, c, size, yaw)
	var floors := int(size.y / floor_h)
	for f in floors:
		var y := base.y + 1.9 + f * floor_h
		if y > base.y + size.y - 0.8:
			break
		b.box("win", Vector3(c.x, y, c.z), Vector3(size.x + 0.06, 1.2, size.z * 0.82), yaw)
		b.box("win", Vector3(c.x, y, c.z), Vector3(size.x * 0.82, 1.2, size.z + 0.06), yaw)
	b.box("c_wall_border", Vector3(c.x, base.y + size.y + 0.15, c.z), Vector3(size.x + 0.3, 0.3, size.z + 0.3), yaw)
	col(sb, c, size, yaw)


## Mái dốc 2 bên dọc trục X cục bộ, đặt trên khối có đỉnh ở cao độ `top`.
static func gable_roof(b: MeshBatch, key: String, c: Vector3, w: float, d: float, top: float, rise: float, yaw: float = 0.0) -> void:
	var bs := Basis(Vector3.UP, yaw)
	var half := d * 0.5 + 0.6
	var slope := atan2(rise, half)
	for s: float in [-1.0, 1.0]:
		var rb := bs * Basis(Vector3.RIGHT, s * slope)
		var p := c + bs * Vector3(0, top + rise * 0.5, s * half * 0.5)
		b.box_basis(key, rb, p, Vector3(w + 1.0, 0.18, sqrt(half * half + rise * rise)))


## Rào thấp quanh khu (bờ cây hoặc hàng rào sắt), chừa `gaps` (danh sách cạnh: 0=-z 1=+z 2=-x 3=+x).
static func perimeter(b: MeshBatch, sb: StaticBody3D, c: Vector3, hx: float, hz: float, key: String, h: float, open_sides: Array = []) -> void:
	var sides := [
		[Vector3(0, 0, -hz), Vector3(hx * 2, h, 0.6)],
		[Vector3(0, 0, hz), Vector3(hx * 2, h, 0.6)],
		[Vector3(-hx, 0, 0), Vector3(0.6, h, hz * 2)],
		[Vector3(hx, 0, 0), Vector3(0.6, h, hz * 2)],
	]
	for k in 4:
		if open_sides.has(k):
			continue
		var o: Vector3 = sides[k][0]
		var sz: Vector3 = sides[k][1]
		var p := c + o + Vector3(0, h * 0.5, 0)
		b.box(key, p, sz)
		col(sb, p, Vector3(sz.x, 1.2, sz.z))


static func sign_board(parent: Node3D, b: MeshBatch, text: String, pos: Vector3, face: Vector3, w: float = 7.0, bg: String = "cb_green", fg: Color = Color.WHITE) -> void:
	var yaw := atan2(face.x, face.z)
	b.box(bg, pos, Vector3(w, 1.5, 0.2), yaw)
	for sx: float in [-1.0, 1.0]:
		var pp := pos + face.rotated(Vector3.UP, PI * 0.5) * (w * 0.5 - 0.3) * sx
		b.box("cb_fence", Vector3(pp.x, pos.y * 0.5, pp.z), Vector3(0.15, pos.y, 0.15))
	var lb := Label3D.new()
	lb.text = text
	lb.font_size = 110
	lb.outline_size = 0
	lb.pixel_size = 0.01
	lb.modulate = fg
	lb.position = pos + face * 0.12
	lb.rotation.y = yaw
	lb.shaded = false
	parent.add_child(lb)


## Dãy nhà ống (nhà phố hẹp nhiều tầng) dọc mép khu, mặt tiền hướng `face` ra đường.
static func tube_row(b: MeshBatch, sb: StaticBody3D, a: Vector3, e: Vector3, face: Vector3, depth: float, rng: RandomNumberGenerator) -> void:
	var dir := (e - a).normalized()
	var total := a.distance_to(e)
	var u := 0.0
	while u < total - 3.5:
		var w := minf(rng.randf_range(4.0, 6.5), total - u)
		var h := rng.randf_range(3, 6) * 3.3
		var base := a + dir * (u + w * 0.5) - face * depth * 0.5
		var key := "bld%d" % rng.randi_range(0, 6)
		var size := Vector3(w - 0.15, h, depth)
		if absf(face.x) > 0.5:
			size = Vector3(depth, h, w - 0.15)
		b.box(key, base + Vector3(0, h * 0.5, 0), size)
		col(sb, base + Vector3(0, h * 0.5, 0), size)
		var front := base + face * (depth * 0.5 + 0.04)
		for f in int(h / 3.3):
			var y := 1.9 + f * 3.3
			b.box("win", front + Vector3(0, y, 0), Vector3(0.06, 1.3, (w - 1.4)) if absf(face.x) > 0.5 else Vector3(w - 1.4, 1.3, 0.06))
			if f > 0:
				b.box("cb_balc", front + face * 0.5 + Vector3(0, y - 0.9, 0), Vector3(1.0, 0.12, w - 0.6) if absf(face.x) > 0.5 else Vector3(w - 0.6, 0.12, 1.0))
		# biển hiệu tầng trệt
		b.box("cb_aw%d" % rng.randi_range(0, 3), front + face * 0.08 + Vector3(0, 3.0, 0), Vector3(0.1, 0.7, w - 0.8) if absf(face.x) > 0.5 else Vector3(w - 0.8, 0.7, 0.1))
		u += w


## Hàng cây dọc bên trong rào khu
static func tree_ring(b: MeshBatch, c: Vector3, hx: float, hz: float, inset: float, step: float, rng: RandomNumberGenerator, sides: Array = [0, 1, 2, 3]) -> void:
	for k: int in sides:
		var horiz := k < 2
		var len := hx if horiz else hz
		var t := -len + inset
		while t < len - inset:
			var p := c + (Vector3(t, 0, (-1 if k == 0 else 1) * (hz - inset)) if horiz else Vector3((-1 if k == 2 else 1) * (hx - inset), 0, t))
			Scenery.tree(b, p, rng.randf_range(0.85, 1.2))
			t += step


static func _tx(vi: String, en: String) -> String:
	return vi if Game.lang == "vi" else en


# ------------------------------------------------------------------ nhà ở: 3 x 3 khối nhà cao thấp
static func _residential(b: MeshBatch, sb: StaticBody3D, c: Vector3, hx: float, hz: float, rng: RandomNumberGenerator) -> void:
	b.box("c_walk", c + Vector3(0, 0.05, 0), Vector3(hx * 2, 0.12, hz * 2))
	# số nhà theo kích thước khối: khối nhỏ 3x3 như cũ, khối dài thì nhiều nhà hơn, không phình nhà ra
	var nx := clampi(roundi(hx * 2.0 / 40.0), 2, 8)
	var nz := clampi(roundi(hz * 2.0 / 40.0), 2, 8)
	var w := hx * 2.0 / nx
	var d := hz * 2.0 / nz
	for ix in nx:
		for iz in nz:
			var p := c + Vector3(-hx + w * (ix + 0.5), 0, -hz + d * (iz + 0.5))
			if ix > 0 and ix < nx - 1 and iz > 0 and iz < nz - 1:
				# sân trong: cây xanh
				b.box("cb_grass", p + Vector3(0, 0.13, 0), Vector3(w - 4, 0.04, d - 4))
				for k in 4:
					Scenery.tree(b, p + Vector3(rng.randf_range(-w * 0.3, w * 0.3), 0, rng.randf_range(-d * 0.3, d * 0.3)), rng.randf_range(0.9, 1.3))
				continue
			var h := rng.randf_range(8.0, 30.0)
			building(b, sb, "bld%d" % rng.randi_range(0, 6), p, Vector3(w - rng.randf_range(3.0, 6.0), h, d - rng.randf_range(3.0, 6.0)))


# ------------------------------------------------------------------ công viên + hồ
static func _park(parent: Node3D, b: MeshBatch, sb: StaticBody3D, c: Vector3, hx: float, hz: float, rng: RandomNumberGenerator) -> void:
	b.box("cb_grass", c + Vector3(0, 0.04, 0), Vector3(hx * 2, 0.08, hz * 2))
	perimeter(b, sb, c, hx, hz, "cb_hedge", 1.0)
	# hồ: 2 hình tròn chồng nhau cho bờ không đều
	var lake := [[c + Vector3(-4, 0, 2), 17.0], [c + Vector3(9, 0, -6), 11.0]]
	for l in lake:
		var lc: Vector3 = l[0]
		var r: float = l[1]
		b.cyl("cb_stone", lc + Vector3(0, 0.08, 0), r + 1.0, 0.16)
		b.cyl("cb_lake", lc + Vector3(0, 0.1, 0), r, 0.16)
		col(sb, lc + Vector3(0, 0.6, 0), Vector3(r * 1.5, 1.2, r * 1.5))
	# đường dạo quanh hồ
	var k := 0
	while k < 28:
		var a := TAU * k / 28.0
		var a2 := TAU * (k + 1) / 28.0
		var r := 22.0
		b.strip("cb_path", c + Vector3(cos(a) * r, 0, sin(a) * r * 0.9), c + Vector3(cos(a2) * r, 0, sin(a2) * r * 0.9), 2.4, 0.1, 0.04)
		if k % 3 == 0:
			Scenery.tree(b, c + Vector3(cos(a) * (r + 5.0), 0, sin(a) * (r + 5.0) * 0.9), rng.randf_range(1.0, 1.5))
		if k % 4 == 1:
			var bp := c + Vector3(cos(a) * (r - 2.0), 0.25, sin(a) * (r - 2.0) * 0.9)
			b.box("cb_bench", bp, Vector3(1.8, 0.12, 0.5), -a)
		k += 1
	# lối vào từ 4 phía
	for dir: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var e := dir * (hx if absf(dir.x) > 0.5 else hz)
		b.strip("cb_path", c + e, c + dir * 23.0, 3.0, 0.1, 0.04)
	# thủy tạ giữa hồ
	var pv := c + Vector3(-6, 0, 3)
	b.box("cb_stone", pv + Vector3(0, 0.35, 0), Vector3(7, 0.5, 7))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			b.box("cb_t_red", pv + Vector3(sx * 2.8, 1.9, sz * 2.8), Vector3(0.3, 2.8, 0.3))
	gable_roof(b, "cb_t_roof", pv, 6.0, 6.0, 3.3, 1.4)
	b.strip("cb_bench", pv + Vector3(3.5, 0, 0), c + Vector3(17, 0, 3), 1.6, 0.3, 0.12)
	# hàng cây quanh rìa
	var x := -hx + 4.0
	while x < hx - 3.0:
		for sz: float in [-1.0, 1.0]:
			Scenery.tree(b, c + Vector3(x, 0, sz * (hz - 3.5)), rng.randf_range(0.9, 1.3))
		x += 9.0
	sign_board(parent, b, _tx("CÔNG VIÊN", "CITY PARK"), c + Vector3(0, 2.4, -hz + 1.6), Vector3(0, 0, -1), 8.0)


# ------------------------------------------------------------------ trường học
static func _school(parent: Node3D, b: MeshBatch, sb: StaticBody3D, c: Vector3, hx: float, hz: float, rng: RandomNumberGenerator) -> void:
	b.box("cb_pave", c + Vector3(0, 0.04, 0), Vector3(hx * 2, 0.08, hz * 2))
	tree_ring(b, c, hx, hz, 3.0, 8.0, rng, [0])
	perimeter(b, sb, c, hx, hz, "cb_fence", 1.8)
	# khối nhà chữ U hướng ra đường phía nam (-z)
	var back := c + Vector3(0, 0, hz - 10.0)
	building(b, sb, "cb_yellow", back, Vector3(hx * 1.6, 12.0, 12.0), 0.0, 3.8)
	gable_roof(b, "cb_roof_red", back, hx * 1.6, 12.0, 12.0, 2.6)
	for sx: float in [-1.0, 1.0]:
		var wing := c + Vector3(sx * (hx - 9.0), 0, hz * 0.2)
		building(b, sb, "cb_yellow", wing, Vector3(12.0, 8.0, hz * 0.9), 0.0, 3.8)
		gable_roof(b, "cb_roof_red", wing, hz * 0.9, 12.0, 8.0, 2.0, PI * 0.5)
	# sân bóng
	var fc := c + Vector3(0, 0, -hz * 0.4)
	b.box("cb_field", fc + Vector3(0, 0.1, 0), Vector3(36, 0.04, 22))
	b.box("cb_white", fc + Vector3(0, 0.13, 0), Vector3(0.15, 0.02, 22))
	for sx: float in [-1.0, 1.0]:
		b.box("cb_white", fc + Vector3(sx * 18, 0.13, 0), Vector3(0.15, 0.02, 22))
		b.box("cb_white", fc + Vector3(sx * 17.5, 1.2, 0), Vector3(0.12, 2.4, 6.0))
	for sz: float in [-1.0, 1.0]:
		b.box("cb_white", fc + Vector3(0, 0.13, sz * 11), Vector3(36, 0.02, 0.15))
	# cột cờ
	var fp := c + Vector3(0, 0, hz * 0.15)
	b.cyl("cb_fence", fp + Vector3(0, 5.5, 0), 0.08, 11.0)
	b.box("cb_flag", fp + Vector3(1.0, 10.2, 0), Vector3(2.0, 1.3, 0.04))
	for sx: float in [-1.0, 1.0]:
		var z := fc.z - 10.0
		while z < fc.z + 14.0:
			Scenery.tree(b, Vector3(fc.x + sx * 22.0, 0, z), rng.randf_range(0.9, 1.2))
			z += 6.0
	sign_board(parent, b, _tx("TRƯỜNG TIỂU HỌC", "PRIMARY SCHOOL"), c + Vector3(0, 3.0, -hz - 0.2), Vector3(0, 0, -1), 13.0, "cb_t_red")


# ------------------------------------------------------------------ chợ
static func _market(parent: Node3D, b: MeshBatch, sb: StaticBody3D, c: Vector3, hx: float, hz: float, rng: RandomNumberGenerator) -> void:
	b.box("cb_pave", c + Vector3(0, 0.04, 0), Vector3(hx * 2, 0.08, hz * 2))
	perimeter(b, sb, c, hx, hz, "c_wall_border", 1.0, [2, 3])
	tube_row(b, sb, c + Vector3(-hx, 0, -hz), c + Vector3(-hx, 0, hz), Vector3(-1, 0, 0), 11.0, rng)
	tube_row(b, sb, c + Vector3(hx, 0, -hz), c + Vector3(hx, 0, hz), Vector3(1, 0, 0), 11.0, rng)
	var hall := c + Vector3(0, 0, hz * 0.25)
	building(b, sb, "cb_market", hall, Vector3(hx * 1.4 - 10.0, 8.0, hz * 0.9), 0.0, 8.0)
	gable_roof(b, "cb_roof_metal", hall, hx * 1.4 - 10.0, hz * 0.9, 8.0, 3.5)
	# cửa lớn
	b.box("door", hall + Vector3(0, 2.2, -hz * 0.45 - 0.05), Vector3(8, 4.4, 0.1))
	# dãy sạp mái bạt phía trước
	for row in 2:
		var z := c.z - hz + 9.0 + row * 9.0
		var x := c.x - hx + 17.0
		var k := 0
		while x < c.x + hx - 16.0:
			var p := Vector3(x, 0, z)
			b.box("cb_crate", p + Vector3(0, 0.45, 0), Vector3(3.2, 0.9, 2.0))
			for s in 3:
				b.box("cb_aw%d" % ((s + k) % 4), p + Vector3(-0.9 + s * 0.9, 1.05, 0), Vector3(0.6, 0.3, 1.4))
			b.box_basis("cb_aw%d" % (k % 4), Basis(Vector3.RIGHT, 0.25), p + Vector3(0, 2.5, -0.3), Vector3(3.6, 0.06, 3.0))
			for sx: float in [-1.0, 1.0]:
				b.box("cb_fence", p + Vector3(sx * 1.7, 1.2, -1.4), Vector3(0.06, 2.4, 0.06))
			col(sb, p + Vector3(0, 0.6, 0), Vector3(3.4, 1.2, 2.4))
			x += 5.0
			k += 1
	sign_board(parent, b, _tx("CHỢ TRUNG TÂM", "CENTRAL MARKET"), c + Vector3(0, 3.0, -hz - 0.2), Vector3(0, 0, -1), 12.0, "cb_t_red", Color(1, 0.9, 0.3))


# ------------------------------------------------------------------ cây xăng (mở ra đường phía nam)
static func _gas(parent: Node3D, b: MeshBatch, sb: StaticBody3D, c: Vector3, hx: float, hz: float, rng: RandomNumberGenerator) -> void:
	b.box("c_asph", c + Vector3(0, 0.03, -hz * 0.5), Vector3(hx * 2 - 24, 0.06, hz))
	b.box("cb_pave", c + Vector3(0, 0.05, hz * 0.5), Vector3(hx * 2, 0.12, hz))
	perimeter(b, sb, c, hx, hz, "cb_hedge", 0.9, [0, 2, 3])
	tube_row(b, sb, c + Vector3(-hx, 0, -hz), c + Vector3(-hx, 0, hz), Vector3(-1, 0, 0), 11.0, rng)
	tube_row(b, sb, c + Vector3(hx, 0, -hz), c + Vector3(hx, 0, hz), Vector3(1, 0, 0), 11.0, rng)
	# mái che + cột
	var cp := c + Vector3(0, 0, -hz * 0.55)
	b.box("cb_canopy", cp + Vector3(0, 5.6, 0), Vector3(26, 0.8, 12))
	b.box("cb_green", cp + Vector3(0, 5.6, -6.02), Vector3(26, 0.5, 0.06))
	b.box("cb_green", cp + Vector3(0, 5.6, 6.02), Vector3(26, 0.5, 0.06))
	for sx: float in [-9.0, -3.0, 3.0, 9.0]:
		b.box("cb_white", cp + Vector3(sx, 2.6, 0), Vector3(0.5, 5.2, 0.5))
		# đảo bơm
		b.box("concrete", cp + Vector3(sx, 0.12, 0), Vector3(1.4, 0.24, 6.0))
		for sz: float in [-1.8, 1.8]:
			b.box("cb_pump", cp + Vector3(sx, 1.0, sz), Vector3(0.8, 1.6, 0.6))
			b.box("cb_white", cp + Vector3(sx, 1.4, sz), Vector3(0.82, 0.4, 0.62))
			col(sb, cp + Vector3(sx, 0.8, sz), Vector3(0.9, 1.6, 0.7))
	# cửa hàng tiện lợi
	var shop := c + Vector3(-hx * 0.3, 0, hz * 0.05)
	building(b, sb, "cb_white", shop, Vector3(18, 4.5, 9), 0.0, 4.5)
	b.box("cb_green", shop + Vector3(0, 3.9, -4.55), Vector3(18, 0.8, 0.1))
	b.box("win", shop + Vector3(0, 1.6, -4.55), Vector3(12, 2.2, 0.08))
	# cột giá xăng
	var pole := c + Vector3(hx - 16.0, 0, -hz + 3.0)
	b.box("cb_fence", pole + Vector3(0, 3.5, 0), Vector3(0.4, 7.0, 0.4))
	sign_board(parent, b, _tx("XĂNG DẦU", "GAS STATION"), pole + Vector3(0, 7.6, 0), Vector3(0, 0, -1), 6.0)
	# phía sau: vài nhà ở
	building(b, sb, "bld%d" % rng.randi_range(0, 6), c + Vector3(hx * 0.35, 0, hz - 12.0), Vector3(30, rng.randf_range(12, 22), 16))
	tree_ring(b, c, hx - 12.0, hz, 2.5, 7.0, rng, [1])


# ------------------------------------------------------------------ nhà máy
static func _factory(parent: Node3D, b: MeshBatch, sb: StaticBody3D, c: Vector3, hx: float, hz: float, rng: RandomNumberGenerator) -> void:
	b.box("cb_pave", c + Vector3(0, 0.04, 0), Vector3(hx * 2, 0.08, hz * 2))
	perimeter(b, sb, c, hx, hz, "cb_fence", 2.2)
	tree_ring(b, c, hx, hz, 2.5, 7.0, rng, [0, 2])
	var hall := c + Vector3(-hx * 0.12, 0, hz * 0.22)
	var w := hx * 1.45
	var d := hz * 1.15
	building(b, sb, "cb_fac", hall, Vector3(w, 10.0, d), 0.0, 10.0)
	# mái răng cưa
	var n := 6
	for k in n:
		var z := hall.z - d * 0.5 + d * (k + 0.5) / n
		b.box_basis("cb_fac_roof", Basis(Vector3.RIGHT, -0.5), Vector3(hall.x, 11.2, z), Vector3(w, 0.2, d / n * 1.1))
		b.box("win", Vector3(hall.x, 11.0, z + d / n * 0.48), Vector3(w * 0.98, 1.6, 0.1))
	# ống khói sọc đỏ trắng
	building(b, sb, "cb_white", c + Vector3(-hx * 0.45, 0, -hz + 14.0), Vector3(24, 9.6, 10), 0.0, 3.2)
	var ch := c + Vector3(hx - 10.0, 0, hz - 10.0)
	for k in 6:
		b.cyl("cb_white" if k % 2 == 0 else "cb_flag", ch + Vector3(0, 2.2 + k * 4.4, 0), 1.3 - k * 0.08, 4.4)
	col(sb, ch + Vector3(0, 13, 0), Vector3(2.6, 26, 2.6))
	# bồn chứa
	for k in 2:
		var tp := c + Vector3(hx - 10.0, 0, -hz + 12.0 + k * 13.0)
		b.cyl("cb_tank", tp + Vector3(0, 4.5, 0), 4.5, 9.0)
		b.cyl("cb_fac_roof", tp + Vector3(0, 9.1, 0), 4.6, 0.3)
		col(sb, tp + Vector3(0, 4.5, 0), Vector3(8.5, 9.0, 8.5))
	# bãi xe tải
	for k in 3:
		var tp := c + Vector3(hx * 0.05 + k * 9.0, 0, -hz + 9.0)
		b.box("cb_white", tp + Vector3(0, 2.0, 0), Vector3(2.5, 2.8, 7.0))
		b.box("cb_aw1", tp + Vector3(0, 1.6, 4.4), Vector3(2.4, 2.0, 1.8))
		col(sb, tp + Vector3(0, 1.6, 0.8), Vector3(2.6, 3.2, 9.0))
	sign_board(parent, b, _tx("NHÀ MÁY CƠ KHÍ", "STEEL WORKS"), c + Vector3(0, 3.4, -hz - 0.2), Vector3(0, 0, -1), 12.0, "cb_aw1")


# ------------------------------------------------------------------ chùa
static func _temple(parent: Node3D, b: MeshBatch, sb: StaticBody3D, c: Vector3, hx: float, hz: float, rng: RandomNumberGenerator) -> void:
	b.box("cb_pave", c + Vector3(0, 0.05, 0), Vector3(hx * 2, 0.1, hz * 2))
	b.strip("cb_stone", c + Vector3(0, 0, -hz), c + Vector3(0, 0, hz * 0.3), 6.0, 0.11, 0.04)
	perimeter(b, sb, c, hx, hz, "cb_t_yel", 1.6)
	tree_ring(b, c, hx, hz, 3.0, 7.0, rng, [1, 2, 3])
	# nhà tăng, nhà khách hai bên
	for sx: float in [-1.0, 1.0]:
		var hp := c + Vector3(sx * (hx - 12.0), 0, hz * 0.45)
		building(b, sb, "cb_t_yel", hp, Vector3(10, 4.5, 22), 0.0, 99.0)
		gable_roof(b, "cb_t_roof", hp, 22.0, 10.0, 4.5, 1.5, PI * 0.5)
	# cổng tam quan phía nam
	var g := c + Vector3(0, 0, -hz + 1.0)
	for sx: float in [-6.0, -2.2, 2.2, 6.0]:
		b.box("cb_t_yel", g + Vector3(sx, 2.5, 0), Vector3(1.0, 5.0, 1.4))
	b.box("cb_t_yel", g + Vector3(0, 4.2, 0), Vector3(12.0, 1.2, 1.4))
	gable_roof(b, "cb_t_roof", g, 13.0, 2.4, 4.8, 0.9)
	gable_roof(b, "cb_t_roof", g + Vector3(0, 1.6, 0), 4.6, 2.0, 4.8, 0.7)
	# chính điện 2 tầng mái
	var hall := c + Vector3(0, 0, hz * 0.3)
	b.box("cb_stone", hall + Vector3(0, 0.6, 0), Vector3(28, 1.2, 18))
	col(sb, hall + Vector3(0, 0.6, 0), Vector3(28, 1.2, 18))
	building(b, sb, "cb_t_yel", hall + Vector3(0, 1.2, 0), Vector3(22, 6.0, 12), 0.0, 99.0)
	for k in 8:
		b.box("cb_t_red", hall + Vector3(-9.6 + k * 2.75, 3.6, -6.4), Vector3(0.5, 4.8, 0.5))
	gable_roof(b, "cb_t_roof", hall, 24.0, 14.0, 7.2, 1.8)
	building(b, sb, "cb_t_yel", hall + Vector3(0, 8.4, 0), Vector3(14, 2.4, 7), 0.0, 99.0)
	gable_roof(b, "cb_t_roof", hall, 16.0, 8.5, 10.8, 1.8)
	b.box("door", hall + Vector3(0, 3.0, -6.05), Vector3(3.0, 3.6, 0.1))
	# tháp 7 tầng
	var tw := c + Vector3(-hx + 13.0, 0, -hz * 0.15)
	for k in 7:
		var s := 6.0 - k * 0.6
		var y := 0.2 + k * 3.0
		b.box("cb_t_yel" if k % 2 == 0 else "cb_white", tw + Vector3(0, y + 1.2, 0), Vector3(s, 2.4, s))
		b.box("cb_t_roof", tw + Vector3(0, y + 2.6, 0), Vector3(s + 1.6, 0.35, s + 1.6))
	b.cyl("cb_t_yel", tw + Vector3(0, 22.5, 0), 0.25, 2.0)
	col(sb, tw + Vector3(0, 10, 0), Vector3(6, 20, 6))
	# lư hương, ao sen, cây đa
	b.cyl("cb_fac_roof", c + Vector3(0, 0.9, -hz * 0.25), 0.8, 1.6)
	b.cyl("cb_stone", c + Vector3(hx - 14, 0.1, -hz * 0.3), 8.0, 0.2)
	b.cyl("cb_lake", c + Vector3(hx - 14, 0.15, -hz * 0.3), 7.0, 0.2)
	for k in 7:
		b.cyl("cb_field", c + Vector3(hx - 14 + rng.randf_range(-5, 5), 0.27, -hz * 0.3 + rng.randf_range(-5, 5)), 0.6, 0.04)
	for p: Vector3 in [c + Vector3(hx - 8, 0, hz - 8), c + Vector3(-hx + 8, 0, hz - 8), c + Vector3(hx - 10, 0, -hz + 8)]:
		b.cyl("trunk", p + Vector3(0, 2.5, 0), 0.9, 5.0)
		b.sphere("leaf", p + Vector3(0, 7.0, 0), Vector3(13, 7, 13))
		col(sb, p + Vector3(0, 2.5, 0), Vector3(1.8, 5, 1.8))
	sign_board(parent, b, _tx("CHÙA AN LẠC", "AN LAC PAGODA"), c + Vector3(0, 6.6, -hz + 0.2), Vector3(0, 0, -1), 9.0, "cb_t_red", Color(1, 0.85, 0.3))
