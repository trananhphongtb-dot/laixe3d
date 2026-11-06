class_name CityMode
extends Node3D
## Luật giao thông trong thành phố + chế độ lái tự do và nhiệm vụ.

signal mission_finished(success: bool, reward: int, details: String)

var city: City
var car: PlayerCar
var hud: Hud
var mission: Dictionary = {}
var mission_id: int = -1

var violations: int = 0
var earned: int = 0
var time: float = 0.0
var _dist_acc: float = 0.0
var _last_pos: Vector3
var _cool: Dictionary = {}
var _wrong_t: float = 0.0
var _last_blink: float = -100.0
var _node_prev: Vector2i = Vector2i(-1, -1)
var _prev_s: float = 1e9
var _in_x: bool = false
var _x_yaw: float = 0.0
var _x_signal: bool = false
var _belt_t: float = 0.0
var _info_t: float = 0.0
var _done: bool = false
var _marker: Node3D
var _targets: Array = []
var _target_idx: int = 0
var _hold: float = 0.0
var _rng := RandomNumberGenerator.new()
# lái tự do: lưu trạng thái xe vài giây gần nhất để "lái lại đoạn này"
var _hist: Array = []
var _hist_t: float = 0.0
var _holding: bool = false
var _hold_xf: Transform3D
var _popup: Control
const REWIND_S := 8.0          # mặc định lùi bao nhiêu giây
const HIST_KEEP := 16.0       # lưu lịch sử bấy nhiêu giây
# Lỗi báo muộn (xi nhan, đèn đỏ, sai làn) cần lùi xa hơn để kịp tới trước chỗ sai
const REWIND_BY := {"v_red_light": 12.0, "v_no_signal": 12.0, "v_wrong_lane": 10.0, "v_speed": 7.0, "v_crash": 8.0}
var _countdown: bool = false


func setup(p_city: City, p_car: PlayerCar, p_hud: Hud, p_mission: int) -> void:
	city = p_city
	car = p_car
	hud = p_hud
	mission_id = p_mission
	city.player = car
	process_physics_priority = 100
	car.crashed.connect(_on_crash)
	_last_pos = car.global_position
	if mission_id >= 0:
		mission = Game.MISSIONS[mission_id]
		_rng.seed = 1000 + mission_id * 37
		_setup_mission()


func spawn_transform() -> Transform3D:
	var p := city.lane_point(Vector2i(0, 0), Vector3(0, 0, 1), 18.0)
	return Transform3D(Basis(), p + Vector3(0, 0.15, 0))


# ------------------------------------------------------------------ vi phạm

func _violate(key: String, cool: float = 6.0, money_pen: bool = true) -> void:
	var now := time
	if _cool.has(key) and now - float(_cool[key]) < cool:
		return
	_cool[key] = now
	violations += 1
	Sfx.play("fail", -4.0)
	if mission_id < 0 and _popup == null and not _holding:
		_violation_popup(key)
	else:
		hud.toast(Game.t("viol") + ": " + Game.t(key), Color(1.0, 0.45, 0.3), 3.0)


func _snapshot() -> Dictionary:
	return {"t": time, "xf": car.global_transform, "lv": car.linear_velocity, "av": car.angular_velocity,
		"mode": car.auto_mode, "gear": car.gear, "blink": car.blinker, "lights": car.lights_on, "hb": car.handbrake,
		"belt": car.seatbelt, "gas": hud.gas.value, "gas_l": hud.gas.locked, "brake": hud.brake_p.value, "brake_l": hud.brake_p.locked}


func _violation_popup(key: String) -> void:
	_holding = true
	_hold_xf = car.global_transform
	var keep_v := [car.linear_velocity, car.angular_velocity]
	hud.set_controls_enabled(false, true)
	car.set_horn(false)
	var buttons: Array = []
	if key != "v_belt" and _hist.size() > 0:
		buttons.append([Game.t("rw_replay"), func():
			_popup = null
			_rewind(key)])
	buttons.append([Game.t("rw_continue"), func():
		_popup = null
		_holding = false
		car.linear_velocity = keep_v[0]
		car.angular_velocity = keep_v[1]
		hud.set_controls_enabled(true, true)])
	_popup = UiTheme.dialog(hud, Game.t("viol") + ": " + Game.t(key), Game.t(key + "_why"), buttons, Color(1.0, 0.45, 0.3))


func _rewind(key: String) -> void:
	var back: float = float(REWIND_BY.get(key, REWIND_S))
	var snap: Dictionary = _hist[0]
	for h in _hist:
		var d: Dictionary = h
		if float(d["t"]) <= time - back:
			snap = d
	car.global_transform = snap["xf"]
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	car.auto_mode = snap["mode"]
	car.gear = snap["gear"]
	car.blinker = snap["blink"]
	car.set_lights(snap["lights"])
	car.handbrake = snap["hb"]
	car.seatbelt = snap["belt"]
	hud.reset_steering()
	hud.gas.set_value(snap["gas"])
	hud.gas.locked = snap["gas_l"]
	hud.brake_p.set_value(snap["brake"])
	hud.brake_p.locked = snap["brake_l"]
	violations = maxi(0, violations - 1)
	_cool.erase(key)
	# bỏ lịch sử sau điểm quay lại, reset trạng thái nhận diện ngã tư / làn
	var keep: Array = []
	for h in _hist:
		if float(h["t"]) <= float(snap["t"]):
			keep.append(h)
	_hist = keep
	_prev_s = 1e9
	_in_x = false
	_wrong_t = 0.0
	_last_pos = car.global_position
	_hold_xf = car.global_transform
	_holding = true
	Sfx.play("ui", -4.0)
	_resume_after_countdown(snap["lv"], snap["av"])


## Xe đứng yên 3 giây (vô lăng đã về giữa) để người chơi chuẩn bị, rồi mới chạy lại với tốc độ cũ
func _resume_after_countdown(lv: Vector3, av: Vector3) -> void:
	_countdown = true
	hud.set_controls_enabled(false, true)
	hud.toast(Game.t("rw_done"), UiTheme.ACCENT, 2.5)
	for n in [3, 2, 1]:
		hud.toast(str(n), Color(1.0, 0.85, 0.3), 0.9)
		Sfx.play("tick", -4.0)
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree():
			return
	hud.toast(Game.t("rw_go"), Color(0.5, 1.0, 0.5), 1.5)
	Sfx.play("ding", -4.0)
	_countdown = false
	_holding = false
	car.linear_velocity = lv
	car.angular_velocity = av
	hud.set_controls_enabled(true, true)


func _on_crash(_impact: float) -> void:
	_violate("v_crash", 2.0)


func _physics_process(delta: float) -> void:
	if car == null or _done:
		return
	if _holding:
		car.global_transform = _hold_xf
		car.linear_velocity = Vector3.ZERO
		car.angular_velocity = Vector3.ZERO
		return
	time += delta
	if mission_id < 0:
		_hist_t -= delta
		if _hist_t <= 0.0:
			_hist_t = 0.1
			_hist.append(_snapshot())
			while _hist.size() > 0 and time - float(_hist[0]["t"]) > HIST_KEEP:
				_hist.pop_front()
	var p := car.global_position
	var h := car.forward()
	h.y = 0
	h = h.normalized()
	if car.blinker == -1 or car.blinker == 1:
		_last_blink = time

	# tốc độ
	if car.speed_kmh > 62.0:
		_violate("v_speed", 8.0)
	# dây an toàn
	if not car.seatbelt and car.speed_kmh > 8.0:
		_belt_t -= delta
		if _belt_t <= 0.0:
			_belt_t = 3.0
			Sfx.play("chime", -6.0)
			if mission_id >= 0:
				_violate("v_belt", 60.0)
	var gx := p.x - city.snap_x(p.x)
	var gz := p.z - city.snap_z(p.z)
	var on_ns := absf(gx) < City.RW
	var on_ew := absf(gz) < City.RW
	var n := city.nearest_node(p)
	var np := city.node_pos(n.x, n.y)
	# đi sai làn
	var wrong := false
	if on_ns != on_ew:
		var center := Vector3(city.snap_x(p.x), 0, p.z) if on_ns else Vector3(p.x, 0, city.snap_z(p.z))
		var axis_ok := absf(h.z) > 0.75 if on_ns else absf(h.x) > 0.75
		if axis_ok and car.speed_kmh > 5.0:
			var lat := (p - center).dot(City.right_of(h))
			wrong = lat < -0.7
	if wrong:
		_wrong_t += delta
		if _wrong_t > 1.2:
			_violate("v_wrong_lane", 6.0)
	else:
		_wrong_t = 0.0
	# vượt đèn đỏ
	var fp := car.front_point()
	var cardinal := Vector3(signf(h.x), 0, 0) if absf(h.x) > absf(h.z) else Vector3(0, 0, signf(h.z))
	if n != _node_prev:
		_node_prev = n
		_prev_s = 1e9
	var s := (np - fp).dot(cardinal)
	var lat_n := absf((np - fp).dot(City.right_of(cardinal)))
	if _prev_s > City.STOP_D and s <= City.STOP_D and s > City.STOP_D - 3.0 and lat_n < City.RW:
		if city.light_for(n, cardinal) == "R":
			_violate("v_red_light", 4.0)
	_prev_s = s
	# rẽ không xi nhan
	var in_x := absf(p.x - np.x) < City.RW and absf(p.z - np.z) < City.RW
	if in_x and not _in_x:
		_x_yaw = atan2(h.x, h.z)
		_x_signal = time - _last_blink < 4.0
	if _in_x and in_x and (car.blinker == -1 or car.blinker == 1):
		_x_signal = true
	if _in_x and not in_x:
		var dy := absf(wrapf(atan2(h.x, h.z) - _x_yaw, -PI, PI))
		if dy > deg_to_rad(50.0) and dy < deg_to_rad(140.0) and not _x_signal:
			_violate("v_no_signal", 3.0)
	_in_x = in_x

	# quãng đường -> tiền thưởng khi lái tự do
	var moved := Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length()
	_last_pos = p
	if mission_id < 0:
		_dist_acc += moved
		if _dist_acc >= 150.0:
			_dist_acc = 0.0
			earned += 1
			Game.money += 1
	else:
		_update_mission(delta)

	_info_t -= delta
	if _info_t <= 0.0:
		_info_t = 0.25
		_update_info()


func _update_info() -> void:
	if mission_id < 0:
		hud.set_info("%s\n%s: %d   %s: %d" % [Game.t("menu_free"), Game.t("viol_count"), violations, Game.t("money"), Game.money])
		return
	var left := maxi(0, int(float(mission["time"]) - time))
	var txt := "%s %d: %s\n%s: %d:%02d   %s: %d" % [Game.t("mission_word"), mission_id + 1, Game.t("mk_" + String(mission["kind"])),
		Game.t("time_left"), left / 60, left % 60, Game.t("viol_count"), violations]
	if _target_idx < _targets.size():
		var tg: Dictionary = _targets[_target_idx]
		txt += "\n> " + Game.t(String(tg["label"]))
	hud.set_info(txt)


# ------------------------------------------------------------------ nhiệm vụ

func _random_edge() -> Array:
	while true:
		var i := _rng.randi_range(0, City.N - 1)
		var j := _rng.randi_range(0, City.N - 1)
		var d: Vector3 = City.DIRS[_rng.randi_range(0, 3)]
		var nb := Vector2i(i, j) + Vector2i(int(d.x), int(d.z))
		if not city.node_ok(nb.x, nb.y):
			continue
		if i == 0 and j == 0:
			continue
		return [Vector2i(i, j), d]
	return []


func _setup_mission() -> void:
	var kind: String = mission["kind"]
	match kind:
		"park", "parallel":
			var e := _random_edge()
			var u := _rng.randf_range(32.0, 48.0)
			var d: Vector3 = e[1]
			var c := city.park_spot(e[0], d, u)
			var hl := 3.4 if kind == "park" else 3.3
			_targets.append({"kind": "bay", "pos": c, "dir": d, "hl": hl, "hw": 1.3, "label": "tg_park"})
			_draw_bay(c, d, hl, 1.3)
			if kind == "parallel":
				for sgn: float in [-1.0, 1.0]:
					_parked_car(c + d * 6.6 * sgn, d)
			else:
				_parked_car(c + d * 7.8, d)
		"taxi":
			for k in 2:
				var e := _random_edge()
				var d: Vector3 = e[1]
				var pos := city.park_spot(e[0], d, _rng.randf_range(25.0, 55.0))
				_targets.append({"kind": "point", "pos": pos, "label": "tg_pickup" if k == 0 else "tg_dropoff"})
		"delivery":
			for k in int(mission["points"]):
				var e := _random_edge()
				var d: Vector3 = e[1]
				var pos := city.park_spot(e[0], d, _rng.randf_range(25.0, 55.0))
				_targets.append({"kind": "point", "pos": pos, "label": "tg_delivery"})
	_marker = Node3D.new()
	add_child(_marker)
	var cm := CylinderMesh.new()
	cm.top_radius = 2.4
	cm.bottom_radius = 2.4
	cm.height = 4.0
	cm.cap_top = false
	cm.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(1.0, 0.8, 0.1, 0.28)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mm
	mi.position.y = 2.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.add_child(mi)
	_set_target(0)
	hud.toast(Game.t("mdesc_" + kind), UiTheme.ACCENT, 5.0)


func _set_target(i: int) -> void:
	_target_idx = i
	_hold = 0.0
	if i >= _targets.size():
		_marker.visible = false
		hud.set_target(null)
		return
	var tg: Dictionary = _targets[i]
	var pos: Vector3 = tg["pos"]
	_marker.global_position = pos
	_marker.visible = tg["kind"] == "point"
	hud.set_target(pos, Game.t(String(tg["label"])))


func _draw_bay(c: Vector3, d: Vector3, hl: float, hw: float) -> void:
	var b := MeshBatch.new()
	MeshBatch.mat("bay_line", Color(1.0, 0.8, 0.1), 0.5, 0.6)
	var r := City.right_of(d)
	for s: float in [-1.0, 1.0]:
		b.strip("bay_line", c - d * hl + r * hw * s, c + d * hl + r * hw * s, 0.18, 0.02, 0.02)
		b.strip("bay_line", c + d * hl * s - r * hw, c + d * hl * s + r * hw, 0.18, 0.02, 0.02)
	b.commit(self, false)
	var lb := Label3D.new()
	lb.text = "P"
	lb.font_size = 160
	lb.pixel_size = 0.01
	lb.modulate = Color(1.0, 0.85, 0.2, 0.9)
	lb.position = c + Vector3(0, 0.03, 0)
	lb.rotation = Vector3(-PI * 0.5, atan2(-d.x, -d.z), 0)
	add_child(lb)


func _parked_car(pos: Vector3, d: Vector3) -> void:
	var spec: Dictionary = Game.CARS["sedan"]
	var sb := StaticBody3D.new()
	var r := CarModel.build_simple(spec, Game.COLORS[_rng.randi_range(0, 7)])
	sb.add_child(r["exterior"])
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(float(spec["wid"]), 1.2, float(spec["len"]))
	cs.shape = bs
	cs.position.y = 0.85
	sb.add_child(cs)
	add_child(sb)
	sb.global_transform = Transform3D(Basis(Vector3.UP, atan2(d.x, d.z)), pos)
	city.obstacles.append(sb)


func _update_mission(delta: float) -> void:
	if float(mission["time"]) - time <= 0.0:
		_finish(false, Game.t("m_timeout"))
		return
	if _target_idx >= _targets.size():
		return
	var tg: Dictionary = _targets[_target_idx]
	var ok := false
	if tg["kind"] == "point":
		var pos: Vector3 = tg["pos"]
		var dd := Vector2(car.global_position.x - pos.x, car.global_position.z - pos.z).length()
		ok = dd < 4.0 and car.speed_kmh < 1.5
	else:
		var c: Vector3 = tg["pos"]
		var d: Vector3 = tg["dir"]
		var rect := [Vector2(c.x, c.z), Vector2(d.x, d.z), float(tg["hl"]), float(tg["hw"])]
		ok = car.speed_kmh < 1.0
		if ok:
			for pt in car.corner_points():
				var lp: Vector2 = pt - rect[0]
				var ax: Vector2 = rect[1]
				if absf(lp.dot(ax)) > float(rect[2]) + 0.05 or absf(lp.dot(Vector2(-ax.y, ax.x))) > float(rect[3]) + 0.05:
					ok = false
					break
	if ok:
		_hold += delta
		if _hold > 1.0:
			Sfx.play("coin", -2.0)
			hud.toast(Game.t("tg_done_" + String(tg["label"])), Color(0.5, 1.0, 0.5), 3.0)
			_set_target(_target_idx + 1)
			if _target_idx >= _targets.size():
				_finish(true, "")
	else:
		_hold = 0.0


func _finish(success: bool, reason: String) -> void:
	if _done:
		return
	_done = true
	hud.set_target(null)
	var reward := 0
	var details := ""
	if success:
		var factor := clampf(1.0 - violations * 0.1, 0.3, 1.0)
		var time_bonus := clampf((float(mission["time"]) - time) / float(mission["time"]), 0.0, 1.0)
		reward = int(round(float(mission["reward"]) * factor * (0.85 + time_bonus * 0.3)))
		Game.missions_done[mission_id] = true
		Game.add_money(reward)
		details = Game.tf("m_result", [violations, reward])
		Sfx.play("win", 0.0)
	else:
		details = reason
		Sfx.play("over", 0.0)
	Game.save_game()
	mission_finished.emit(success, reward, details)
