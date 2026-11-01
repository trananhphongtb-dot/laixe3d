class_name TouchSteer
extends TouchCtl
## Vô lăng ảo: chạm và xoay. Giá trị +1 = đánh lái hết sang trái.

const MAX_ROT := deg_to_rad(270.0)
var value: float = 0.0
var _rot: float = 0.0           # góc vô lăng trên màn hình (dương = theo chiều kim đồng hồ)
var _last_ang: float = 0.0


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


func _angle(pos: Vector2) -> float:
	var c := global_position + size * 0.5
	return (pos - c).angle()


func _process(delta: float) -> void:
	if not held and absf(_rot) > 0.001:
		_rot = move_toward(_rot, 0.0, delta * 7.0)
		value = -_rot / MAX_ROT
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.46
	var col := Color(0.08, 0.08, 0.09, 0.82)
	var rim := Color(0.85, 0.85, 0.85, 0.9) if held else Color(0.65, 0.65, 0.65, 0.85)
	draw_circle(c, r, Color(0, 0, 0, 0.25))
	draw_arc(c, r - 8, 0, TAU, 48, col, 16.0, true)
	draw_arc(c, r - 8, 0, TAU, 48, rim, 2.0, true)
	draw_arc(c, r - 16, 0, TAU, 48, rim, 1.5, true)
	var ang := _rot
	for k in 3:
		var a: float = ang + [PI, 0.0, PI * 0.5][k]
		var dir := Vector2(cos(a), sin(a))
		draw_line(c + dir * r * 0.18, c + dir * (r - 14), col, 12.0, true)
	draw_circle(c, r * 0.2, col)
	draw_circle(c, r * 0.2, rim, false, 2.0, true)
	# vạch đánh dấu đỉnh vô lăng
	var top := Vector2(cos(ang - PI * 0.5), sin(ang - PI * 0.5))
	draw_line(c + top * (r - 22), c + top * (r + 2), Color(1, 0.55, 0.1), 6.0, true)
