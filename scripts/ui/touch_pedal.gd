class_name TouchPedal
extends TouchCtl
## Bàn đạp: đạp càng gần phía trên càng mạnh.

var value: float = 0.0
var color := Color(0.3, 0.3, 0.3)


func touch_down(id: int, pos: Vector2) -> void:
	super.touch_down(id, pos)
	_update(pos)


func touch_move(_id: int, pos: Vector2) -> void:
	_update(pos)


func touch_up(id: int) -> void:
	super.touch_up(id)
	value = 0.0
	queue_redraw()


func _update(pos: Vector2) -> void:
	var ly := (pos - global_position).y / maxf(size.y, 1.0)
	value = clampf(0.35 + (1.0 - ly) * 0.75, 0.35, 1.0)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.75 if held else 0.5)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(1, 1, 1, 0.6)
	sb.set_border_width_all(2)
	draw_style_box(sb, r)
	# rãnh chống trượt
	for i in 6:
		var y := r.position.y + r.size.y * (0.18 + i * 0.12)
		draw_line(Vector2(r.position.x + 12, y), Vector2(r.end.x - 12, y), Color(0, 0, 0, 0.35), 4.0)
	if held:
		var h := r.size.y * value
		draw_rect(Rect2(Vector2(r.position.x + 4, r.end.y - h), Vector2(6, h)), Color(1, 1, 1, 0.8))
	var f := get_theme_default_font()
	var fs := 20
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while tw > r.size.x - 6 and fs > 10:
		fs -= 1
		tw = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(size.x * 0.5 - tw * 0.5, r.end.y - 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
