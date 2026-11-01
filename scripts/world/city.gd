class_name City
extends Node3D
## Thành phố dạng lưới: đường 2 chiều (đi bên phải), ngã tư có đèn, nhà cửa, xe AI.

const N := 4                 # số nút mỗi cạnh
const B := 120.0             # khoảng cách giữa 2 ngã tư
const RW := 6.5              # nửa bề rộng mặt đường
const LANE := 1.75           # tâm làn xe chạy cách tim đường
const PARK := 5.0            # tâm làn đỗ xe
const STOP_D := 9.0          # vạch dừng cách tâm ngã tư
const DIRS := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]

var batch := MeshBatch.new()
var night: bool = false
var lights: Dictionary = {}      # Vector2i -> {mats:[ns, ew], t, phase, offset}
var ai_cars: Array = []
var obstacles: Array = []        # node có global_position cần né (xe đỗ...)
var player: Node3D
var _rng := RandomNumberGenerator.new()

const PHASES := [["G", "R", 9.0], ["Y", "R", 3.0], ["R", "R", 1.5], ["R", "G", 9.0], ["R", "Y", 3.0], ["R", "R", 1.5]]


func _init(p_night: bool = false) -> void:
	night = p_night


func _ready() -> void:
	_rng.seed = 2024
	_mats()
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
	var palette := [Color(0.85, 0.8, 0.7), Color(0.7, 0.75, 0.8), Color(0.9, 0.88, 0.85), Color(0.75, 0.6, 0.5),
		Color(0.6, 0.65, 0.6), Color(0.95, 0.9, 0.75), Color(0.5, 0.55, 0.65)]
	for i in palette.size():
		MeshBatch.mat("bld%d" % i, palette[i], 0.85)
	MeshBatch.mat("win", Color(0.2, 0.28, 0.38) if not night else Color(1.0, 0.85, 0.5), 0.2, 1.5 if night else 0.0, 0.3)


func node_pos(i: int, j: int) -> Vector3:
	return Vector3(i * B, 0, j * B)


func node_ok(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < N and j < N


static func right_of(d: Vector3) -> Vector3:
	return d.rotated(Vector3.UP, -PI * 0.5)


func _build() -> void:
	var size := (N - 1) * B
	var center := Vector3(size * 0.5, 0, size * 0.5)
	EnvBuilder.ground(self, Vector2(size + 160, size + 160), center, Color(0.29, 0.42, 0.22) if not night else Color(0.12, 0.18, 0.1))
	# Đường
	for i in N:
		for j in N:
			var p := node_pos(i, j)
			batch.box("c_asph", p + Vector3(0, -0.005, 0), Vector3(RW * 2, 0.03, RW * 2))
			if node_ok(i + 1, j):
				_road(p, node_pos(i + 1, j))
			if node_ok(i, j + 1):
				_road(p, node_pos(i, j + 1))
			var count := 0
			for d: Vector3 in DIRS:
				var nb := Vector2i(i, j) + Vector2i(int(d.x), int(d.z))
				if node_ok(nb.x, nb.y):
					count += 1
			if count >= 3:
				_intersection(i, j)
	# Khu nhà
	var bsb := StaticBody3D.new()
	add_child(bsb)
	for i in N - 1:
		for j in N - 1:
			var a := node_pos(i, j)
			var c := node_pos(i + 1, j + 1)
			var m := RW + 3.2
			CityBlocks.build(CityBlocks.KINDS.get(Vector2i(i, j), "res"), self, batch, bsb, a.x + m, c.x - m, a.z + m, c.z - m, _rng)
	_outskirts()
	# Tường bao (phía đông mở ra ngoại ô)
	var sb := StaticBody3D.new()
	add_child(sb)
	var E := size
	var gp := 16.0
	var walls := [
		[Vector3(-30, 1.5, E * 0.5), Vector3(1, 3, E + 60)],
		[Vector3(E * 0.5, 1.5, -30), Vector3(E + 60, 3, 1)],
		[Vector3(E * 0.5, 1.5, E + 30), Vector3(E + 60, 3, 1)],
		# phía đông thành phố: chừa 2 lối ra ở z = B và z = 2B
		_wall_z(E + 30, -30, B - gp),
		_wall_z(E + 30, B + gp, 2 * B - gp),
		_wall_z(E + 30, 2 * B + gp, E + 30),
		# rào quanh vùng ngoại ô
		[Vector3((E + 30 + OUT_X + 40) * 0.5, 1.0, -60), Vector3(OUT_X + 40 - E - 30, 2, 1)],
		[Vector3((E + 30 + OUT_X + 40) * 0.5, 1.0, E + 60), Vector3(OUT_X + 40 - E - 30, 2, 1)],
		[Vector3(OUT_X + 40, 1.0, E * 0.5), Vector3(1, 2, E + 120)],
		_wall_z(E + 30, -60, -30),
		_wall_z(E + 30, E + 30, E + 60),
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
const EDGE := (N - 1) * B          # mép đông thành phố
const RIVER_X := EDGE + 200.0
const RIVER_W := 22.0
const OUT_X := EDGE + 360.0


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
	MeshBatch.mat("bund_road", Color(0.48, 0.44, 0.32), 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var z1 := B
	var z2 := 2.0 * B
	var gap := Vector2(RIVER_X - RIVER_W * 0.5 - 13.0 - EDGE, RIVER_X + RIVER_W * 0.5 + 13.0 - EDGE)
	# 2 đường ngang ra ngoại ô + đường dọc nối 2 đầu
	_rural_road(Vector3(EDGE + RW, 0, z1), Vector3(OUT_X, 0, z1), 4.0, [gap - Vector2(RW, RW)])
	_rural_road(Vector3(EDGE + RW, 0, z2), Vector3(OUT_X, 0, z2), 4.0, [gap - Vector2(RW, RW)])
	batch.box("c_asph", Vector3(OUT_X, -0.005, z1), Vector3(8, 0.03, 8))
	batch.box("c_asph", Vector3(OUT_X, -0.005, z2), Vector3(8, 0.03, 8))
	_rural_road(Vector3(OUT_X, 0, z1 + 4.0), Vector3(OUT_X, 0, z2 - 4.0), 4.0)
	# lối vào ngã tư phía đông (vạch dừng, vạch người đi bộ, đèn)
	for j in [1, 2]:
		_east_approach(3, j)
	# sông + cầu
	var sc := Node3D.new()
	add_child(sc)
	var sbatch := MeshBatch.new()
	Scenery.river(sc, sbatch, Vector3(RIVER_X, 0, -60), Vector3(RIVER_X, 0, EDGE + 60), RIVER_W,
		[Vector2(z1 + 60 - 7.0, z1 + 60 + 7.0), Vector2(z2 + 60 - 7.0, z2 + 60 + 7.0)])
	Scenery.bridge(sc, sbatch, Vector3(RIVER_X, 0, z1), Vector3(1, 0, 0), RIVER_W + 6.0, 4.2)
	Scenery.bridge(sc, sbatch, Vector3(RIVER_X, 0, z2), Vector3(1, 0, 0), RIVER_W + 6.0, 4.2)
	# hàng tre dọc bờ sông, làng mái ngói, cột điện, cây ven đường
	Scenery.bamboo_row(sbatch, Vector3(RIVER_X - 18, 0, -40), Vector3(RIVER_X - 18, 0, z1 - 14), 6.0, 3)
	Scenery.bamboo_row(sbatch, Vector3(RIVER_X + 18, 0, z2 + 14), Vector3(RIVER_X + 18, 0, EDGE + 50), 6.0, 4)
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
	var excl := [Rect2(-40, -40, EDGE + 80, EDGE + 80), Rect2(EDGE, z1 - 9, OUT_X - EDGE + 10, 18), Rect2(EDGE, z2 - 9, OUT_X - EDGE + 10, 18),
		Rect2(OUT_X - 9, z1 - 9, 18, z2 - z1 + 18), Rect2(RIVER_X - 20, -400, 40, 1000),
		Rect2(RIVER_X + 50, z1 - 34, 90, 26), Rect2(RIVER_X - 130, z2 + 8, 70, 26), Rect2(RIVER_X + 50, z2 + 10, 80, 26)]
	Scenery.surround(self, Vector3(EDGE * 0.5 + 210, 0, EDGE * 0.5), Rect2(-40, -40, EDGE + 80, EDGE + 80), 470.0, night, Scenery.cur_rain, 21, excl)


func _east_approach(i: int, j: int) -> void:
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


func _road(a: Vector3, b: Vector3) -> void:
	var d := (b - a).normalized()
	var r := right_of(d)
	var s := a + d * RW
	var e := b - d * RW
	batch.strip("c_asph", s, e, RW * 2, -0.005, 0.03)
	# vạch tim đường đứt đoạn, liền gần ngã tư
	var length := s.distance_to(e)
	var u := 0.0
	while u < length:
		var solid := u < 14.0 or u > length - 14.0
		var seg := 3.0 if not solid else 2.0
		batch.strip("c_yline" if solid else "c_line", s + d * u, s + d * minf(u + seg, length), 0.15, 0.012, 0.02)
		u += seg if solid else 7.0
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
	return Vector2i(clampi(roundi(p.x / B), 0, N - 1), clampi(roundi(p.z / B), 0, N - 1))


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
	for k in mini(count, edges.size()):
		var e: Array = edges[k]
		var car := AiCar.new()
		var spec: Dictionary = Game.CARS[styles[k % styles.size()]]
		var col: Color = Game.COLORS[_rng.randi_range(0, Game.COLORS.size() - 1)]
		car.setup(self, spec, col, e[0], e[1], _rng.randf_range(0.15, 0.6))
		add_child(car)
		ai_cars.append(car)


## Vị trí điểm làn xe chạy trên cạnh từ nút a theo hướng d, ở khoảng cách u từ a.
func lane_point(a: Vector2i, d: Vector3, u: float) -> Vector3:
	return node_pos(a.x, a.y) + d * u + right_of(d) * LANE


func park_spot(a: Vector2i, d: Vector3, u: float) -> Vector3:
	return node_pos(a.x, a.y) + d * u + right_of(d) * PARK
