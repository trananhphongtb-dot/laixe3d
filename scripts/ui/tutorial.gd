class_name Tutorial
extends Control
## Hướng dẫn từng bước dạng popup, người chơi làm thử thật trên xe.

signal finished(skipped: bool)

var hud: Hud
var car: PlayerCar
var steps: Array = []
var idx: int = -1
var card: PanelContainer
var title_l: Label
var body_l: Label
var next_b: Button
var skip_b: Button
var ok_l: Label
var _t: float = 0.0
var _ok_timer: float = -1.0
var _cam_toggles: int = 0
var _moved: bool = false
var _braked: bool = false


func setup(p_hud: Hud, p_car: PlayerCar) -> void:
	hud = p_hud
	car = p_car
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	hud.camera_toggle.connect(func(): _cam_toggles += 1)
	_build_steps()
	_build_card()
	_go(0)


func _build_steps() -> void:
	var ctrl: String = Game.settings.get("control", "wheel")
	var steer_key := "tut_steer_" + ctrl
	var steer_target: Control = hud.steer if hud.steer else hud.btn_left
	steps = [
		{"k": "tut_welcome", "tap": true},
		{"k": steer_key, "t": steer_target, "ok": func(): return absf(car.steer_input) > 0.55},
	]
	if car.manual:
		steps.append({"k": "tut_gear_manual", "t": hud.clutch_p, "ok": func(): return car.gear >= 1})
		steps.append({"k": "tut_gas_manual", "t": hud.gas, "ok": func(): return car.speed_kmh > 8.0})
	else:
		steps.append({"k": "ls_brake_hold", "t": hud.brake_p, "ok": func(): return hud.brake_p.locked and hud.brake_p.value >= 0.15})
		steps.append({"k": "tut_gear_auto", "t": hud.gear_btns.get("D"), "ok": func(): return car.auto_mode == "D"})
		steps.append({"k": "ls_brake_release", "t": hud.brake_p, "ok": func(): return hud.brake_p.value <= 0.0})
		steps.append({"k": "tut_gas", "t": hud.gas, "ok": func(): return car.speed_kmh > 10.0})
	steps.append({"k": "tut_brake", "t": hud.brake_p, "ok": func(): return car.speed_kmh < 1.0})
	steps.append({"k": "tut_blinker", "t": hud.b_blink_l, "ok": func(): return car.blinker == -1 or car.blinker == 1})
	steps.append({"k": "tut_cam", "t": hud.cam_btn, "ok": func(): return _cam_toggles >= 2})
	steps.append({"k": "tut_buttons", "t": hud.b_belt, "tap": true})
	steps.append({"k": "tut_gauges", "t": hud.gauges, "tap": true})
	steps.append({"k": "tut_done", "tap": true})


func _build_card() -> void:
	card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.1, 0.94)
	sb.set_corner_radius_all(20)
	sb.border_color = UiTheme.ACCENT
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 14
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(560, 0)
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.0
	card.anchor_bottom = 0.0
	card.offset_left = -280
	card.offset_right = 280
	card.offset_top = 132
	card.offset_bottom = 132
	add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)
	title_l = UiTheme.label("", 18, UiTheme.ACCENT)
	vb.add_child(title_l)
	body_l = UiTheme.label("", 24, Color.WHITE)
	body_l.custom_minimum_size = Vector2(510, 0)
	vb.add_child(body_l)
	ok_l = UiTheme.label("", 24, Color(0.45, 1.0, 0.55))
	vb.add_child(ok_l)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.alignment = BoxContainer.ALIGNMENT_END
	vb.add_child(hb)
	skip_b = UiTheme.button(Game.t("tut_skip"), func(): _finish(true), 54)
	skip_b.custom_minimum_size.x = 170
	skip_b.add_theme_font_size_override("font_size", 20)
	hb.add_child(skip_b)
	next_b = UiTheme.button(Game.t("tut_next"), func(): _advance(), 54)
	next_b.custom_minimum_size.x = 170
	hb.add_child(next_b)


func _go(i: int) -> void:
	idx = i
	_ok_timer = -1.0
	ok_l.text = ""
	ok_l.visible = false
	if idx >= steps.size():
		_finish(false)
		return
	var st: Dictionary = steps[idx]
	title_l.text = Game.tf("tut_step", [idx + 1, steps.size()])
	body_l.text = Game.t(st["k"])
	var tap: bool = st.get("tap", false)
	next_b.visible = tap
	next_b.text = Game.t("tut_start") if idx == steps.size() - 1 else Game.t("tut_next")
	skip_b.visible = idx < steps.size() - 1
	queue_redraw()


func _advance() -> void:
	_go(idx + 1)


func _finish(skipped: bool) -> void:
	set_process(false)
	visible = false
	finished.emit(skipped)
	queue_free()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if idx < 0 or idx >= steps.size():
		return
	var st: Dictionary = steps[idx]
	if _ok_timer >= 0.0:
		_ok_timer -= delta
		if _ok_timer < 0.0:
			_advance()
		return
	if st.has("ok"):
		var cb: Callable = st["ok"]
		var k: String = st["k"]
		# bước phanh: chỉ tính khi xe đã chạy
		if k == "tut_brake" and not _moved:
			_moved = car.speed_kmh > 5.0
			return
		if k == "tut_brake":
			if car.brake_input > 0.05:
				_braked = true
			if not _braked:
				return
		if cb.call():
			_ok_timer = 1.1
			ok_l.text = "✓ " + Game.t("tut_good")
			ok_l.visible = true
			Sfx.play("ding", -6.0)


func _draw() -> void:
	if idx < 0 or idx >= steps.size():
		return
	var st: Dictionary = steps[idx]
	var t: Control = st.get("t")
	if t == null or not is_instance_valid(t) or not t.is_visible_in_tree():
		return
	var rect := t.get_global_rect().grow(8.0 + sin(_t * 6.0) * 4.0)
	rect.position -= get_global_rect().position
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.draw_center = false
	sb.border_color = Color(1.0, 0.75, 0.15, 0.9)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(22)
	sb.anti_aliasing = true
	draw_style_box(sb, rect)
	# đường nối từ thẻ tới nút
	var cr := card.get_global_rect()
	cr.position -= get_global_rect().position
	var from := Vector2(clampf(rect.get_center().x, cr.position.x + 30, cr.end.x - 30), cr.end.y)
	var to := rect.get_center()
	var dir := (to - from).normalized()
	var end := to - dir * (minf(rect.size.x, rect.size.y) * 0.5 + 6.0)
	draw_dashed_line(from, end, Color(1.0, 0.75, 0.15, 0.85), 3.0, 10.0, true)
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([end, end - dir * 18 + side * 9, end - dir * 18 - side * 9]), Color(1.0, 0.75, 0.15, 0.95))
