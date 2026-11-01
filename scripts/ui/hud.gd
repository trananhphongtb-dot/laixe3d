class_name Hud
extends CanvasLayer
## Giao diện khi lái: vô lăng, bàn đạp, cần số, nút chức năng, đồng hồ, gương, thông báo.

signal camera_toggle
signal pause_requested

var car: PlayerCar
var root: Control
var steer: TouchSteer
var btn_left: TouchCtl
var btn_right: TouchCtl
var gas: TouchThrottle
var cam_btn: TouchCtl
var brake_p: TouchPedal
var clutch_p: TouchPedal
var gauges: Gauges
var info_label: Label
var info_panel: PanelContainer
var toast_box: VBoxContainer
var compass: Control
var target_pos: Variant = null
var target_label: String = ""
var b_blink_l: TouchCtl
var b_blink_r: TouchCtl
var b_hazard: TouchCtl
var b_belt: TouchCtl
var b_light: TouchCtl
var b_hb: TouchCtl
var b_horn: TouchCtl
var b_key: TouchCtl
var gear_btns: Dictionary = {}
var mirrors_root: Control
var mirror_cams: Array = []    # [Camera3D, local Transform3D]
var mirror_vps: Array[SubViewport] = []
var controls_enabled: bool = true
var cabin_view: bool = true

var _touch_owner: Dictionary = {}
var _touch_ctls: Array[TouchCtl] = []
var _mirror_frame: int = 0
var _mirror_every: int = 2


func setup(p_car: PlayerCar) -> void:
	car = p_car
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)

	_build_mirrors()
	_build_info()
	_build_controls()
	_build_gauges()
	_build_compass()


# ------------------------------------------------------------------ dựng giao diện

func _anchor(c: Control, preset: int, pos: Vector2, sz: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.size = sz
	var a := c.anchor_left
	var b := c.anchor_top
	c.offset_left = pos.x
	c.offset_top = pos.y
	c.offset_right = pos.x + sz.x
	c.offset_bottom = pos.y + sz.y
	c.anchor_right = a
	c.anchor_bottom = b


func _add_touch(c: TouchCtl) -> TouchCtl:
	root.add_child(c)
	_touch_ctls.append(c)
	return c


func _btn(icon: String, text: String, preset: int, pos: Vector2, sz: Vector2) -> TouchCtl:
	var b := TouchCtl.new()
	b.icon = icon
	if icon != "":
		b.caption = text
	else:
		b.label = text
	_anchor(b, preset, pos, sz)
	return _add_touch(b)


func _build_controls() -> void:
	var ctrl: String = Game.settings.get("control", "wheel")
	var BL := Control.PRESET_BOTTOM_LEFT
	var BR := Control.PRESET_BOTTOM_RIGHT
	var TR := Control.PRESET_TOP_RIGHT
	if ctrl == "wheel":
		steer = TouchSteer.new()
		_anchor(steer, BL, Vector2(18, -306), Vector2(290, 290))
		_add_touch(steer)
	elif ctrl == "buttons":
		btn_left = _btn("arrow_l", "", BL, Vector2(20, -176), Vector2(140, 150))
		btn_left.rounded = false
		btn_right = _btn("arrow_r", "", BL, Vector2(176, -176), Vector2(140, 150))
		btn_right.rounded = false

	# Cần ga dạng thanh trượt
	gas = TouchThrottle.new()
	gas.label = Game.t("hud_gas")
	_anchor(gas, BR, Vector2(-134, -350), Vector2(120, 334))
	_add_touch(gas)
	# Phanh
	brake_p = TouchPedal.new()
	brake_p.label = Game.t("hud_brake")
	brake_p.color = Color(0.72, 0.16, 0.14)
	_anchor(brake_p, BR, Vector2(-270, -240), Vector2(128, 224))
	_add_touch(brake_p)
	brake_p.pressed.connect(func(): gas.set_value(0.0))
	var gx := -364.0
	if car.manual:
		clutch_p = TouchPedal.new()
		clutch_p.label = Game.t("hud_clutch")
		clutch_p.color = Color(0.25, 0.35, 0.7)
		clutch_p.instant = true
		clutch_p.press_rate = 20.0
		_anchor(clutch_p, BR, Vector2(-392, -220), Vector2(116, 204))
		_add_touch(clutch_p)
		gx = -490.0
		var up := _btn("up", "", BR, Vector2(gx, -214), Vector2(84, 92))
		up.rounded = false
		up.pressed.connect(func(): car.shift_manual(1))
		var dn := _btn("down", "", BR, Vector2(gx, -112), Vector2(84, 92))
		dn.rounded = false
		dn.pressed.connect(func(): car.shift_manual(-1))
		b_key = _btn("key", Game.t("hud_start"), BR, Vector2(gx + 6, -300), Vector2(72, 72))
		b_key.toggle_color = Color(0.95, 0.5, 0.1)
		b_key.pressed.connect(func(): car.start_engine())
	else:
		var modes := ["P", "R", "N", "D"]
		for i in 4:
			var m: String = modes[i]
			var b := _btn("", m, BR, Vector2(gx, -300 + i * 72), Vector2(80, 66))
			b.label = m
			b.rounded = false
			b.font_size = 30
			b.toggle_color = Color(0.98, 0.58, 0.1)
			b.pressed.connect(func(): car.set_auto_mode(m))
			gear_btns[m] = b

	# Xi nhan + khẩn cấp (phía trên vô lăng)
	b_blink_l = _btn("arrow_l", "", BL, Vector2(22, -398), Vector2(82, 70))
	b_blink_l.rounded = false
	b_blink_l.toggle_color = Color(0.15, 0.8, 0.35)
	b_blink_l.blink = true
	b_blink_l.pressed.connect(func(): car.toggle_blinker(-1))
	b_hazard = _btn("hazard", "", BL, Vector2(114, -398), Vector2(82, 70))
	b_hazard.rounded = false
	b_hazard.toggle_color = Color(0.9, 0.2, 0.15)
	b_hazard.blink = true
	b_hazard.pressed.connect(func(): car.toggle_blinker(2))
	b_blink_r = _btn("arrow_r", "", BL, Vector2(206, -398), Vector2(82, 70))
	b_blink_r.rounded = false
	b_blink_r.toggle_color = Color(0.15, 0.8, 0.35)
	b_blink_r.blink = true
	b_blink_r.pressed.connect(func(): car.toggle_blinker(1))

	# Hàng nút tròn trên bên phải
	var x := -88.0
	var pause := _btn("pause", "", TR, Vector2(x, 12), Vector2(74, 74))
	pause.pressed.connect(func(): pause_requested.emit())
	x -= 84
	cam_btn = _btn("cam", Game.t("hud_cam"), TR, Vector2(x, 12), Vector2(74, 74))
	cam_btn.pressed.connect(func(): camera_toggle.emit())
	x -= 84
	b_hb = _btn("handbrake", Game.t("hud_handbrake"), TR, Vector2(x, 12), Vector2(74, 74))
	b_hb.toggle_color = Color(0.85, 0.15, 0.1)
	b_hb.pressed.connect(func():
		car.handbrake = not car.handbrake
		Sfx.play("shift", -8.0))
	x -= 84
	b_light = _btn("light", Game.t("hud_lights"), TR, Vector2(x, 12), Vector2(74, 74))
	b_light.toggle_color = Color(0.25, 0.55, 1.0)
	b_light.pressed.connect(func():
		car.set_lights(not car.lights_on)
		Sfx.play("ui", -6.0))
	x -= 84
	b_belt = _btn("belt", Game.t("hud_belt"), TR, Vector2(x, 12), Vector2(74, 74))
	b_belt.toggle_color = Color(0.15, 0.72, 0.38)
	b_belt.pressed.connect(func():
		car.seatbelt = not car.seatbelt
		Sfx.play("shift", -6.0))
	x -= 84
	b_horn = _btn("horn", Game.t("hud_horn"), TR, Vector2(x, 12), Vector2(74, 74))
	b_horn.pressed.connect(func(): car.set_horn(true))
	b_horn.released.connect(func(): car.set_horn(false))


func _build_gauges() -> void:
	gauges = Gauges.new()
	gauges.max_speed = float(car.spec["top"])
	var gx := -250.0 if car.manual else -180.0
	_anchor(gauges, Control.PRESET_CENTER_BOTTOM, Vector2(gx, -164), Vector2(360, 150))
	root.add_child(gauges)


func _build_info() -> void:
	info_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.66)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	info_panel.add_theme_stylebox_override("panel", sb)
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.position = Vector2(12, 12)
	info_panel.custom_minimum_size = Vector2(330, 0)
	root.add_child(info_panel)
	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 20)
	info_label.custom_minimum_size = Vector2(330, 0)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_panel.add_child(info_label)
	info_panel.visible = false

	toast_box = VBoxContainer.new()
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(toast_box, Control.PRESET_CENTER_TOP, Vector2(-330, 150), Vector2(660, 300))
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	toast_box.add_theme_constant_override("separation", 6)
	root.add_child(toast_box)


func _build_compass() -> void:
	compass = Control.new()
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(compass, Control.PRESET_CENTER_TOP, Vector2(-80, 126), Vector2(160, 110))
	compass.draw.connect(_draw_compass)
	compass.visible = false
	root.add_child(compass)


func _build_mirrors() -> void:
	mirrors_root = Control.new()
	mirrors_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	mirrors_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mirrors_root)
	if not Game.settings.get("mirrors", true):
		return
	var g: int = Game.settings.get("graphics", 1)
	var scale: float = [0.45, 0.6, 0.85][g]
	_mirror_every = [3, 2, 1][g]
	var d := car.dims
	var W: float = d["W"]
	var top: float = d["top"]
	var zf: float = d["zf"]
	var eye: Vector3 = d["eye"]
	# [vị trí trên màn hình, kích thước, vị trí camera, góc quay, fov]
	var defs := [
		[Control.PRESET_CENTER_TOP, Vector2(-190, 8), Vector2(380, 112), Vector3(0, eye.y + 0.05, eye.z - 0.3), 0.0, 38.0],
		[Control.PRESET_TOP_LEFT, Vector2(10, 238), Vector2(210, 128), Vector3(W * 0.5 + 0.12, top + 0.15, zf - 0.25), deg_to_rad(-10.0), 34.0],
		[Control.PRESET_TOP_RIGHT, Vector2(-220, 250), Vector2(210, 128), Vector3(-W * 0.5 - 0.12, top + 0.15, zf - 0.25), deg_to_rad(10.0), 34.0],
	]
	for df in defs:
		var sz: Vector2 = df[2]
		var vp := SubViewport.new()
		vp.size = Vector2i(int(sz.x * scale), int(sz.y * scale))
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.positional_shadow_atlas_size = 0
		var cam := Camera3D.new()
		cam.cull_mask = 1
		cam.fov = df[5]
		cam.far = 160.0
		cam.near = 0.2
		vp.add_child(cam)
		add_child(vp)
		# Gương nhìn ra sau: quay 180 độ (camera mặc định nhìn -Z, đuôi xe là -Z)
		var pitch := deg_to_rad(-3.0) if df[0] == Control.PRESET_CENTER_TOP else deg_to_rad(-7.0)
		var local := Transform3D(Basis(Vector3.UP, float(df[4])) * Basis(Vector3.RIGHT, pitch), df[3])
		mirror_cams.append([cam, local])
		mirror_vps.append(vp)
		var frame := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.05, 0.05)
		sb.set_corner_radius_all(16)
		sb.content_margin_left = 5
		sb.content_margin_right = 5
		sb.content_margin_top = 5
		sb.content_margin_bottom = 5
		frame.add_theme_stylebox_override("panel", sb)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_anchor(frame, df[0], df[1], sz)
		var tr := TextureRect.new()
		tr.texture = vp.get_texture()
		tr.flip_h = true
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(tr)
		mirrors_root.add_child(frame)


# ------------------------------------------------------------------ API

func set_info(text: String) -> void:
	info_panel.visible = text != ""
	info_label.text = text


func toast(text: String, color: Color = Color.WHITE, dur: float = 3.0) -> void:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.03, 0.75)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pc.add_child(l)
	toast_box.add_child(pc)
	while toast_box.get_child_count() > 4:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	var tw := pc.create_tween()
	tw.tween_interval(dur)
	tw.tween_property(pc, "modulate:a", 0.0, 0.5)
	tw.tween_callback(pc.queue_free)


func set_target(pos: Variant, text: String = "") -> void:
	target_pos = pos
	target_label = text
	compass.visible = pos != null


func set_cabin_view(v: bool) -> void:
	cabin_view = v
	mirrors_root.visible = v
	for vp in mirror_vps:
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if v else SubViewport.UPDATE_DISABLED


func set_controls_enabled(v: bool) -> void:
	controls_enabled = v
	if not v:
		for id in _touch_owner.keys():
			var c: TouchCtl = _touch_owner[id]
			c.touch_up(id)
		_touch_owner.clear()


# ------------------------------------------------------------------ cảm ứng

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			if not controls_enabled:
				return
			for i in range(_touch_ctls.size() - 1, -1, -1):
				var c := _touch_ctls[i]
				if c.is_visible_in_tree() and c.get_global_rect().has_point(e.position):
					_touch_owner[e.index] = c
					c.touch_down(e.index, e.position)
					break
		else:
			if _touch_owner.has(e.index):
				var c: TouchCtl = _touch_owner[e.index]
				_touch_owner.erase(e.index)
				c.touch_up(e.index)
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if _touch_owner.has(e.index):
			var c: TouchCtl = _touch_owner[e.index]
			c.touch_move(e.index, e.position)
	elif event is InputEventKey and controls_enabled:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		match k.keycode:
			KEY_Q:
				car.toggle_blinker(-1)
			KEY_E:
				car.toggle_blinker(1)
			KEY_H:
				car.toggle_blinker(2)
			KEY_C:
				camera_toggle.emit()
			KEY_L:
				car.set_lights(not car.lights_on)
			KEY_B:
				car.seatbelt = not car.seatbelt
			KEY_SPACE:
				car.handbrake = not car.handbrake
			KEY_ESCAPE:
				pause_requested.emit()
			KEY_1:
				car.set_auto_mode("P")
			KEY_2:
				car.set_auto_mode("R")
			KEY_3:
				car.set_auto_mode("N")
			KEY_4:
				car.set_auto_mode("D")
			KEY_PAGEUP:
				car.shift_manual(1)
			KEY_PAGEDOWN:
				car.shift_manual(-1)
			KEY_K:
				car.start_engine()


func _process(delta: float) -> void:
	if car == null:
		return
	# Gom đầu vào
	var s := 0.0
	var ctrl: String = Game.settings.get("control", "wheel")
	if steer:
		s = steer.value
	elif btn_left:
		var target := 0.0
		if btn_left.held:
			target += 1.0
		if btn_right.held:
			target -= 1.0
		s = move_toward(car.steer_input, target, delta * (1.4 if target != 0.0 else 3.0))
	elif ctrl == "tilt":
		var acc := Input.get_accelerometer()
		var v := -acc.x / 7.5
		if Game.settings.get("tilt_invert", false):
			v = -v
		s = clampf(v, -1.0, 1.0)
		if absf(s) < 0.06:
			s = 0.0
	var kb_s := 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		kb_s += 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		kb_s -= 1.0
	if kb_s != 0.0:
		s = kb_s
	var thr := gas.value
	var brk := brake_p.value
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		thr = 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		brk = 1.0
		gas.set_value(0.0)
	var clu := clutch_p != null and clutch_p.value > 0.5
	if Input.is_key_pressed(KEY_SHIFT):
		clu = true
	if not controls_enabled:
		thr = 0.0
		brk = 0.0
		gas.set_value(0.0)
	car.steer_input = s
	car.throttle = thr
	car.brake_input = brk
	car.clutch = clu

	# Cập nhật trạng thái nút
	b_blink_l.active = car.blinker == -1
	b_blink_r.active = car.blinker == 1
	b_hazard.active = car.blinker == 2
	b_belt.active = car.seatbelt
	b_light.active = car.lights_on
	b_hb.active = car.handbrake
	if b_key:
		b_key.active = not car.engine_on
		b_key.blink = not car.engine_on
	for k in gear_btns.keys():
		var gb: TouchCtl = gear_btns[k]
		var a: bool = car.auto_mode == k
		if gb.active != a:
			gb.active = a
			gb.queue_redraw()
	for c in [b_blink_l, b_blink_r, b_hazard, b_belt, b_light, b_hb]:
		c.queue_redraw()

	gauges.speed = car.speed_kmh
	gauges.rpm = car.rpm
	gauges.gear_text = car.gear_label()
	gauges.blink_l = car.blink_phase and (car.blinker == -1 or car.blinker == 2)
	gauges.blink_r = car.blink_phase and (car.blinker == 1 or car.blinker == 2)
	gauges.belt = car.seatbelt
	gauges.handbrake = car.handbrake
	gauges.lights = car.lights_on
	gauges.engine_on = car.engine_on

	if compass.visible:
		compass.queue_redraw()

	# Gương
	if cabin_view and mirror_cams.size() > 0:
		_mirror_frame += 1
		var xf := car.global_transform
		for i in mirror_cams.size():
			var pair: Array = mirror_cams[i]
			var cam: Camera3D = pair[0]
			var local: Transform3D = pair[1]
			cam.global_transform = xf * local
			mirror_vps[i].render_target_update_mode = SubViewport.UPDATE_ONCE if _mirror_frame % _mirror_every == 0 else SubViewport.UPDATE_DISABLED


func _draw_compass() -> void:
	if target_pos == null or car == null:
		return
	var tp: Vector3 = target_pos
	var to := tp - car.global_position
	to.y = 0
	var dist := to.length()
	var fwd := car.forward()
	fwd.y = 0
	var ang := fwd.signed_angle_to(to.normalized(), Vector3.UP)  # dương = mục tiêu bên trái
	var c := Vector2(80, 44)
	var a := -ang - PI * 0.5
	var dir := Vector2(cos(a), sin(a))
	var side := Vector2(-dir.y, dir.x)
	compass.draw_circle(c, 38, Color(0, 0, 0, 0.5))
	compass.draw_colored_polygon(PackedVector2Array([c + dir * 30, c - dir * 14 + side * 18, c - dir * 6, c - dir * 14 - side * 18]), Color(1.0, 0.8, 0.15))
	var f := compass.get_theme_default_font()
	var txt := "%d m" % int(dist)
	if target_label != "":
		txt = target_label + " · " + txt
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	compass.draw_string(f, Vector2(80 - tw * 0.5, 104), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
