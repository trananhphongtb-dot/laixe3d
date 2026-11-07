class_name City
extends Node3D
## Thành phố dạng lưới: đường 2 chiều (đi bên phải), ngã tư có đèn, nhà cửa, xe AI.

const N := 4                 # số nút mỗi cạnh
const B := 220.0             # khoảng cách trung bình giữa 2 ngã tư (thực tế mỗi khúc dài ngắn khác nhau, xem xs/zs)
const RW := 6.5              # nửa bề rộng mặt đường
const LANE := 1.75           # tâm làn xe chạy cách tim đường
const PARK := 5.0            # tâm làn đỗ xe
const STOP_D := 9.0          # vạch dừng cách tâm ngã tư
const DIRS := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
const GAPS := [150.0, 190.0, 240.0, 300.0, 360.0]
const URBAN := ["res", "school", "market", "gas", "factory", "temple"]
# Tỉ lệ các loại khối theo kiểu cảnh: phố thì nhiều nhà, quê thì nhiều ruộng và rừng
const MIX := {
	"country": {"field": 34, "forest": 16, "village": 18, "res": 12, "park": 6, "market": 4, "gas": 4, "temple": 6},
	"tea": {"hill": 34, "forest": 22, "village": 14, "field": 8, "res": 10, "park": 4, "gas": 4, "temple": 4},
	"coast": {"res": 30, "park": 14, "village": 14, "market": 8, "forest": 10, "field": 8, "gas": 6, "school": 6, "temple": 4},
	"lake": {"park": 24, "res": 22, "forest": 16, "village": 10, "school": 8, "temple": 8, "field": 6, "market": 3, "gas": 3},
}

var batch := MeshBatch.new()
var xs: Array = []               # toạ độ x của các hàng ngã tư (khoảng cách không đều nhau)
var zs: Array = []               # toạ độ z của các cột ngã tư
var EX: float = 0.0              # mép đông
var EZ: float = 0.0              # mép nam
var kinds: Dictionary = {}       # Vector2i (khối) -> loại khối
var lit: Dictionary = {}         # Vector2i (nút) -> có đèn tín hiệu
var layout_seed: int = -1        # < 0: ngẫu nhiên mỗi lần chơi
var night: bool = false
var lights: Dictionary = {}      # Vector2i -> {mats:[ns, ew], t, phase, offset}
var ai_cars: Array = []
var solid_zones: Array = []      # đoạn vạch liền (cấm lấn sang làn trái): {"alongx", "c", "a", "b"}
var obstacles: Array = []        # node có global_position cần né (xe đỗ...)
var player: Node3D
var _rng := RandomNumberGenerator.new()

const PHASES := [["G", "R", 9.0], ["Y", "R", 3.0], ["R", "R", 1.5], ["R", "G", 9.0], ["R", "Y", 3.0], ["R", "R", 1.5]]


func _init(p_night: bool = false, p_seed: int = -1) -> void:
	night = p_night
	layout_seed = p_seed


func _ready() -> void:
	_rng.seed = 2024
	batch.chunk = 160.0
	_mats()
	_layout()
	_build()
	Scenery.texturize("c_asph", 0.35, 0.3, 0.25)
	Scenery.texturize("c_walk", 0.6, 0.3, 0.3)
	batch.commit(self)


func _mats() -> void:
	# vật liệu phụ thuộc ngày/đêm: tạo lại mỗi lần
	for k in ["c_lamp", "win", "far_field"]:
		MeshBatch._mats.erase(k)
	MeshBatch.mat("c_asph", Color(0.17, 0.18, 0.2), 0.8)
	MeshBatch.mat("c_line", Color(0.92, 0.92, 0.92), 0.6)
	MeshBatch.mat("c_yline", Color(0.98, 0.78, 0.1), 0.6)
	MeshBatch.mat("c_walk", Color(0.6, 0.58, 0.55), 0.9)
	MeshBatch.mat("c_curb", Color(0.75, 0.74, 0.72), 0.9)
	MeshBatch.mat("trunk", Color(0.36, 0.25, 0.16), 0.9)
	MeshBatch.mat("leaf", Color(0.2, 0.45, 0.18), 0.9)
	MeshBatch.mat("c_lamp_pole", Color(0.3, 0.32, 0.35), 0.5, 0.0, 0.5)
	MeshBatch.mat("c_lamp", Color(1.0, 0.85, 0.55), 0.5, 3.0 if night else 0.3)
	MeshBatch.mat("c_wall_border", Color(0.55, 0.55, 0.52), 0.9)
	MeshBatch.mat("c_sign_red", Color(0.85, 0.1, 0.1), 0.6)
	MeshBatch.mat("c_sign_white", Color(0.96, 0.96, 0.96), 0.6)
	MeshBatch.mat("bund_road", Color(0.48, 0.44, 0.32), 1.0)
	var palette := [Color(0.85, 0.8, 0.7), Color(0.7, 0.75, 0.8), Color(0.9, 0.88, 0.85), Color(0.75, 0.6, 0.5),
		Color(0.6, 0.65, 0.6), Color(0.95, 0.9, 0.75), Color(0.5, 0.55, 0.65)]
	for i in palette.size():
		MeshBatch.mat("bld%d" % i, palette[i], 0.85)
	MeshBatch.mat("win", Color(0.2, 0.28, 0.38) if not night else Color(1.0, 0.85, 0.5), 0.2, 1.5 if night else 0.0, 0.3)


func node_pos(i: int, j: int) -> Vector3:
	return Vector3(xs[i], 0, zs[j])


## Sinh khoảng cách giữa các ngã tư (khúc ngắn khúc dài), loại khối và nút có đèn
func _layout() -> void:
	var rng := RandomNumberGenerator.new()
	if layout_seed >= 0:
		rng.seed = layout_seed
	else:
		rng.randomize()
	xs = _gaps_axis(rng)
	zs = _gaps_axis(rng)
	EX = float(xs[N - 1])
	EZ = float(zs[N - 1])
	# loại khối theo kiểu cảnh đang chọn
	var mix: Dictionary = MIX.get(Scenery.theme, MIX["country"])
	var total := 0
	for k in mix.keys():
		total += int(mix[k])
	for i in N - 1:
		for j in N - 1:
			var r := rng.randi_range(0, total - 1)
			var kind := "res"
			for k in mix.keys():
				r -= int(mix[k])
				if r < 0:
					kind = String(k)
					break
			kinds[Vector2i(i, j)] = kind
	kinds[Vector2i(0, 0)] = "res" if Scenery.theme != "tea" else "village"
	# đèn tín hiệu chỉ đặt ở nơi có khu dân cư; đường quê thì thưa đèn
	var n_lit := 0
	for i in N:
		for j in N:
			var urban := 0
			for dx in [-1, 0]:
				for dz in [-1, 0]:
					var bk := Vector2i(i + dx, j + dz)
					if kinds.has(bk) and URBAN.has(kinds[bk]):
						urban += 1
			var on := urban >= 2
			lit[Vector2i(i, j)] = on
			if on:
				n_lit += 1
	if n_lit < 3:
		for nd in [Vector2i(1, 1), Vector2i(2, 2), Vector2i(1, 2)]:
			lit[nd] = true


func _gaps_axis(rng: RandomNumberGenerator) -> Array:
	var g: Array = []
	for i in N - 1:
		g.append(float(GAPS[rng.randi_range(0, GAPS.size() - 1)]))
	# luôn có cả khúc ngắn lẫn khúc dài
	var mx := -1.0
	var mn := 1e9
	for v in g:
		mx = maxf(mx, float(v))
		mn = minf(mn, float(v))
	if mx < 300.0:
		g[rng.randi_range(0, g.size() - 1)] = 330.0
	if mn > 200.0:
		var k := rng.randi_range(0, g.size() - 1)
		if float(g[k]) < 320.0:
			g[k] = 160.0
		else:
			g[(k + 1) % g.size()] = 160.0
	var a: Array = [0.0]
	for v in g:
		a.append(float(a[a.size() - 1]) + float(v))
	return a


func edge_len(a: Vector2i, d: Vector3) -> float:
	var b := a + Vector2i(int(d.x), int(d.z))
	return node_pos(a.x, a.y).distance_to(node_pos(b.x, b.y))


## Toạ độ đường lưới gần nhất (để nhận diện đi sai làn)
func snap_x(x: float) -> float:
	var best := float(xs[0])
	for v in xs:
		if absf(float(v) - x) < absf(best - x):
			best = float(v)
	return best


func snap_z(z: float) -> float:
	var best := float(zs[0])
	for v in zs:
		if absf(float(v) - z) < absf(best - z):
			best = float(v)
	return best


func node_ok(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < N and j < N


static func right_of(d: Vector3) -> Vector3:
	return d.rotated(Vector3.UP, -PI * 0.5)


func _build() -> void:
	var center := Vector3(EX * 0.5, 0, EZ * 0.5)
	EnvBuilder.ground(self, Vector2(EX + 160, EZ + 160), center, Color(0.29, 0.42, 0.22) if not night else Color(0.12, 0.18, 0.1))
	# Đường
	for i in N:
		for j in N:
			var p := node_pos(i, j)
			batch.box("c_asph", p + Vector3(0, -0.005, 0), Vector3(RW * 2, 0.03, RW * 2))
			if node_ok(i + 1, j):
				_road(p, node_pos(i + 1, j), lit[Vector2i(i, j)] and lit[Vector2i(i + 1, j)], i * 7 + j)
			if node_ok(i, j + 1):
				_road(p, node_pos(i, j + 1), lit[Vector2i(i, j)] and lit[Vector2i(i, j + 1)], i * 5 + j + 40)
			var count := 0
			for d: Vector3 in DIRS:
				var nb := Vector2i(i, j) + Vector2i(int(d.x), int(d.z))
				if node_ok(nb.x, nb.y):
					count += 1
			if count >= 3 and lit[Vector2i(i, j)]:
				_intersection(i, j)
	# Khu nhà / ruộng / rừng
	var bsb := StaticBody3D.new()
	add_child(bsb)
	for i in N - 1:
		for j in N - 1:
			var a := node_pos(i, j)
			var c := node_pos(i + 1, j + 1)
			var m := RW + 3.2
			CityBlocks.build(String(kinds[Vector2i(i, j)]), self, batch, bsb, a.x + m, c.x - m, a.z + m, c.z - m, _rng)
	_outskirts()
	# Tường bao (phía đông mở ra ngoại ô)
	var sb := StaticBody3D.new()
	add_child(sb)
	var gp := 16.0
	var z1: float = zs[1]
	var z2: float = zs[2]
	var walls := [
		[Vector3(-30, 1.5, EZ * 0.5), Vector3(1, 3, EZ + 60)],
		[Vector3(EX * 0.5, 1.5, -30), Vector3(EX + 60, 3, 1)],
		[Vector3(EX * 0.5, 1.5, EZ + 30), Vector3(EX + 60, 3, 1)],
		# phía đông thành phố: chừa 2 lối ra ở z = zs[1] và z = zs[2]
		_wall_z(EX + 30, -30, z1 - gp),
		_wall_z(EX + 30, z1 + gp, z2 - gp),
		_wall_z(EX + 30, z2 + gp, EZ + 30),
		# rào quanh vùng ngoại ô
		[Vector3((EX + 30 + OUT_X + 40) * 0.5, 1.0, -60), Vector3(OUT_X + 40 - EX - 30, 2, 1)],
		[Vector3((EX + 30 + OUT_X + 40) * 0.5, 1.0, EZ + 60), Vector3(OUT_X + 40 - EX - 30, 2, 1)],
		[Vector3(OUT_X + 40, 1.0, EZ * 0.5), Vector3(1, 2, EZ + 120)],
		_wall_z(EX + 30, -60, -30),
		_wall_z(EX + 30, EZ + 30, EZ + 60),
	]
	for w in walls:
		var c: Vector3 = w[0]
		var sz: Vector3 = w[1]
		batch.box("c_wall_border", c, sz)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = sz
		cs.shape = bs
		cs.position = c
		sb.add_child(cs)


func _wall_z(x: float, za: float, zb: float) -> Array:
	return [Vector3(x, 1.5, (za + zb) * 0.5), Vector3(1, 3, zb - za)]


## Ngoại ô: đường quê vòng qua đồng lúa, sông và 2 cây cầu, làng mái ngói, cột điện.
const RIVER_W := 22.0
var EDGE: float = 0.0              # mép đông thành phố
var RIVER_X: float = 0.0
var OUT_X: float = 0.0


func _rural_road(a: Vector3, b: Vector3, hw: float = 4.0, skip: Array = []) -> void:
	var d := (b - a)
	var l := d.length()
	var dn := d / l
	var r := right_of(dn)
	# chia đoạn để bỏ qua phần cầu
	var cuts: Array = [0.0]
	for sk in skip:
		var v: Vector2 = sk
		cuts.append(v.x)
		cuts.append(v.y)
	cuts.append(l)
	for i in range(0, cuts.size(), 2):
		var t0: float = cuts[i]
		var t1: float = cuts[i + 1]
		if t1 - t0 < 0.5:
			continue
		var p0 := a + dn * t0
		var p1 := a + dn * t1
		batch.strip("c_asph", p0, p1, hw * 2.0, -0.005, 0.03)
		batch.strip("bund_road", p0 + r * (hw + 0.8), p1 + r * (hw + 0.8), 1.6, -0.01, 0.03)
		batch.strip("bund_road", p0 - r * (hw + 0.8), p1 - r * (hw + 0.8), 1.6, -0.01, 0.03)
		for sx: float in [-1.0, 1.0]:
			batch.strip("c_line", p0 + r * (hw - 0.2) * sx, p1 + r * (hw - 0.2) * sx, 0.15, 0.012, 0.02)
		var u := t0 + 2.0
		while u < t1 - 3.0:
			batch.strip("c_line", a + dn * u, a + dn * minf(u + 3.0, t1), 0.14, 0.012, 0.02)
			u += 9.0


func _outskirts() -> void:
	EDGE = EX
	RIVER_X = EDGE + 200.0
	OUT_X = EDGE + 360.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var z1: float = zs[1]
	var z2: float = zs[2]
	var gap := Vector2(RIVER_X - RIVER_W * 0.5 - 13.0 - EDGE, RIVER_X + RIVER_W * 0.5 + 13.0 - EDGE)
	# 2 đường ngang ra ngoại ô + đường dọc nối 2 đầu
	_rural_road(Vector3(EDGE + RW, 0, z1), Vector3(OUT_X, 0, z1), 4.0, [gap - Vector2(RW, RW)])
	_rural_road(Vector3(EDGE + RW, 0, z2), Vector3(OUT_X, 0, z2), 4.0, [gap - Vector2(RW, RW)])
	batch.box("c_asph", Vector3(OUT_X, -0.005, z1), Vector3(8, 0.03, 8))
	batch.box("c_asph", Vector3(OUT_X, -0.005, z2), Vector3(8, 0.03, 8))
	_rural_road(Vector3(OUT_X, 0, z1 + 4.0), Vector3(OUT_X, 0, z2 - 4.0), 4.0)
	# lối vào ngã tư phía đông (vạch dừng, vạch người đi bộ, đèn)
	for j in [1, 2]:
		_east_approach(N - 1, j)
	# sông + cầu
	var sc := Node3D.new()
	add_child(sc)
	var sbatch := MeshBatch.new()
	sbatch.chunk = 160.0
	Scenery.river(sc, sbatch, Vector3(RIVER_X, 0, -60), Vector3(RIVER_X, 0, EZ + 60), RIVER_W,
		[Vector2(z1 + 60 - 7.0, z1 + 60 + 7.0), Vector2(z2 + 60 - 7.0, z2 + 60 + 7.0)])
	Scenery.bridge(sc, sbatch, Vector3(RIVER_X, 0, z1), Vector3(1, 0, 0), RIVER_W + 6.0, 4.2)
	Scenery.bridge(sc, sbatch, Vector3(RIVER_X, 0, z2), Vector3(1, 0, 0), RIVER_W + 6.0, 4.2)
	# hàng tre dọc bờ sông, làng mái ngói, cột điện, cây ven đường
	Scenery.bamboo_row(sbatch, Vector3(RIVER_X - 18, 0, -40), Vector3(RIVER_X - 18, 0, z1 - 14), 6.0, 3)
	Scenery.bamboo_row(sbatch, Vector3(RIVER_X + 18, 0, z2 + 14), Vector3(RIVER_X + 18, 0, EZ + 50), 6.0, 4)
	Scenery.village(sbatch, Vector3(RIVER_X + 90, 0, z1 - 20), 4, Vector3(0, 0, 1), 11)
	Scenery.village(sbatch, Vector3(RIVER_X - 100, 0, z2 + 22), 3, Vector3(0, 0, -1), 12)
	Scenery.village(sbatch, Vector3(RIVER_X + 90, 0, z2 + 24), 3, Vector3(0, 0, -1), 13)
	Scenery.power_line(sbatch, Vector3(EDGE + 40, 0, z1 - 7.5), Vector3(OUT_X - 6, 0, z1 - 7.5), 38.0)
	Scenery.power_line(sbatch, Vector3(OUT_X + 7.5, 0, z1), Vector3(OUT_X + 7.5, 0, z2), 40.0)
	var x := EDGE + 50.0
	while x < OUT_X - 10:
		if absf(x - RIVER_X) > 25.0:
			Scenery.tree(sbatch, Vector3(x, 0, z2 - 7.5), rng.randf_range(0.8, 1.2))
		x += rng.randf_range(16.0, 26.0)
	sbatch.commit(sc)
	# đồng lúa, núi, mây quanh cả thành phố và ngoại ô
	var inner := Rect2(-40, -40, EX + 80, EZ + 80)
	var excl := [inner, Rect2(EDGE, z1 - 9, OUT_X - EDGE + 10, 18), Rect2(EDGE, z2 - 9, OUT_X - EDGE + 10, 18),
		Rect2(OUT_X - 9, z1 - 9, 18, z2 - z1 + 18), Rect2(RIVER_X - 20, -400, 40, EZ + 800),
		Rect2(RIVER_X + 50, z1 - 34, 90, 26), Rect2(RIVER_X - 130, z2 + 8, 70, 26), Rect2(RIVER_X + 50, z2 + 10, 80, 26)]
	var rr := maxf(EX + 600.0, EZ + 420.0) * 0.5
	Scenery.surround(self, Vector3(EX * 0.5 + 210, 0, EZ * 0.5), inner, rr, night, Scenery.cur_rain, 21, excl)


func _east_approach(i: int, j: int) -> void:
	if not lights.has(Vector2i(i, j)):
		return
	var p := node_pos(i, j)
	var d := Vector3(1, 0, 0)
	var r := right_of(d)
	var stop_c := p + d * STOP_D
	batch.strip("c_line", stop_c, stop_c - r * (LANE * 2.0), 0.4, 0.014, 0.02)
	for k in 9:
		var zp := p + d * (RW + 1.2) + r * (-RW + 0.8 + k * 1.45)
		batch.strip("c_line", zp - d * 1.0, zp + d * 1.0, 0.55, 0.013, 0.02)
	if lights.has(Vector2i(i, j)):
		var info: Dictionary = lights[Vector2i(i, j)]
		var mats: Array = info["mats"]
		TrafficLight.build(batch, self, p + d * (STOP_D + 0.5) - r * (RW + 0.9), d, mats[1], 4.0, mats[1])
		TrafficLight.build(batch, self, p - d * (RW + 2.0) - r * (RW + 0.9), d, mats[1], 2.6)


func _road(a: Vector3, b: Vector3, urban: bool = true, rseed: int = 0) -> void:
	var d := (b - a).normalized()
	var r := right_of(d)
	var s := a + d * RW
	var e := b - d * RW
	batch.strip("c_asph", s, e, RW * 2, -0.005, 0.03)
	# vạch tim đường đứt đoạn, liền gần ngã tư; thêm một đoạn vạch đôi liền ở giữa (cấm lấn làn)
	var length := s.distance_to(e)
	var z0 := -1.0
	var z1 := -1.0
	if rseed % 2 == 0 and length > 190.0:
		z0 = length * 0.36
		z1 = z0 + minf(75.0, length * 0.3)
		for off: float in [-0.14, 0.14]:
			batch.strip("c_yline", s + d * z0 + r * off, s + d * z1 + r * off, 0.12, 0.012, 0.02)
		var along_x := absf(d.x) > 0.5
		var p0 := s + d * z0
		var p1 := s + d * z1
		if along_x:
			solid_zones.append({"alongx": true, "c": a.z, "a": minf(p0.x, p1.x), "b": maxf(p0.x, p1.x)})
		else:
			solid_zones.append({"alongx": false, "c": a.x, "a": minf(p0.z, p1.z), "b": maxf(p0.z, p1.z)})
	var u := 0.0
	while u < length:
		var solid := u < 14.0 or u > length - 14.0
		var seg := 3.0 if not solid else 2.0
		var in_zone := z0 >= 0.0 and u >= z0 - 2.0 and u <= z1
		if not in_zone:
			batch.strip("c_yline" if solid else "c_line", s + d * u, s + d * minf(u + seg, length), 0.15, 0.012, 0.02)
		u += seg if solid else 7.0
	# biển tốc độ tối đa cho từng chiều đi
	var lim := 50 if urban else 60
	_speed_sign(s + d * 28.0 + r * (RW + 1.3), -d, lim)
	_speed_sign(e - d * 28.0 - r * (RW + 1.3), d, lim)
	if not urban:
		_country_edge(s, e, d, r, length, rseed)
		return
	# vạch làn đỗ xe
	for side: float in [-1.0, 1.0]:
		var off := r * (LANE * 2.0 + 0.1) * side
		var uu := 16.0
		while uu < length - 16.0:
			batch.strip("c_line", s + d * uu + off, s + d * (uu + 1.5) + off, 0.12, 0.012, 0.02)
			uu += 4.0
	# vỉa hè hai bên
	for side: float in [-1.0, 1.0]:
		var off := r * (RW + 1.6) * side
		batch.strip("c_walk", s - d * 1.6 + off, e + d * 1.6 + off, 3.2, 0.06, 0.14)
		batch.strip("c_curb", s + r * (RW + 0.1) * side, e + r * (RW + 0.1) * side, 0.2, 0.08, 0.16)
		# cây + đèn đường
		var k := 10.0
		while k < length - 8.0:
			var tp := s + d * k + r * (RW + 2.4) * side
			if int(k) % 20 < 10:
				batch.cyl("trunk", tp + Vector3(0, 1.0, 0), 0.14, 2.0)
				batch.sphere("leaf", tp + Vector3(0, 2.9, 0), Vector3(2.4, 2.2, 2.4))
			else:
				batch.cyl("c_lamp_pole", tp + Vector3(0, 3.2, 0), 0.07, 6.4)
				batch.box("c_lamp", tp + Vector3(0, 6.4, 0) - r * side * 0.9, Vector3(0.5, 0.15, 0.3), atan2(d.x, d.z))
			k += 10.0


func _speed_sign(pos: Vector3, toward: Vector3, limit: int) -> void:
	var yaw := atan2(toward.x, toward.z)
	batch.cyl("c_lamp_pole", pos + Vector3(0, 1.3, 0), 0.05, 2.6)
	batch.box("c_sign_red", pos + Vector3(0, 2.7, 0), Vector3(0.85, 0.85, 0.05), yaw)
	batch.box("c_sign_white", pos + Vector3(0, 2.7, 0) + toward * 0.03, Vector3(0.6, 0.6, 0.05), yaw)
	var lb := Label3D.new()
	lb.text = str(limit)
	lb.font_size = 96
	lb.pixel_size = 0.0065
	lb.modulate = Color(0.05, 0.05, 0.06)
	lb.outline_size = 0
	lb.shaded = false
	lb.position = pos + Vector3(0, 2.7, 0) + toward * 0.065
	lb.rotation.y = yaw
	lb.visibility_range_end = 130.0
	add_child(lb)


## Giới hạn tốc độ (km/h) tại vị trí p theo loại đường: trong khu đông nhà 50, ngoài đường 60
func speed_limit_at(p: Vector3) -> int:
	var xl := snap_x(p.x)
	var zl := snap_z(p.z)
	var i := xs.find(xl)
	var j := zs.find(zl)
	if i < 0 or j < 0:
		return 60
	if absf(p.x - xl) <= absf(p.z - zl):
		var k := 0
		while k < N - 2 and p.z > float(zs[k + 1]):
			k += 1
		return 50 if lit.get(Vector2i(i, k), false) and lit.get(Vector2i(i, k + 1), false) else 60
	var k2 := 0
	while k2 < N - 2 and p.x > float(xs[k2 + 1]):
		k2 += 1
	return 50 if lit.get(Vector2i(k2, j), false) and lit.get(Vector2i(k2 + 1, j), false) else 60


## Có đang nằm trong đoạn vạch liền không? Trả về toạ độ tim đường nếu có (còn không trả -1e9)
func solid_center(p: Vector3) -> Dictionary:
	for z in solid_zones:
		if bool(z["alongx"]):
			if absf(p.z - float(z["c"])) < RW and p.x > float(z["a"]) and p.x < float(z["b"]):
				return z
		elif absf(p.x - float(z["c"])) < RW and p.z > float(z["a"]) and p.z < float(z["b"]):
			return z
	return {}


## Đường ngoài phố: lề đất hai bên, cây mọc thưa tự nhiên (không vỉa hè, không đèn đường)
func _country_edge(s: Vector3, e: Vector3, d: Vector3, r: Vector3, length: float, rseed: int) -> void:
	for side: float in [-1.0, 1.0]:
		batch.strip("bund_road", s + r * (RW + 0.8) * side, e + r * (RW + 0.8) * side, 1.6, -0.01, 0.03)
		batch.strip("c_line", s + r * (RW - 0.3) * side, e + r * (RW - 0.3) * side, 0.15, 0.012, 0.02)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5000 + rseed
	for side: float in [-1.0, 1.0]:
		var k := rng.randf_range(10.0, 22.0)
		while k < length - 10.0:
			var tp := s + d * k + r * (RW + rng.randf_range(2.5, 9.0)) * side
			if Scenery.theme == "tea" and rng.randf() < 0.5:
				Scenery.pine(batch, tp, rng.randf_range(0.9, 1.4))
			else:
				Scenery.tree(batch, tp, rng.randf_range(0.8, 1.3))
			k += rng.randf_range(14.0, 34.0)
	# thỉnh thoảng có hàng cột điện chạy dọc đường
	if rseed % 3 == 0:
		Scenery.power_line(batch, s + r * (RW + 4.5), e + r * (RW + 4.5), 40.0)


func _intersection(i: int, j: int) -> void:
	var p := node_pos(i, j)
	var mats := [TrafficLight.make_mats(), TrafficLight.make_mats()]
	var info := {"mats": mats, "offset": _rng.randf_range(0.0, 27.0)}
	lights[Vector2i(i, j)] = info
	for d: Vector3 in DIRS:
		var nb := Vector2i(i, j) + Vector2i(int(d.x), int(d.z))
		if not node_ok(nb.x, nb.y):
			continue
		# d: hướng từ ngã tư đi ra. Xe đi vào ngã tư theo hướng -d.
		var r := right_of(d)
		# vạch dừng trên làn đi vào (bên phải của hướng -d = bên trái của d)
		var stop_c := p + d * STOP_D
		batch.strip("c_line", stop_c - r * 0.0, stop_c - r * (LANE * 2.0), 0.4, 0.014, 0.02)
		# vạch người đi bộ
		for k in 9:
			var zp := p + d * (RW + 1.2) + r * (-RW + 0.8 + k * 1.45)
			batch.strip("c_line", zp - d * 1.0, zp + d * 1.0, 0.55, 0.013, 0.02)
		# cột đèn ở góc phải của làn đi vào
		# 2 cột cho mỗi hướng: cột gần ở góc phải trước vạch dừng, cột xa thấp ở góc phải bên kia ngã tư
		# (dừng sát vạch vẫn nhìn thấy qua kính lái). Cột gần cũng gắn mặt đèn quay ngược cho hướng đối diện.
		var axis := 0 if absf(d.z) > 0.5 else 1
		var pole := p + d * (STOP_D + 0.5) - r * (RW + 0.9)
		var opp := Vector2i(i, j) - Vector2i(int(d.x), int(d.z))
		TrafficLight.build(batch, self, pole, d, mats[axis], 4.0, mats[axis] if node_ok(opp.x, opp.y) else {})
		TrafficLight.build(batch, self, p - d * (RW + 2.0) - r * (RW + 0.9), d, mats[axis], 2.6)


# ------------------------------------------------------------------ đèn tín hiệu

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for key in lights.keys():
		var info: Dictionary = lights[key]
		var ph := _phase_at(t + float(info["offset"]))
		if info.get("last", -1) != ph:
			info["last"] = ph
			var mats: Array = info["mats"]
			TrafficLight.set_state(mats[0], PHASES[ph][0])
			TrafficLight.set_state(mats[1], PHASES[ph][1])


func _phase_at(t: float) -> int:
	var cyc := 0.0
	for p in PHASES:
		cyc += float(p[2])
	var x := fmod(t, cyc)
	for i in PHASES.size():
		x -= float(PHASES[i][2])
		if x < 0.0:
			return i
	return 0


## Trạng thái đèn cho xe đi theo hướng `move_dir` tại ngã tư `n`. "" nếu không có đèn.
func light_for(n: Vector2i, move_dir: Vector3) -> String:
	if not lights.has(n):
		return ""
	var info: Dictionary = lights[n]
	var ph: int = info.get("last", 0)
	var axis := 0 if absf(move_dir.z) > 0.5 else 1
	return PHASES[ph][axis]


func nearest_node(p: Vector3) -> Vector2i:
	var bi := 0
	var bj := 0
	for i in N:
		if absf(float(xs[i]) - p.x) < absf(float(xs[bi]) - p.x):
			bi = i
		if absf(float(zs[i]) - p.z) < absf(float(zs[bj]) - p.z):
			bj = i
	return Vector2i(bi, bj)


## Số xe AI nên có: ngoài phố vắng hơn
func traffic_for(count: int) -> int:
	var n := 0
	for v in lit.values():
		if v:
			n += 1
	var f := 0.55 + 0.45 * float(n) / float(N * N)
	return maxi(4, roundi(float(count) * f))


# ------------------------------------------------------------------ xe AI

func spawn_traffic(count: int) -> void:
	var edges: Array = []
	for i in N:
		for j in N:
			for d: Vector3 in DIRS:
				var nb := Vector2i(i, j) + Vector2i(int(d.x), int(d.z))
				if node_ok(nb.x, nb.y):
					edges.append([Vector2i(i, j), d])
	edges.shuffle()
	var styles := ["sedan", "hatch", "suv", "pickup", "sedan", "hatch"]
	var kinds := ["car", "moto", "car", "truck", "moto", "car", "bike", "car", "moto", "car", "moto", "truck"]
	for k in mini(count, edges.size()):
		var e: Array = edges[k]
		var car := AiCar.new()
		var spec: Dictionary = Game.CARS[styles[k % styles.size()]]
		var col: Color = Game.COLORS[_rng.randi_range(0, Game.COLORS.size() - 1)]
		car.setup(self, spec, col, e[0], e[1], _rng.randf_range(0.15, 0.6), kinds[k % kinds.size()])
		add_child(car)
		ai_cars.append(car)


## Vị trí điểm làn xe chạy trên cạnh từ nút a theo hướng d, ở khoảng cách u từ a.
func lane_point(a: Vector2i, d: Vector3, u: float) -> Vector3:
	return node_pos(a.x, a.y) + d * u + right_of(d) * LANE


func park_spot(a: Vector2i, d: Vector3, u: float) -> Vector3:
	return node_pos(a.x, a.y) + d * u + right_of(d) * PARK
