class_name Gauges
extends Control
## Cụm đồng hồ: tốc độ (km/h) và vòng tua (x1000 v/ph), kèm đèn báo.

var speed: float = 0.0
var rpm: float = 0.0
var gear_text: String = "P"
var blink_l: bool = false
var blink_r: bool = false
var belt: bool = true
var handbrake: bool = false
var lights: bool = false
var engine_on: bool = true
var max_speed: float = 200.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	queue_redraw()


func _dial(c: Vector2, r: float, value: float, vmax: float, step: float, label_div: float, red_from: float, unit: String) -> void:
	var a0 := deg_to_rad(140.0)
	var a1 := deg_to_rad(400.0)
	draw_circle(c, r, Color(0.04, 0.05, 0.07, 0.78))
	draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.35), 2.0, true)
	if red_from < vmax:
		var ar := a0 + (a1 - a0) * red_from / vmax
		draw_arc(c, r - 6, ar, a1, 16, Color(0.9, 0.15, 0.1, 0.9), 6.0, true)
	var f := get_theme_default_font()
	var v := 0.0
	var fs := int(r * 0.16)
	while v <= vmax + 0.01:
		var a := a0 + (a1 - a0) * v / vmax
		var dir := Vector2(cos(a), sin(a))
		draw_line(c + dir * (r - 4), c + dir * (r - 14), Color(1, 1, 1, 0.85), 2.0, true)
		var txt := str(int(round(v / label_div)))
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + dir * (r - 28) + Vector2(-tw * 0.5, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.8))
		v += step
	var a_n := a0 + (a1 - a0) * clampf(value / vmax, 0.0, 1.05)
	var nd := Vector2(cos(a_n), sin(a_n))
	draw_line(c - nd * 8, c + nd * (r - 10), Color(1.0, 0.35, 0.1), 4.0, true)
	draw_circle(c, 7, Color(0.85, 0.85, 0.85))
	var uw := f.get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 0.13)).x
	draw_string(f, c + Vector2(-uw * 0.5, r * 0.62), unit, HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 0.13), Color(1, 1, 1, 0.6))


func _draw() -> void:
	var r := minf(size.y * 0.5, size.x * 0.25) - 4
	var cl := Vector2(r + 4, size.y * 0.5)
	var cr := Vector2(size.x - r - 4, size.y * 0.5)
	var vmax := 220.0 if max_speed > 190 else 180.0
	_dial(cl, r, rpm, 8000.0, 1000.0, 1000.0, 6500.0, "x1000 v/ph")
	_dial(cr, r, speed, vmax, 20.0, 1.0, vmax + 1.0, "km/h")
	var f := get_theme_default_font()
	# Ô giữa: số và tốc độ dạng số
	var mid := Vector2(size.x * 0.5, size.y * 0.5)
	var box := Rect2(mid - Vector2(52, 44), Vector2(104, 88))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, 0.78)
	sb.set_corner_radius_all(10)
	draw_style_box(sb, box)
	var st := str(int(round(speed)))
	var fs := 34
	var tw := f.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, mid + Vector2(-tw * 0.5, -2), st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	var gw := f.get_string_size(gear_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	draw_string(f, mid + Vector2(-gw * 0.5, 34), gear_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.4, 0.9, 1.0))
	# Đèn báo xi nhan
	var y := box.position.y - 14
	var gcol := Color(0.15, 0.95, 0.3)
	var off := Color(1, 1, 1, 0.12)
	var lc := gcol if blink_l else off
	var rc := gcol if blink_r else off
	draw_colored_polygon(PackedVector2Array([Vector2(mid.x - 48, y), Vector2(mid.x - 30, y - 11), Vector2(mid.x - 30, y + 11)]), lc)
	draw_colored_polygon(PackedVector2Array([Vector2(mid.x + 48, y), Vector2(mid.x + 30, y - 11), Vector2(mid.x + 30, y + 11)]), rc)
	# Dây an toàn / phanh tay / đèn / máy
	var iy := box.end.y + 18
	if not belt:
		draw_string(f, Vector2(mid.x - 50, iy), Game.t("g_belt"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.2, 0.2))
	if handbrake:
		draw_string(f, Vector2(mid.x + 4, iy), "(P)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.2, 0.2))
	if lights:
		draw_circle(Vector2(mid.x + 44, iy - 6), 6, Color(0.3, 0.6, 1.0))
	if not engine_on:
		draw_string(f, Vector2(mid.x - 26, box.position.y - 30), Game.t("g_engine"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.6, 0.1))
