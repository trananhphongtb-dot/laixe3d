class_name MenuCard
extends Button
## Thẻ menu: biểu tượng tròn màu, tiêu đề đậm, dòng mô tả nhỏ.

var icon_name: String = ""
var title: String = ""
var sub: String = ""
var accent := Color(0.98, 0.62, 0.12)
var title_size: int = 30
var sub_size: int = 20
var _hover: float = 0.0
static var _bold: Font


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	text = ""
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _on_enter() -> void:
	_hover = 1.0
	queue_redraw()


func _on_exit() -> void:
	_hover = 0.0
	queue_redraw()


func _draw() -> void:
	if _bold == null:
		_bold = Icons.bold_font(0.8)
	var r := Rect2(Vector2.ZERO, size)
	var sb := StyleBoxFlat.new()
	var pressed_now := is_pressed() or button_pressed
	sb.bg_color = Color(0.1, 0.12, 0.17, 0.88).lerp(Color(0.16, 0.19, 0.26, 0.95), _hover * 0.6)
	if pressed_now:
		sb.bg_color = Color(accent.r, accent.g, accent.b, 0.35)
	if disabled:
		sb.bg_color = Color(0.08, 0.09, 0.12, 0.7)
	sb.set_corner_radius_all(18)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	sb.border_width_left = 5
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.95 if not disabled else 0.25)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 6
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	var a := 1.0 if not disabled else 0.4
	var ic := Vector2(26 + minf(size.y * 0.36, 42.0), size.y * 0.5)
	if icon_name != "":
		var ir := minf(size.y * 0.34, 40.0)
		draw_circle(ic, ir, Color(accent.r, accent.g, accent.b, 0.22 * a))
		Icons.draw(self, icon_name, ic, ir * 1.05, Color(accent.r, accent.g, accent.b, a))
	var x := ic.x + minf(size.y * 0.36, 42.0) + 18.0 if icon_name != "" else 22.0
	var f := get_theme_default_font()
	var tfs := title_size
	var ty := size.y * 0.5 + (tfs * 0.36 if sub == "" else -2.0)
	var tw := _bold.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	while tw > size.x - x - 14 and tfs > 14:
		tfs -= 1
		tw = _bold.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	draw_string(_bold, Vector2(x, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(1, 1, 1, a))
	if sub != "":
		var sfs := sub_size
		while f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x > size.x - x - 12 and sfs > 11:
			sfs -= 1
		draw_string(f, Vector2(x, ty + sfs + 8), sub, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 8, sfs, Color(1, 1, 1, 0.6 * a))
