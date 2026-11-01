class_name TouchPedal
extends TouchCtl
## Bàn đạp phanh / côn: giữ để đạp (càng cao càng mạnh), thả ra thì nhả từ từ về 0.

var value: float = 0.0
var color := Color(0.3, 0.3, 0.3)
var release_rate: float = 1.6     # mỗi giây giảm bao nhiêu khi thả tay
var press_rate: float = 4.0
var instant: bool = false         # côn: nhả ngay
var _target: float = 0.0


func touch_down(id: int, pos: Vector2) -> void:
	super.touch_down(id, pos)
	_update(pos)


func touch_move(_id: int, pos: Vector2) -> void:
	_update(pos)


func touch_up(id: int) -> void:
	super.touch_up(id)
	_target = 0.0
	if instant:
		value = 0.0


func _update(pos: Vector2) -> void:
	var ly := (pos - global_position).y / maxf(size.y, 1.0)
	_target = clampf(0.4 + (1.0 - ly) * 0.75, 0.4, 1.0)


func _process(delta: float) -> void:
	var v := value
	if held:
		value = move_toward(value, _target, press_rate * delta)
	else:
		value = move_toward(value, 0.0, release_rate * delta)
	if v != value:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.5)
	sb.set_corner_radius_all(18)
	sb.border_color = Color(1, 1, 1, 0.3 if held else 0.18)
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	# mặt bàn đạp
	var pad := Rect2(r.position + Vector2(10, 10), r.size - Vector2(20, 44))
	var ps := StyleBoxFlat.new()
	var c := color.lerp(Color.WHITE, 0.15 if held else 0.0)
	ps.bg_color = Color(c.r, c.g, c.b, 0.8)
	ps.set_corner_radius_all(12)
	ps.anti_aliasing = true
	draw_style_box(ps, pad)
	for i in 7:
		var y := pad.position.y + pad.size.y * (0.12 + i * 0.125)
		draw_line(Vector2(pad.position.x + 10, y), Vector2(pad.end.x - 10, y), Color(0, 0, 0, 0.3), 3.0)
	# mức đạp
	if value > 0.01:
		var h := pad.size.y * value
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(1, 1, 1, 0.28)
		fill.set_corner_radius_all(12)
		draw_style_box(fill, Rect2(Vector2(pad.position.x, pad.end.y - h), Vector2(pad.size.x, h)))
	var f := get_theme_default_font()
	var fs := 16
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while tw > r.size.x - 6 and fs > 10:
		fs -= 1
		tw = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(size.x * 0.5 - tw * 0.5, r.end.y - 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85))
