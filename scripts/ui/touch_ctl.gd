class_name TouchCtl
extends Control
## Nút điều khiển cảm ứng hỗ trợ đa chạm (HUD tự phân phối sự kiện chạm).

signal pressed
signal released

var held: bool = false
var label: String = ""         # chữ lớn ở giữa (P R N D...)
var caption: String = ""       # chú thích nhỏ dưới biểu tượng
var icon: String = ""
var active: bool = false
var blink: bool = false
var toggle_color := Color(0.2, 0.75, 0.35)
var font_size: int = 26
var rounded: bool = true
var _touch_id: int = -1
var _flash: float = 0.0

static var _bold: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func touch_down(id: int, _pos: Vector2) -> void:
	_touch_id = id
	held = true
	_flash = 1.0
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
	if _bold == null:
		_bold = Icons.bold_font(0.7)
	var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	var lit := active and (not blink or Engine.get_process_frames() % 40 < 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.42)
	if lit:
		sb.bg_color = Color(toggle_color.r, toggle_color.g, toggle_color.b, 0.82)
	if held:
		sb.bg_color = sb.bg_color.lerp(Color(1, 1, 1, 0.5), 0.45)
	var rad := int(minf(r.size.x, r.size.y) * (0.5 if rounded else 0.22))
	sb.set_corner_radius_all(rad)
	sb.border_color = Color(1, 1, 1, 0.22) if not lit else Color(1, 1, 1, 0.55)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	var col := Color(1, 1, 1, 0.95)
	var c := size * 0.5
	var s := minf(size.x, size.y)
	if icon != "":
		var ic := c - Vector2(0, s * 0.08 if caption != "" else 0.0)
		Icons.draw(self, icon, ic, s * (0.42 if caption != "" else 0.5), col)
	if label != "":
		var fs := font_size
		var tw := _bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while tw > size.x - 10 and fs > 10:
			fs -= 1
			tw = _bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_bold, Vector2(c.x - tw * 0.5, c.y + fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if caption != "":
		var f := get_theme_default_font()
		var cs := 12
		var cw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
		while cw > size.x - 6 and cs > 8:
			cs -= 1
			cw = f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
		draw_string(f, Vector2(c.x - cw * 0.5, size.y - s * 0.14), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, Color(1, 1, 1, 0.75))


func _process(delta: float) -> void:
	if blink and active:
		queue_redraw()
