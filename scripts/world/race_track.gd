class_name RaceTrack
extends Node3D
## Đường đua vòng kín giữa thiên nhiên: sinh ngẫu nhiên, vẽ mặt đường, mũi tên, biển báo cua, cảnh hai bên.

const HW := 5.5                 # nửa bề rộng mặt đường
const LAT_G := 4.5              # gia tốc ngang cho phép khi tính tốc độ vào cua (m/s²)

var pts := PackedVector3Array()
var tang := PackedVector3Array()
var curv := PackedFloat32Array()   # độ cong |1/R| đã làm mượt
var n: int = 0
var step: float = 4.0
var total: float = 0.0
var bbox := Rect2()
var theme: String = "country"
var night: bool = false
var rain: bool = false
var rseed: int = 1
var _corridor: Array = []


func _init(p_theme: String = "country", p_night: bool = false, p_rain: bool = false, p_seed: int = 1) -> void:
	theme = p_theme
	night = p_night
	rain = p_rain
	rseed = p_seed


func _ready() -> void:
	_generate()
	_materials()
	_build_road()
	_dress()


# ------------------------------------------------------------------ hình học

func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var poly := PackedVector2Array()
	var ok := false
	for attempt in 120:
		var r0 := rng.randf_range(290.0, 400.0)
		var amp := 1.0 - attempt * 0.006
		var ak := [rng.randf_range(0.04, 0.15) * amp, rng.randf_range(0.03, 0.12) * amp, rng.randf_range(0.02, 0.07) * amp]
		var ph := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
		var squash := rng.randf_range(0.7, 1.0)
		poly = PackedVector2Array()
		var m := 360
		for i in m:
			var th := TAU * i / m
			var r: float = r0 * (1.0 + ak[0] * sin(2.0 * th + ph[0]) + ak[1] * sin(3.0 * th + ph[1]) + ak[2] * sin(4.0 * th + ph[2]))
			poly.append(Vector2(cos(th) * r, sin(th) * r * squash))
		var len_total := 0.0
		for i in m:
			len_total += poly[i].distance_to(poly[(i + 1) % m])
		var kmax := 0.0
		for i in m:
			kmax = maxf(kmax, _menger(poly[(i - 3 + m) % m], poly[i], poly[(i + 3) % m]))
		if kmax <= 1.0 / 52.0 and len_total > 1700.0 and len_total < 2900.0:
			ok = true
			break
	if not ok:
		poly = PackedVector2Array()
		for i in 360:
			poly.append(Vector2(cos(TAU * i / 360.0), sin(TAU * i / 360.0)) * 320.0)
	if rng.randf() < 0.5:
		poly.reverse()
	# lấy mẫu đều theo chiều dài cung
	var m2 := poly.size()
	var cum := PackedFloat32Array([0.0])
	for i in m2:
		cum.append(cum[i] + poly[i].distance_to(poly[(i + 1) % m2]))
	total = cum[m2]
	n = roundi(total / 4.0)
	step = total / n
	var seg := 0
	for k in n:
		var s := k * step
		while seg < m2 - 1 and cum[seg + 1] < s:
			seg += 1
		var t := (s - cum[seg]) / maxf(cum[seg + 1] - cum[seg], 0.001)
		var q := poly[seg].lerp(poly[(seg + 1) % m2], t)
		pts.append(Vector3(q.x, 0.0, q.y))
	var raw := PackedFloat32Array()
	for k in n:
		var d := pts[(k + 1) % n] - pts[(k - 1 + n) % n]
		d.y = 0.0
		tang.append(d.normalized())
		raw.append(_menger3(pts[(k - 4 + n) % n], pts[k], pts[(k + 4) % n]))
	for k in n:
		var mx := 0.0
		for j in range(-3, 4):
			mx = maxf(mx, raw[(k + j + n) % n])
		curv.append(mx)
	var mn := Vector2(1e9, 1e9)
	var mxv := Vector2(-1e9, -1e9)
	for p in pts:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.z))
		mxv = Vector2(maxf(mxv.x, p.x), maxf(mxv.y, p.z))
	bbox = Rect2(mn, mxv - mn)


static func _menger(a: Vector2, b: Vector2, c: Vector2) -> float:
	var ab := a.distance_to(b)
	var bc := b.distance_to(c)
	var ca := c.distance_to(a)
	if ab * bc * ca < 0.0001:
		return 0.0
	return 2.0 * absf((b - a).cross(c - a)) / (ab * bc * ca)


static func _menger3(a: Vector3, b: Vector3, c: Vector3) -> float:
	return _menger(Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z))


## Điểm trên đường tại quãng s (mét, có thể âm hoặc lớn hơn một vòng), lệch ngang `off` (dương = phải)
func point_at(s: float, off: float = 0.0) -> Vector3:
	var f := fposmod(s, total) / step
	var i := int(f) % n
	var t := f - floorf(f)
	var p := pts[i].lerp(pts[(i + 1) % n], t)
	var d := tang[i].lerp(tang[(i + 1) % n], t).normalized()
	return p + Vector3(-d.z, 0, d.x) * off


func dir_at(s: float) -> Vector3:
	var f := fposmod(s, total) / step
	var i := int(f) % n
	var t := f - floorf(f)
	return tang[i].lerp(tang[(i + 1) % n], t).normalized()


## Độ cong lớn nhất trong đoạn [s, s + ahead]
func curv_ahead(s: float, ahead: float) -> float:
	var i0 := int(fposmod(s, total) / step)
	var cnt := int(ahead / step) + 1
	var mx := 0.0
	for k in cnt:
		mx = maxf(mx, curv[(i0 + k) % n])
	return mx


## Chỉ số điểm gần nhất (tìm quanh `around`)
func nearest_index(p: Vector3, around: int, back: int = 8, fwd: int = 30) -> int:
	var best := around
	var bd := 1e18
	for k in range(-back, fwd + 1):
		var i := (around + k + n * 4) % n
		var d := pts[i].distance_squared_to(p)
		if d < bd:
			bd = d
			best = i
	return best


func lateral(p: Vector3, i: int) -> float:
	var t := tang[i]
	return (p - pts[i]).dot(Vector3(-t.z, 0, t.x))


func transform_at(s: float, off: float, lift: float = 0.0) -> Transform3D:
	var d := dir_at(s)
	return Transform3D(Basis(Vector3.UP, atan2(d.x, d.z)), point_at(s, off) + Vector3(0, lift, 0))


# ------------------------------------------------------------------ dựng đường

func _materials() -> void:
	Scenery._theme_mats()
	MeshBatch.mat("race_road", Color(0.17, 0.17, 0.18), 0.92)
	MeshBatch.mat("race_shoulder", Color(0.5, 0.44, 0.34), 1.0)
	MeshBatch.mat("race_line", Color(0.95, 0.95, 0.92), 0.7)
	MeshBatch.mat("race_yellow", Color(0.95, 0.8, 0.15), 0.7)
	MeshBatch.mat("race_arrow", Color(1.0, 0.82, 0.1), 0.6, 0.35)
	MeshBatch.mat("race_red", Color(0.82, 0.1, 0.08), 0.7)
	MeshBatch.mat("race_black", Color(0.05, 0.05, 0.06), 0.8)
	MeshBatch.mat("race_post", Color(0.75, 0.75, 0.75), 0.6)
	Scenery.texturize("race_shoulder", 0.4, 0.3, 0.2)


func _build_road() -> void:
	var b := MeshBatch.new()
	b.chunk = 160.0
	for i in n:
		var a := pts[i]
		var c := pts[(i + 1) % n]
		var d := c - a
		var l := d.length()
		var yaw := atan2(d.x, d.z)
		var mid := (a + c) * 0.5
		var right := Vector3(-d.z, 0, d.x).normalized()
		b.box("race_road", mid + Vector3(0, 0.015, 0), Vector3(HW * 2.0, 0.03, l + 1.4), yaw)
		for sd: float in [-1.0, 1.0]:
			b.box("race_shoulder", mid + right * sd * (HW + 1.6) + Vector3(0, 0.011, 0), Vector3(3.2, 0.022, l + 1.4), yaw)
			b.box("race_line", mid + right * sd * (HW - 0.5) + Vector3(0, 0.035, 0), Vector3(0.24, 0.02, l + 0.3), yaw)
		if i % 6 < 3:
			b.box("race_yellow", mid + Vector3(0, 0.035, 0), Vector3(0.2, 0.02, l + 0.2), yaw)
	# mũi tên chạy trên mặt đường, cách nhau ~28 m
	for i in range(3, n, 7):
		var p := pts[i]
		var t := tang[i]
		var r := Vector3(-t.z, 0, t.x)
		var tip := p + t * 2.6
		b.strip("race_arrow", p - t * 1.4 + r * 2.3, tip, 0.6, 0.05, 0.02)
		b.strip("race_arrow", p - t * 1.4 - r * 2.3, tip, 0.6, 0.05, 0.02)
	# biển báo ở phía ngoài các khúc cua gắt
	var last_sign := -100
	for i in n:
		if curv[i] > 0.0095 and i - last_sign >= 3:
			last_sign = i
			var turn := tang[i].cross(tang[(i + 4) % n]).y
			var outer := Vector3(-tang[i].z, 0, tang[i].x) * (1.0 if turn > 0.0 else -1.0)
			var bp := pts[i] + outer * (HW + 4.0)
			var face := atan2(-outer.x, -outer.z)
			b.cyl("race_post", bp + Vector3(0, 0.8, 0), 0.07, 1.6)
			b.box("race_red" if (i / 3) % 2 == 0 else "race_line", bp + Vector3(0, 1.9, 0), Vector3(1.6, 1.0, 0.1), face)
			b.box("race_arrow", bp + Vector3(0, 1.9, 0) - outer * 0.07, Vector3(1.1, 0.25, 0.04), face)
	# vạch xuất phát / đích + cổng
	var t0 := tang[0]
	var r0 := Vector3(-t0.z, 0, t0.x)
	var yaw0 := atan2(t0.x, t0.z)
	for k in 8:
		for j in 2:
			var key := "race_black" if (k + j) % 2 == 0 else "race_line"
			b.box(key, pts[0] + r0 * (-HW + 0.7 + k * 1.375) + t0 * (j * 1.0 - 0.5) + Vector3(0, 0.04, 0), Vector3(1.375, 0.02, 1.0), yaw0)
	for sd: float in [-1.0, 1.0]:
		b.box("race_post", pts[0] + r0 * sd * (HW + 1.6) + Vector3(0, 3.1, 0), Vector3(0.4, 6.2, 0.4), yaw0)
	b.box("race_line", pts[0] + Vector3(0, 6.0, 0), Vector3(HW * 2.0 + 3.6, 1.3, 0.35), yaw0)
	b.box("race_red", pts[0] + Vector3(0, 6.0, 0) - t0 * 0.2, Vector3(HW * 2.0 + 3.6, 0.35, 0.1), yaw0)
	b.commit(self)
	# vùng loại trừ cảnh quan dọc đường
	for i in range(0, n, 6):
		_corridor.append(Rect2(pts[i].x - 20.0, pts[i].z - 20.0, 40.0, 40.0))


# ------------------------------------------------------------------ cảnh quan

func _dress() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed + 99
	var g := Scenery.gfx()
	var b := MeshBatch.new()
	b.chunk = 160.0
	var pad := 260.0
	var area := Rect2(bbox.position - Vector2(pad, pad), bbox.size + Vector2(pad, pad) * 2.0)
	var far_col := Color(0.31, 0.47, 0.21)
	match theme:
		"tea":
			Scenery.tea_hills(b, area, _corridor, rseed)
			far_col = Color(0.24, 0.42, 0.2)
		"coast":
			var inner := Rect2(bbox.position.x + 25.0, bbox.position.y, bbox.size.x, bbox.size.y)
			Scenery.coast(b, area, _corridor, inner, area.size.x * 1.2, rseed)
			far_col = Color(0.4, 0.5, 0.26)
		"lake":
			Scenery.lake_park(b, area, _corridor, bbox, rseed)
			far_col = Color(0.33, 0.52, 0.24)
		"forest":
			far_col = Color(0.14, 0.3, 0.14)
			_scatter(b, rng, area, [40.0, 34.0, 28.0][g] as float, 0.85, "pine")
		"mountain":
			far_col = Color(0.4, 0.38, 0.26)
			_scatter(b, rng, area, [60.0, 50.0, 42.0][g] as float, 0.7, "rock")
		_:
			Scenery.rice_fields(b, area, _corridor, rseed)
	_roadside(b, rng)
	var c := bbox.get_center()
	var outer_r := maxf(bbox.size.x, bbox.size.y) * 0.5 + pad
	Scenery.backdrop(self, b, Vector3(c.x, 0, c.y), outer_r, night, rain, far_col, outer_r * 1.7)


func _scatter(b: MeshBatch, rng: RandomNumberGenerator, area: Rect2, cell: float, prob: float, kind: String) -> void:
	var x := area.position.x
	while x < area.end.x:
		var z := area.position.y
		while z < area.end.y:
			var q := Vector2(x + rng.randf() * cell, z + rng.randf() * cell)
			if rng.randf() < prob and not Scenery._in_any(q, _corridor, 4.0):
				var p := Vector3(q.x, 0, q.y)
				if kind == "rock" and rng.randf() < 0.45:
					var sz := rng.randf_range(2.0, 6.0)
					b.sphere("rock", p + Vector3(0, sz * 0.25, 0), Vector3(sz, sz * 0.7, sz * 0.85))
				elif rng.randf() < 0.6:
					Scenery.pine(b, p, rng.randf_range(1.0, 1.9))
				else:
					Scenery.tree(b, p, rng.randf_range(1.0, 1.7))
			z += cell
		x += cell


## Cây / đá sát mép đường theo từng chủ đề
func _roadside(b: MeshBatch, rng: RandomNumberGenerator) -> void:
	var g := Scenery.gfx()
	var every := 1
	var chance := 0.5
	match theme:
		"forest":
			chance = 0.95
		"mountain":
			chance = 0.55
		"country":
			chance = 0.3
		_:
			chance = 0.4
	var gap: int = [3, 2, 2][g] if theme == "forest" else 5
	for i in range(0, n, gap * every):
		for sd: float in [-1.0, 1.0]:
			if rng.randf() > chance:
				continue
			var off := sd * rng.randf_range(HW + 6.0, HW + (22.0 if theme == "forest" else 14.0))
			var p := pts[i] + Vector3(-tang[i].z, 0, tang[i].x) * off
			match theme:
				"coast":
					Scenery.palm(b, p, rng)
				"lake":
					Scenery.willow(b, p, rng.randf_range(0.9, 1.4))
				"tea":
					if rng.randf() < 0.6:
						Scenery.pine(b, p, rng.randf_range(0.9, 1.5))
					else:
						Scenery.tree(b, p, rng.randf_range(0.9, 1.4))
				"mountain":
					if rng.randf() < 0.5:
						var sz := rng.randf_range(1.6, 4.5)
						b.sphere("rock", p + Vector3(0, sz * 0.25, 0), Vector3(sz, sz * 0.7, sz * 0.85))
					else:
						Scenery.pine(b, p, rng.randf_range(1.0, 1.7))
				"forest":
					if rng.randf() < 0.65:
						Scenery.pine(b, p, rng.randf_range(1.1, 2.0))
					else:
						Scenery.tree(b, p, rng.randf_range(1.0, 1.7))
				_:
					Scenery.tree(b, p, rng.randf_range(0.9, 1.5))
