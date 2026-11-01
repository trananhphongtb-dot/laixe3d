class_name ExamCourse
extends Node3D
## Sân sát hạch sa hình hạng B với 11 bài thi và chấm điểm tự động.

signal finished(passed: bool, score: int, log: Array)

const EDGE_OUT := 1.4          # vượt quá vạch này = ra khỏi hình thi
const STOP_TOL := 0.5          # dừng cách vạch tối đa 500 mm
const PASS_SCORE := 80

var car: PlayerCar
var hud: Hud
var practice: int = 0          # 0 = thi đủ 11 bài, 1..11 = luyện riêng một bài

var rects: Array = []
var path := PackedVector3Array()   # đường tâm sân thi (dùng cho kiểm thử / bản đồ)
var lessons: Array = []
var batch := MeshBatch.new()
var spawn_xf: Transform3D

var score: int = 100
var log: Array = []
var cur: int = 0
var running: bool = false
var ended: bool = false
var time: float = 0.0
var stop_time: float = 0.0

var _pos := Vector3.ZERO
var _dir := Vector3(0, 0, 1)
var _wheel_state: Array = [0, 0, 0, 0]
var _line_cool: float = 0.0
var _rpm_over: bool = false
var _over_time_acc: float = 0.0
var _light_mats: Dictionary
var _light_state: String = "G"
var _light_t: float = 0.0
var _situ: Dictionary = {}
var _info_t: float = 0.0


func _ready() -> void:
	_mats()
	_build()
	batch.commit(self)


func _mats() -> void:
	MeshBatch.mat("asph", Color(0.2, 0.21, 0.23), 0.85)
	MeshBatch.mat("line", Color(0.95, 0.95, 0.95), 0.6)
	MeshBatch.mat("yline", Color(0.98, 0.8, 0.1), 0.6)
	MeshBatch.mat("redline", Color(0.85, 0.1, 0.1), 0.6)
	MeshBatch.mat("conc", Color(0.62, 0.62, 0.6), 0.9)
	MeshBatch.mat("curb", Color(0.75, 0.74, 0.7), 0.9)
	MeshBatch.mat("rail", Color(0.35, 0.3, 0.28), 0.5, 0.0, 0.6)
	MeshBatch.mat("sleeper", Color(0.35, 0.25, 0.18), 0.9)
	MeshBatch.mat("trunk", Color(0.36, 0.25, 0.16), 0.9)
	MeshBatch.mat("leaf", Color(0.2, 0.45, 0.18), 0.9)
	MeshBatch.mat("wall", Color(0.88, 0.86, 0.8), 0.9)
	MeshBatch.mat("roof", Color(0.55, 0.18, 0.12), 0.8)
	MeshBatch.mat("post", Color(0.85, 0.85, 0.85), 0.6)
	MeshBatch.mat("signbg", Color(0.08, 0.3, 0.7), 0.6)
	MeshBatch.mat("stripe_r", Color(0.85, 0.1, 0.1), 0.6)
	MeshBatch.mat("fence", Color(0.3, 0.45, 0.3), 0.8)


# =================================================================== dựng sân

func _left(d: Vector3) -> Vector3:
	return d.rotated(Vector3.UP, PI * 0.5)


func _v2(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


func _add_rect(center: Vector3, d: Vector3, half_len: float, half_w: float) -> void:
	rects.append([_v2(center), Vector2(d.x, d.z).normalized(), half_len, half_w])


func _road_piece(a: Vector3, b: Vector3, hw: float, lines: bool = true, line_l: bool = true, line_r: bool = true) -> void:
	var d := (b - a)
	d.y = 0.0
	var l := _left(d.normalized())
	batch.strip("asph", a, b, hw * 2.0 + 1.6, -0.005, 0.03)
	if lines:
		if line_l:
			batch.strip("line", a + l * (hw + 0.1), b + l * (hw + 0.1), 0.2, 0.012, 0.02)
		if line_r:
			batch.strip("line", a - l * (hw + 0.1), b - l * (hw + 0.1), 0.2, 0.012, 0.02)


func _straight(length: float, hw: float = 2.0, line_l: bool = true, line_r: bool = true) -> Dictionary:
	var a := _pos
	var b := _pos + _dir * length
	_add_rect((a + b) * 0.5, _dir, length * 0.5 + 0.05, hw)
	_road_piece(a, b, hw, true, line_l, line_r)
	var info := {"origin": a, "dir": _dir, "left": _left(_dir), "length": length, "hw": hw}
	for k in int(length):
		path.append(a + _dir * float(k))
	_pos = b
	return info


func _turn(sgn: float, radius: float = 9.0, hw: float = 2.6, angle: float = PI * 0.5) -> void:
	var l := _left(_dir)
	var c := _pos + l * radius * sgn
	var r0 := _pos - c
	var steps := 10
	var prev := _pos
	var prev_dir := _dir
	for i in range(1, steps + 1):
		var t := angle * sgn * float(i) / steps
		var p := c + r0.rotated(Vector3.UP, t)
		var d := _dir.rotated(Vector3.UP, t)
		var mid := (prev + p) * 0.5
		var chord := (p - prev)
		_add_rect(mid, chord.normalized(), chord.length() * 0.5 + 0.35, hw)
		var ext := chord.normalized() * 0.3
		batch.strip("asph", prev - ext, p + ext, hw * 2.0 + 1.6, -0.006, 0.03)
		var pl := _left(prev_dir)
		var nl := _left(d)
		batch.strip("line", prev + pl * (hw + 0.1) - ext * 0.3, p + nl * (hw + 0.1) + ext * 0.3, 0.2, 0.012, 0.02)
		batch.strip("line", prev - pl * (hw + 0.1) - ext * 0.3, p - nl * (hw + 0.1) + ext * 0.3, 0.2, 0.012, 0.02)
		path.append(p)
		prev = p
		prev_dir = d
	_pos = prev
	_dir = _dir.rotated(Vector3.UP, angle * sgn).normalized()


func _sign(info: Dictionary, num: int) -> void:
	var o: Vector3 = info["origin"]
	var d: Vector3 = info["dir"]
	var l: Vector3 = info["left"]
	var hw: float = info["hw"]
	var p := o + d * 1.5 - l * (hw + 2.0)
	batch.cyl("post", p + Vector3(0, 1.1, 0), 0.05, 2.2)
	var yaw := atan2(-d.x, -d.z)
	batch.box("signbg", p + Vector3(0, 2.4, 0), Vector3(1.5, 0.9, 0.05), yaw)
	var lb := Label3D.new()
	lb.text = "%s %d\n%s" % [Game.t("lesson_word").to_upper(), num, Game.t("lesson_%d" % num)]
	lb.font_size = 48
	lb.pixel_size = 0.0045
	lb.outline_size = 6
	lb.width = 300.0
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.position = p + Vector3(0, 2.4, 0) - d * 0.04
	lb.rotation.y = yaw
	add_child(lb)


func _tree(p: Vector3, s: float = 1.0) -> void:
	batch.cyl("trunk", p + Vector3(0, 1.0 * s, 0), 0.15 * s, 2.0 * s)
	batch.sphere("leaf", p + Vector3(0, 2.8 * s, 0), Vector3(2.4, 2.2, 2.4) * s)


func _lesson(num: int, kind: String, info: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var L := info.duplicate()
	L["num"] = num
	L["kind"] = kind
	L["st"] = {}
	L.merge(extra)
	lessons.append(L)
	_sign(info, num)
	return L


func _stop_line(info: Dictionary, u: float, hw: float) -> void:
	var o: Vector3 = info["origin"]
	var d: Vector3 = info["dir"]
	var l: Vector3 = info["left"]
	var p := o + d * (u + 0.15)
	batch.strip("line", p + l * hw, p - l * hw, 0.3, 0.014, 0.02)


func _build() -> void:
	EnvBuilder.ground(self, Vector2(220, 420), Vector3(-10, 0, 165), Color(0.36, 0.52, 0.27))
	_pos = Vector3.ZERO
	_dir = Vector3(0, 0, 1)

	# ---- Bài 1: Xuất phát
	var i1 := _straight(24.0)
	_stop_line(i1, 12.0, 2.0)
	_lesson(1, "start", i1, {"line_u": 12.0})
	spawn_xf = Transform3D(Basis(Vector3.UP, atan2(_dir.x, _dir.z)), Vector3(0, 0.15, 4.0))
	# vạch xuất phát sau xe
	batch.strip("yline", Vector3(-2, 0, 1.2), Vector3(2, 0, 1.2), 0.25, 0.014, 0.02)

	# ---- Bài 2: Dừng xe nhường đường cho người đi bộ
	var i2 := _straight(24.0)
	_stop_line(i2, 12.0, 2.0)
	for k in 7:
		var o: Vector3 = i2["origin"]
		var zp := o + _dir * 14.0 + _left(_dir) * (-1.8 + k * 0.6)
		batch.strip("line", zp - _dir * 1.4, zp + _dir * 1.4, 0.38, 0.013, 0.02)
	_lesson(2, "stopline", i2, {"line_u": 12.0})
	_straight(6.0)

	# ---- Bài 3: Dừng và khởi hành xe ngang dốc
	var i3 := _hill()
	_lesson(3, "hill", i3, {"line_u": 11.0})
	_straight(6.0)
	_turn(-1.0)

	# ---- Bài 4: Qua vệt bánh xe và đường vuông góc
	var i4 := _straight(24.0)
	var o4: Vector3 = i4["origin"]
	var l4: Vector3 = i4["left"]
	var strip_off := -0.72
	var sa := o4 + _dir * 5.0 + l4 * strip_off
	var sbp := o4 + _dir * 19.0 + l4 * strip_off
	batch.strip("conc", sa, sbp, 0.72, 0.02, 0.03)
	batch.strip("yline", sa + l4 * 0.4, sbp + l4 * 0.4, 0.08, 0.03, 0.02)
	batch.strip("yline", sa - l4 * 0.4, sbp - l4 * 0.4, 0.08, 0.03, 0.02)
	_lesson(4, "tracks", i4, {"strip_u0": 5.0, "strip_u1": 19.0, "strip_w": strip_off, "strip_half": 0.36})
	_straight(4.0)
	_turn(1.0)

	# ---- Bài 5: Qua ngã tư có đèn tín hiệu
	var i5 := _straight(34.0)
	_stop_line(i5, 14.0, 2.0)
	var o5: Vector3 = i5["origin"]
	var l5: Vector3 = i5["left"]
	var cross_c := o5 + _dir * 20.0
	_add_rect(cross_c, l5, 16.0, 5.0)
	batch.strip("asph", cross_c - l5 * 16.0, cross_c + l5 * 16.0, 11.0, -0.004, 0.03)
	for s: float in [-1.0, 1.0]:
		var e := cross_c + _dir * 5.1 * s
		batch.strip("line", e + l5 * 16.0, e + l5 * 2.7, 0.2, 0.013, 0.02)
		batch.strip("line", e - l5 * 16.0, e - l5 * 2.7, 0.2, 0.013, 0.02)
	_light_mats = TrafficLight.make_mats()
	TrafficLight.set_state(_light_mats, "G")
	TrafficLight.build(batch, self, o5 + _dir * 14.2 - l5 * 3.4, -_dir, _light_mats)
	TrafficLight.build(batch, self, cross_c + _dir * 6.5 + l5 * 3.4, -_dir, _light_mats)
	_lesson(5, "light", i5, {"line_u": 14.0})
	_straight(6.0)

	# ---- Bài 6: Đường vòng quanh co
	var i6 := {"origin": _pos, "dir": _dir, "left": _left(_dir), "length": 0.0, "hw": 1.75}
	var start6 := _pos
	_turn(1.0, 7.0, 1.75)
	_turn(-1.0, 7.0, 1.75)
	var L6 := _lesson(6, "scurve", i6)
	L6["end_pos"] = _pos
	L6["length"] = (_pos - start6).dot(i6["dir"])
	_straight(6.0)
	_turn(1.0)

	# ---- Bài 7: Ghép xe dọc vào nơi đỗ
	var i7 := _straight(34.0, 3.5, true, false)
	var o7: Vector3 = i7["origin"]
	var l7: Vector3 = i7["left"]
	var bay_u := 16.0
	var bay_w := 2.8
	var bay_d := 5.6
	_lane_edge_with_gap(i7, -1.0, bay_u - bay_w * 0.5, bay_u + bay_w * 0.5)
	var bay_c := o7 + _dir * bay_u - l7 * (3.5 + bay_d * 0.5)
	_add_rect(bay_c, l7, bay_d * 0.5, bay_w * 0.5)
	_bay_lines(bay_c, l7, _dir, bay_d, bay_w)
	_lesson(7, "park", i7, {"bay": [_v2(bay_c), Vector2(l7.x, l7.z), bay_d * 0.5, bay_w * 0.5]})
	_straight(6.0)
	_turn(-1.0)

	# ---- Bài 8: Tạm dừng ở chỗ có đường sắt chạy qua
	var i8 := _straight(24.0)
	_stop_line(i8, 11.0, 2.0)
	var o8: Vector3 = i8["origin"]
	var l8: Vector3 = i8["left"]
	for rr: float in [12.9, 14.4]:
		var rp := o8 + _dir * rr
		batch.strip("rail", rp + l8 * 9.0, rp - l8 * 9.0, 0.12, 0.06, 0.1)
	for k in 9:
		var sp := o8 + _dir * 13.65 + l8 * (-8.0 + k * 2.0)
		batch.strip("sleeper", sp - _dir * 1.2, sp + _dir * 1.2, 0.3, 0.02, 0.04)
	for s: float in [-1.0, 1.0]:
		var bp := o8 + _dir * (11.5 if s < 0 else 15.8) - l8 * 3.2 * (-s if s > 0 else 1.0)
		batch.cyl("post", bp + Vector3(0, 0.6, 0), 0.1, 1.2)
		var arm := bp + Vector3(0, 3.0, 0)
		batch.box("stripe_r", arm, Vector3(0.12, 4.6, 0.12))
	_lesson(8, "stopline", i8, {"line_u": 11.0, "rail": true})

	# ---- Bài 9: Thay đổi số trên đường bằng
	var i9 := _straight(54.0)
	var o9: Vector3 = i9["origin"]
	var l9: Vector3 = i9["left"]
	for u: float in [2.0, 27.0, 52.0]:
		var p := o9 + _dir * u
		batch.strip("yline", p + l9 * 2.0, p - l9 * 2.0, 0.25, 0.014, 0.02)
	for pair in [[6.0, "lesson9_up"], [31.0, "lesson9_down"]]:
		var lb := Label3D.new()
		lb.text = Game.t(pair[1])
		lb.font_size = 96
		lb.pixel_size = 0.012
		lb.modulate = Color(1, 1, 1, 0.9)
		lb.outline_size = 0
		lb.position = o9 + _dir * float(pair[0]) + Vector3(0, 0.03, 0)
		lb.rotation = Vector3(-PI * 0.5, atan2(-_dir.x, -_dir.z), 0)
		add_child(lb)
	_lesson(9, "gears", i9, {"zone_a": 27.0, "zone_b": 52.0})
	_turn(-1.0)

	# ---- Bài 10: Ghép xe ngang vào nơi đỗ
	var i10 := _straight(36.0, 3.5, true, false)
	var o10: Vector3 = i10["origin"]
	var l10: Vector3 = i10["left"]
	var pb_u := 18.0
	var pb_len := 7.4
	var pb_d := 2.7
	_lane_edge_with_gap(i10, -1.0, pb_u - pb_len * 0.5, pb_u + pb_len * 0.5)
	var pbc := o10 + _dir * pb_u - l10 * (3.5 + pb_d * 0.5)
	_add_rect(pbc, _dir, pb_len * 0.5, pb_d * 0.5)
	_bay_lines(pbc, _dir, l10, pb_len, pb_d, true)
	_lesson(10, "park", i10, {"bay": [_v2(pbc), Vector2(_dir.x, _dir.z), pb_len * 0.5, pb_d * 0.5]})
	_straight(4.0)
	_turn(1.0)

	# ---- Bài 11: Kết thúc
	var i11 := _straight(44.0)
	var o11: Vector3 = i11["origin"]
	var l11: Vector3 = i11["left"]
	var fp := o11 + _dir * 34.0
	for k in 8:
		var a := fp + l11 * (-2.0 + k * 0.5)
		batch.strip("line" if k % 2 == 0 else "asph", a, a + l11 * 0.5, 0.6, 0.015, 0.02)
	for s: float in [-1.0, 1.0]:
		var gp := fp + l11 * 3.4 * s
		batch.box("post", gp + Vector3(0, 1.8, 0), Vector3(0.25, 3.6, 0.25))
	batch.strip("signbg", fp + l11 * 3.4 + Vector3(0, 3.5, 0), fp - l11 * 3.4 + Vector3(0, 3.5, 0), 0.6, 3.5, 0.6)
	var fl := Label3D.new()
	fl.text = Game.t("finish_word")
	fl.font_size = 64
	fl.pixel_size = 0.01
	fl.position = fp + Vector3(0, 3.5, 0) - _dir * 0.35
	fl.rotation.y = atan2(-_dir.x, -_dir.z)
	add_child(fl)
	_lesson(11, "finish", i11, {"line_u": 34.0})

	_decor()


func _lane_edge_with_gap(info: Dictionary, side: float, u0: float, u1: float) -> void:
	var o: Vector3 = info["origin"]
	var d: Vector3 = info["dir"]
	var l: Vector3 = info["left"]
	var hw: float = info["hw"]
	var length: float = info["length"]
	var off := l * (hw + 0.1) * side
	batch.strip("line", o + off, o + d * u0 + off, 0.2, 0.012, 0.02)
	batch.strip("line", o + d * u1 + off, o + d * length + off, 0.2, 0.012, 0.02)


## Vẽ ô đỗ: `axis` = hướng chiều dài ô (từ làn đường đi ra ngoài với ô dọc).
func _bay_lines(c: Vector3, axis: Vector3, across: Vector3, length: float, width: float, parallel: bool = false) -> void:
	batch.strip("asph", c - axis * (length * 0.5 + 0.8), c + axis * (length * 0.5 + 0.8), width + 1.6, -0.004, 0.03)
	var hl := length * 0.5
	var hw := width * 0.5
	if parallel:
		# ô ngang: vẽ 2 cạnh ngắn và cạnh ngoài
		var outer := c - across * (hw + 0.1)
		batch.strip("yline", outer - axis * hl, outer + axis * hl, 0.2, 0.014, 0.02)
		for s: float in [-1.0, 1.0]:
			var e := c + axis * (hl + 0.1) * s
			batch.strip("yline", e - across * hw, e + across * hw, 0.2, 0.014, 0.02)
	else:
		# ô dọc: 2 cạnh dài và cạnh cuối
		var back := c - axis * (hl + 0.1)
		batch.strip("yline", back - across * hw, back + across * hw, 0.2, 0.014, 0.02)
		for s: float in [-1.0, 1.0]:
			var e := c + across * (hw + 0.1) * s
			batch.strip("yline", e - axis * hl, e + axis * hl, 0.2, 0.014, 0.02)


func _hill() -> Dictionary:
	var hw := 2.0
	var a := _pos
	var d := _dir
	var l := _left(d)
	var flat1 := 3.0
	var ramp := 12.0
	var topl := 6.0
	var h := 1.5
	var total := flat1 + ramp + topl + ramp + flat1
	_add_rect(a + d * total * 0.5, d, total * 0.5 + 0.05, hw)
	var sb := StaticBody3D.new()
	add_child(sb)
	var width := hw * 2.0 + 1.6
	# phẳng đầu và cuối
	_road_piece(a, a + d * flat1, hw)
	_road_piece(a + d * (total - flat1), a + d * total, hw)
	var slope_len := sqrt(ramp * ramp + h * h)
	var thick := 0.6
	for part in [[flat1, 1.0], [flat1 + ramp + topl, -1.0]]:
		var u0: float = part[0]
		var s: float = part[1]
		var zaxis := (d * ramp + Vector3.UP * h * s).normalized()
		var yaxis := zaxis.cross(l).normalized()
		var basis := Basis(l, yaxis, zaxis)
		var y_mid := h * 0.5
		var surf_mid := a + d * (u0 + ramp * 0.5) + Vector3(0, y_mid, 0)
		var center := surf_mid - yaxis * thick * 0.5
		batch.box_basis("asph", basis, center, Vector3(width, thick, slope_len + 0.1))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(width + 2.0, thick, slope_len + 0.1)
		cs.shape = bs
		cs.transform = Transform3D(basis, center)
		sb.add_child(cs)
		for side: float in [-1.0, 1.0]:
			batch.box_basis("line", basis, surf_mid + yaxis * 0.012 + l * (hw + 0.1) * side, Vector3(0.2, 0.02, slope_len))
		if s > 0:
			# vạch dừng trên dốc tại u = 11 (8 m lên dốc)
			var uu := 11.0 - flat1
			var frac := uu / ramp
			var lp := a + d * (u0 + uu + 0.15) + Vector3(0, h * frac, 0) + yaxis * 0.015
			batch.box_basis("line", basis, lp, Vector3(hw * 2.0, 0.02, 0.3))
	# đỉnh dốc
	var top_c := a + d * (flat1 + ramp + topl * 0.5) + Vector3(0, h - thick * 0.5, 0)
	var basis_t := Basis(Vector3.UP, atan2(d.x, d.z))
	batch.box_basis("asph", basis_t, top_c, Vector3(width, thick, topl + 0.2))
	var cs2 := CollisionShape3D.new()
	var bs2 := BoxShape3D.new()
	bs2.size = Vector3(width + 2.0, thick, topl + 0.2)
	cs2.shape = bs2
	cs2.transform = Transform3D(basis_t, top_c)
	sb.add_child(cs2)
	for side: float in [-1.0, 1.0]:
		batch.box_basis("line", basis_t, top_c + Vector3(0, thick * 0.5 + 0.012, 0) + l * (hw + 0.1) * side, Vector3(0.2, 0.02, topl))
	var info := {"origin": a, "dir": d, "left": l, "length": total, "hw": hw}
	for k in int(total):
		path.append(a + d * float(k))
	_pos = a + d * total
	return info


func _decor() -> void:
	# Tòa nhà trung tâm sát hạch gần điểm xuất phát
	var bp := Vector3(-16, 0, 10)
	batch.box("wall", bp + Vector3(0, 3, 0), Vector3(10, 6, 16))
	batch.box("roof", bp + Vector3(0, 6.3, 0), Vector3(11, 0.6, 17))
	var lb := Label3D.new()
	lb.text = Game.t("exam_center")
	lb.font_size = 72
	lb.pixel_size = 0.012
	lb.modulate = Color(0.8, 0.1, 0.1)
	lb.position = bp + Vector3(5.05, 4.6, 0)
	lb.rotation.y = PI * 0.5
	add_child(lb)
	# Hàng rào và cây
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for z in range(-20, 350, 6):
		batch.box("fence", Vector3(-110, 0.9, z), Vector3(0.15, 1.8, 6.0))
		batch.box("fence", Vector3(90, 0.9, z), Vector3(0.15, 1.8, 6.0))
	for k in 40:
		var p := Vector3(rng.randf_range(-105, 85), 0, rng.randf_range(-15, 345))
		if _classify(Vector2(p.x, p.z)) == 2 and _min_dist(Vector2(p.x, p.z)) > 6.0:
			_tree(p, rng.randf_range(0.8, 1.3))
	# Cọc tiêu dọc đường
	MeshBatch.mat("cone", Color(1.0, 0.45, 0.05), 0.7)
	var o: Vector3 = lessons[0]["origin"]
	for k in 4:
		batch.cyl("cone", o + Vector3(3.2, 0.35, 2 + k * 5), 0.15, 0.7)


func _min_dist(p: Vector2) -> float:
	var best := 1e9
	for r in rects:
		best = minf(best, _overflow(r, p))
	return best


# =================================================================== kiểm tra vị trí

func _overflow(r: Array, p: Vector2) -> float:
	var c: Vector2 = r[0]
	var ax: Vector2 = r[1]
	var lp := p - c
	var u := absf(lp.dot(ax)) - float(r[2])
	var w := absf(lp.dot(Vector2(-ax.y, ax.x))) - float(r[3])
	return maxf(u, w)


## 0 = trong làn, 1 = đè vạch, 2 = ra ngoài
func _classify(p: Vector2) -> int:
	var m := 1e9
	for r in rects:
		var o := _overflow(r, p)
		if o < m:
			m = o
			if m <= 0.0:
				return 0
	return 1 if m <= EDGE_OUT else 2


func _u(L: Dictionary, p: Vector3) -> float:
	var o: Vector3 = L["origin"]
	var d: Vector3 = L["dir"]
	var v := p - o
	return v.x * d.x + v.z * d.z


func _w(L: Dictionary, p: Vector3) -> float:
	var o: Vector3 = L["origin"]
	var l: Vector3 = L["left"]
	var v := p - o
	return v.x * l.x + v.z * l.z


func _in_rect(r: Array, p: Vector2, tol: float = 0.0) -> bool:
	return _overflow(r, p) <= tol


# =================================================================== chạy bài thi

func start(p_car: PlayerCar, p_hud: Hud, p_practice: int) -> void:
	car = p_car
	hud = p_hud
	practice = p_practice
	car.stalled.connect(_on_stall)
	car.crashed.connect(_on_crash)
	if practice > 0:
		cur = practice - 1
		var L: Dictionary = lessons[cur]
		var o: Vector3 = L["origin"]
		var d: Vector3 = L["dir"]
		var back := 3.0 if practice != 1 else -4.0
		spawn_xf = Transform3D(Basis(Vector3.UP, atan2(d.x, d.z)), o - d * back + Vector3(0, 0.15, 0))
		# luyện bài lẻ: bỏ qua phần xuất phát, thắt sẵn dây an toàn
		if practice != 1:
			car.seatbelt = true
	car.global_transform = spawn_xf
	running = true
	time = 0.0
	_intro()


func _on_stall() -> void:
	if running:
		_deduct(5, "pen_stall")


func _on_crash(_impact: float) -> void:
	if running:
		_fatal("pen_crash")


func _intro() -> void:
	var L: Dictionary = lessons[cur]
	hud.toast("%s %d: %s" % [Game.t("lesson_word"), L["num"], Game.t("lesson_%d" % L["num"])], UiTheme.ACCENT, 3.5)
	hud.toast(Game.t("hint_%d" % L["num"]), Color(0.85, 0.9, 1.0), 6.0)


func _deduct(p: int, key: String) -> void:
	if not running:
		return
	score -= p
	log.append("-%d  %s" % [p, Game.t(key)])
	hud.toast("-%d: %s" % [p, Game.t(key)], Color(1.0, 0.4, 0.3), 3.5)
	Sfx.play("fail", -2.0)
	if score < PASS_SCORE:
		_end(false, Game.t("pen_low_score"))


func _fatal(key: String) -> void:
	if not running:
		return
	log.append("%s: %s" % [Game.t("disqualified"), Game.t(key)])
	hud.toast(Game.t(key), Color(1.0, 0.25, 0.2), 5.0)
	Sfx.play("over", 0.0)
	_end(false)


func _end(passed: bool, reason: String = "") -> void:
	if ended:
		return
	ended = true
	running = false
	if _situ.has("snd"):
		var snd: AudioStreamPlayer = _situ["snd"]
		snd.stop()
	if reason != "" and not passed:
		log.insert(0, reason)
	finished.emit(passed, score, log)


func _lesson_done(L: Dictionary) -> void:
	L["st"]["done"] = true
	Sfx.play("ding", -3.0)
	if practice > 0:
		var ok := score >= PASS_SCORE
		_end(ok)
		return
	cur += 1
	if cur >= lessons.size():
		_end(score >= PASS_SCORE)
		return
	_intro()


func _physics_process(delta: float) -> void:
	_update_light(delta)
	if not running or car == null:
		return
	time += delta
	if car.speed_kmh < 0.8:
		stop_time += delta
	else:
		stop_time = 0.0
	_line_cool = maxf(0.0, _line_cool - delta)
	_check_wheels()
	if not running:
		return
	_check_rpm()
	if time > 18.0 * 60.0:
		_over_time_acc += delta
		if _over_time_acc >= 3.0:
			_over_time_acc = 0.0
			_deduct(1, "pen_total_time")
	var L: Dictionary = lessons[cur]
	var st: Dictionary = L["st"]
	if not st.has("t"):
		st["t"] = 0.0
	if _u(L, car.front_point()) > -1.0 or L["num"] == 1:
		st["t"] = float(st["t"]) + delta
	match String(L["kind"]):
		"start":
			_do_start(L, st)
		"stopline":
			_do_stopline(L, st)
		"hill":
			_do_hill(L, st)
		"tracks":
			_do_tracks(L, st)
		"light":
			_do_light(L, st)
		"scurve":
			_do_scurve(L, st)
		"park":
			_do_park(L, st)
		"gears":
			_do_gears(L, st)
		"finish":
			_do_finish(L, st, delta)
	_info_t -= delta
	if _info_t <= 0.0:
		_info_t = 0.25
		_update_info(L, st)


func _update_info(L: Dictionary, st: Dictionary) -> void:
	var t := int(time)
	var lines := "%s %d/11: %s\n%s: %d   %s: %02d:%02d" % [Game.t("lesson_word"), L["num"], Game.t("lesson_%d" % L["num"]),
		Game.t("score"), score, Game.t("time"), t / 60, t % 60]
	if L["kind"] == "light":
		lines += "\n" + Game.t("light_" + _light_state)
	if st.has("parked") and st["parked"]:
		lines += "\n" + Game.t("parked_ok")
	hud.set_info(lines)


func _check_wheels() -> void:
	var pts := car.wheel_points()
	var any_new := false
	for i in 4:
		var c := _classify(pts[i])
		if c == 2:
			_fatal("pen_out")
			return
		if c == 1 and _wheel_state[i] == 0:
			any_new = true
		_wheel_state[i] = c
	if any_new and _line_cool <= 0.0:
		_line_cool = 1.5
		_deduct(5, "pen_line")


func _check_rpm() -> void:
	if car.rpm > 4000.0 and car.engine_on:
		if not _rpm_over:
			_rpm_over = true
			_deduct(2, "pen_rpm")
	elif car.rpm < 3700.0:
		_rpm_over = false


# ---- Bài 1
func _do_start(L: Dictionary, st: Dictionary) -> void:
	var fu := _u(L, car.front_point())
	var line_u: float = L["line_u"]
	if not st.has("moved") and car.speed_kmh > 1.0:
		st["moved"] = true
		if car.blinker != -1 and car.blinker != 2:
			_deduct(5, "pen_no_left_signal")
		if not car.seatbelt:
			_deduct(5, "pen_no_belt")
	var t: float = st["t"]
	if fu > line_u:
		if not st.has("passed"):
			st["passed"] = true
			if t > 20.0:
				_deduct(5, "pen_start_20s")
		_lesson_done(L)
		return
	if t > 30.0:
		_fatal("pen_start_30s")


# ---- Dừng tại vạch (bài 2, 8) và phần dùng chung
func _track_stop(L: Dictionary, st: Dictionary, fu: float) -> void:
	var line_u: float = L["line_u"]
	if stop_time > 0.35:
		var dd := line_u - fu
		if dd >= -0.05 and dd <= STOP_TOL + 0.05:
			st["good"] = true
		elif dd < -0.05 and dd > -4.0:
			st["over"] = true
		elif dd > STOP_TOL + 0.05 and dd < 5.0:
			st["early"] = true


func _judge_stop(st: Dictionary, fatal_key: String) -> void:
	if st.get("good", false):
		return
	if st.get("over", false):
		_deduct(5, "pen_stop_over")
	elif st.get("early", false):
		_deduct(5, "pen_stop_early")
	else:
		_fatal(fatal_key)


func _do_stopline(L: Dictionary, st: Dictionary) -> void:
	var fu := _u(L, car.front_point())
	var line_u: float = L["line_u"]
	if L.get("rail", false) and not st.has("bell") and fu > 0.0:
		st["bell"] = true
		Sfx.play("bell", -6.0)
	if not st.has("judged"):
		_track_stop(L, st, fu)
		if fu > line_u + 1.5:
			st["judged"] = true
			_judge_stop(st, "pen_no_stop")
	if fu > float(L["length"]) - 0.5:
		_lesson_done(L)


# ---- Bài 3
func _do_hill(L: Dictionary, st: Dictionary) -> void:
	var fu := _u(L, car.front_point())
	var line_u: float = L["line_u"]
	if not st.has("judged"):
		_track_stop(L, st, fu)
		if stop_time > 0.35 and (st.get("good", false) or st.get("over", false)) and not st.has("stop_fu"):
			st["stop_fu"] = fu
			st["stop_t"] = 0.0
		if st.has("stop_fu"):
			st["stop_t"] = float(st["stop_t"]) + get_physics_process_delta_time()
			if fu < float(st["stop_fu"]) - 0.5:
				_fatal("pen_rollback")
				return
			if float(st["stop_t"]) > 30.0:
				_fatal("pen_hill_30s")
				return
		if fu > line_u + 1.5:
			st["judged"] = true
			_judge_stop(st, "pen_no_stop_hill")
	if fu > float(L["length"]) - 0.5:
		_lesson_done(L)


# ---- Bài 4
func _do_tracks(L: Dictionary, st: Dictionary) -> void:
	var u0: float = L["strip_u0"]
	var u1: float = L["strip_u1"]
	var sw: float = L["strip_w"]
	var sh: float = L["strip_half"]
	# bánh phải: chỉ số 1 (trước phải), 3 (sau phải)
	for idx: int in [1, 3]:
		var w: VehicleWheel3D = car.wheels[idx]
		var p := w.global_position
		var u := _u(L, p)
		if u > u0 + 0.3 and u < u1 - 0.3:
			st["on"] = true
			var lat := _w(L, p)
			if absf(lat - sw) > sh:
				_fatal("pen_tracks")
				return
	if _u(L, car.rear_point()) > u1:
		if not st.get("on", false):
			_fatal("pen_tracks")
			return
	if _u(L, car.front_point()) > float(L["length"]) - 0.5:
		_lesson_done(L)


# ---- Bài 5
func _update_light(delta: float) -> void:
	if _light_mats.is_empty():
		return
	_light_t -= delta
	if _light_t <= 0.0:
		match _light_state:
			"G":
				_light_state = "Y"
				_light_t = 3.0
			"Y":
				_light_state = "R"
				_light_t = 9.0
			"R":
				_light_state = "G"
				_light_t = 10.0
		TrafficLight.set_state(_light_mats, _light_state)


func _do_light(L: Dictionary, st: Dictionary) -> void:
	var fu := _u(L, car.front_point())
	var line_u: float = L["line_u"]
	if not st.has("init"):
		st["init"] = true
		# Khi xe vào bài: 65% gặp đèn đỏ
		if randf() < 0.65:
			_light_state = "Y"
			_light_t = 0.6
		else:
			_light_state = "G"
			_light_t = 8.0
		TrafficLight.set_state(_light_mats, _light_state)
		st["prev_fu"] = fu
	var prev: float = st["prev_fu"]
	st["prev_fu"] = fu
	if not st.has("crossed"):
		if _light_state == "R":
			st["saw_red"] = true
			_track_stop(L, st, fu)
		if _light_state == "G" and st.get("saw_red", false) and fu < line_u:
			st["green_wait"] = float(st.get("green_wait", 0.0)) + get_physics_process_delta_time()
			if st["green_wait"] > 20.0 and not st.has("slow_pen"):
				st["slow_pen"] = true
				_deduct(5, "pen_light_20s")
		if prev <= line_u and fu > line_u:
			st["crossed"] = true
			if _light_state == "R":
				_deduct(10, "pen_red_light")
			elif st.get("saw_red", false):
				if st.get("over", false) and not st.get("good", false):
					_deduct(5, "pen_stop_over")
				elif st.get("early", false) and not st.get("good", false):
					_deduct(5, "pen_stop_early")
	if fu > float(L["length"]) - 0.5:
		_lesson_done(L)


# ---- Bài 6
func _do_scurve(L: Dictionary, st: Dictionary) -> void:
	if float(st["t"]) > 120.0 and not st.has("slow"):
		st["slow"] = true
		_deduct(5, "pen_slow_2min")
	var endp: Vector3 = L["end_pos"]
	var d: Vector3 = L["dir"]
	var v := car.front_point() - endp
	if v.x * d.x + v.z * d.z > 0.5:
		_lesson_done(L)


# ---- Bài 7, 10
func _do_park(L: Dictionary, st: Dictionary) -> void:
	var bay: Array = L["bay"]
	if not st.get("parked", false):
		var inside := true
		for p in car.corner_points():
			if not _in_rect(bay, p, 0.02):
				inside = false
				break
		if inside and stop_time > 0.5:
			st["parked"] = true
			Sfx.play("ding", -2.0)
			hud.toast(Game.t("parked_ok"), Color(0.5, 1.0, 0.5), 3.0)
	if float(st["t"]) > 120.0 and not st.has("slow"):
		st["slow"] = true
		_deduct(5, "pen_slow_2min")
	var fu := _u(L, car.front_point())
	var ru := _u(L, car.rear_point())
	if minf(fu, ru) > float(L["length"]) - 1.5:
		if not st.get("parked", false):
			_fatal("pen_not_parked")
			return
		_lesson_done(L)


# ---- Bài 9
func _do_gears(L: Dictionary, st: Dictionary) -> void:
	var fu := _u(L, car.front_point())
	var za: float = L["zone_a"]
	var zb: float = L["zone_b"]
	if fu > 2.0 and fu < za:
		st["max_spd"] = maxf(float(st.get("max_spd", 0.0)), car.speed_kmh)
		st["max_gear"] = maxi(int(st.get("max_gear", 0)), car.current_gear_num())
	if fu >= za and not st.has("a_done"):
		st["a_done"] = true
		if float(st.get("max_spd", 0.0)) < 24.0:
			_deduct(5, "pen_gear_speed_up")
		if car.manual and int(st.get("max_gear", 0)) < 2:
			_deduct(5, "pen_gear_up")
	if fu >= zb and not st.has("b_done"):
		st["b_done"] = true
		if car.speed_kmh >= 24.0:
			_deduct(5, "pen_gear_speed_down")
		if car.manual and car.gear != 1:
			_deduct(5, "pen_gear_down")
		_lesson_done(L)


# ---- Bài 11 + tình huống bất ngờ
func _do_finish(L: Dictionary, st: Dictionary, delta: float) -> void:
	var fu := _u(L, car.front_point())
	var line_u: float = L["line_u"]
	if practice == 0:
		_situation(fu, delta)
		if not running:
			return
	if not st.has("crossed") and fu > line_u:
		st["crossed"] = true
		if car.blinker != 1:
			_deduct(5, "pen_no_right_signal")
		if not running:
			return
		_lesson_done(L)


func _situation(fu: float, delta: float) -> void:
	if not _situ.has("state"):
		_situ["state"] = "wait"
		_situ["at"] = randf_range(5.0, 12.0)
	match String(_situ["state"]):
		"wait":
			if fu > float(_situ["at"]) and car.speed_kmh > 3.0:
				_situ["state"] = "alarm"
				_situ["t"] = 0.0
				var snd := Sfx.make_loop_player("alarm")
				add_child(snd)
				snd.volume_db = Sfx.vol_db(-4.0)
				snd.play()
				_situ["snd"] = snd
				hud.toast(Game.t("situation_start"), Color(1.0, 0.5, 0.2), 4.0)
		"alarm":
			_situ["t"] = float(_situ["t"]) + delta
			if car.blinker == 2 and not _situ.has("hz_ok"):
				_situ["hz_ok"] = true
			if float(_situ["t"]) > 3.0 and not _situ.has("hz_ok") and not _situ.has("pen"):
				_situ["pen"] = true
				_deduct(10, "pen_situation")
				if not running:
					return
			if (car.blinker == 2 and stop_time > 1.0) or float(_situ["t"]) > 10.0:
				_situ["state"] = "over"
				var snd: AudioStreamPlayer = _situ["snd"]
				snd.stop()
				hud.toast(Game.t("situation_end"), Color(0.6, 1.0, 0.6), 4.0)
		"over":
			if car.speed_kmh > 3.0:
				_situ["state"] = "done"
				if car.blinker == 2:
					_deduct(5, "pen_hazard_on")
