class_name TouchSteer
extends TouchCtl
## Vô lăng ảo: chạm và xoay. Giá trị +1 = đánh lái hết sang trái.

const MAX_ROT := deg_to_rad(270.0)   # 0,75 vòng mỗi bên: trên màn cảm ứng quay ít hơn xe thật cho đỡ mỏi tay
var value: float = 0.0
var _rot: float = 0.0           # góc vô lăng trên màn hình (dương = theo chiều kim đồng hồ)
var _last_ang: float = 0.0
var car_speed: float = 0.0      # km/h, âm = đang lùi (HUD cập nhật)


func touch_down(id: int, pos: Vector2) -> void:
	super.touch_down(id, pos)
	_last_ang = _angle(pos)


func touch_move(_id: int, pos: Vector2) -> void:
	var a := _angle(pos)
	var d := wrapf(a - _last_ang, -PI, PI)
	_last_ang = a
	# bỏ qua khi chạm sát tâm để tránh nhảy góc
	var local := pos - global_position - size * 0.5
	if local.length() < size.x * 0.12:
		return
	_rot = clampf(_rot + d, -MAX_ROT, MAX_ROT)
	value = -_rot / MAX_ROT
	queue_redraw()


## Đưa vô lăng về giữa ngay (dùng khi quay lại đoạn trước)
func reset() -> void:
	_rot = 0.0
	value = 0.0
	queue_redraw()


func _angle(pos: Vector2) -> float:
	var c := global_position + size * 0.5
	return (pos - c).angle()


func _process(delta: float) -> void:
	if not held and absf(_rot) > 0.001:
		# Tự trả lái như xe thật: đứng yên thì giữ nguyên; đang chạy thì lực trả tỉ lệ với góc đang đánh
		# (đánh càng nhiều về càng nhanh) cộng một tốc độ tối thiểu, nên về giữa trong khoảng 1 giây.
		var lin := 0.0     # tốc độ tối thiểu (rad/s)
		var k := 0.0       # hệ số tỉ lệ theo góc (1/s)
		if car_speed > 1.0:
			lin = minf(3.0 + car_speed * 0.15, 10.0)
			k = minf(3.0 + car_speed * 0.1, 8.0)
		elif car_speed < -1.0:
			lin = 1.5
			k = 1.5
		if lin > 0.0:
			var step := maxf(delta * lin, absf(_rot) * (1.0 - exp(-k * delta)))
			_rot = move_toward(_rot, 0.0, step)
		value = -_rot / MAX_ROT
		queue_redraw()


## Vẽ vô lăng thể thao 3 chấu, đáy vát, bọc da chỉ đỏ
func _draw() -> void:
	var c := size * 0.5
	var R := minf(size.x, size.y) * 0.45
	var rw := R * 0.17                      # độ dày vành
	var ang := _rot
	var rot := func(p: Vector2) -> Vector2: return c + p.rotated(ang)
	# bóng đổ
	draw_circle(c + Vector2(0, 6), R + rw * 0.4, Color(0, 0, 0, 0.22))
	# vành (đáy vát: y > 0.8R thì kẹp lại)
	var pts := PackedVector2Array()
	var inner := PackedVector2Array()
	for k in 73:
		var t := TAU * float(k) / 72.0
		var p := Vector2(cos(t), sin(t)) * R
		if p.y > R * 0.8:
			p.y = R * 0.8
		pts.append(rot.call(p))
		inner.append(rot.call(p * 0.9))
	var leather := Color(0.07, 0.07, 0.08, 0.95) if not held else Color(0.11, 0.11, 0.12, 0.98)
	draw_polyline(pts, leather, rw, true)
	# viền sáng phía trên (ánh da) và mép trong
	var hl := PackedVector2Array()
	for k in 25:
		var t := -PI * 0.85 + PI * 0.7 * float(k) / 24.0
		hl.append(rot.call(Vector2(cos(t), sin(t)) * (R + rw * 0.28)))
	draw_polyline(hl, Color(1, 1, 1, 0.22), rw * 0.18, true)
	draw_polyline(inner, Color(0.35, 0.35, 0.38, 0.6), 1.5, true)
	# đường chỉ khâu đỏ
	for k in 36:
		var t := TAU * float(k) / 36.0
		var p := Vector2(cos(t), sin(t)) * (R - rw * 0.5)
		if p.y > R * 0.8 - rw * 0.5:
			continue
		draw_circle(rot.call(p), 1.6, Color(0.85, 0.15, 0.12, 0.85))
	# vạch đỏ ở đỉnh
	var top_pts := PackedVector2Array()
	for k in 7:
		var t := -PI * 0.5 - 0.1 + 0.2 * float(k) / 6.0
		top_pts.append(rot.call(Vector2(cos(t), sin(t)) * R))
	draw_polyline(top_pts, Color(0.9, 0.12, 0.1), rw * 1.05, true)
	# chấu ngang bạc + chấu dưới đen
	var silver := Color(0.72, 0.74, 0.78, 0.97)
	for sx in [-1.0, 1.0]:
		var sp := PackedVector2Array([rot.call(Vector2(sx * R * 0.24, -R * 0.1)), rot.call(Vector2(sx * (R - rw * 0.4), -R * 0.06)),
			rot.call(Vector2(sx * (R - rw * 0.4), R * 0.12)), rot.call(Vector2(sx * R * 0.24, R * 0.2))])
		draw_colored_polygon(sp, Color(0.12, 0.12, 0.13, 0.97))
		var sp2 := PackedVector2Array([rot.call(Vector2(sx * R * 0.26, -R * 0.08)), rot.call(Vector2(sx * (R - rw * 0.5), -R * 0.04)),
			rot.call(Vector2(sx * (R - rw * 0.5), R * 0.0)), rot.call(Vector2(sx * R * 0.26, R * 0.02))])
		draw_colored_polygon(sp2, silver)
		# nút bấm trên chấu
		for k in 2:
			var bc: Vector2 = rot.call(Vector2(sx * R * (0.42 + k * 0.17), R * 0.1))
			draw_circle(bc, R * 0.045, Color(0.3, 0.3, 0.33))
			draw_circle(bc, R * 0.045, Color(1, 1, 1, 0.25), false, 1.0, true)
	var bs := PackedVector2Array([rot.call(Vector2(-R * 0.12, R * 0.2)), rot.call(Vector2(R * 0.12, R * 0.2)),
		rot.call(Vector2(R * 0.08, R * 0.8)), rot.call(Vector2(-R * 0.08, R * 0.8))])
	draw_colored_polygon(bs, Color(0.1, 0.1, 0.11, 0.97))
	# tâm vô lăng (túi khí) + logo
	draw_circle(c, R * 0.3, Color(0.09, 0.09, 0.1, 0.98))
	draw_circle(c, R * 0.3, Color(1, 1, 1, 0.15), false, 2.0, true)
	draw_circle(c, R * 0.24, Color(0.13, 0.13, 0.14))
	draw_circle(c, R * 0.075, silver)
	Icons.draw(self, "steer", c, R * 0.12, Color(0.15, 0.15, 0.16))
