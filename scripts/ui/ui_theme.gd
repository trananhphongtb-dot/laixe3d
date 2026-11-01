class_name UiTheme
extends RefCounted
## Giao diện dùng chung cho menu và hộp thoại.

const ACCENT := Color(0.98, 0.62, 0.12)
const BG := Color(0.07, 0.08, 0.11, 0.92)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 24
	var normal := _sb(Color(0.16, 0.18, 0.24, 0.95), Color(1, 1, 1, 0.12))
	var hover := _sb(Color(0.22, 0.25, 0.33, 0.98), Color(1, 1, 1, 0.25))
	var pressed := _sb(Color(0.9, 0.52, 0.08, 1.0), Color(1, 1, 1, 0.4))
	var disabled := _sb(Color(0.12, 0.12, 0.14, 0.8), Color(1, 1, 1, 0.05))
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", Color(0.95, 0.95, 0.97))
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", Color(1, 1, 1))
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
	t.set_font_size("font_size", "Button", 24)
	var panel := _sb(BG, Color(1, 1, 1, 0.1))
	panel.content_margin_left = 22
	panel.content_margin_right = 22
	panel.content_margin_top = 18
	panel.content_margin_bottom = 18
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_color("font_color", "Label", Color(0.93, 0.94, 0.96))
	t.set_font_size("font_size", "Label", 22)
	t.set_font_size("font_size", "CheckButton", 22)
	t.set_font_size("font_size", "OptionButton", 22)
	t.set_stylebox("normal", "OptionButton", normal)
	t.set_stylebox("hover", "OptionButton", hover)
	t.set_stylebox("pressed", "OptionButton", pressed)
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_font_size("font_size", "PopupMenu", 26)
	t.set_font_size("normal_font_size", "RichTextLabel", 21)
	t.set_font_size("bold_font_size", "RichTextLabel", 22)
	var grab := StyleBoxFlat.new()
	grab.bg_color = ACCENT
	grab.set_corner_radius_all(6)
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	var sl := StyleBoxFlat.new()
	sl.bg_color = Color(1, 1, 1, 0.15)
	sl.content_margin_top = 4
	sl.content_margin_bottom = 4
	sl.set_corner_radius_all(6)
	t.set_stylebox("slider", "HSlider", sl)
	var sbar := StyleBoxFlat.new()
	sbar.bg_color = Color(1, 1, 1, 0.25)
	sbar.set_corner_radius_all(4)
	t.set_stylebox("grabber", "VScrollBar", sbar)
	_theme = t
	return t


static func _sb(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(12)
	s.border_color = border
	s.set_border_width_all(2)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func button(text: String, cb: Callable, min_h: int = 64) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.pressed.connect(func():
		Sfx.play("ui", -4.0)
		cb.call())
	return b


static func label(text: String, size: int = 22, color: Color = Color(0.93, 0.94, 0.96)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Hộp thoại giữa màn hình. buttons: Array of [text, Callable].
static func dialog(parent: Node, title: String, body: String, buttons: Array, title_color: Color = ACCENT) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = get_theme()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(560, 0)
	cc.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	pc.add_child(vb)
	var tl := label(title, 34, title_color)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tl)
	if body != "":
		var sc := ScrollContainer.new()
		sc.custom_minimum_size = Vector2(560, mini(360, 40 + body.count("\n") * 30))
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var bl := label(body, 22)
		bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(bl)
		vb.add_child(sc)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	for bdef in buttons:
		var cb: Callable = bdef[1]
		var b := button(str(bdef[0]), func():
			root.queue_free()
			cb.call())
		b.custom_minimum_size = Vector2(170, 66)
		hb.add_child(b)
	parent.add_child(root)
	return root
