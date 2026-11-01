class_name Gauges
extends Control
## Cụm đồng hồ số kiểu xe đời mới: tốc độ km/h lớn ở giữa, số, vạch vòng tua, đèn báo.

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
var _bold: Font
var _shown_speed: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_shown_speed = lerpf(_shown_speed, speed, clampf(delta * 8.0, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	if _bold == null:
		_bold = Icons.bold_font(1.0)
	var f := get_theme_default_font()
	var r := Rect2(Vector2.ZERO, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.72)
	sb.set_corner_radius_all(26)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	var cx := size.x * 0.5

	# Tốc độ
	var st := str(int(round(_shown_speed)))
	var fs := 64
	var tw := _bold.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_bold, Vector2(cx - tw * 0.5, 86), st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	var unit := "km/h"
	var uw := f.get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(f, Vector2(cx - uw * 0.5, 108), unit, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.85, 1.0, 0.9))

	# Số (bên trái)
	var gr := Rect2(Vector2(18, 40), Vector2(70, 60))
	var gs := StyleBoxFlat.new()
	var gcol := Color(0.98, 0.62, 0.12)
	if gear_text == "R":
		gcol = Color(0.95, 0.3, 0.25)
	elif gear_text == "N" or gear_text == "P":
		gcol = Color(0.55, 0.6, 0.7)
	gs.bg_color = Color(gcol.r, gcol.g, gcol.b, 0.22)
	gs.border_color = gcol
	gs.set_border_width_all(2)
	gs.set_corner_radius_all(12)
	gs.anti_aliasing = true
	draw_style_box(gs, gr)
	var gfs := 34 if gear_text.length() <= 1 else 28
	var gw := _bold.get_string_size(gear_text, HORIZONTAL_ALIGNMENT_LEFT, -1, gfs).x
	draw_string(_bold, Vector2(gr.get_center().x - gw * 0.5, gr.get_center().y + gfs * 0.36), gear_text, HORIZONTAL_ALIGNMENT_LEFT, -1, gfs, gcol)

	# Vòng tua (bên phải): số + chữ
	var rr := Rect2(Vector2(size.x - 88, 40), Vector2(70, 60))
	var rtxt := "%.1f" % (rpm / 1000.0)
	var rw := _bold.get_string_size(rtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var rcol := Color.WHITE if rpm < 4000.0 else (Color(1.0, 0.75, 0.2) if rpm < 6000.0 else Color(1.0, 0.3, 0.25))
	draw_string(_bold, Vector2(rr.get_center().x - rw * 0.5, rr.get_center().y + 4), rtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, rcol)
	var lab := "x1000"
	var lw := f.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(f, Vector2(rr.get_center().x - lw * 0.5, rr.get_center().y + 24), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.55))

	# Thanh vòng tua dạng vạch
	var n := 24
	var bx := 22.0
	var bw := size.x - 44.0
	var seg := bw / n
	var lit := int(clampf(rpm / 7000.0, 0.0, 1.0) * n + 0.5)
	for i in n:
		var t := float(i) / (n - 1)
		var c := Color(0.25, 0.85, 0.45).lerp(Color(1.0, 0.8, 0.2), clampf(t * 1.8 - 0.4, 0.0, 1.0))
		if t > 0.82:
			c = Color(1.0, 0.3, 0.25)
		if i >= lit:
			c = Color(1, 1, 1, 0.1)
		var h := 6.0 + t * 8.0
		draw_rect(Rect2(Vector2(bx + i * seg + 1, size.y - 14 - h), Vector2(seg - 3, h)), c)

	# Đèn báo trên cùng
	var y := 22.0
	var on := Color(0.15, 1.0, 0.4)
	var off := Color(1, 1, 1, 0.1)
	Icons.draw(self, "arrow_l", Vector2(cx - 120, y), 24, on if blink_l else off)
	Icons.draw(self, "arrow_r", Vector2(cx + 120, y), 24, on if blink_r else off)
	var x := cx - 60.0
	if not belt:
		Icons.draw(self, "belt", Vector2(x, y), 22, Color(1.0, 0.25, 0.2))
	if handbrake:
		Icons.draw(self, "handbrake", Vector2(cx - 20, y), 20, Color(1.0, 0.25, 0.2), 2.0)
	if lights:
		Icons.draw(self, "light", Vector2(cx + 20, y), 22, Color(0.3, 0.65, 1.0))
	if not engine_on:
		Icons.draw(self, "key", Vector2(cx + 60, y), 22, Color(1.0, 0.6, 0.1))
