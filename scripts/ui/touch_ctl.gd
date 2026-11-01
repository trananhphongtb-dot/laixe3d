class_name TouchCtl
extends Control
## Nút điều khiển cảm ứng hỗ trợ đa chạm (HUD tự phân phối sự kiện chạm).

signal pressed
signal released

var held: bool = false
var label: String = ""
var icon: String = ""          # arrow_l, arrow_r, hazard, horn, light, belt, cam, pause, key, hb, up, down
var active: bool = false       # trạng thái bật (đèn sáng)
var blink: bool = false        # nhấp nháy khi active
var toggle_color := Color(0.2, 0.75, 0.35)
var font_size: int = 22
var _touch_id: int = -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func touch_down(id: int, _pos: Vector2) -> void:
	_touch_id = id
	held = true
	pressed.emit()
	queue_redraw()


func touch_move(_id: int, _pos: Vector2) -> void:
	pass


func touch_up(_id: int) -> void:
	_touch_id = -1
	held = false
	released.emit()
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg := Color(0, 0, 0, 0.42)
	if held:
		bg = Color(1, 1, 1, 0.35)
	elif active and (not blink or Engine.get_process_frames() % 40 < 20):
		bg = Color(toggle_color.r, toggle_color.g, toggle_color.b, 0.75)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(min(size.x, size.y) * 0.25))
	sb.border_color = Color(1, 1, 1, 0.5)
	sb.set_border_width_all(2)
	draw_style_box(sb, r)
	var c := size * 0.5
	var s := minf(size.x, size.y)
	var col := Color(1, 1, 1, 0.95)
	match icon:
		"arrow_l":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, 0), c + Vector2(s * 0.05, -s * 0.25), c + Vector2(s * 0.05, s * 0.25)]), col)
			draw_rect(Rect2(c + Vector2(0, -s * 0.09), Vector2(s * 0.25, s * 0.18)), col)
		"arrow_r":
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.3, 0), c + Vector2(-s * 0.05, -s * 0.25), c + Vector2(-s * 0.05, s * 0.25)]), col)
			draw_rect(Rect2(c + Vector2(-s * 0.25, -s * 0.09), Vector2(s * 0.25, s * 0.18)), col)
		"hazard":
			var p := PackedVector2Array([c + Vector2(0, -s * 0.3), c + Vector2(s * 0.3, s * 0.22), c + Vector2(-s * 0.3, s * 0.22), c + Vector2(0, -s * 0.3)])
			draw_polyline(p, Color(1, 0.3, 0.2) if not active else col, 4.0)
			var p2 := PackedVector2Array([c + Vector2(0, -s * 0.12), c + Vector2(s * 0.13, s * 0.11), c + Vector2(-s * 0.13, s * 0.11), c + Vector2(0, -s * 0.12)])
			draw_polyline(p2, Color(1, 0.3, 0.2) if not active else col, 3.0)
		"up":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.28), c + Vector2(s * 0.28, s * 0.18), c + Vector2(-s * 0.28, s * 0.18)]), col)
		"down":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, s * 0.28), c + Vector2(s * 0.28, -s * 0.18), c + Vector2(-s * 0.28, -s * 0.18)]), col)
		"pause":
			draw_rect(Rect2(c + Vector2(-s * 0.18, -s * 0.22), Vector2(s * 0.12, s * 0.44)), col)
			draw_rect(Rect2(c + Vector2(s * 0.06, -s * 0.22), Vector2(s * 0.12, s * 0.44)), col)
		_:
			pass
	if label != "":
		var f := get_theme_default_font()
		var fs := font_size
		var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while tw > size.x - 8 and fs > 10:
			fs -= 1
			tw = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var y := c.y + fs * 0.35
		if icon != "":
			y = size.y - 6
		draw_string(f, Vector2(c.x - tw * 0.5, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _process(_d: float) -> void:
	if blink and active:
		queue_redraw()
