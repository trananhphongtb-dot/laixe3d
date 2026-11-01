class_name PlayerCar
extends VehicleBody3D
## Xe người chơi: vật lý, hộp số tự động / số sàn, đèn, xi nhan, âm thanh.

signal crashed(impact: float)
signal stalled
signal engine_started
signal gear_changed
signal hint(key: String)

const RATIOS := [3.6, 2.15, 1.45, 1.05, 0.82]
const FINAL := 4.1
const IDLE := 800.0
const REDLINE := 6500.0

var spec: Dictionary
var dims: Dictionary
var manual: bool = false

# Đầu vào (HUD cập nhật mỗi khung hình)
var steer_input: float = 0.0     # +1 = trái
var throttle: float = 0.0
var brake_input: float = 0.0
var clutch: bool = false
var handbrake: bool = false

# Trạng thái
var auto_mode: String = "P"      # P R N D
var auto_gear: int = 1
var gear: int = 0                # số sàn: -1 R, 0 N, 1..5
var engine_on: bool = true
var rpm: float = IDLE
var speed_ms: float = 0.0        # có dấu: + tiến, - lùi
var speed_kmh: float = 0.0
var blinker: int = 0             # -1 trái, 1 phải, 2 khẩn cấp
var blink_phase: bool = false
var lights_on: bool = false
var seatbelt: bool = false
var horn_on: bool = false
var wet: bool = false

var wheels: Array[VehicleWheel3D] = []
var model: Dictionary
var steer_mesh: Node3D
var engine_audio: AudioStreamPlayer
var _skid: AudioStreamPlayer
var _horn: AudioStreamPlayer
var _blink_t: float = 0.0
var _spots: Array[SpotLight3D] = []
var _cranking: float = 0.0
var _last_vel: Vector3 = Vector3.ZERO
var _crash_cool: float = 0.0


func setup(car_spec: Dictionary, color: Color, is_manual: bool) -> void:
	spec = car_spec
	manual = is_manual
	dims = CarModel.dims(spec)
	mass = spec["mass"]
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, float(dims["base"]) - 0.05, 0)
	contact_monitor = true
	max_contacts_reported = 4
	can_sleep = false
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0   # lực cản tính riêng cho đúng thực tế (ma sát lăn, gió, phanh động cơ)
	angular_damp = 0.6
	collision_layer = 1
	collision_mask = 1

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	var L: float = dims["L"]
	var W: float = dims["W"]
	var H: float = dims["H"]
	var base: float = dims["base"]
	bs.size = Vector3(W * 0.96, (H - base) * 0.85, L * 0.96)
	cs.shape = bs
	cs.position = Vector3(0, base + (H - base) * 0.47, 0)
	add_child(cs)

	model = CarModel.build(spec, color, true, CarModel.LAYER_EXTERIOR)
	add_child(model["exterior"])
	add_child(model["interior"])
	steer_mesh = model["steer"]

	var wr: float = dims["wheel_r"]
	for front in [true, false]:
		for sx: float in [1.0, -1.0]:
			var w := VehicleWheel3D.new()
			w.position = Vector3(sx * float(dims["track"]), wr + 0.12, float(dims["wheel_front_z"]) if front else float(dims["wheel_rear_z"]))
			w.wheel_radius = wr
			w.wheel_rest_length = 0.16
			w.suspension_travel = 0.18
			w.suspension_stiffness = 45.0
			w.suspension_max_force = mass * 12.0
			w.damping_compression = 2.4
			w.damping_relaxation = 3.0
			w.wheel_friction_slip = 2.5
			w.wheel_roll_influence = 0.02
			w.use_as_steering = front
			w.use_as_traction = front   # dẫn động cầu trước như đa số xe con
			var vis := CarModel.make_wheel_mesh(wr, CarModel.LAYER_EXTERIOR)
			w.add_child(vis)
			add_child(w)
			wheels.append(w)

	# Đèn pha
	for sx: float in [-1.0, 1.0]:
		var s := SpotLight3D.new()
		s.position = Vector3(sx * W * 0.34, float(dims["top"]) - 0.14, L * 0.5 + 0.1)
		s.rotation.y = PI
		s.rotation.x = deg_to_rad(-6.0)
		s.spot_range = 45.0
		s.spot_angle = 32.0
		s.light_energy = 3.0
		s.light_color = Color(1.0, 0.96, 0.85)
		s.visible = false
		s.shadow_enabled = false
		add_child(s)
		_spots.append(s)

	engine_audio = preload("res://scripts/car/engine_audio.gd").new()
	add_child(engine_audio)
	_skid = Sfx.make_loop_player("skid")
	add_child(_skid)
	_horn = Sfx.make_loop_player("horn")
	add_child(_horn)

	body_entered.connect(_on_body_entered)
	if manual:
		gear = 0
	else:
		auto_mode = "P"


func _ready() -> void:
	_skid.play()


## Bàn đạp ga điện tử: nhẹ ở đầu hành trình, mạnh dần về cuối (giống xe thật)
const GAS_KMH := 100.0      # số tự động: ga 100% ≈ 100 km/h (mỗi mức ga ứng với một tốc độ)
const GAS_REV_KMH := 15.0


func gas_target_ms() -> float:
	return throttle * GAS_KMH / 3.6


static func _pedal(t: float) -> float:
	return pow(clampf(t, 0.0, 1.0), 1.1)


static func brake_decel(b: float) -> float:
	var pts := [[0.0, 0.0], [0.1, 0.5], [0.25, 1.5], [0.5, 3.0], [0.75, 5.5], [1.0, 8.5]]
	for i in range(1, pts.size()):
		if b <= pts[i][0]:
			var a: Array = pts[i - 1]
			var c: Array = pts[i]
			return lerpf(a[1], c[1], (b - a[0]) / (c[0] - a[0]))
	return 8.5


func set_wet(v: bool) -> void:
	wet = v
	for w in wheels:
		w.wheel_friction_slip = 1.8 if v else 2.5


func eye_position() -> Vector3:
	return dims["eye"]


func forward() -> Vector3:
	return global_transform.basis.z


func gear_label() -> String:
	if manual:
		if gear == -1:
			return "R"
		if gear == 0:
			return "N"
		return str(gear)
	if auto_mode == "D":
		return "D" + str(auto_gear)
	return auto_mode


## Số hiện tại theo dạng số (dùng cho bài thi thay đổi số): R=-1, N/P=0.
func current_gear_num() -> int:
	if manual:
		return gear
	match auto_mode:
		"D":
			return auto_gear
		"R":
			return -1
	return 0


func set_auto_mode(m: String) -> void:
	if manual or m == auto_mode:
		return
	# Như xe thật: rời số P phải đạp phanh; đổi D <-> R hoặc về P phải dừng hẳn
	if auto_mode == "P" and brake_input < 0.1 and not handbrake:
		hint.emit("hint_brake_to_shift")
		return
	var moving := absf(speed_ms) > 0.6
	if moving and (m == "P" or (m == "R" and speed_ms > 0.0) or (m == "D" and speed_ms < 0.0)):
		Sfx.play("grind", -6.0)
		hint.emit("hint_stop_to_shift")
		return
	auto_mode = m
	auto_gear = 1
	Sfx.play("shift", -4.0)
	gear_changed.emit()


func shift_manual(dir: int) -> void:
	if not manual:
		return
	if not clutch:
		Sfx.play("grind", -4.0)
		return
	var g := clampi(gear + dir, -1, 5)
	if g == -1 and speed_ms > 1.0:
		Sfx.play("grind", -4.0)
		return
	gear = g
	Sfx.play("shift", -4.0)
	gear_changed.emit()


func start_engine() -> void:
	if engine_on or _cranking > 0.0:
		return
	_cranking = 0.9
	Sfx.play("crank", -2.0)


func toggle_blinker(side: int) -> void:
	blinker = 0 if blinker == side else side
	_blink_t = 0.0
	blink_phase = blinker != 0
	if blinker != 0:
		Sfx.play("tick", -8.0)


func set_lights(v: bool) -> void:
	lights_on = v
	for s in _spots:
		s.visible = v
	var hm: StandardMaterial3D = model["head_mat"]
	hm.emission_energy_multiplier = 3.0 if v else 0.6


func set_horn(v: bool) -> void:
	if v == horn_on:
		return
	horn_on = v
	if v:
		_horn.volume_db = Sfx.vol_db(-4.0)
		_horn.play()
	else:
		_horn.stop()


## Vị trí (trên mặt phẳng XZ) tâm 4 bánh: [trước trái, trước phải, sau trái, sau phải].
func wheel_points() -> Array:
	var pts: Array = []
	for w in wheels:
		var p := w.global_position
		pts.append(Vector2(p.x, p.z))
	return pts


## 4 góc thân xe trên mặt phẳng XZ.
func corner_points() -> Array:
	var L: float = float(dims["L"]) * 0.5
	var W: float = float(dims["W"]) * 0.5
	var pts: Array = []
	for c: Vector3 in [Vector3(W, 0, L), Vector3(-W, 0, L), Vector3(W, 0, -L), Vector3(-W, 0, -L)]:
		var p := global_transform * c
		pts.append(Vector2(p.x, p.z))
	return pts


func front_point() -> Vector3:
	return global_transform * Vector3(0, 0, float(dims["L"]) * 0.5)


func rear_point() -> Vector3:
	return global_transform * Vector3(0, 0, -float(dims["L"]) * 0.5)


func _wheel_rpm() -> float:
	return absf(speed_ms) / (TAU * float(dims["wheel_r"])) * 60.0


func _physics_process(delta: float) -> void:
	var fwd := forward()
	speed_ms = linear_velocity.dot(fwd)
	speed_kmh = absf(speed_ms) * 3.6
	_crash_cool = maxf(0.0, _crash_cool - delta)

	# Đề máy
	if _cranking > 0.0:
		_cranking -= delta
		if _cranking <= 0.0:
			engine_on = true
			rpm = IDLE + 300.0
			engine_started.emit()

	# Lái
	# Góc lái tối đa giảm theo tốc độ để gia tốc ngang không quá ~0.6G (xe chạy nhanh không bị lật/xoay vòng)
	var wheelbase: float = float(dims["wheel_front_z"]) - float(dims["wheel_rear_z"])
	var v2 := maxf(speed_ms * speed_ms, 1.0)
	var max_steer := minf(0.6, atan(wheelbase * 6.0 / v2))
	# Đường cong: tay lái nhẹ ở giữa, mạnh dần khi đánh nhiều
	var sens: float = Game.settings.get("steer_sens", 1.0)
	var si := clampf(steer_input * sens, -1.0, 1.0)
	var curved := signf(si) * pow(absf(si), 1.5)
	var rate := lerpf(1.8, 0.7, clampf(speed_kmh / 80.0, 0.0, 1.0))
	steering = move_toward(steering, curved * max_steer, delta * rate)
	if steer_mesh:
		steer_mesh.rotation.z = -steer_input * deg_to_rad(540.0)

	var force := 0.0
	var power: float = spec["power"]
	var top_ms: float = float(spec["top"]) / 3.6
	var wrpm := _wheel_rpm()
	# Phanh chân: giữ xe đứng yên bằng phanh bánh; khi xe chạy dùng lực giảm tốc theo thang thực tế
	var brake_v := 0.0
	if brake_input > 0.02 and absf(speed_ms) < 0.5:
		brake_v = 12.0 + brake_input * 40.0

	if not engine_on:
		rpm = move_toward(rpm, 0.0, delta * 3000.0)
	elif manual:
		var g := gear
		if clutch or g == 0:
			var free_target := IDLE + throttle * 5200.0
			rpm = move_toward(rpm, free_target, delta * (6000.0 if throttle > rpm / 6000.0 else 2500.0))
		else:
			var ratio: float = RATIOS[absi(g) - 1] if g != 0 else 1.0
			if g == -1:
				ratio = 3.4
			var r_w := wrpm * ratio * FINAL
			# Bộ ly hợp trượt khi xe vừa khởi hành
			var slip_rpm := IDLE + 300.0 + throttle * 1300.0
			if r_w < slip_rpm and throttle > 0.12:
				rpm = move_toward(rpm, slip_rpm, delta * 4000.0)
			else:
				rpm = move_toward(rpm, maxf(r_w, 0.0), delta * 9000.0)
			if r_w < 480.0 and throttle < 0.12 and absf(speed_ms) < 2.0:
				_stall()
			else:
				var mult := pow(ratio / RATIOS[0], 0.75)
				force = minf(_pedal(throttle) * power * mult, _pedal(throttle) * power * 15.0 / maxf(absf(speed_ms), 3.0))
				if rpm >= REDLINE:
					force = 0.0
				if g == -1:
					force = -force
					if speed_ms < -6.0:
						force = 0.0
				# phanh động cơ
				if throttle < 0.05 and speed_kmh > 5.0:
					force -= signf(speed_ms) * power * 0.05 * mult
	else:
		match auto_mode:
			"P":
				brake_v = maxf(brake_v, 20.0)
				rpm = move_toward(rpm, IDLE + throttle * 3500.0, delta * 4000.0)
			"N":
				rpm = move_toward(rpm, IDLE + throttle * 3500.0, delta * 4000.0)
			"R":
				var r_w := wrpm * 3.4 * FINAL
				rpm = move_toward(rpm, maxf(IDLE + throttle * 1500.0, r_w), delta * 6000.0)
				force = -(throttle * power * 0.75)
				if throttle >= 0.05:
					# lùi: mức ga = tốc độ lùi mong muốn (tối đa ~15 km/h)
					var tgt_r := throttle * GAS_REV_KMH / 3.6
					var hold_r := mass * 9.8 * 0.012
					var kr := clampf((tgt_r + speed_ms) / 1.0, 0.0, 1.0)
					force = -(hold_r + (maxf(throttle, 0.2) * power * 0.75 - hold_r) * kr) if -speed_ms < tgt_r else 0.0
				if throttle < 0.05 and brake_input < 0.08 and speed_ms > -1.8:
					force = -power * 0.11
				if speed_ms < -6.0:
					force = maxf(force, 0.0)
			"D":
				var ratio: float = RATIOS[auto_gear - 1]
				var r_w := wrpm * ratio * FINAL
				var up_at := 2100.0 + throttle * 1800.0
				if r_w > up_at and auto_gear < 5:
					auto_gear += 1
				elif auto_gear > 1:
					var lower: float = wrpm * RATIOS[auto_gear - 2] * FINAL
					if lower < up_at * 0.62:
						auto_gear -= 1
				ratio = RATIOS[auto_gear - 1]
				r_w = wrpm * ratio * FINAL
				rpm = move_toward(rpm, maxf(IDLE + throttle * 900.0, r_w), delta * 6000.0)
				# Mức ga = tốc độ mong muốn (vd 30% ≈ 30 km/h): ga càng cao xe lên càng nhanh,
				# tới gần tốc độ đó thì lực kéo chỉ còn đủ bù lực cản -> xe giữ đều. Lên dốc vẫn chậm lại.
				var pd := _pedal(maxf(throttle, 0.2))
				force = minf(pd * power * pow(ratio / RATIOS[0], 0.6), pd * power * 15.0 / maxf(speed_ms, 3.0))
				if throttle >= 0.05:
					var tgt := gas_target_ms()
					var hold := mass * 9.8 * 0.012 + 0.42 * speed_ms * speed_ms
					var k := clampf((tgt - speed_ms) / 1.5, 0.0, 1.0)
					force = hold + (force - hold) * k if speed_ms < tgt else 0.0
				else:
					force = 0.0
				if throttle < 0.05 and brake_input < 0.08 and speed_ms < 1.8:
					force = power * 0.11
				if speed_ms > top_ms:
					force = 0.0

	engine_force = force
	brake = brake_v
	# Lực phanh chân theo thang thực tế (m/s²): 10% giữ xe, 25% rà ~1,5, 50% ~3, 100% ~8,5 (có ABS)
	if brake_input > 0.02 and absf(speed_ms) >= 0.5:
		var dec := brake_decel(brake_input)
		if wet:
			dec = minf(dec, 5.5)
		dec = minf(dec, absf(speed_ms) / delta * 0.9)
		apply_central_force(-fwd * signf(speed_ms) * mass * dec)
	# Lực cản khi chạy trớn: ma sát lăn + gió + phanh động cơ (số tự động, nhả ga)
	if absf(speed_ms) > 0.3:
		var resist := mass * 9.8 * 0.012 + 0.42 * speed_ms * speed_ms
		var over := not manual and auto_mode == "D" and throttle >= 0.05 and speed_ms > gas_target_ms() + 0.4
		if not manual and engine_on and (auto_mode == "D" or auto_mode == "R") and (throttle < 0.05 or over) and speed_kmh > 8.0:
			resist += mass * (0.18 + 0.06 * float(6 - auto_gear))
		apply_central_force(-fwd * signf(speed_ms) * resist)
	if handbrake:
		wheels[2].brake = 30.0
		wheels[3].brake = 30.0
	else:
		wheels[2].brake = 0.0
		wheels[3].brake = 0.0

	# Âm thanh động cơ
	engine_audio.rpm = rpm
	engine_audio.throttle = throttle if engine_on else 0.0
	engine_audio.running = engine_on

	# Rít lốp
	var min_skid := 1.0
	for w in wheels:
		if w.is_in_contact():
			min_skid = minf(min_skid, w.get_skidinfo())
	var skid_amt := clampf((0.6 - min_skid) / 0.6, 0.0, 1.0) if speed_kmh > 12.0 else 0.0
	_skid.volume_db = Sfx.vol_db(-14.0 + skid_amt * 12.0) if skid_amt > 0.02 else -80.0

	# Đèn phanh
	var tm: StandardMaterial3D = model["tail_mat"]
	tm.emission_energy_multiplier = 2.5 if brake_input > 0.05 else (1.0 if lights_on else 0.3)

	_last_vel = linear_velocity
	_anti_roll(delta)


## Chống lật: hãm tốc độ lắc ngang, kéo thân xe về thẳng; nếu vẫn lật thì tự dựng lại sau 2 giây.
var _flip_t: float = 0.0
signal flipped_reset


func _anti_roll(delta: float) -> void:
	var up := global_transform.basis.y
	var fwd := global_transform.basis.z
	# mô-men kéo xe về thẳng đứng khi nghiêng nhiều
	var tilt := up.cross(Vector3.UP)
	if up.y < 0.97:
		apply_torque(tilt * mass * 25.0)
	if up.y < 0.35:
		_flip_t += delta
		if _flip_t > 2.0:
			_flip_t = 0.0
			var yaw := atan2(fwd.x, fwd.z)
			global_transform = Transform3D(Basis(Vector3.UP, yaw), global_position + Vector3(0, 0.8, 0))
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			flipped_reset.emit()
	else:
		_flip_t = 0.0


func _process(delta: float) -> void:
	# Xi nhan
	var bl: StandardMaterial3D = model["blink_l"]
	var br: StandardMaterial3D = model["blink_r"]
	if blinker != 0:
		_blink_t += delta
		if _blink_t >= 0.38:
			_blink_t = 0.0
			blink_phase = not blink_phase
			Sfx.play("tick" if blink_phase else "tock", -8.0)
	else:
		blink_phase = false
	var on_l := blink_phase and (blinker == -1 or blinker == 2)
	var on_r := blink_phase and (blinker == 1 or blinker == 2)
	bl.emission_energy_multiplier = 3.0 if on_l else 0.0
	br.emission_energy_multiplier = 3.0 if on_r else 0.0


func _stall() -> void:
	if not engine_on:
		return
	engine_on = false
	Sfx.play("stall", -2.0)
	stalled.emit()


func _on_body_entered(_body: Node) -> void:
	var impact := (_last_vel - linear_velocity).length()
	impact = maxf(impact, _last_vel.length() * 0.5)
	if impact > 2.5 and _crash_cool <= 0.0:
		_crash_cool = 1.0
		Sfx.play("crash", clampf(-12.0 + impact, -12.0, 2.0))
		crashed.emit(impact)
