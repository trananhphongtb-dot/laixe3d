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
	_show_page("main")
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
	MeshBatch.mat("g_floor", Color(0.16, 0.17, 0.19), 0.35, 0.0, 0.2)
	MeshBatch.mat("g_wall", Color(0.22, 0.23, 0.26), 0.9)
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
		l.light_energy = 1.6
		add_child(l)
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
	turntable.rotation.y += delta * 0.25


# ------------------------------------------------------------------ giao diện

func _build_ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = UiTheme.get_theme()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(ui)

	var left := VBoxContainer.new()
	left.position = Vector2(36, 26)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(left)
	title_label = UiTheme.label("LÁI XE 3D", 64, Color(1, 1, 1))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title_label.add_theme_constant_override("outline_size", 8)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	left.add_child(title_label)
	var sub := UiTheme.label("", 24, UiTheme.ACCENT)
	sub.name = "Sub"
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	left.add_child(sub)

	var sp := PanelContainer.new()
	sp.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	sp.offset_left = 28
	sp.offset_top = -118
	sp.offset_right = 520
	sp.offset_bottom = -24
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(sp)
	stats_label = UiTheme.label("", 21)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	sp.add_child(stats_label)

	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -520
	panel.offset_right = -24
	panel.offset_top = 20
	panel.offset_bottom = -20
	ui.add_child(panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	sc.add_child(content)


func _update_stats() -> void:
	stats_label.text = "%s: %d   ·   %s: %s\n%s: %d/100   ·   %s: %d/%d" % [
		Game.t("money"), Game.money, Game.t("car"), Game.car_name(Game.car_id),
		Game.t("best_score"), Game.exam_best, Game.t("exam_passes"), Game.exam_passes, Game.exam_tries]
	var sub: Label = title_label.get_parent().get_node("Sub")
	sub.text = Game.t("subtitle")


func _clear() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()


func _header(text: String) -> void:
	var l := UiTheme.label(text, 32, UiTheme.ACCENT)
	content.add_child(l)


func _back() -> void:
	content.add_child(UiTheme.button("‹ " + Game.t("back"), func(): _show_page("main"), 58))


func _show_page(p: String) -> void:
	page = p
	_clear()
	_update_stats()
	match p:
		"main":
			_page_main()
		"exam":
			_page_exam()
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
		["menu_exam", func(): _show_page("exam")],
		["menu_free", func(): _show_page("free")],
		["menu_missions", func(): _show_page("missions")],
		["menu_garage", func(): _show_page("garage")],
		["menu_settings", func(): _show_page("settings")],
		["menu_guide", func(): _show_page("guide")],
		["menu_language", func(): _show_page("language")],
		["menu_rate", func(): Game.open_rate_page()],
	]
	for it in items:
		var b := UiTheme.button(Game.t(it[0]), it[1], 70)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 28)
		content.add_child(b)


func _page_exam() -> void:
	_header(Game.t("menu_exam"))
	var full := UiTheme.button(Game.t("exam_full"), func(): Game.start_drive("exam"), 76)
	full.add_theme_font_size_override("font_size", 28)
	content.add_child(full)
	content.add_child(UiTheme.label(Game.t("practice_title"), 22, Color(0.8, 0.85, 0.95)))
	for i in range(1, 12):
		var n := i
		var done := " ✓" if Game.lessons_done.has(i) else ""
		var b := UiTheme.button("%d. %s%s" % [i, Game.t("lesson_%d" % i), done], func():
			Game.practice_lesson = n
			Game.start_drive("practice"), 56)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 22)
		content.add_child(b)
	_back()


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
		var state := " ✓" if Game.missions_done.has(i) else ("" if unlocked else " (" + Game.t("locked") + ")")
		var txt := "%d. %s%s — %d %s%s" % [i + 1, Game.t("mk_" + String(md["kind"])), extra, md["reward"], Game.t("coins"), state]
		var b := UiTheme.button(txt, func():
			Game.mission_id = idx
			Game.start_drive("mission"), 58)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 21)
		b.disabled = not unlocked
		content.add_child(b)
	_back()


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
