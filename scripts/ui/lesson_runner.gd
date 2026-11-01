class_name LessonRunner
extends Control
## Bài học lái theo tình huống trên đường liên tục.
## - Mỗi bước có mục tiêu đo thật (tốc độ, khoảng cách, vị trí). Đạt mới sang bước sau.
## - Chưa đạt: báo lý do và làm lại đúng bước đó (tại chỗ, hoặc ở tình huống kế tiếp phía trước).
## - Bước đã đạt không phải làm lại. Popup hiện thì xe đứng yên, ga/phanh/số/vô lăng giữ nguyên.
## Chuỗi lỗi do tick trả về có thể kèm chỉ thị:
##   "@next:msg"            làm lại bước này ở tình huống kế tiếp phía trước
##   "@redo_next:id:msg"    quay về bước id, ở tình huống kế tiếp
##   "@skip:msg"            ghi lỗi rồi sang bước sau (không thể làm lại tại chỗ)
##   "msg"                  làm lại bước này tại chỗ

signal finished

var hud: Hud
var car: PlayerCar
var yard: LessonYard
var lesson: int = 1
var steps: Array = []
var idx: int = -1
var st: Dictionary = {}           # dữ liệu tạm của bước hiện tại
var inst: int = 0                 # tình huống đang dùng (vạch dừng, ô đỗ, cầu...)
var guided: bool = true
var results: Array = []
var compact: bool = false
var _t: float = 0.0
var _stop_t: float = 0.0
var _warn_cool: Dictionary = {}
var _note: String = ""
var _note_good: bool = true
var _skip_c: Vector3 = Vector3(1e9, 0, 1e9)   # bài 2: ngã tư đã hỏng, bỏ qua để làm ở ngã tư sau
var _turn_j: Dictionary = {}
var _snap: Dictionary = {}                    # trạng thái xe lúc bắt đầu bước hiện tại (để "Làm lại")
var _fail_dlg: Control                  # bài 2: ngã tư đang rẽ

var card: PanelContainer
var title_l: Label
var body_l: Label
var note_l: Label
var hint_l: Label
var next_b: Button

var _holding: bool = false
var _hold_xf: Transform3D
var _hold_vel: Array = [Vector3.ZERO, Vector3.ZERO]


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
		5:
			_steps_hill()
	steps.append({"k": "ls_done", "tap": true})
	_expand_steps()
	_build_card()
	hud.gate_passed.connect(_on_gate)
	_go(0)


# ================================================================== tiện ích đo đạc

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


func _v() -> float:
	return car.speed_kmh


func _fz() -> float:
	return car.front_point().z


func _cm(d: float) -> String:
	return "%d cm" % int(round(absf(d) * 100.0))


func _cur() -> Dictionary:
	return yard.instances[clampi(inst, 0, yard.instances.size() - 1)]


func _cz(key: String) -> float:
	return float(_cur()[key])


## Chọn tình huống kế tiếp nằm phía trước xe ít nhất `margin` mét (theo khóa vị trí `key`)
func _next_inst(key: String, margin: float) -> void:
	for k in yard.instances.size():
		var d: Dictionary = yard.instances[k]
		if float(d[key]) - _fz() > margin:
			inst = k
			return
	inst = yard.instances.size() - 1


## Sau khi làm lại vì lỗi, chưa bắt lỗi tốc độ cho tới khi người chơi đưa tốc độ về đúng
func _too_fast(limit: float) -> String:
	if _v() <= limit:
		st["grace"] = false
		return ""
	if st.get("grace", false):
		return ""
	return Game.tf("lf_too_fast_slow", [int(round(_v())), int(limit)])


func _gear_step(key_auto: String, key_manual: String, want_reverse: bool, from_park: bool = false, id: String = "") -> Dictionary:
	var ok := func(): return _reverse() if want_reverse else _drive()
	if car.manual:
		return {"k": key_manual, "id": id, "t": hud.clutch_p, "ok": ok}
	var g: Control = hud.gear_btns.get("R" if want_reverse else "D")
	return {"k": key_auto, "id": id, "t": g, "ok": ok, "from_park": from_park}


func _park_step() -> Dictionary:
	var t: Control = hud.b_hb if car.manual else hud.gear_btns.get("P")
	return {"k": "ls_park_manual" if car.manual else "ls_park", "t": t, "ok": func(): return _parked()}


## Bước giữ tốc độ trong khoảng [lo, hi] liên tục `secs` giây.
## Nhanh quá, hoặc đã vào khoảng rồi lại tụt xuống = làm lại tại chỗ. Quá hạn `deadline` = làm ở tình huống sau.
func _speed_step(key: String, lo: float, hi: float, secs: float, deadline: Callable = Callable()) -> Dictionary:
	return {"k": key, "t": hud.gas, "tick": _tick_speed.bind(lo, hi, deadline),
		"ok": func(): return float(st.get("t_in", 0.0)) >= secs,
		"judge": func(): return Game.tf("lg_speed", [int(lo), int(hi), int(secs)])}


func _tick_speed(dt: float, lo: float, hi: float, deadline: Callable) -> String:
	var v := _v()
	if v >= lo and v <= hi:
		st["t_in"] = float(st.get("t_in", 0.0)) + dt
		st["was_in"] = true
		st["grace"] = false
	else:
		st["t_in"] = 0.0
		if not st.get("grace", false):
			if v > hi + 0.5:
				return Game.tf("lf_too_fast", [int(round(v)), int(lo), int(hi)])
			if st.get("was_in", false) and v < lo - 0.5:
				return Game.tf("lf_too_slow", [int(round(v)), int(lo), int(hi)])
	if deadline.is_valid() and deadline.call():
		return "@next:" + Game.tf("lf_not_in_time", [int(lo), int(hi)])
	return ""


## Xe số tự động rời số P: tách 3 bước — kéo phanh giữ cố định, chạm D, rồi nhả phanh.
func _expand_steps() -> void:
	var out: Array = []
	for s in steps:
		var d: Dictionary = s
		if d.get("from_park", false) and not car.manual:
			out.append({"k": "ls_brake_hold", "t": hud.brake_p, "ok": func(): return hud.brake_p.locked and hud.brake_p.value >= 0.15})
			out.append(d)
			out.append({"k": "ls_brake_release", "t": hud.brake_p, "ok": func(): return hud.brake_p.value <= 0.0})
		else:
			out.append(d)
	steps = out


func _step_index(key: String) -> int:
	for k in steps.size():
		var s: Dictionary = steps[k]
		if String(s.get("id", "")) == key:
			return k
	for k in steps.size():
		if String(steps[k]["k"]) == key:
			return k
	return idx


# ================================================================== bài 1: khởi hành và dừng xe (vạch STOP lặp lại)
func _steps_stop() -> void:
	steps = [
		{"k": "l1_intro", "tap": true},
		{"k": "l1_belt", "t": hud.b_belt, "ok": func(): return car.seatbelt},
		_gear_step("l1_gear", "l1_gear_manual", false, true),
		{"k": "l1_signal", "t": hud.b_blink_l, "ok": func(): return car.blinker == -1},
		_speed_step("l1_go", 25.0, 35.0, 3.0, func(): return _fz() > _cz("line_z") - 22.0),
		{"k": "l1_slow", "id": "slow", "t": hud.brake_p,
			"enter": func():
				if _fz() > _cz("line_z") - 16.0:
					_next_inst("line_z", 30.0),
			"ok": func(): return _fz() >= _cz("line_z") - 3.5 and _v() < 10.0,
			"tick": _tick_l1_slow,
			"judge": func(): return Game.t("lg_slow")},
		{"k": "l1_stop", "t": hud.brake_p, "ok": _ok_stop_line.bind("line_z"), "tick": _tick_stop_line.bind("line_z", ""),
			"judge": func(): return Game.tf("l1_good", [_cm(_cz("line_z") - _fz())])},
		_park_step(),
	]


func _tick_l1_slow(_dt: float) -> String:
	if _fz() >= _cz("line_z") - 3.5 and _v() >= 10.0:
		return "@next:" + Game.tf("lf_slow", [int(round(_v()))])
	return ""


func _ok_stop_line(key: String) -> bool:
	var d := _cz(key) - _fz()
	return _stopped() and d >= -0.05 and d <= 0.5


func _tick_stop_line(_dt: float, key: String, redo_id: String) -> String:
	var d := _cz(key) - _fz()
	if d < -0.05:
		if redo_id == "":
			return "@next:" + Game.tf("lf_over_line", [_cm(d)])
		return "@redo_next:%s:%s" % [redo_id, Game.tf("lf_over_line", [_cm(d)])]
	if _stopped() and d > 0.5:
		_warn("lw_not_yet", 3.0)
	return ""


# ================================================================== bài 2: rẽ phải, rẽ trái (lưới ngã tư thông nhau)
func _cardinal() -> Vector3:
	var h := car.forward()
	return Vector3(signf(h.x), 0, 0) if absf(h.x) > absf(h.z) else Vector3(0, 0, signf(h.z))


## Ngã tư phía trước theo hướng xe đang chạy: {c, d, s (khoảng cách dọc tới tâm)}. {} nếu không có.
func _junction_ahead() -> Dictionary:
	var d := _cardinal()
	var left := d.rotated(Vector3.UP, PI * 0.5)
	var p := car.front_point()
	var best := {}
	var bs := 1e9
	for q in yard.instances:
		var c: Vector3 = q["c"]
		if c.distance_to(_skip_c) < 1.0:
			continue
		var rel := c - p
		rel.y = 0
		var s := rel.dot(d)
		if s > -LessonYard.HW and s < bs and absf(rel.dot(left)) < 6.0:
			bs = s
			best = {"c": c, "d": d, "s": s}
	return best


func _js() -> float:
	var j := _junction_ahead()
	return float(j["s"]) if j.size() > 0 else 1e9


## Xe đang ở làn bên phải của đường mới, thẳng hướng, đã ra khỏi ngã tư
func _lane_ok() -> bool:
	var c: Vector3 = st.get("c", Vector3.ZERO)
	var d := _cardinal()
	var rel := car.global_position - c
	rel.y = 0
	var lat := rel.dot(d.rotated(Vector3.UP, -PI * 0.5))
	var h := car.forward()
	h.y = 0
	return rel.dot(d) > LessonYard.HW + 4.0 and lat > 0.3 and lat < LessonYard.HW - 0.3 and h.normalized().angle_to(d) < deg_to_rad(12.0)


func _blink_ok(sgn: float) -> bool:
	return car.blinker == (1 if sgn < 0 else -1)


func _turn_group(sgn: float) -> Array:
	var pre := "r" if sgn < 0 else "l"
	return [
		{"k": "l2_signal_" + pre, "id": "sig_" + pre, "t": hud.b_blink_r if sgn < 0 else hud.b_blink_l,
			"ok": func(): return _blink_ok(sgn) and _js() > 30.0 and _js() < 200.0,
			"tick": _tick_signal.bind(sgn, pre)},
		{"k": "l2_slow", "id": "slow_" + pre, "t": hud.brake_p,
			"ok": func(): return _js() <= LessonYard.HW + 3.0 and _v() < 15.0,
			"tick": _tick_turn_slow.bind(pre),
			"judge": func(): return Game.t("lg_turn_slow")},
		{"k": "l2_turn_" + pre, "id": "turn_" + pre, "t": hud.steer,
			"enter": func():
				st["yaw0"] = _yaw()
				_turn_j = _junction_ahead(),
			"ok": func(): return _turned() * sgn > deg_to_rad(55.0),
			"tick": _tick_turn.bind(sgn, pre),
			"judge": func(): return Game.t("l2_good_turn")},
		{"k": "l2_straight_" + pre, "id": "lane_" + pre, "t": hud.steer,
			"enter": func():
				st["c"] = _turn_j.get("c", car.global_position),
			"ok": func(): return _lane_ok(),
			"tick": _tick_lane.bind(pre),
			"judge": func(): return Game.t("l2_good_r" if sgn < 0 else "l2_good_l")},
	]


func _tick_signal(_dt: float, sgn: float, pre: String) -> String:
	var j := _junction_ahead()
	if j.size() > 0 and float(j["s"]) <= 30.0 and float(j["s"]) > 8.0 and not _blink_ok(sgn) and _v() > 3.0:
		_skip_c = j["c"]
		return "@redo_next:sig_%s:%s" % [pre, Game.t("l2_signal_late")]
	return ""


func _tick_turn_slow(_dt: float, pre: String) -> String:
	var j := _junction_ahead()
	if j.size() > 0 and float(j["s"]) <= LessonYard.HW + 3.0 and _v() >= 15.0:
		_skip_c = j["c"]
		return "@redo_next:sig_%s:%s" % [pre, Game.tf("lf_turn_fast", [int(round(_v()))])]
	return ""


func _tick_turn(_dt: float, sgn: float, pre: String) -> String:
	var j: Dictionary = _turn_j
	if j.is_empty():
		_turn_j = _junction_ahead()
		return ""
	var c: Vector3 = j["c"]
	var d: Vector3 = j["d"]
	var rel := car.global_position - c
	rel.y = 0
	if rel.dot(d) > LessonYard.HW + 4.0 and absf(_turned()) < deg_to_rad(30.0):
		_skip_c = c
		return "@redo_next:sig_%s:%s" % [pre, Game.t("lf_missed_turn")]
	if _turned() * sgn < -deg_to_rad(40.0):
		_skip_c = c
		return "@redo_next:sig_%s:%s" % [pre, Game.t("lf_wrong_way")]
	if sgn > 0 and rel.dot(d) < -1.5 and rel.dot(d.rotated(Vector3.UP, PI * 0.5)) > 0.8:
		# rẽ trái cắt góc: lấn sang bên trái khi chưa tới giữa ngã tư
		_skip_c = c
		return "@redo_next:sig_%s:%s" % [pre, Game.t("l2_cut")]
	return ""


func _tick_lane(_dt: float, pre: String) -> String:
	var c: Vector3 = st["c"]
	var rel := car.global_position - c
	rel.y = 0
	if rel.dot(_cardinal()) > 24.0 and not _lane_ok():
		_skip_c = c
		return "@redo_next:sig_%s:%s" % [pre, Game.t("lf_wrong_lane")]
	return ""


func _steps_turn() -> void:
	steps = [
		{"k": "l2_intro", "tap": true},
		_gear_step("l1_gear", "l1_gear_manual", false, true),
		_speed_step("l2_go", 15.0, 25.0, 2.0),
	]
	steps.append_array(_turn_group(-1.0))
	steps.append({"k": "l2_part2", "tap": true})
	steps.append_array(_turn_group(1.0))


# ================================================================== bài 3: quay đầu 3 điểm
func _far_gap() -> float:
	var m := -1e9
	for p in car.corner_points():
		m = maxf(m, (p as Vector2).x)
	return float(yard.geo["hw"]) - m


func _rear_gap() -> float:
	var m := 1e9
	for p in car.corner_points():
		m = minf(m, (p as Vector2).x)
	return m + float(yard.geo["hw"])


func _steps_uturn() -> void:
	steps = [
		{"k": "l3_intro", "tap": true},
		{"k": "l3_signal", "t": hud.b_blink_l, "ok": func(): return car.blinker == -1},
		_gear_step("l1_gear", "l1_gear_manual", false, true),
		{"k": "l3_fwd", "t": hud.steer, "enter": func(): st["yaw0"] = _yaw(),
			"ok": func(): return _turned() > deg_to_rad(30.0) or _far_gap() < 1.2,
			"tick": func(_dt: float) -> String: return _too_fast(8.0)},
		{"k": "l3_stop1", "t": hud.brake_p,
			"ok": func(): return _stopped() and _far_gap() >= 0.15 and _far_gap() <= 0.6,
			"tick": _tick_gap.bind(true),
			"judge": func(): return Game.tf("l3_gap", [_cm(_far_gap())])},
		_gear_step("l3_rev", "l3_rev_manual", true),
		{"k": "l3_back", "t": hud.steer, "enter": func(): st["yaw0"] = _yaw(),
			"ok": func(): return _turned() > deg_to_rad(40.0) or _rear_gap() < 1.2,
			"tick": func(_dt: float) -> String: return _too_fast(8.0)},
		{"k": "l3_stop2", "t": hud.brake_p,
			"ok": func(): return _stopped() and _rear_gap() >= 0.15 and _rear_gap() <= 0.8,
			"tick": _tick_gap.bind(false),
			"judge": func(): return Game.tf("l3_gap_rear", [_cm(_rear_gap())])},
		_gear_step("l3_fwd2", "l1_gear_manual", false),
		{"k": "l3_out", "t": hud.steer,
			"ok": func(): return absf(wrapf(_yaw() - PI, -PI, PI)) < deg_to_rad(15.0) and car.global_position.x > 0.2 and _v() > 3.0,
			"tick": func(_dt: float) -> String: return _too_fast(12.0),
			"judge": func(): return Game.t("l3_good")},
	]


func _tick_gap(_dt: float, front: bool) -> String:
	var g := _far_gap() if front else _rear_gap()
	if g < 0.03:
		# đã chạm lề thì không làm lại tại chỗ được: ghi lỗi, sang bước sau
		return "@skip:" + Game.t("l3_hit" if front else "l3_hit_rear")
	if _stopped() and g > (0.6 if front else 0.8):
		_warn("lw_kerb_far", 3.0)
	return ""


# ================================================================== bài 4: lùi chuồng (ô đỗ lặp lại dọc đường)
func _eye_z() -> float:
	return (car.global_transform * car.eye_position()).z


func _bay_yaw() -> float:
	return wrapf(_yaw() - PI * 0.5, -PI, PI)


func _in_bay() -> bool:
	var bay: Array = _cur()["bay"]
	for p in car.corner_points():
		var lp: Vector2 = (p as Vector2) - (bay[0] as Vector2)
		if absf(lp.x) > float(bay[2]) + 0.1 or absf(lp.y) > float(bay[3]) + 0.1:
			return false
	return true


func _steps_garage() -> void:
	steps = [
		{"k": "l4_intro", "tap": true},
		_gear_step("l1_gear", "l1_gear_manual", false, true, "gear"),
		_speed_step("l4_drive", 5.0, 10.0, 2.0, func(): return _eye_z() > _cz("mark_z") - 3.0),
		{"k": "l4_stop", "id": "stop", "t": hud.brake_p,
			"enter": func():
				if _eye_z() > _cz("mark_z") - 5.0:
					_next_inst("mark_z", 10.0),
			"ok": func(): return _stopped() and absf(_eye_z() - _cz("mark_z")) <= 0.4,
			"tick": _tick_mark,
			"judge": func(): return Game.t("l4_stop_good")},
		_gear_step("l4_rev", "l3_rev_manual", true),
		{"k": "l4_lock", "t": hud.steer, "enter": func(): st["yaw0"] = _yaw(),
			"ok": func(): return _turned() > deg_to_rad(65.0),
			"tick": func(_dt: float) -> String:
				if absf(car.global_position.z - _cz("bay_z")) > 10.0:
					return "@redo_next:gear:" + Game.t("lf_left_bay")
				return _too_fast(8.0)},
		{"k": "l4_straight", "t": hud.steer,
			"ok": func(): return absf(_bay_yaw()) < deg_to_rad(8.0) and absf(car.steer_input) < 0.25,
			"tick": func(_dt: float) -> String:
				if _bay_yaw() > deg_to_rad(30.0):
					return "@redo_next:gear:" + Game.t("lf_over_rotate")
				return _too_fast(8.0)},
		{"k": "l4_in", "t": hud.brake_p,
			"ok": func(): return _stopped() and _in_bay(),
			"tick": _tick_in_bay,
			"judge": func(): return Game.t("l4_good")},
		_park_step(),
	]


func _tick_mark(_dt: float) -> String:
	var d := _eye_z() - _cz("mark_z")
	if d > 0.8:
		return "@next:" + Game.tf("lf_past_mark", [_cm(d)])
	if _stopped() and d < -0.4:
		_warn("lw_not_yet", 3.0)
	return ""


func _tick_in_bay(_dt: float) -> String:
	var bay: Array = _cur()["bay"]
	var back_x: float = (bay[0] as Vector2).x - float(bay[2])
	for p in car.corner_points():
		if (p as Vector2).x < back_x - 0.3:
			return "@redo_next:gear:" + Game.t("lf_too_deep")
	if _stopped() and not _in_bay():
		_warn("lw_not_in_bay", 3.0)
	return _too_fast(6.0)


# ================================================================== bài 5: đề-pa lên cầu (cầu lặp lại)
func _steps_hill() -> void:
	steps = [
		{"k": "l5_intro", "tap": true},
		_gear_step("l1_gear", "l1_gear_manual", false, true),
		{"k": "l5_approach", "id": "app", "t": hud.gas,
			"enter": func():
				if _fz() > _cz("z0") - 12.0:
					_next_inst("z0", 20.0),
			"ok": func(): return _fz() >= _cz("z0") - 1.0 and _v() < 10.0,
			"tick": func(_dt: float) -> String:
				if _fz() >= _cz("z0") - 1.0 and _v() >= 10.0:
					return "@next:" + Game.tf("lf_slow", [int(round(_v()))])
				return "",
			"judge": func(): return Game.t("lg_slow")},
		{"k": "l5_stop", "id": "stop", "t": hud.brake_p, "ok": _ok_stop_line.bind("line_z"), "tick": _tick_stop_line.bind("line_z", ""),
			"judge": func(): return Game.tf("l1_good", [_cm(_cz("line_z") - _fz())])},
		{"k": "l5_hold", "t": hud.b_hb,
			"enter": func(): st["fz0"] = _fz(),
			"ok": func(): return car.handbrake and _stop_t > 2.0,
			"tick": _tick_rollback},
		{"k": "l5_start", "t": hud.gas,
			"enter": func():
				st["fz0"] = _fz()
				st["t0"] = _t,
			"ok": func(): return _fz() > _cz("top_z") + 1.0,
			"tick": func(dt: float) -> String:
				var f := _tick_rollback(dt)
				if f != "":
					return f
				if _t - float(st["t0"]) > 30.0:
					return "@redo_next:stop:" + Game.t("pen_hill_30s")
				return "",
			"judge": func(): return Game.t("l5_good")},
	]


func _tick_rollback(_dt: float) -> String:
	if _fz() < float(st.get("fz0", _fz())) - 0.5:
		return "@redo_next:stop:" + Game.t("pen_rollback")
	return ""


# ================================================================== popup

func _build_card() -> void:
	card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.1, 0.95)
	sb.set_corner_radius_all(22)
	sb.border_color = Color(0.35, 0.8, 1.0)
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", sb)
	card.gui_input.connect(_on_card_input)
	add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(vb)
	title_l = UiTheme.label("", 21, Color(0.35, 0.8, 1.0))
	vb.add_child(title_l)
	note_l = UiTheme.label("", 27, Color(0.45, 1.0, 0.55))
	note_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_l.visible = false
	vb.add_child(note_l)
	body_l = UiTheme.label("", 30, Color.WHITE)
	body_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_l.custom_minimum_size = Vector2(640, 0)
	vb.add_child(body_l)
	hint_l = UiTheme.label("", 21, Color(1.0, 0.82, 0.3))
	vb.add_child(hint_l)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.alignment = BoxContainer.ALIGNMENT_END
	vb.add_child(hb)
	next_b = UiTheme.button(Game.t("tut_next"), func(): _on_next(), 60)
	next_b.custom_minimum_size.x = 190
	next_b.add_theme_font_size_override("font_size", 26)
	hb.add_child(next_b)
	if not guided:
		card.visible = false


func _gate_for(s: Dictionary) -> Array:
	var t = s.get("t")
	if t == null or not (t is TouchCtl):
		return []
	if t == hud.steer or t == hud.gas or t == hud.brake_p:
		var arr: Array = [hud.gas, hud.brake_p]
		if hud.steer:
			arr.append(hud.steer)
		if hud.btn_left:
			arr.append_array([hud.btn_left, hud.btn_right])
		return arr
	return [t]


func _on_gate(_ctl: TouchCtl) -> void:
	if guided and not compact and idx >= 0 and idx < steps.size():
		_set_compact(true)


func _on_card_input(e: InputEvent) -> void:
	if compact or idx < 0 or idx >= steps.size():
		return
	var s: Dictionary = steps[idx]
	var pressed_ev: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	if pressed_ev and s.get("tap", false):
		_on_next()


func _on_next() -> void:
	var s: Dictionary = steps[idx]
	if s.get("tap", false):
		_go(idx + 1)
	else:
		_set_compact(true)


func _set_compact(v: bool) -> void:
	compact = v
	if v:
		card.anchor_left = 0.5
		card.anchor_right = 0.5
		card.anchor_top = 0.0
		card.anchor_bottom = 0.0
		card.offset_left = -330
		card.offset_right = 330
		card.offset_top = 176
		card.offset_bottom = 176
		body_l.add_theme_font_size_override("font_size", 23)
		body_l.custom_minimum_size = Vector2(600, 0)
		note_l.visible = false
		title_l.visible = false
		hint_l.visible = false
		next_b.visible = false
		card.modulate.a = 0.9
		hud.gate_ctls = []
		_pause(false)
	else:
		card.anchor_left = 0.5
		card.anchor_right = 0.5
		card.anchor_top = 0.5
		card.anchor_bottom = 0.5
		card.offset_left = -350
		card.offset_right = 350
		card.offset_top = -200
		card.offset_bottom = -200
		body_l.add_theme_font_size_override("font_size", 30)
		body_l.custom_minimum_size = Vector2(640, 0)
		title_l.visible = true
		card.modulate.a = 1.0
		var s: Dictionary = steps[idx]
		var gate := _gate_for(s)
		var tap: bool = s.get("tap", false)
		hud.gate_ctls = gate
		next_b.visible = tap or gate.is_empty()
		next_b.text = (Game.t("ls_finish") if idx == steps.size() - 1 else Game.t("tut_next")) if tap else "OK"
		hint_l.visible = not tap and not gate.is_empty()
		hint_l.text = "👉 " + Game.t("ls_tap_hint")
		_pause(true)
	card.call_deferred("reset_size")
	queue_redraw()


func _pause(v: bool, always: bool = false) -> void:
	if not guided and not always:
		return
	# Giữ xe đứng yên tại chỗ trong lúc đọc; ga/phanh/số/vô lăng giữ nguyên mức
	if v and not _holding:
		_holding = true
		_hold_xf = car.global_transform
		_hold_vel = [car.linear_velocity, car.angular_velocity]
	elif not v and _holding:
		_holding = false
		car.linear_velocity = _hold_vel[0]
		car.angular_velocity = _hold_vel[1]
	hud.set_controls_enabled(not v, true)


func _physics_process(_delta: float) -> void:
	if _holding:
		car.global_transform = _hold_xf
		car.linear_velocity = Vector3.ZERO
		car.angular_velocity = Vector3.ZERO


func _go(i: int, again: bool = false) -> void:
	idx = i
	st = {"grace": again}
	if idx >= steps.size():
		_finish()
		return
	var s: Dictionary = steps[idx]
	var tap: bool = s.get("tap", false)
	if not guided and tap:
		if s.has("enter"):
			(s["enter"] as Callable).call()
		_go(idx + 1)
		return
	var title := "%s · %s %d/%d" % [Game.t("lesson_l%d" % lesson).to_upper(), Game.t("step_word"), idx + 1, steps.size()]
	if again:
		title += " · " + Game.t("ls_redo")
	title_l.text = title
	body_l.text = Game.t(s["k"])
	note_l.text = _note
	note_l.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55) if _note_good else Color(1.0, 0.5, 0.35))
	note_l.visible = _note != ""
	_note = ""
	if not tap:
		_snap = _snapshot()
	if s.has("enter"):
		(s["enter"] as Callable).call()
	if guided:
		_set_compact(false)
	queue_redraw()


func _snapshot() -> Dictionary:
	var d := {"xf": car.global_transform, "lv": car.linear_velocity, "av": car.angular_velocity,
		"mode": car.auto_mode, "gear": car.gear, "blink": car.blinker, "hb": car.handbrake, "belt": car.seatbelt,
		"gas": hud.gas.value, "gas_l": hud.gas.locked, "brake": hud.brake_p.value, "brake_l": hud.brake_p.locked, "inst": inst}
	if _holding:
		d["xf"] = _hold_xf
		d["lv"] = _hold_vel[0]
		d["av"] = _hold_vel[1]
	return d


func _restore(d: Dictionary) -> void:
	if d.is_empty():
		return
	car.global_transform = d["xf"]
	car.linear_velocity = d["lv"]
	car.angular_velocity = d["av"]
	_hold_xf = d["xf"]
	_hold_vel = [d["lv"], d["av"]]
	car.auto_mode = d["mode"]
	car.gear = d["gear"]
	car.blinker = d["blink"]
	car.handbrake = d["hb"]
	car.seatbelt = d["belt"]
	hud.gas.set_value(d["gas"])
	hud.gas.locked = d["gas_l"]
	hud.brake_p.set_value(d["brake"])
	hud.brake_p.locked = d["brake_l"]
	inst = d["inst"]
	_skip_c = Vector3(1e9, 0, 1e9)
	_stop_t = 0.0


## Bỏ chỉ thị cũ ở đầu lời báo lỗi ("@next:", "@skip:", "@redo_next:id:")
static func _clean(msg: String) -> String:
	if msg.begins_with("@redo_next:") or msg.begins_with("@redo:"):
		var rest := msg.substr(msg.find(":") + 1)
		return rest.substr(rest.find(":") + 1)
	if msg.begins_with("@"):
		return msg.substr(msg.find(":") + 1)
	return msg


## Sai bước: xe dừng, hiện bảng lỗi với 2 lựa chọn
##  - Làm lại: xe quay về đúng lúc vừa xong bước trước (vị trí, tốc độ, số, xi nhan, ga/phanh) để làm lại bước này
##  - Tiếp tục: đóng bảng, xe chạy tiếp như thường, bước này tính là chưa đạt
func _fail(msg: String) -> void:
	msg = _clean(msg)
	results.append([false, msg])
	Sfx.play("fail", -4.0)
	var s: Dictionary = steps[idx]
	if guided and not compact:
		_set_compact(true)
	_pause(true, true)
	var body := "✗ " + msg + "\n\n" + Game.t("ls_how") + " " + Game.t(s["k"])
	_fail_dlg = UiTheme.dialog(hud, Game.t("ls_wrong"), body, [
		[Game.t("ls_redo_btn"), func():
			_fail_dlg = null
			_restore(_snap)
			if guided:
				_note = "✗ " + msg
				_note_good = false
				_go(idx, true)
			else:
				_pause(false, true)
				st = {"grace": true}
				if s.has("enter"):
					(s["enter"] as Callable).call()],
		[Game.t("ls_continue_btn"), func():
			_fail_dlg = null
			_pause(false, true)
			_note = ""
			_go(idx + 1)],
	], Color(1.0, 0.5, 0.35))


func _pass(s: Dictionary) -> void:
	var msg := Game.t("tut_good")
	if s.has("judge"):
		msg = String((s["judge"] as Callable).call())
		results.append([true, msg])
	Sfx.play("ding", -5.0)
	if not guided and s.has("judge"):
		hud.toast("✓ " + msg, Color(0.45, 1.0, 0.55), 2.5)
	_note = "✓ " + msg
	_note_good = true
	_go(idx + 1)


func _finish() -> void:
	_pause(false)
	set_process(false)
	set_physics_process(false)
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
	if guided and not compact:
		return
	if _fail_dlg != null:
		return
	var s: Dictionary = steps[idx]
	if s.get("tap", false):
		return
	if s.has("tick"):
		var f: String = (s["tick"] as Callable).call(delta)
		if f != "":
			_fail(f)
			return
	if s.has("ok") and (s["ok"] as Callable).call():
		_pass(s)


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
	if compact:
		return
	var cr := card.get_global_rect()
	var from := Vector2(clampf(rect.get_center().x, cr.position.x + 30, cr.end.x - 30), cr.end.y)
	var to := rect.get_center()
	var dir := (to - from).normalized()
	var end := to - dir * (minf(rect.size.x, rect.size.y) * 0.5 + 6.0)
	draw_dashed_line(from, end, Color(0.35, 0.8, 1.0, 0.85), 3.0, 10.0, true)
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([end, end - dir * 18 + side * 9, end - dir * 18 - side * 9]), Color(0.35, 0.8, 1.0, 0.95))
