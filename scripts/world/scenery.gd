class_name Scenery
extends RefCounted
## Phong cảnh vẽ bằng code: núi nhiều lớp, mây, đồng lúa có bờ, mương, sông, cầu, làng mái ngói, tre, cột điện.

static var _tex: Dictionary = {}
static var cur_rain: bool = false
static var theme: String = "country"     # country · tea · coast · lake
const THEMES := ["country", "tea", "coast", "lake"]
const RACE_THEMES := ["country", "tea", "coast", "lake", "forest", "mountain"]


static func pick_theme(want: String) -> String:
	theme = want if THEMES.has(want) else THEMES[randi() % THEMES.size()]
	return theme


## Chọn cảnh cho đường đua (có thêm rừng và núi)
static func pick_race_theme(want: String) -> String:
	theme = want if RACE_THEMES.has(want) else RACE_THEMES[randi() % RACE_THEMES.size()]
	return theme


static func gfx() -> int:
	return int(Game.settings.get("graphics", 1))


# ------------------------------------------------------------------ vân bề mặt (triplanar)

static func noise_tex(key: String, base: Color, var_amt: float, freq: float, stripes: bool = false) -> Texture2D:
	if _tex.has(key):
		return _tex[key]
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var n := FastNoiseLite.new()
	n.seed = hash(key) & 0xffff
	n.frequency = freq
	n.fractal_octaves = 3
	for y in size:
		for x in size:
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			if stripes:
				# hàng lúa: sọc mảnh + nhiễu
				var row := 0.5 + 0.5 * sin(float(y) * 0.9)
				v = v * 0.6 + row * 0.4
			var c := base.lightened(var_amt * (v - 0.5)) if v > 0.5 else base.darkened(var_amt * (0.5 - v))
			img.set_pixel(x, y, c)
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


## Gắn vân nhiễu cho vật liệu có sẵn trong MeshBatch (mặt đường, cỏ...)
static func texturize(key: String, scale: float, var_amt: float = 0.35, freq: float = 0.08, stripes: bool = false) -> void:
	if gfx() == 0:
		return
	var m: StandardMaterial3D = MeshBatch._mats.get(key)
	if m == null or m.albedo_texture != null:
		return
	var base := m.albedo_color
	m.albedo_texture = noise_tex(key + "_t", base, var_amt, freq, stripes)
	m.albedo_color = Color.WHITE
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


# ------------------------------------------------------------------ núi + mây

static func mountains(parent: Node3D, center: Vector3, r0: float, night: bool = false) -> void:
	var layers := [[r0, 70.0, Color(0.27, 0.42, 0.33)], [r0 * 1.35, 110.0, Color(0.36, 0.48, 0.52)], [r0 * 1.8, 160.0, Color(0.52, 0.6, 0.68)]]
	if gfx() == 0:
		layers = layers.slice(0, 2)
	var n := FastNoiseLite.new()
	n.seed = 77
	n.frequency = 0.9
	n.fractal_octaves = 4
	for li in layers.size():
		var L: Array = layers[li]
		var r: float = L[0]
		var hmax: float = L[1]
		var col: Color = L[2]
		if theme == "tea" and li == 0:
			col = Color(0.2, 0.38, 0.24)
		elif theme == "coast":
			col = col.lerp(Color(0.45, 0.6, 0.7), 0.3)
		if night:
			col = col.darkened(0.75)
		var seg := 140
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var prev_top := Vector3.ZERO
		var prev_bot := Vector3.ZERO
		var prev_h := 0.0
		for k in seg + 1:
			var a := TAU * float(k) / seg
			var dir := Vector3(cos(a), 0, sin(a))
			var h := (n.get_noise_2d(cos(a) * 3.0 + li * 7.0, sin(a) * 3.0) * 0.5 + 0.5)
			h = pow(h, 1.6) * hmax + hmax * 0.12
			if theme == "coast" and dir.x < -0.2:
				# phía biển: chỉ còn đảo nhỏ thấp ngoài khơi
				h *= clampf(0.6 + dir.x * 1.2, 0.04, 1.0) if li == 0 else 0.03
			elif theme == "tea" and li == 0:
				h *= 1.25
			var top := center + dir * r + Vector3(0, h, 0)
			var bot := center + dir * (r - 30.0) + Vector3(0, -2.0, 0)
			if k > 0:
				var c_top := col.lightened(0.12 + 0.25 * (prev_h / hmax))
				var c_bot := col.darkened(0.25)
				for v in [[prev_bot, c_bot], [prev_top, c_top], [top, col.lightened(0.12 + 0.25 * (h / hmax))],
						[prev_bot, c_bot], [top, col.lightened(0.12 + 0.25 * (h / hmax))], [bot, c_bot]]:
					st.set_color(v[1])
					st.add_vertex(v[0])
			prev_top = top
			prev_bot = bot
			prev_h = h
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.disable_fog = li > 0
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


static func clouds(parent: Node3D, center: Vector3, r: float, night: bool, rain: bool) -> void:
	if night or gfx() == 0:
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 0.92) if not rain else Color(0.7, 0.72, 0.75, 0.95)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.disable_fog = true
	var b := MeshBatch.new()
	MeshBatch._mats["cloud"] = m
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 26:
		var a := rng.randf() * TAU
		var d := rng.randf_range(r * 0.5, r * 1.3)
		var c := center + Vector3(cos(a) * d, rng.randf_range(130, 200), sin(a) * d)
		for j in rng.randi_range(3, 6):
			var off := Vector3(rng.randf_range(-35, 35), rng.randf_range(-4, 6), rng.randf_range(-15, 15))
			var s := rng.randf_range(25, 45)
			b.sphere("cloud", c + off, Vector3(s * 1.6, s * 0.45, s))
	b.commit(parent, false)


# ------------------------------------------------------------------ đồng quê

static func _mats() -> void:
	MeshBatch.mat("paddy0", Color(0.36, 0.6, 0.22), 0.95)
	MeshBatch.mat("paddy1", Color(0.44, 0.66, 0.24), 0.95)
	MeshBatch.mat("paddy2", Color(0.62, 0.66, 0.26), 0.95)
	MeshBatch.mat("paddy3", Color(0.3, 0.52, 0.2), 0.95)
	MeshBatch.mat("paddy_w", Color(0.3, 0.4, 0.42), 0.25, 0.0, 0.0)   # ruộng ngập nước
	MeshBatch.mat("bund", Color(0.42, 0.45, 0.26), 1.0)
	MeshBatch.mat("water", Color(0.15, 0.27, 0.32), 0.12, 0.0, 0.2)
	MeshBatch.mat("bank", Color(0.45, 0.42, 0.33), 1.0)
	MeshBatch.mat("trunk", Color(0.36, 0.25, 0.16), 0.9)
	MeshBatch.mat("leaf", Color(0.2, 0.45, 0.18), 0.9)
	MeshBatch.mat("leaf2", Color(0.28, 0.5, 0.2), 0.9)
	MeshBatch.mat("bamboo", Color(0.45, 0.58, 0.25), 0.8)
	MeshBatch.mat("bamboo_leaf", Color(0.32, 0.55, 0.22), 0.9)
	MeshBatch.mat("roof", Color(0.62, 0.25, 0.16), 0.85)
	MeshBatch.mat("roof2", Color(0.5, 0.2, 0.14), 0.85)
	MeshBatch.mat("wall_y", Color(0.93, 0.85, 0.55), 0.9)
	MeshBatch.mat("wall_w", Color(0.92, 0.9, 0.84), 0.9)
	MeshBatch.mat("door", Color(0.35, 0.22, 0.14), 0.8)
	MeshBatch.mat("pole", Color(0.65, 0.65, 0.62), 0.8)
	MeshBatch.mat("wire", Color(0.08, 0.08, 0.08), 0.8)
	MeshBatch.mat("concrete", Color(0.68, 0.67, 0.64), 0.9)
	MeshBatch.mat("rail", Color(0.85, 0.85, 0.82), 0.6)
	MeshBatch.mat("hay", Color(0.8, 0.68, 0.35), 1.0)
	texturize("paddy0", 0.25, 0.4, 0.15, true)
	texturize("paddy1", 0.25, 0.4, 0.15, true)
	texturize("paddy2", 0.25, 0.4, 0.15, true)
	texturize("paddy3", 0.25, 0.4, 0.15, true)
	texturize("bund", 0.4, 0.35, 0.2)
	texturize("bank", 0.3, 0.4, 0.12)


static func _in_any(p: Vector2, rects: Array, pad: float) -> bool:
	for r in rects:
		var rr: Rect2 = r
		if rr.grow(pad).has_point(p):
			return true
	return false


## Đồng lúa chia ô trong vùng `area`, trừ các vùng `exclude` (đường, sân thi...)
static func rice_fields(b: MeshBatch, area: Rect2, exclude: Array, rseed: int = 1) -> void:
	_mats()
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var cell := 18.0 if gfx() > 0 else 26.0
	var x := area.position.x
	while x < area.end.x:
		var z := area.position.y
		var w := rng.randf_range(cell * 0.8, cell * 1.3)
		while z < area.end.y:
			var h := rng.randf_range(cell * 0.7, cell * 1.4)
			var c := Vector2(x + w * 0.5, z + h * 0.5)
			if not _in_any(c, exclude, maxf(w, h) * 0.6):
				var key := "paddy%d" % rng.randi_range(0, 3)
				if rng.randf() < 0.12:
					key = "paddy_w"
				b.box(key, Vector3(c.x, 0.03, c.y), Vector3(w - 0.5, 0.06, h - 0.5))
				# bờ ruộng
				b.box("bund", Vector3(c.x, 0.08, z + 0.15), Vector3(w, 0.16, 0.45))
				b.box("bund", Vector3(x + 0.15, 0.08, c.y), Vector3(0.45, 0.16, h))
				# đống rơm, cây lẻ
				var r := rng.randf()
				if r < 0.03:
					b.sphere("hay", Vector3(c.x, 0.6, c.y), Vector3(1.8, 1.6, 1.8))
				elif r < 0.06 and gfx() > 0:
					tree(b, Vector3(x + 0.5, 0, z + 0.5), rng.randf_range(0.8, 1.2))
			z += h
		x += w


static func tree(b: MeshBatch, p: Vector3, s: float = 1.0) -> void:
	b.cyl("trunk", p + Vector3(0, 1.1 * s, 0), 0.16 * s, 2.2 * s)
	b.sphere("leaf", p + Vector3(0, 3.0 * s, 0), Vector3(2.6, 2.2, 2.6) * s)
	if gfx() > 0:
		b.sphere("leaf2", p + Vector3(0.6, 3.6, 0.3) * s, Vector3(1.8, 1.6, 1.8) * s)
		b.sphere("leaf2", p + Vector3(-0.5, 3.4, -0.4) * s, Vector3(1.7, 1.5, 1.7) * s)


static func bamboo(b: MeshBatch, p: Vector3, rng: RandomNumberGenerator) -> void:
	var n := rng.randi_range(5, 9) if gfx() > 0 else 4
	for k in n:
		var off := Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
		var h := rng.randf_range(6.0, 10.0)
		var tilt := Basis(Vector3(off.z, 0, -off.x).normalized() if off.length() > 0.1 else Vector3.RIGHT, 0.12)
		b.box_basis("bamboo", tilt, p + off + tilt * Vector3(0, h * 0.5, 0), Vector3(0.12, h, 0.12))
		# tán tre: nhiều chùm lá thon dài, rủ xuống
		for j in 3:
			var hh := h * (0.55 + 0.17 * j)
			var lean := off.normalized() * (0.4 + 0.3 * j) if off.length() > 0.1 else Vector3(0.3, 0, 0)
			b.sphere("bamboo_leaf", p + off + tilt * Vector3(0, hh, 0) + lean, Vector3(1.3, 2.4 - j * 0.3, 1.3))


## Hàng tre dọc theo đoạn thẳng a -> b
static func bamboo_row(b: MeshBatch, a: Vector3, c: Vector3, gap: float, rseed: int) -> void:
	_mats()
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var d := c - a
	var l := d.length()
	var t := 0.0
	while t < l:
		bamboo(b, a + d.normalized() * t, rng)
		t += gap * rng.randf_range(0.8, 1.3)


## Nhà dân mái ngói (tâm p, hướng mặt tiền yaw)
static func house(b: MeshBatch, p: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	_mats()
	var w := rng.randf_range(6.0, 9.0)
	var d := rng.randf_range(5.0, 7.0)
	var h := rng.randf_range(3.0, 3.8)
	var bs := Basis(Vector3.UP, yaw)
	var wall := "wall_y" if rng.randf() < 0.6 else "wall_w"
	b.box_basis(wall, bs, p + Vector3(0, h * 0.5, 0), Vector3(w, h, d))
	# mái ngói 2 mái
	var roof := "roof" if rng.randf() < 0.5 else "roof2"
	var rh := 1.7
	for s: float in [-1.0, 1.0]:
		var slope := atan2(rh, d * 0.5 + 0.5)
		var rb := bs * Basis(Vector3.RIGHT, s * slope)
		var c := p + bs * Vector3(0, h + rh * 0.5, s * (d * 0.25 + 0.12))
		b.box_basis(roof, rb, c, Vector3(w + 0.8, 0.14, sqrt(pow(d * 0.5 + 0.5, 2) + rh * rh)))
	# đầu hồi
	b.box_basis(wall, bs, p + Vector3(0, h + rh * 0.35, 0), Vector3(w - 0.1, rh * 0.7, d * 0.45))
	# cửa + cửa sổ
	b.box_basis("door", bs, p + bs * Vector3(0, 1.1, d * 0.5 + 0.02), Vector3(1.2, 2.2, 0.06))
	for sx: float in [-1.0, 1.0]:
		b.box_basis("door", bs, p + bs * Vector3(sx * w * 0.3, 1.6, d * 0.5 + 0.02), Vector3(1.0, 1.0, 0.06))
	# sân gạch + tường rào thấp
	b.box_basis("concrete", bs, p + bs * Vector3(0, 0.03, d * 0.5 + 3.0), Vector3(w + 2.0, 0.06, 6.0))
	for sx: float in [-1.0, 1.0]:
		b.box_basis(wall, bs, p + bs * Vector3(sx * (w * 0.5 + 1.0), 0.6, d * 0.5 + 3.0), Vector3(0.25, 1.2, 6.0))


static func village(b: MeshBatch, center: Vector3, count: int, face_dir: Vector3, rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var yaw := atan2(face_dir.x, face_dir.z)
	var side := face_dir.rotated(Vector3.UP, PI * 0.5)
	for k in count:
		var p := center + side * (k - count * 0.5) * 13.0 - face_dir * rng.randf_range(0.0, 4.0)
		house(b, p, yaw, rng)
		if rng.randf() < 0.7:
			tree(b, p + side * 6.0 - face_dir * 4.0, rng.randf_range(0.9, 1.3))
	bamboo_row(b, center - face_dir * 12.0 - side * count * 7.0, center - face_dir * 12.0 + side * count * 7.0, 4.5, rseed + 1)


## Cột điện + dây dọc đoạn a -> c, lệch sang bên `off`
static func power_line(b: MeshBatch, a: Vector3, c: Vector3, gap: float = 40.0) -> void:
	_mats()
	var d := c - a
	var l := d.length()
	var dn := d / l
	var n := int(l / gap)
	var prev := Vector3.ZERO
	for k in n + 1:
		var p := a + dn * (k * gap)
		b.box("pole", p + Vector3(0, 4.5, 0), Vector3(0.25, 9.0, 0.25))
		b.box("pole", p + Vector3(0, 8.4, 0), Vector3(1.8, 0.12, 0.12), atan2(dn.x, dn.z) + PI * 0.5)
		if k > 0 and gfx() > 0:
			for sx: float in [-0.8, 0.0, 0.8]:
				var side := dn.rotated(Vector3.UP, PI * 0.5) * sx
				var q0 := prev + side + Vector3(0, 8.4, 0)
				var q1 := p + side + Vector3(0, 8.4, 0)
				var mid := (q0 + q1) * 0.5 - Vector3(0, 0.9, 0)
				b.strip("wire", q0, mid, 0.03, q0.y - 0.45, 0.03)
				b.strip("wire", mid, q1, 0.03, q1.y - 0.45, 0.03)
		prev = p


# ------------------------------------------------------------------ sông, cầu

## Sông chạy thẳng từ a đến c, rộng `w`. Trả về danh sách vật cản bờ (StaticBody) để xe không lao xuống sông.
static func river(parent: Node3D, b: MeshBatch, a: Vector3, c: Vector3, w: float, gaps: Array) -> void:
	_mats()
	var d := (c - a)
	d.y = 0
	var dn := d.normalized()
	var side := dn.rotated(Vector3.UP, PI * 0.5)
	b.strip("water", a, c, w, 0.015, 0.03)
	for s: float in [-1.0, 1.0]:
		var off := side * (w * 0.5 + 1.2) * s
		b.strip("bank", a + off, c + off, 2.6, 0.03, 0.05)
	# bờ chắn: chia đoạn, chừa chỗ cho cầu (gaps = các khoảng t trên đoạn a->c)
	var sb := StaticBody3D.new()
	parent.add_child(sb)
	var l := d.length()
	var cuts: Array = [0.0]
	for g in gaps:
		var gg: Vector2 = g
		cuts.append(gg.x)
		cuts.append(gg.y)
	cuts.append(l)
	for i in range(0, cuts.size(), 2):
		var t0: float = cuts[i]
		var t1: float = cuts[i + 1]
		if t1 - t0 < 1.0:
			continue
		for s: float in [-1.0, 1.0]:
			var p0 := a + dn * t0 + side * (w * 0.5 + 2.4) * s
			var p1 := a + dn * t1 + side * (w * 0.5 + 2.4) * s
			var mid := (p0 + p1) * 0.5
			b.box("concrete", mid + Vector3(0, 0.3, 0), Vector3(0.4, 0.6, t1 - t0), atan2(dn.x, dn.z))
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(0.5, 1.2, t1 - t0)
			cs.shape = bs
			cs.transform = Transform3D(Basis(Vector3.UP, atan2(dn.x, dn.z)), mid + Vector3(0, 0.6, 0))
			sb.add_child(cs)


## Cầu bắc qua sông theo hướng `dir`, tâm `c`, dài `l`, nửa rộng `hw`. Lái qua được (có lan can va chạm).
static func bridge(parent: Node3D, b: MeshBatch, c: Vector3, dir: Vector3, l: float, hw: float) -> void:
	_mats()
	var dn := dir.normalized()
	var yaw := atan2(dn.x, dn.z)
	var bs := Basis(Vector3.UP, yaw)
	var side := dn.rotated(Vector3.UP, PI * 0.5)
	var sb := StaticBody3D.new()
	parent.add_child(sb)
	var rise := 0.9
	var ramp := 9.0
	var mid_len := l
	# mặt cầu giữa
	var deck_t := 0.5
	_slab(b, sb, bs, c + Vector3(0, rise - deck_t * 0.5, 0), Vector3(hw * 2.0 + 1.0, deck_t, mid_len))
	# hai dốc lên cầu
	for s: float in [-1.0, 1.0]:
		var ang := atan2(rise, ramp)
		var rb := bs * Basis(Vector3.RIGHT, s * ang)
		var rc := c + dn * s * (mid_len * 0.5 + ramp * 0.5) + Vector3(0, rise * 0.5, 0) - rb.y * deck_t * 0.5
		_slab(b, sb, rb, rc, Vector3(hw * 2.0 + 1.0, deck_t, sqrt(ramp * ramp + rise * rise) + 0.1))
	# vạch kẻ trên cầu
	b.box_basis("rail", bs, c + Vector3(0, rise + 0.01, 0), Vector3(0.15, 0.02, mid_len))
	# lan can + trụ cầu
	for s: float in [-1.0, 1.0]:
		var o := side * (hw + 0.4) * s
		b.box_basis("rail", bs, c + o + Vector3(0, rise + 0.55, 0), Vector3(0.15, 0.12, mid_len))
		b.box_basis("rail", bs, c + o + Vector3(0, rise + 1.05, 0), Vector3(0.18, 0.15, mid_len))
		var k := -mid_len * 0.5
		while k <= mid_len * 0.5:
			b.box_basis("rail", bs, c + o + dn * k + Vector3(0, rise + 0.55, 0), Vector3(0.2, 1.1, 0.2))
			k += 2.5
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.4, 1.4, mid_len + ramp * 1.2)
		cs.shape = box
		cs.transform = Transform3D(bs, c + o + Vector3(0, rise + 0.5, 0))
		sb.add_child(cs)
	for k in [-0.3, 0.0, 0.3]:
		b.box_basis("concrete", bs, c + dn * mid_len * float(k) + Vector3(0, -0.5, 0), Vector3(hw * 1.4, 2.0, 1.4))


static func _slab(b: MeshBatch, sb: StaticBody3D, basis: Basis, pos: Vector3, size: Vector3) -> void:
	MeshBatch.mat("bridge_deck", Color(0.3, 0.31, 0.33), 0.85)
	b.box_basis("bridge_deck", basis, pos, size)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = size
	cs.shape = bx
	cs.transform = Transform3D(basis, pos)
	sb.add_child(cs)


## Cảnh nền chung: núi, mây, đồng lúa vòng quanh một vùng
static func surround(parent: Node3D, center: Vector3, inner: Rect2, outer_r: float, night: bool, rain: bool, rseed: int, extra_exclude: Array = []) -> void:
	var b := MeshBatch.new()
	b.chunk = 160.0
	var area := Rect2(center.x - outer_r, center.z - outer_r, outer_r * 2.0, outer_r * 2.0)
	var excl := [inner]
	excl.append_array(extra_exclude)
	var far := outer_r * 2.4
	var far_col := Color(0.31, 0.47, 0.21)
	match theme:
		"tea":
			tea_hills(b, area, excl, rseed)
			far_col = Color(0.24, 0.42, 0.2)
		"coast":
			coast(b, area, excl, inner, far, rseed)
			far_col = Color(0.4, 0.5, 0.26)
		"lake":
			lake_park(b, area, excl, inner, rseed)
			far_col = Color(0.33, 0.52, 0.24)
		_:
			rice_fields(b, area, excl, rseed)
	backdrop(parent, b, center, outer_r, night, rain, far_col)


## Nền xa + mặt đất đi được + núi + mây (dùng chung cho thành phố và đường đua)
static func backdrop(parent: Node3D, b: MeshBatch, center: Vector3, outer_r: float, night: bool, rain: bool, far_col: Color, mountain_r: float = -1.0) -> void:
	var far := outer_r * 2.4
	# nền xa: mảng lớn phủ kín tới chân núi
	MeshBatch._mats.erase("far_field")
	MeshBatch.mat("far_field", far_col if not night else far_col.darkened(0.65), 1.0)
	texturize("far_field", 0.08, 0.35, 0.05)
	b.box("far_field", center + Vector3(0, -0.06, 0), Vector3(far * 2.0, 0.05, far * 2.0))
	b.commit(parent)
	# nền đi được ở mọi chỗ (xe không rơi khỏi mép bản đồ)
	var gb := StaticBody3D.new()
	var gcs := CollisionShape3D.new()
	gcs.shape = WorldBoundaryShape3D.new()
	gb.add_child(gcs)
	parent.add_child(gb)
	mountains(parent, center, mountain_r if mountain_r > 0.0 else maxf(outer_r * 2.2, 420.0), night)
	clouds(parent, center, outer_r * 2.0, night, rain)


# ------------------------------------------------------------------ các bối cảnh khác

static func _theme_mats() -> void:
	_mats()
	MeshBatch.mat("tea", Color(0.2, 0.46, 0.17), 0.95)
	MeshBatch.mat("tea2", Color(0.27, 0.53, 0.2), 0.95)
	MeshBatch.mat("tea_soil", Color(0.45, 0.33, 0.22), 1.0)
	MeshBatch.mat("pine", Color(0.12, 0.3, 0.17), 0.9)
	MeshBatch.mat("sand", Color(0.86, 0.79, 0.6), 1.0)
	MeshBatch.mat("sea", Color(0.13, 0.4, 0.55), 0.06, 0.0, 0.3)
	MeshBatch.mat("sea_foam", Color(0.85, 0.92, 0.95), 0.6)
	MeshBatch.mat("palm_trunk", Color(0.5, 0.4, 0.28), 0.9)
	MeshBatch.mat("palm_leaf", Color(0.25, 0.52, 0.2), 0.9)
	MeshBatch.mat("lawn", Color(0.36, 0.58, 0.25), 1.0)
	MeshBatch.mat("lake", Color(0.14, 0.33, 0.4), 0.06, 0.0, 0.3)
	MeshBatch.mat("willow", Color(0.38, 0.6, 0.25), 0.9)
	MeshBatch.mat("flower0", Color(0.9, 0.3, 0.45), 0.9)
	MeshBatch.mat("flower1", Color(0.98, 0.8, 0.2), 0.9)
	MeshBatch.mat("flower2", Color(0.85, 0.85, 0.95), 0.9)
	MeshBatch.mat("boat", Color(0.55, 0.3, 0.15), 0.8)
	MeshBatch.mat("rock", Color(0.5, 0.48, 0.45), 0.95)
	texturize("sand", 0.3, 0.25, 0.2)
	texturize("tea_soil", 0.4, 0.3, 0.2)
	texturize("lawn", 0.25, 0.3, 0.12)


static func pine(b: MeshBatch, p: Vector3, s: float = 1.0) -> void:
	b.cyl("trunk", p + Vector3(0, 1.5 * s, 0), 0.18 * s, 3.0 * s)
	for k in 4:
		var w := (3.4 - k * 0.75) * s
		b.sphere("pine", p + Vector3(0, (2.4 + k * 1.5) * s, 0), Vector3(w, 2.2 * s, w))


static func palm(b: MeshBatch, p: Vector3, rng: RandomNumberGenerator) -> void:
	var lean := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
	var h := rng.randf_range(6.0, 9.0)
	var segs := 5
	var top := p
	for k in segs:
		var t0 := float(k) / segs
		var t1 := float(k + 1) / segs
		var a := p + Vector3(0, h * t0, 0) + lean * t0 * t0 * h * 0.3
		var c := p + Vector3(0, h * t1, 0) + lean * t1 * t1 * h * 0.3
		var dirv := (c - a)
		var bs := Basis(Vector3.UP.cross(dirv.normalized()).normalized(), Vector3.UP.angle_to(dirv.normalized())) if dirv.normalized().cross(Vector3.UP).length() > 0.01 else Basis()
		b.box_basis("palm_trunk", bs, (a + c) * 0.5, Vector3(0.32, dirv.length() + 0.05, 0.32))
		top = c
	for k in 8:
		var yaw := TAU * k / 8.0 + rng.randf() * 0.3
		var fb := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.45)
		b.box_basis("palm_leaf", fb, top + Basis(Vector3.UP, yaw) * Vector3(0, -0.2, 1.4), Vector3(0.7, 0.05, 3.2))
	b.sphere("palm_trunk", top + Vector3(0, -0.3, 0), Vector3(0.7, 0.6, 0.7))


static func willow(b: MeshBatch, p: Vector3, s: float = 1.0) -> void:
	b.cyl("trunk", p + Vector3(0, 1.4 * s, 0), 0.22 * s, 2.8 * s)
	b.sphere("willow", p + Vector3(0, 3.6 * s, 0), Vector3(4.2, 2.6, 4.2) * s)
	b.sphere("willow", p + Vector3(0, 2.4 * s, 0), Vector3(4.6, 2.8, 4.6) * s)


## Đồi chè: luống chè chạy theo hàng trên các ô, xen hàng thông
static func tea_hills(b: MeshBatch, area: Rect2, exclude: Array, rseed: int) -> void:
	_theme_mats()
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var cell := 30.0 if gfx() > 0 else 40.0
	var x := area.position.x
	while x < area.end.x:
		var z := area.position.y
		while z < area.end.y:
			var c := Vector2(x + cell * 0.5, z + cell * 0.5)
			if not _in_any(c, exclude, cell * 0.6):
				var r := rng.randf()
				if r < 0.16:
					# rừng thông nhỏ
					for k in 4:
						pine(b, Vector3(c.x + rng.randf_range(-12, 12), 0, c.y + rng.randf_range(-12, 12)), rng.randf_range(1.0, 1.6))
				else:
					b.box("tea_soil", Vector3(c.x, 0.02, c.y), Vector3(cell - 0.5, 0.04, cell - 0.5))
					var along_x := rng.randf() < 0.5
					var rows := int(cell / 1.8)
					var key := "tea" if rng.randf() < 0.6 else "tea2"
					for k in rows:
						var o := -cell * 0.5 + 0.9 + k * 1.8
						if along_x:
							b.box(key, Vector3(c.x, 0.4, c.y + o), Vector3(cell - 2.0, 0.8, 1.1))
						else:
							b.box(key, Vector3(c.x + o, 0.4, c.y), Vector3(1.1, 0.8, cell - 2.0))
					if r < 0.24:
						pine(b, Vector3(x + 1, 0, z + 1), rng.randf_range(1.1, 1.5))
			z += cell
		x += cell


## Bờ biển: cát, hàng dừa, mặt biển phía tây; phía đất liền là ruộng màu
static func coast(b: MeshBatch, area: Rect2, exclude: Array, inner: Rect2, far: float, rseed: int) -> void:
	_theme_mats()
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var shore := inner.position.x - 70.0
	var c := area.get_center()
	# biển
	b.box("sea", Vector3(shore - far * 0.5 - 30.0, 0.01, c.y), Vector3(far, 0.04, far * 3.0))
	# bãi cát + bọt sóng
	b.box("sand", Vector3(shore - 15.0, 0.02, c.y), Vector3(60.0, 0.04, area.size.y + far))
	var z := c.y - area.size.y * 0.5 - far * 0.5
	while z < c.y + area.size.y * 0.5 + far * 0.5:
		b.box("sea_foam", Vector3(shore - 45.0 + sin(z * 0.05) * 2.0, 0.035, z), Vector3(1.2, 0.02, 9.0))
		z += 9.5
	# hàng dừa dọc bờ
	z = area.position.y
	while z < area.end.y:
		if not _in_any(Vector2(shore + 5.0, z), exclude, 6.0):
			palm(b, Vector3(shore + rng.randf_range(-12.0, 12.0), 0, z), rng)
		z += rng.randf_range(7.0, 13.0)
	# thuyền thúng, thuyền gỗ
	for k in 8:
		var bp := Vector3(shore - rng.randf_range(60, 300), 0.15, c.y + rng.randf_range(-400, 400))
		b.box("boat", bp, Vector3(2.2, 0.6, 7.0), rng.randf() * TAU)
	# đất liền: ruộng + dừa rải rác
	var land := Rect2(shore + 15.0, area.position.y, area.end.x - shore - 15.0, area.size.y)
	rice_fields(b, land, exclude, rseed)
	for k in 40:
		var p := Vector2(rng.randf_range(land.position.x, land.end.x), rng.randf_range(land.position.y, land.end.y))
		if not _in_any(p, exclude, 8.0):
			palm(b, Vector3(p.x, 0, p.y), rng)


## Công viên hồ: bãi cỏ, hồ lớn, liễu rủ, bồn hoa, ghế đá
static func lake_park(b: MeshBatch, area: Rect2, exclude: Array, inner: Rect2, rseed: int) -> void:
	_theme_mats()
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	# vài hồ quanh khu, tránh vùng loại trừ
	var lakes: Array = []
	for k in 400:
		if lakes.size() >= 14:
			break
		var r := rng.randf_range(25.0, 60.0)
		var p := Vector2(rng.randf_range(area.position.x + r, area.end.x - r), rng.randf_range(area.position.y + r, area.end.y - r))
		if k % 2 == 0:
			# ưu tiên hồ sát khu đường để nhìn thấy từ xe
			var sx := 1.0 if rng.randf() < 0.5 else -1.0
			p.x = (inner.get_center().x + sx * (inner.size.x * 0.5 + r + rng.randf_range(14.0, 40.0)))
		if _in_any(p, exclude, r + 10.0):
			continue
		var ok := true
		for l in lakes:
			if p.distance_to(l[0]) < r + float(l[1]) + 20.0:
				ok = false
		if not ok:
			continue
		lakes.append([p, r])
		b.cyl("bank", Vector3(p.x, 0.05, p.y), r + 2.0, 0.06)
		b.cyl("lake", Vector3(p.x, 0.07, p.y), r, 0.06)
		b.cyl("lake", Vector3(p.x + r * 0.4, 0.07, p.y - r * 0.3), r * 0.7, 0.06)
		var n := int(r * 0.35)
		for j in n:
			var a := TAU * j / n
			var tp := Vector2(p.x, p.y) + Vector2(cos(a), sin(a)) * (r + 5.0)
			if not _in_any(tp, exclude, 4.0):
				willow(b, Vector3(tp.x, 0, tp.y), rng.randf_range(0.9, 1.3))
	# cây, bồn hoa, ghế rải khắp bãi cỏ
	var cell := 22.0
	var x := area.position.x
	while x < area.end.x:
		var z := area.position.y
		while z < area.end.y:
			var cc := Vector2(x + cell * 0.5, z + cell * 0.5)
			if not _in_any(cc, exclude, cell * 0.6):
				b.box("lawn", Vector3(cc.x, 0.02, cc.y), Vector3(cell + 0.05, 0.04, cell + 0.05))
			var c := Vector2(x + rng.randf_range(4, cell - 4), z + rng.randf_range(4, cell - 4))
			var in_lake := false
			for l in lakes:
				if c.distance_to(l[0]) < float(l[1]) * 1.6 + 6.0:
					in_lake = true
			if not in_lake and not _in_any(c, exclude, 6.0):
				var r := rng.randf()
				if r < 0.35:
					tree(b, Vector3(c.x, 0, c.y), rng.randf_range(0.9, 1.4))
				elif r < 0.5:
					b.cyl("flower%d" % rng.randi_range(0, 2), Vector3(c.x, 0.15, c.y), rng.randf_range(1.2, 2.2), 0.3)
				elif r < 0.56:
					b.box("door", Vector3(c.x, 0.25, c.y), Vector3(1.8, 0.12, 0.5), rng.randf() * TAU)
			z += cell
		x += cell
