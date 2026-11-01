class_name TouchThrottle
extends TouchCtl
## Cần ga dạng thanh trượt: kéo lên tăng ga, kéo xuống giảm, thả tay giữ nguyên mức.

var value: float = 0.0
var _last_y: float = 0.0


func touch_down(id: int, pos: Vector2) -> void:
	super.touch_down(id, pos)
	_last_y = pos.y


func touch_move(_id: int, pos: Vector2) -> void:
	var dy := pos.y - _last_y
	_last_y = pos.y
	var track := maxf(size.y - 70.0, 40.0)
	value = clampf(value - dy / track, 0.0, 1.0)
	if value < 0.02:
		value = 0.0
	queue_redraw()


func set_value(v: float) -> void:
	if absf(v - value) > 0.001:
		value = v
		queue_redraw()


func _draw() -> void:
	if _bold == null:
		_bold = Icons.bold_font(0.7)
	var r := Rect2(Vector2(10, 4), Vector2(size.x - 20, size.y - 8))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.5)
	sb.set_corner_radius_all(int(r.size.x * 0.5))
	sb.border_color = Color(1, 1, 1, 0.3 if held else 0.18)
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	# vạch chia
	var top := r.position.y + 30.0
	var bottom := r.end.y - 30.0
	for k in 11:
		var y := lerpf(bottom, top, k / 10.0)
		var wdt := 10.0 if k % 5 == 0 else 5.0
		draw_line(Vector2(r.position.x + 8, y), Vector2(r.position.x + 8 + wdt, y), Color(1, 1, 1, 0.35), 2.0)
	# phần đã nhấn ga
	var level_y := lerpf(bottom, top, value)
	if value > 0.0:
		var fill := StyleBoxFlat.new()
		var g := Color(0.2, 0.85, 0.4).lerp(Color(1.0, 0.45, 0.15), clampf((value - 0.5) * 2.0, 0.0, 1.0))
		fill.bg_color = Color(g.r, g.g, g.b, 0.55)
		fill.set_corner_radius_all(int(r.size.x * 0.5) - 6)
		fill.anti_aliasing = true
		draw_style_box(fill, Rect2(Vector2(r.position.x + 6, level_y), Vector2(r.size.x - 12, r.end.y - 6 - level_y)))
	# tay nắm
	var hb := StyleBoxFlat.new()
	hb.bg_color = Color(0.95, 0.96, 0.98, 0.95) if held else Color(0.85, 0.87, 0.9, 0.9)
	hb.set_corner_radius_all(14)
	hb.shadow_color = Color(0, 0, 0, 0.35)
	hb.shadow_size = 5
	hb.anti_aliasing = true
	var hr := Rect2(Vector2(r.position.x - 4, level_y - 15), Vector2(r.size.x + 8, 30))
	draw_style_box(hb, hr)
	for k in 3:
		var yy := level_y - 6 + k * 6
		draw_line(Vector2(hr.position.x + 18, yy), Vector2(hr.end.x - 18, yy), Color(0, 0, 0, 0.25), 2.0)
	# chữ
	var pct := "%d%%" % int(round(value * 100.0))
	var fs := 20
	var tw := _bold.get_string_size(pct, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ty := level_y - 24 if level_y - 24 > top else level_y + 40
	draw_string(_bold, Vector2(size.x * 0.5 - tw * 0.5, ty), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	var f := get_theme_default_font()
	var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(f, Vector2(size.x * 0.5 - lw * 0.5, r.end.y - 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.8))
	# mũi tên gợi ý kéo
	if value == 0.0 and not held:
		Icons.draw(self, "up", Vector2(size.x * 0.5, top + 10), 22, Color(1, 1, 1, 0.5))
