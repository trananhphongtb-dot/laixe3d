extends Node3D
## Màn hình chính: garage 3D phía sau, 8 mục bên phải.

var ui: Control
var panel: PanelContainer
var content: VBoxContainer
var stats_label: Label
var title_label: Label
var page: String = "main"
var turntable: Node3D
var car_node: Node3D
var cam: Camera3D
var garage_idx: int = 0
var _idle: AudioStreamPlayer
var _t: float = 0.0


func _ready() -> void:
	_build_3d()
	_build_ui()
	garage_idx = Game.CAR_ORDER.find(Game.car_id)
	if garage_idx < 0:
		garage_idx = 0
	_show_car(Game.car_id, Game.car_color)
	_show_page(Game.menu_open_page)
	Game.menu_open_page = "main"
	Game.language_changed.connect(_on_lang)
	Game.money_changed.connect(_update_stats)


func _on_lang() -> void:
	_show_page(page)


func _build_3d() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.055, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.37, 0.42)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var batch := MeshBatch.new()
	MeshBatch.mat("g_floor", Color(0.1, 0.11, 0.14), 0.25, 0.0, 0.3)
	MeshBatch.mat("g_wall", Color(0.13, 0.14, 0.18), 0.9)
	MeshBatch.mat("g_stripe", Color(0.98, 0.62, 0.12), 0.6, 0.15)
	MeshBatch.mat("g_light", Color(1, 1, 1), 0.5, 4.0)
	MeshBatch.mat("g_tt", Color(0.1, 0.1, 0.11), 0.3, 0.0, 0.6)
	batch.box("g_floor", Vector3(0, -0.05, 0), Vector3(30, 0.1, 30))
	batch.box("g_wall", Vector3(0, 4, -9), Vector3(30, 8, 0.3))
	batch.box("g_wall", Vector3(-9, 4, 0), Vector3(0.3, 8, 30))
	batch.box("g_stripe", Vector3(0, 0.7, -8.8), Vector3(30, 0.1, 0.05))
	batch.box("g_stripe", Vector3(-8.8, 0.7, 0), Vector3(0.05, 0.1, 30))
	for x: float in [-3.0, 0.0, 3.0]:
		batch.box("g_light", Vector3(x, 6.0, -1.0), Vector3(0.3, 0.06, 5.0))
	batch.commit(self)
	for p: Vector3 in [Vector3(-3, 5, 2), Vector3(3, 5, -2)]:
		var l := OmniLight3D.new()
		l.position = p
		l.omni_range = 14.0
		l.light_energy = 1.1
		add_child(l)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 7, 0)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	spot.spot_range = 12.0
	spot.spot_angle = 28.0
	spot.light_energy = 6.0
	spot.light_color = Color(1.0, 0.95, 0.88)
	add_child(spot)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 3.45
	tm.outer_radius = 3.55
	tm.rings = 64
	tm.ring_segments = 4
	ring.mesh = tm
	ring.scale = Vector3(1, 0.1, 1)
	ring.position.y = 0.04
	ring.material_override = MeshBatch.mat("g_ring", UiTheme.ACCENT, 0.5, 2.5)
	add_child(ring)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 0.5
	sun.shadow_enabled = true
	add_child(sun)
	turntable = Node3D.new()
	add_child(turntable)
	var cm := CylinderMesh.new()
	cm.top_radius = 3.4
	cm.bottom_radius = 3.4
	cm.height = 0.08
	cm.radial_segments = 40
	var tt := MeshInstance3D.new()
	tt.mesh = cm
	tt.material_override = MeshBatch.mat("g_tt", Color.BLACK)
	tt.position.y = 0.0
	turntable.add_child(tt)
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.position = Vector3(5.6, 2.2, 5.2)
	cam.look_at(Vector3(1.2, 0.6, 0), Vector3.UP)
	_idle = Sfx.make_loop_player("engine_ai")
	add_child(_idle)
	_idle.volume_db = Sfx.vol_db(-24.0)
	_idle.pitch_scale = 0.62
	_idle.play()


func _show_car(id: String, color_idx: int) -> void:
	if car_node:
		car_node.queue_free()
	var r := CarModel.build_simple(Game.car_spec(id), Game.COLORS[color_idx % Game.COLORS.size()])
	car_node = r["exterior"]
	car_node.position.y = 0.04
	turntable.add_child(car_node)


func _process(delta: float) -> void:
	_t += delta
	turntable.rotation.y += delta * 0.22
	var a := 0.75 + sin(_t * 0.15) * 0.18
	cam.position = Vector3(sin(a) * 7.2, 2.0 + sin(_t * 0.2) * 0.15, cos(a) * 7.2)
	cam.look_at(Vector3(cos(a), 0, -sin(a)) * 2.1 + Vector3(0, 0.6, 0), Vector3.UP)


# ------------------------------------------------------------------ giao diện

func _build_ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = UiTheme.get_theme()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(ui)

	# Lớp tối dần hai bên cho chữ dễ đọc
	for side in [0, 1]:
		var g := Gradient.new()
		g.set_color(0, Color(0.02, 0.03, 0.05, 0.85))
		g.set_color(1, Color(0.02, 0.03, 0.05, 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0, 0) if side == 0 else Vector2(1, 0)
		gt.fill_to = Vector2(1, 0) if side == 0 else Vector2(0, 0)
		var tr := TextureRect.new()
		tr.texture = gt
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if side == 0:
			tr.set_anchors_preset(Control.PRESET_LEFT_WIDE)
			tr.offset_right = 520
		else:
			tr.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
			tr.offset_left = -700
		ui.add_child(tr)

	# Logo + tiêu đề
	var logo := Control.new()
	logo.position = Vector2(34, 30)
	logo.size = Vector2(84, 84)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.draw.connect(func():
		logo.draw_circle(Vector2(42, 42), 40, Color(UiTheme.ACCENT.r, UiTheme.ACCENT.g, UiTheme.ACCENT.b, 0.18))
		logo.draw_arc(Vector2(42, 42), 30, 0, TAU, 40, UiTheme.ACCENT, 7.0, true)
		logo.draw_circle(Vector2(42, 42), 8, UiTheme.ACCENT)
		for ang: float in [PI, 0.0, PI * 0.5]:
			logo.draw_line(Vector2(42, 42), Vector2(42, 42) + Vector2(cos(ang), sin(ang)) * 28, UiTheme.ACCENT, 6.0, true))
	ui.add_child(logo)
	var left := VBoxContainer.new()
	left.position = Vector2(132, 26)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_constant_override("separation", 0)
	ui.add_child(left)
	title_label = UiTheme.label("LÁI XE 3D", 62, Color(1, 1, 1))
	title_label.add_theme_font_override("font", Icons.bold_font(1.1))
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	left.add_child(title_label)
	var sub := UiTheme.label("", 22, UiTheme.ACCENT)
	sub.name = "Sub"
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	left.add_child(sub)

	# Hàng chỉ số (xu, điểm, số lần đạt)
	var chips := HBoxContainer.new()
	chips.name = "Chips"
	chips.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	chips.offset_left = 30
	chips.offset_top = -86
	chips.offset_bottom = -26
	chips.add_theme_constant_override("separation", 12)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(chips)
	stats_label = Label.new()   # giữ cho tương thích, không hiển thị
	stats_label.visible = false
	ui.add_child(stats_label)

	panel = PanelContainer.new()
	var ps := StyleBoxEmpty.new()
	panel.add_theme_stylebox_override("panel", ps)
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -540
	panel.offset_right = -24
	panel.offset_top = 22
	panel.offset_bottom = -18
	ui.add_child(panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	sc.add_child(content)


func _chip(icon: String, text: String, col: Color) -> Control:
	var c := Control.new()
	var f := Icons.bold_font(0.6)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 70
	c.custom_minimum_size = Vector2(w, 56)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.1, 0.14, 0.85)
		sb.set_corner_radius_all(28)
		sb.border_color = Color(col.r, col.g, col.b, 0.5)
		sb.set_border_width_all(2)
		sb.anti_aliasing = true
		c.draw_style_box(sb, Rect2(Vector2.ZERO, c.size))
		Icons.draw(c, icon, Vector2(30, 28), 26, col)
		c.draw_string(f, Vector2(52, 36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE))
	return c


func _update_stats() -> void:
	var chips: HBoxContainer = ui.get_node("Chips")
	for ch in chips.get_children():
		ch.queue_free()
	chips.add_child(_chip("coin", str(Game.money), Color(1.0, 0.8, 0.2)))
	chips.add_child(_chip("trophy", "%s %d" % [Game.t("chip_best"), Game.exam_best], UiTheme.ACCENT))
	chips.add_child(_chip("flag", "%s %d/%d" % [Game.t("chip_pass"), Game.exam_passes, Game.exam_tries], Color(0.45, 0.85, 1.0)))
	var sub: Label = title_label.get_parent().get_node("Sub")
	sub.text = Game.t("subtitle")


func _clear() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()


func _header(text: String) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	var bb := Button.new()
	bb.custom_minimum_size = Vector2(60, 60)
	bb.flat = true
	bb.focus_mode = Control.FOCUS_NONE
	bb.draw.connect(func():
		bb.draw_circle(Vector2(30, 30), 28, Color(1, 1, 1, 0.12 if not bb.is_pressed() else 0.3))
		Icons.draw(bb, "back", Vector2(30, 30), 30, Color.WHITE))
	bb.pressed.connect(func():
		Sfx.play("ui", -4.0)
		_show_page("main"))
	hb.add_child(bb)
	var l := UiTheme.label(text, 34, Color.WHITE)
	l.add_theme_font_override("font", Icons.bold_font(0.9))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(l)
	content.add_child(hb)


func _back() -> void:
	pass


func _card(icon: String, title: String, sub: String, cb: Callable, h: int = 88, accent: Color = UiTheme.ACCENT) -> MenuCard:
	var c := MenuCard.new()
	c.icon_name = icon
	c.title = title
	c.sub = sub
	c.accent = accent
	c.custom_minimum_size = Vector2(0, h)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.pressed.connect(func():
		Sfx.play("ui", -4.0)
		cb.call())
	return c


func _show_page(p: String) -> void:
	page = p
	_clear()
	_update_stats()
	match p:
		"main":
			_page_main()
		"exam":
			_page_exam()
		"lessons":
			_page_lessons()
		"free":
			_page_free()
		"missions":
			_page_missions()
		"garage":
			_page_garage()
		"settings":
			_page_settings()
		"guide":
			_page_guide()
		"language":
			_page_language()
	if p != "garage":
		_show_car(Game.car_id, Game.car_color)


func _page_main() -> void:
	var items := [
		["flag", "menu_exam", "msub_exam", func(): _show_page("exam"), Color(0.98, 0.62, 0.12)],
		["road", "menu_free", "msub_free", func(): _show_page("free"), Color(0.55, 0.65, 1.0)],
		["target", "menu_missions", "msub_missions", func(): _show_page("missions"), Color(0.45, 0.9, 0.45)],
		["car", "menu_garage", "msub_garage", func(): _show_page("garage"), Color(0.95, 0.4, 0.45)],
		["gear", "menu_settings", "msub_settings", func(): _show_page("settings"), Color(0.7, 0.72, 0.8)],
		["book", "menu_guide", "msub_guide", func(): _show_page("guide"), Color(0.75, 0.55, 1.0)],
		["globe", "menu_language", "msub_language", func(): _show_page("language"), Color(0.3, 0.85, 0.75)],
		["star", "menu_rate", "msub_rate", func(): Game.open_rate_page(), Color(1.0, 0.82, 0.2)],
	]
	# Chiều cao khả dụng để các thẻ giãn kín tới đáy màn hình
	var avail := get_viewport().get_visible_rect().size.y - 40.0 - 4.0
	var big_h := 132.0
	var gap := 12.0
	var row_h := floorf((avail - big_h - gap - gap * 3.0) / 4.0)
	var big := _card("steer", Game.t("menu_lessons"), Game.t("msub_lessons"), func(): _show_page("lessons"), int(big_h), Color(0.35, 0.8, 1.0))
	big.title_size = 36
	big.sub_size = 19
	content.add_child(big)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(grid)
	for it in items:
		var c := _card(it[0], Game.t(it[1]), Game.t(it[2]), it[3], int(row_h), it[4])
		c.title_size = 27
		c.sub_size = 16
		grid.add_child(c)


func _page_exam() -> void:
	_header(Game.t("menu_exam"))
	content.add_child(_card("play", Game.t("exam_full"), Game.t("msub_exam_full"), func(): Game.start_drive("exam"), 92))
	content.add_child(UiTheme.label(Game.t("practice_title"), 22, Color(0.8, 0.85, 0.95)))
	for i in range(1, 12):
		var n := i
		var done: bool = Game.lessons_done.has(i)
		var c := _card("check" if done else "flag", "%d. %s" % [i, Game.t("lesson_%d" % i)], Game.t("passed") if done else "", func():
			Game.practice_lesson = n
			Game.start_drive("practice"), 64, Color(0.45, 0.9, 0.45) if done else Color(0.6, 0.65, 0.75))
		content.add_child(c)


func _page_lessons() -> void:
	_header(Game.t("menu_lessons"))
	content.add_child(UiTheme.label(Game.t("lessons_desc"), 20, Color(0.8, 0.85, 0.95)))
	var icons := ["flag", "road", "back", "car"]
	for i in range(1, 5):
		var n := i
		var done: bool = Game.lessons_learned.has(i)
		var c := _card("check" if done else icons[i - 1], "%d. %s" % [i, Game.t("lesson_l%d" % i)], Game.t("lesson_l%d_sub" % i), func():
			Game.lesson_id = n
			UiTheme.dialog(ui, Game.t("lesson_l%d" % n), Game.t("ls_choose"), [
				[Game.t("ls_guided"), func():
					Game.lesson_guided = true
					Game.start_drive("lesson")],
				[Game.t("ls_self"), func():
					Game.lesson_guided = false
					Game.start_drive("lesson")],
				[Game.t("cancel"), func(): pass],
			]), 90, Color(0.45, 0.9, 0.45) if done else Color(0.35, 0.8, 1.0))
		c.title_size = 26
		content.add_child(c)


func _toggle_row(options: Array, current: Variant, cb: Callable) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for o in options:
		var val: Variant = o[0]
		var b := Button.new()
		b.text = o[1]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = val == current
		b.custom_minimum_size = Vector2(0, 58)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			Sfx.play("ui", -4.0)
			cb.call(val))
		hb.add_child(b)
	return hb


func _page_free() -> void:
	_header(Game.t("menu_free"))
	content.add_child(UiTheme.label(Game.t("time_of_day"), 22))
	content.add_child(_toggle_row([[false, Game.t("day")], [true, Game.t("night")]], Game.free_night, func(v): Game.free_night = v))
	content.add_child(UiTheme.label(Game.t("weather"), 22))
	content.add_child(_toggle_row([[false, Game.t("sunny")], [true, Game.t("rainy")]], Game.free_rain, func(v): Game.free_rain = v))
	var go := UiTheme.button(Game.t("start"), func(): Game.start_drive("free"), 76)
	go.add_theme_font_size_override("font_size", 30)
	content.add_child(go)
	content.add_child(UiTheme.label(Game.t("free_desc"), 20, Color(0.8, 0.82, 0.88)))
	_back()


func _page_missions() -> void:
	_header(Game.t("menu_missions"))
	for i in Game.MISSIONS.size():
		var md: Dictionary = Game.MISSIONS[i]
		var idx := i
		var unlocked := Game.mission_unlocked(i)
		var extra := ""
		if md["night"]:
			extra += " · " + Game.t("night")
		if md["rain"]:
			extra += " · " + Game.t("rainy")
		var done: bool = Game.missions_done.has(i)
		var kind: String = md["kind"]
		var ic := {"park": "car", "parallel": "car", "taxi": "target", "delivery": "road"}[kind] as String
		if done:
			ic = "check"
		if not unlocked:
			ic = "lock"
		var sub := "%d %s%s" % [md["reward"], Game.t("coins"), extra]
		var c := _card(ic, "%d. %s" % [i + 1, Game.t("mk_" + kind)], sub, func():
			Game.mission_id = idx
			Game.start_drive("mission"), 74, Color(0.45, 0.9, 0.45) if done else Color(1.0, 0.8, 0.2))
		c.disabled = not unlocked
		content.add_child(c)


func _page_garage() -> void:
	_header(Game.t("menu_garage"))
	var id: String = Game.CAR_ORDER[garage_idx]
	var spec := Game.car_spec(id)
	_show_car(id, Game.car_color)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var prev := UiTheme.button("‹", func():
		garage_idx = (garage_idx - 1 + Game.CAR_ORDER.size()) % Game.CAR_ORDER.size()
		_show_page("garage"), 64)
	prev.custom_minimum_size.x = 70
	var nm := UiTheme.label(Game.car_name(id), 30, Color.WHITE)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nxt := UiTheme.button("›", func():
		garage_idx = (garage_idx + 1) % Game.CAR_ORDER.size()
		_show_page("garage"), 64)
	nxt.custom_minimum_size.x = 70
	hb.add_child(prev)
	hb.add_child(nm)
	hb.add_child(nxt)
	content.add_child(hb)
	content.add_child(UiTheme.label("%s: %d km/h   %s: %d kg" % [Game.t("top_speed"), int(spec["top"]), Game.t("weight"), int(spec["mass"])], 21))
	var owned := Game.cars_owned.has(id)
	var price: int = spec["price"]
	var action: Button
	if Game.car_id == id:
		action = UiTheme.button(Game.t("in_use"), func(): pass, 66)
		action.disabled = true
	elif owned:
		action = UiTheme.button(Game.t("use_car"), func():
			Game.car_id = id
			Game.save_game()
			_show_page("garage"), 66)
	else:
		action = UiTheme.button(Game.tf("buy_for", [price]), func():
			if Game.money >= price:
				Game.add_money(-price)
				Game.cars_owned.append(id)
				Game.car_id = id
				Game.save_game()
				Sfx.play("coin", 0.0)
			_show_page("garage"), 66)
		action.disabled = Game.money < price
	content.add_child(action)
	content.add_child(UiTheme.label(Game.t("paint"), 22))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for ci in Game.COLORS.size():
		var c: Color = Game.COLORS[ci]
		var b := Button.new()
		b.custom_minimum_size = Vector2(90, 60)
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(10)
		sb.border_color = UiTheme.ACCENT if ci == Game.car_color else Color(1, 1, 1, 0.3)
		sb.set_border_width_all(5 if ci == Game.car_color else 2)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		var cidx := ci
		b.pressed.connect(func():
			Game.car_color = cidx
			Game.save_game()
			Sfx.play("ui", -4.0)
			_show_page("garage"))
		grid.add_child(b)
	content.add_child(grid)
	_back()


func _page_settings() -> void:
	_header(Game.t("menu_settings"))
	var s := Game.settings
	content.add_child(UiTheme.label(Game.t("set_control"), 22))
	content.add_child(_toggle_row([["wheel", Game.t("ctl_wheel")], ["tilt", Game.t("ctl_tilt")], ["buttons", Game.t("ctl_buttons")]],
		s["control"], func(v): Game.set_setting("control", v)))
	content.add_child(UiTheme.label(Game.t("set_steer_sens"), 22))
	var ss := HSlider.new()
	ss.min_value = 0.5
	ss.max_value = 1.5
	ss.step = 0.05
	ss.value = float(s.get("steer_sens", 1.0))
	ss.custom_minimum_size = Vector2(0, 44)
	ss.value_changed.connect(func(v): Game.set_setting("steer_sens", v))
	content.add_child(ss)
	var inv := CheckButton.new()
	inv.text = Game.t("tilt_invert")
	inv.button_pressed = s["tilt_invert"]
	inv.toggled.connect(func(v): Game.set_setting("tilt_invert", v))
	content.add_child(inv)
	content.add_child(UiTheme.label(Game.t("set_trans"), 22))
	content.add_child(_toggle_row([["auto", Game.t("trans_auto")], ["manual", Game.t("trans_manual")]],
		s["transmission"], func(v): Game.set_setting("transmission", v)))
	content.add_child(UiTheme.label(Game.t("set_graphics"), 22))
	content.add_child(_toggle_row([[0, Game.t("gfx_low")], [1, Game.t("gfx_med")], [2, Game.t("gfx_high")]],
		int(s["graphics"]), func(v): Game.set_setting("graphics", v)))
	for pair in [["engine_vol", "set_engine_vol"], ["sfx_vol", "set_sfx_vol"]]:
		var key: String = pair[0]
		content.add_child(UiTheme.label(Game.t(pair[1]), 22))
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(s[key])
		sl.custom_minimum_size = Vector2(0, 44)
		sl.value_changed.connect(func(v): Game.set_setting(key, v))
		content.add_child(sl)
	var mir := CheckButton.new()
	mir.text = Game.t("set_mirrors")
	mir.button_pressed = s["mirrors"]
	mir.toggled.connect(func(v): Game.set_setting("mirrors", v))
	content.add_child(mir)
	_back()


func _page_guide() -> void:
	_header(Game.t("menu_guide"))
	var tb := UiTheme.button(Game.t("tut_try"), func():
		Game.pending_mode = ""
		Game.start_drive("tutorial"), 72)
	tb.add_theme_font_size_override("font_size", 26)
	content.add_child(tb)
	var l := UiTheme.label(Game.t("guide_text"), 20)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(l)
	_back()


func _page_language() -> void:
	_header(Game.t("menu_language"))
	content.add_child(_toggle_row([["vi", "Tiếng Việt"], ["en", "English"]], Game.lang, func(v):
		Game.set_language(v)))
	_back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if page != "main":
			_show_page("main")
		else:
			get_tree().quit()
