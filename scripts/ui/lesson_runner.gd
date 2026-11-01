class_name LessonRunner
extends Control
## Bài học lái theo tình huống: popup hướng dẫn từng bước, người chơi làm thật, game kiểm tra và nhận xét.

signal finished

var hud: Hud
var car: PlayerCar
var yard: LessonYard
var lesson: int = 1
var steps: Array = []
var idx: int = -1
var st: Dictionary = {}          # dữ liệu tạm của bước hiện tại
var card: PanelContainer
var title_l: Label
var body_l: Label
var note_l: Label
var next_b: Button
var _t: float = 0.0
var _ok_timer: float = -1.0
var _stop_t: float = 0.0
var _warn_cool: Dictionary = {}
var guided: bool = true           # false = tự tập: không popup, cuối bài mới nhận xét
var results: Array = []           # [đạt?, lời nhận xét] của các bước có chấm
var try_b: Button
var again_b: Button
var compact: bool = false
var _pending_note: String = ""
var _pending_good: bool = true
var _start_t: float = 0.0


func setup(p_hud: Hud, p_car: PlayerCar, p_yard: LessonYard) -> void:
	hud = p_hud
	car = p_car
	yard = p_yard
	lesson = yard.lesson
	guided = Game.lesson_guided
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	process_physics_priority = 100
	match lesson:
		1:
			_steps_stop()
		2:
			_steps_turn()
		3:
			_steps_uturn()
		4:
			_steps_garage()
	steps.append({"k": "ls_done", "tap": true})
	_build_card()
	_go(0)


# ------------------------------------------------------------------ tiện ích

func _drive() -> bool:
	return car.gear >= 1 if car.manual else car.auto_mode == "D"


func _reverse() -> bool:
	return car.gear == -1 if car.manual else car.auto_mode == "R"


func _parked() -> bool:
	return (car.gear == 0 if car.manual else car.auto_mode == "P") and car.handbrake


func _yaw() -> float:
	var f := car.forward()
	return atan2(f.x, f.z)


## Góc đã quay kể từ đầu bước (dương = quay trái)
func _turned() -> float:
	return wrapf(_yaw() - float(st.get("yaw0", 0.0)), -PI, PI)


func _stopped() -> bool:
	return _stop_t > 0.5


func _gear_step(key_auto: String, key_manual: String, want_reverse: bool) -> Dictionary:
	if car.manual:
		var t: Control = hud.clutch_p
		return {"k": key_manual, "t": t, "ok": func(): return _reverse() if want_reverse else _drive()}
	var g: Control = hud.gear_btns.get("R" if want_reverse else "D")
	return {"k": key_auto, "t": g, "ok": func(): return _reverse() if want_reverse else _drive()}


func _park_step() -> Dictionary:
	var t: Control = hud.b_hb if car.manual else hud.gear_btns.get("P")
	return {"k": "ls_park_manual" if car.manual else "ls_park", "t": t, "ok": func(): return _parked()}


func _cm(d: float) -> String:
	return "%d cm" % int(round(absf(d) * 100.0))


# ------------------------------------------------------------------ bài 1: khởi hành và dừng xe
func _steps_stop() -> void:
	var line_z: float = yard.geo["line_z"]
	steps = [
		{"k": "l1_intro", "tap": true},
		{"k": "l1_belt", "t": hud.b_belt, "ok": func(): return car.seatbelt},
		_gear_step("l1_gear", "l1_gear_manual", false),
		{"k": "l1_signal", "t": hud.b_blink_l, "ok": func(): return car.blinker == -1},
		{"k": "l1_go", "t": hud.gas, "ok": func(): return car.speed_kmh > 12.0},
		{"k": "l1_keep", "t": hud.gauges, "ok": func(): return car.front_point().z > line_z - 16.0},
		{"k": "l1_slow", "t": hud.brake_p, "ok": func(): return car.speed_kmh < 8.0 or car.front_point().z > line_z - 4.0},
		{"k": "l1_stop", "t": hud.brake_p, "ok": func(): return _stopped(), "judge": func():
			var d := line_z - car.front_point().z
			if d < 0.0:
				return [false, Game.tf("l1_over", [_cm(d)])]
			if d > 0.5:
				return [false, Game.tf("l1_early", [_cm(d)])]
			return [true, Game.tf("l1_good", [_cm(d)])]},
		_park_step(),
	]


# ------------------------------------------------------------------ bài 2: rẽ phải, rẽ trái
func _steps_turn() -> void:
	var cz: float = yard.geo["cz"]
	var hw: float = yard.geo["hw"]
	var stop_z: float = yard.geo["stop_z"]
	var right_lane_ok := func():
		var p := car.global_position
		return p.x < -10.0 and p.z > cz - hw + 0.4 and p.z < cz - 0.4 and absf(wrapf(_yaw() + PI * 0.5, -PI, PI)) < deg_to_rad(12.0)
	var left_lane_ok := func():
		var p := car.global_position
		return p.x > 10.0 and p.z > cz + 0.4 and p.z < cz + hw - 0.4 and absf(wrapf(_yaw() - PI * 0.5, -PI, PI)) < deg_to_rad(12.0)
	steps = [
		{"k": "l2_intro", "tap": true},
		_gear_step("l1_gear", "l1_gear_manual", false),
		{"k": "l2_go", "t": hud.gas, "ok": func(): return car.speed_kmh > 10.0},
		{"k": "l2_signal_r", "t": hud.b_blink_r, "ok": func(): return car.blinker == 1, "warn_late": stop_z},
		{"k": "l2_slow", "t": hud.brake_p, "ok": func(): return car.speed_kmh < 15.0 and car.front_point().z > stop_z - 12.0},
		{"k": "l2_turn_r", "t": hud.steer, "enter": func(): st["yaw0"] = _yaw(), "ok": func(): return _turned() < -deg_to_rad(55.0)},
		{"k": "l2_straight_r", "t": hud.steer, "ok": right_lane_ok, "judge": func():
			return [true, Game.t("l2_good_r")]},
		{"k": "l2_part2", "tap": true, "enter": func():
			car.global_transform = yard.spawn_xf
			car.linear_velocity = Vector3.ZERO
			car.angular_velocity = Vector3.ZERO
			car.blinker = 0
			hud.gas.set_value(0.0)},
		{"k": "l2_signal_l", "t": hud.b_blink_l, "ok": func(): return car.blinker == -1},
		{"k": "l2_go", "t": hud.gas, "ok": func(): return car.speed_kmh > 10.0},
		{"k": "l2_slow", "t": hud.brake_p, "ok": func(): return car.speed_kmh < 15.0 and car.front_point().z > stop_z - 12.0},
		{"k": "l2_turn_l", "t": hud.steer, "enter": func(): st["yaw0"] = _yaw(), "ok": func(): return _turned() > deg_to_rad(55.0), "judge": func():
			# rẽ trái phải đi qua gần tâm ngã tư, không cắt góc
			var cut: bool = st.get("cut", false)
			return [not cut, Game.t("l2_cut") if cut else Game.t("l2_good_turn")]},
		{"k": "l2_straight_l", "t": hud.steer, "ok": left_lane_ok, "judge": func():
			return [true, Game.t("l2_good_l")]},
	]


# ------------------------------------------------------------------ bài 3: quay đầu 3 điểm
func _steps_uturn() -> void:
	var hw: float = yard.geo["hw"]
	steps = [
		{"k": "l3_intro", "tap": true},
		{"k": "l3_signal", "t": hud.b_blink_l, "ok": func(): return car.blinker == -1},
		_gear_step("l1_gear", "l1_gear_manual", false),
		{"k": "l3_fwd", "t": hud.steer, "enter": func(): st["yaw0"] = _yaw(), "ok": func(): return _turned() > deg_to_rad(55.0) or car.front_point().x > hw - 1.2},
		{"k": "l3_stop1", "t": hud.brake_p, "ok": func(): return _stopped(), "judge": func():
			var gap := hw - maxf(car.front_point().x, _corner_max_x())
			if gap < 0.05:
				return [false, Game.t("l3_hit")]
			return [true, Game.tf("l3_gap", [_cm(gap)])]},
		_gear_step("l3_rev", "l3_rev_manual", true),
		{"k": "l3_back", "t": hud.steer, "enter": func(): st["yaw0"] = _yaw(), "ok": func(): return _turned() > deg_to_rad(55.0) or car.rear_point().x < -hw + 1.0},
		{"k": "l3_stop2", "t": hud.brake_p, "ok": func(): return _stopped()},
		_gear_step("l3_fwd2", "l1_gear_manual", false),
		{"k": "l3_out", "t": hud.steer, "ok": func():
			var y := wrapf(_yaw() - PI, -PI, PI)
			return absf(y) < deg_to_rad(15.0) and car.global_position.x > 0.2 and car.speed_kmh > 3.0, "judge": func():
			return [true, Game.t("l3_good")]},
	]


func _corner_max_x() -> float:
	var m := -1e9
	for p in car.corner_points():
		var v: Vector2 = p
		m = maxf(m, v.x)
	return m


# ------------------------------------------------------------------ bài 4: lùi chuồng
func _steps_garage() -> void:
	var mark_z: float = yard.geo["mark_z"]
	var bay: Array = yard.geo["bay"]
	steps = [
		{"k": "l4_intro", "tap": true},
		_gear_step("l1_gear", "l1_gear_manual", false),
		{"k": "l4_drive", "t": hud.gas, "ok": func(): return car.global_position.z > mark_z - 9.0},
		{"k": "l4_stop", "t": hud.brake_p, "ok": func(): return _stopped() and car.global_position.z > mark_z - 6.0, "judge": func():
			var eye_z := (car.global_transform * car.eye_position()).z
			var d := eye_z - mark_z
			if absf(d) <= 0.6:
				return [true, Game.t("l4_stop_good")]
			return [false, Game.tf("l4_stop_off", [_cm(d), Game.t("l4_before") if d < 0 else Game.t("l4_after")])]},
		_gear_step("l4_rev", "l3_rev_manual", true),
		{"k": "l4_lock", "t": hud.steer, "enter": func(): st["yaw0"] = _yaw(), "ok": func(): return _turned() > deg_to_rad(65.0)},
		{"k": "l4_straight", "t": hud.steer, "ok": func():
			var y := wrapf(_yaw() - PI * 0.5, -PI, PI)
			return absf(y) < deg_to_rad(8.0) and absf(car.steer_input) < 0.25},
		{"k": "l4_in", "t": hud.brake_p, "ok": func():
			if not _stopped():
				return false
			for p in car.corner_points():
				var v: Vector2 = p
				var lp: Vector2 = v - bay[0]
				if absf(lp.x) > float(bay[2]) + 0.1 or absf(lp.y) > float(bay[3]) + 0.1:
					return false
			return true, "judge": func():
			return [true, Game.t("l4_good")]},
		_park_step(),
	]


# ------------------------------------------------------------------ giao diện thẻ

func _build_card() -> void:
	card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.1, 0.95)
	sb.set_corner_radius_all(22)
	sb.border_color = Color(0.35, 0.8, 1.0)
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		sb.set_content_margin(side, 26)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		sb.set_content_margin(side, 18)
	card.add_theme_stylebox_override("panel", sb)
	add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)
	title_l = UiTheme.label("", 18, Color(0.35, 0.8, 1.0))
	vb.add_child(title_l)
	note_l = UiTheme.label("", 23, Color(0.45, 1.0, 0.55))
	note_l.visible = false
	vb.add_child(note_l)
	body_l = UiTheme.label("", 26, Color.WHITE)
	body_l.custom_minimum_size = Vector2(600, 0)
	vb.add_child(body_l)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.alignment = BoxContainer.ALIGNMENT_END
	vb.add_child(hb)
	again_b = UiTheme.button(Game.t("ls_retry"), func(): Game.start_drive("lesson"), 56)
	again_b.custom_minimum_size.x = 150
	again_b.add_theme_font_size_override("font_size", 20)
	hb.add_child(again_b)
	next_b = UiTheme.button(Game.t("tut_next"), func(): _go(idx + 1), 56)
	next_b.custom_minimum_size.x = 170
	hb.add_child(next_b)
	try_b = UiTheme.button("▶ " + Game.t("ls_try"), func(): _set_compact(true), 56)
	try_b.custom_minimum_size.x = 190
	try_b.add_theme_font_size_override("font_size", 24)
	hb.add_child(try_b)
	if not guided:
		card.visible = false


## Thẻ lớn giữa màn hình (game tạm dừng) hoặc thanh nhắc nhỏ phía trên (đang làm thử).
func _set_compact(v: bool) -> void:
	compact = v
	if v:
		card.anchor_left = 0.5
		card.anchor_right = 0.5
		card.anchor_top = 0.0
		card.anchor_bottom = 0.0
		card.offset_left = -300
		card.offset_right = 300
		card.offset_top = 172
		card.offset_bottom = 172
		body_l.add_theme_font_size_override("font_size", 19)
		body_l.custom_minimum_size = Vector2(560, 0)
		note_l.visible = false
		title_l.visible = false
		for b in [again_b, next_b, try_b]:
			b.visible = false
		card.modulate.a = 0.88
		_pause(false)
	else:
		card.anchor_left = 0.5
		card.anchor_right = 0.5
		card.anchor_top = 0.5
		card.anchor_bottom = 0.5
		card.offset_left = -330
		card.offset_right = 330
		card.offset_top = -150
		card.offset_bottom = -150
		body_l.add_theme_font_size_override("font_size", 26)
		body_l.custom_minimum_size = Vector2(600, 0)
		title_l.visible = true
		again_b.visible = true
		card.modulate.a = 1.0
		_pause(true)
	card.call_deferred("reset_size")
	queue_redraw()


func _pause(v: bool) -> void:
	if not guided:
		return
	# Giữ xe đứng yên tại chỗ trong lúc đọc hướng dẫn, nhả ra thì chạy tiếp đúng vận tốc cũ
	if v and not _holding:
		_holding = true
		_hold_xf = car.global_transform
		_hold_vel = [car.linear_velocity, car.angular_velocity]
	elif not v and _holding:
		_holding = false
		car.linear_velocity = _hold_vel[0]
		car.angular_velocity = _hold_vel[1]
	hud.set_controls_enabled(not v)


var _holding: bool = false
var _hold_xf: Transform3D
var _hold_vel: Array = [Vector3.ZERO, Vector3.ZERO]


func _physics_process(_delta: float) -> void:
	if _holding:
		car.global_transform = _hold_xf
		car.linear_velocity = Vector3.ZERO
		car.angular_velocity = Vector3.ZERO


func _go(i: int) -> void:
	idx = i
	_ok_timer = -1.0
	st = {}
	if idx >= steps.size():
		_finish()
		return
	var s: Dictionary = steps[idx]
	var tap: bool = s.get("tap", false)
	if not guided and tap:
		if s.has("enter"):
			var ecb: Callable = s["enter"]
			ecb.call()
		_go(idx + 1)
		return
	title_l.text = "%s · %s %d/%d" % [Game.t("lesson_l%d" % lesson).to_upper(), Game.t("step_word"), idx + 1, steps.size()]
	body_l.text = Game.t(s["k"])
	note_l.text = _pending_note
	note_l.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55) if _pending_good else Color(1.0, 0.75, 0.3))
	note_l.visible = _pending_note != ""
	_pending_note = ""
	next_b.visible = tap
	try_b.visible = not tap
	next_b.text = Game.t("ls_finish") if idx == steps.size() - 1 else Game.t("tut_next")
	if s.has("enter"):
		var cb: Callable = s["enter"]
		cb.call()
	if guided:
		_set_compact(false)
	queue_redraw()


func _finish() -> void:
	_pause(false)
	set_process(false)
	visible = false
	finished.emit()
	queue_free()


func _warn(key: String, cool: float = 4.0) -> void:
	if _warn_cool.has(key) and _t - float(_warn_cool[key]) < cool:
		return
	_warn_cool[key] = _t
	hud.toast(Game.t(key), Color(1.0, 0.75, 0.3), 3.0)
	Sfx.play("tock", -2.0)


func _process(delta: float) -> void:
	_t += delta
	if not _holding:
		_stop_t = _stop_t + delta if car.speed_kmh < 0.6 else 0.0
	queue_redraw()
	if idx < 0 or idx >= steps.size():
		return
	# nhắc nhở chung
	if car.speed_kmh > 30.0:
		_warn("ls_too_fast")
	if lesson == 3 or lesson == 4:
		if car.speed_kmh > 8.0:
			_warn("ls_slow_down")
	if lesson == 2 and car.global_position.z > float(yard.geo["cz"]) - 3.0 and car.speed_kmh > 22.0:
		_warn("l2_too_fast")
	var s: Dictionary = steps[idx]
	if String(s["k"]) == "l2_turn_l":
		# rẽ trái cắt góc: xe vào phần đường bên trái khi chưa tới tâm ngã tư
		var p := car.global_position
		if p.z < float(yard.geo["cz"]) - 1.0 and p.x > 0.6:
			st["cut"] = true
	if s.has("warn_late") and car.front_point().z > float(s["warn_late"]) - 6.0 and car.blinker != 1:
		_warn("l2_signal_late")
	if guided and not compact:
		return
	if s.has("ok"):
		var cb: Callable = s["ok"]
		if cb.call():
			var good := true
			var msg := "✓ " + Game.t("tut_good")
			if s.has("judge"):
				var jcb: Callable = s["judge"]
				var r: Array = jcb.call()
				good = r[0]
				msg = ("✓ " if good else "! ") + String(r[1])
			if s.has("judge"):
				results.append([good, msg.substr(2)])
			Sfx.play("ding" if good else "tock", -5.0)
			_pending_note = msg
			_pending_good = good
			_go(idx + 1)


func _draw() -> void:
	if not guided or idx < 0 or idx >= steps.size():
		return
	var s: Dictionary = steps[idx]
	var t: Control = s.get("t")
	if t == null or not is_instance_valid(t) or not t.is_visible_in_tree():
		return
	var rect := t.get_global_rect().grow(8.0 + sin(_t * 6.0) * 4.0)
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color(0.35, 0.8, 1.0, 0.95)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(22)
	sb.anti_aliasing = true
	draw_style_box(sb, rect)
	var cr := card.get_global_rect()
	var from := Vector2(clampf(rect.get_center().x, cr.position.x + 30, cr.end.x - 30), cr.end.y)
	var to := rect.get_center()
	var dir := (to - from).normalized()
	var end := to - dir * (minf(rect.size.x, rect.size.y) * 0.5 + 6.0)
	draw_dashed_line(from, end, Color(0.35, 0.8, 1.0, 0.85), 3.0, 10.0, true)
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([end, end - dir * 18 + side * 9, end - dir * 18 - side * 9]), Color(0.35, 0.8, 1.0, 0.95))
