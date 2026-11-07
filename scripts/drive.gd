extends Node3D
## Màn lái xe: dựng thế giới theo chế độ (thi, luyện bài, lái tự do, nhiệm vụ).

var car: PlayerCar
var hud: Hud
var cam_cabin: Camera3D
var cam_chase: Camera3D
var cabin_view: bool = true
var course: ExamCourse
var yard: LessonYard
var lesson_runner: LessonRunner
var city: City
var city_mode: CityMode
var race_track: RaceTrack
var race_mode: RaceMode
var env: Dictionary
var night: bool = false
var rain: bool = false
var _pause_dlg: Control
var _result_shown: bool = false
var _belt_t: float = 0.0
var _blink_peak: float = 0.0


func _ready() -> void:
	get_tree().root.get_viewport().msaa_3d = Viewport.MSAA_2X if int(Game.settings.get("graphics", 1)) >= 2 else Viewport.MSAA_DISABLED
	get_viewport().scaling_3d_scale = [0.7, 0.85, 1.0][int(Game.settings.get("graphics", 1))]
	var m := Game.mode
	if m == "free":
		night = Game.free_night
		rain = Game.free_rain
	elif m == "race":
		night = Game.race_night
		rain = Game.race_rain
	elif m == "mission":
		var md: Dictionary = Game.MISSIONS[Game.mission_id]
		night = md["night"]
		rain = md["rain"]
	env = EnvBuilder.build(self, night, rain)
	Scenery.cur_rain = rain
	if m == "race":
		Scenery.pick_race_theme(Game.race_theme if Game.force_theme == "random" else Game.force_theme)
	else:
		Scenery.pick_theme(Game.free_theme if m == "free" else Game.force_theme)

	car = PlayerCar.new()
	car.setup(Game.car_spec(), Game.COLORS[Game.car_color % Game.COLORS.size()], Game.settings.get("transmission", "auto") == "manual")
	car.set_wet(rain)

	if m == "lesson":
		yard = LessonYard.new(Game.lesson_id)
		add_child(yard)
		add_child(car)
	elif m == "exam" or m == "practice" or m == "tutorial":
		course = ExamCourse.new()
		add_child(course)
		add_child(car)
	elif m == "race":
		race_track = RaceTrack.new(Scenery.theme, night, rain, randi())
		add_child(race_track)
		add_child(car)
	else:
		city = City.new(night, Game.mission_id * 37 + 7000 if m == "mission" else -1)
		add_child(city)
		add_child(car)
		city_mode = CityMode.new()
		add_child(city_mode)

	hud = Hud.new()
	add_child(hud)
	hud.setup(car)
	hud.camera_toggle.connect(_toggle_camera)
	hud.pause_requested.connect(_pause)

	# Camera trong cabin
	cam_cabin = Camera3D.new()
	cam_cabin.position = car.eye_position()
	cam_cabin.rotation.y = PI
	cam_cabin.fov = 72.0
	cam_cabin.near = 0.05
	cam_cabin.far = 2000.0
	cam_cabin.cull_mask = 1 | CarModel.LAYER_INTERIOR
	car.add_child(cam_cabin)
	cam_chase = Camera3D.new()
	cam_chase.fov = 65.0
	cam_chase.far = 2000.0
	cam_chase.cull_mask = 1 | CarModel.LAYER_EXTERIOR
	add_child(cam_chase)
	cam_cabin.current = true

	if env.has("rain"):
		add_child(env["rain"])

	if m == "lesson":
		car.global_transform = yard.spawn_xf
		if Game.lesson_id != 1:
			car.seatbelt = true
		var lr := LessonRunner.new()
		lesson_runner = lr
		hud.root.add_child(lr)
		lr.setup(hud, car, yard)
		lr.finished.connect(_on_lesson_finished)
	elif m == "tutorial":
		car.global_transform = course.spawn_xf
		var tut := Tutorial.new()
		hud.root.add_child(tut)
		tut.setup(hud, car)
		tut.finished.connect(_on_tutorial_finished)
	elif course:
		course.finished.connect(_on_exam_finished)
		course.start(car, hud, Game.practice_lesson if m == "practice" else 0)
		if m == "exam":
			Game.exam_tries += 1
			Game.save_game()
	elif m == "race":
		_setup_race()
	else:
		city_mode.city = city
		car.global_transform = city_mode.spawn_transform()
		city_mode.setup(city, car, hud, Game.mission_id if m == "mission" else -1)
		city_mode.mission_finished.connect(_on_mission_finished)
		var g: int = Game.settings.get("graphics", 1)
		city.spawn_traffic(city.traffic_for([14, 20, 26][g]))
		if night:
			car.set_lights(true)
		if m == "free":
			hud.toast(Game.t("free_hint"), UiTheme.ACCENT, 5.0)
	_chase_snap()


func _setup_race() -> void:
	var lv: int = Game.race_level
	var styles := ["sedan", "hatch", "suv", "pickup"]
	var slots := [[-6.0, -2.3], [-6.0, 2.3], [-12.0, -2.3]]
	var base: float = [9.5, 12.0, 14.5][clampi(lv, 0, 2)]
	var bots: Array = []
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for k in slots.size():
		var bot := RaceBot.new()
		var spec: Dictionary = Game.CARS[styles[(k + rng.randi() % 3) % styles.size()]]
		var col: Color = Game.COLORS[rng.randi_range(0, Game.COLORS.size() - 1)]
		bot.setup(race_track, spec, col, slots[k][0], slots[k][1], base * rng.randf_range(0.93, 1.07), night, k < 2)
		add_child(bot)
		bots.append(bot)
	race_mode = RaceMode.new()
	add_child(race_mode)
	race_mode.setup(race_track, car, hud, bots, Game.race_laps, lv)
	race_mode.race_finished.connect(_on_race_finished)
	if night:
		car.set_lights(true)


func _on_race_finished(rank: int, time: float, reward: int) -> void:
	_end_common()
	await get_tree().create_timer(1.2).timeout
	var t := int(time)
	var body := Game.tf("race_result", [rank, t / 60, t % 60, reward])
	var title := Game.t("race_win") if rank == 1 else Game.tf("race_rank", [rank])
	UiTheme.dialog(hud, title, body, [
		[Game.t("retry"), func(): Game.start_drive("race")],
		[Game.t("to_menu"), func(): Game.goto_menu()],
	], Color(0.4, 1.0, 0.5) if rank <= 2 else Color(1.0, 0.8, 0.3))


func _chase_snap() -> void:
	var xf := car.global_transform
	cam_chase.global_position = xf.origin - xf.basis.z * 7.5 + Vector3(0, 3.0, 0)
	cam_chase.look_at(xf.origin + Vector3(0, 1.0, 0), Vector3.UP)


func _toggle_camera() -> void:
	cabin_view = not cabin_view
	cam_cabin.current = cabin_view
	cam_chase.current = not cabin_view
	if not cabin_view:
		_chase_snap()
	hud.set_cabin_view(cabin_view)
	Sfx.play("ui", -6.0)


func _process(delta: float) -> void:
	if car == null:
		return
	if not cabin_view:
		var xf := car.global_transform
		var back := xf.basis.z
		back.y = 0
		back = back.normalized()
		if car.speed_ms < -1.0:
			back = -back
		var want := xf.origin - back * 7.5 + Vector3(0, 3.0, 0)
		cam_chase.global_position = cam_chase.global_position.lerp(want, clampf(delta * 4.0, 0.0, 1.0))
		cam_chase.look_at(xf.origin + Vector3(0, 1.0, 0), Vector3.UP)
	if env.has("rain"):
		var p: CPUParticles3D = env["rain"]
		var cam := cam_cabin if cabin_view else cam_chase
		p.global_position = cam.global_position + Vector3(0, 12, 0) + car.linear_velocity * 0.4
	# Nhắc dây an toàn khi xe chạy (chế độ thi)
	if course and not car.seatbelt and car.speed_kmh > 5.0:
		_belt_t -= delta
		if _belt_t <= 0.0:
			_belt_t = 2.5
			Sfx.play("chime", -6.0)
	# Tự tắt xi nhan khi trả lái
	if car.blinker == -1 or car.blinker == 1:
		var sv := car.steer_input * (1.0 if car.blinker == -1 else -1.0)
		_blink_peak = maxf(_blink_peak, sv)
		if _blink_peak > 0.45 and sv < 0.08:
			car.blinker = 0
			_blink_peak = 0.0
	else:
		_blink_peak = 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_pause()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not _result_shown and _pause_dlg == null and is_inside_tree():
			_pause()


func _pause() -> void:
	if _result_shown or _pause_dlg != null:
		return
	get_tree().paused = true
	hud.set_controls_enabled(false)
	car.set_horn(false)
	_pause_dlg = UiTheme.dialog(hud, Game.t("paused"), "", [
		[Game.t("resume"), func():
			_pause_dlg = null
			var keep := is_instance_valid(lesson_runner) and lesson_runner.guided and not lesson_runner.compact
			get_tree().paused = false
			hud.set_controls_enabled(not keep, true)],
		[Game.t("restart"), func():
			_pause_dlg = null
			Game.start_drive(Game.mode)],
		[Game.t("go_back"), func():
			_pause_dlg = null
			Game.save_game()
			Game.goto_menu()],
		[Game.t("home"), func():
			_pause_dlg = null
			Game.save_game()
			Game.goto_menu(true)],
	])


func _end_common() -> void:
	_result_shown = true
	hud.set_controls_enabled(false)
	car.throttle = 0.0
	car.brake_input = 1.0
	car.set_horn(false)


func _on_exam_finished(passed: bool, score: int, log: Array) -> void:
	_end_common()
	var practice := Game.mode == "practice"
	if practice:
		if passed:
			Game.lessons_done[Game.practice_lesson] = true
	else:
		if passed:
			Game.exam_passes += 1
			Game.add_money(200)
		Game.exam_best = maxi(Game.exam_best, score if passed else mini(score, 79))
	Game.save_game()
	var title := Game.t("pass") if passed else Game.t("fail")
	var body := "%s: %d/100\n" % [Game.t("score"), score]
	if passed and not practice:
		body += Game.t("reward_200") + "\n"
	if log.is_empty():
		body += Game.t("no_mistakes")
	else:
		body += "\n".join(PackedStringArray(log))
	Sfx.play("win" if passed else "over", 0.0)
	await get_tree().create_timer(1.2).timeout
	var buttons := [[Game.t("retry"), func(): Game.start_drive(Game.mode)], [Game.t("to_menu"), func(): Game.goto_menu()]]
	if practice and passed and Game.practice_lesson < 11:
		buttons.insert(0, [Game.t("next_lesson"), func():
			Game.practice_lesson += 1
			Game.start_drive("practice")])
	var col := Color(0.4, 1.0, 0.5) if passed else Color(1.0, 0.4, 0.3)
	UiTheme.dialog(hud, title, body, buttons, col)
	if passed and not Game.rate_asked:
		_ask_rate()


func _on_mission_finished(success: bool, _reward: int, details: String) -> void:
	_end_common()
	await get_tree().create_timer(1.0).timeout
	var title := Game.t("m_success") if success else Game.t("m_fail")
	var buttons := [[Game.t("retry"), func(): Game.start_drive("mission")], [Game.t("to_menu"), func(): Game.goto_menu()]]
	if success and Game.mission_id < Game.MISSIONS.size() - 1:
		buttons.insert(0, [Game.t("next_mission"), func():
			Game.mission_id += 1
			Game.start_drive("mission")])
	UiTheme.dialog(hud, title, details, buttons, Color(0.4, 1.0, 0.5) if success else Color(1.0, 0.4, 0.3))


func _on_tutorial_finished(_skipped: bool) -> void:
	Game.tutorial_done = true
	Game.save_game()
	var pend := Game.pending_mode
	Game.pending_mode = ""
	if pend != "":
		Game.start_drive(pend)
		return
	_result_shown = true
	UiTheme.dialog(hud, Game.t("tut_finished"), Game.t("tut_finished_body"), [
		[Game.t("exam_full"), func(): Game.start_drive("exam")],
		[Game.t("tut_keep"), func():
			_result_shown = false],
		[Game.t("to_menu"), func(): Game.goto_menu()],
	], Color(0.45, 1.0, 0.55))


func _on_lesson_finished() -> void:
	var results: Array = lesson_runner.results.duplicate()
	var elapsed: float = lesson_runner._t
	await get_tree().process_frame
	Game.lessons_learned[Game.lesson_id] = true
	Game.save_game()
	_result_shown = true
	get_tree().set_deferred("paused", false)
	hud.set_controls_enabled(false)
	car.brake_input = 1.0
	Sfx.play("win", -2.0)
	var body := ""
	var good := 0
	for r in results:
		var rr: Array = r
		body += ("✓ " if rr[0] else "! ") + String(rr[1]) + "\n"
		if rr[0]:
			good += 1
	var t := int(elapsed)
	body += "\n" + Game.tf("ls_summary", [good, results.size(), t / 60, t % 60])
	var buttons: Array = []
	if Game.lesson_guided:
		buttons.append([Game.t("ls_self"), func():
			Game.lesson_guided = false
			Game.start_drive("lesson")])
	else:
		buttons.append([Game.t("ls_again"), func(): Game.start_drive("lesson")])
	if Game.lesson_id < 11:
		buttons.append([Game.t("next_lesson"), func():
			Game.lesson_id += 1
			Game.lesson_guided = true
			Game.start_drive("lesson")])
	buttons.append([Game.t("to_menu"), func(): Game.goto_menu()])
	UiTheme.dialog(hud, Game.t("ls_complete") + ": " + Game.t("lesson_l%d" % Game.lesson_id), body, buttons, Color(0.45, 1.0, 0.55))


func _ask_rate() -> void:
	Game.rate_asked = true
	Game.save_game()
	UiTheme.dialog(hud, Game.t("rate_title"), Game.t("rate_body"), [
		[Game.t("rate_now"), func(): Game.open_rate_page()],
		[Game.t("later"), func(): pass],
	], Color(1.0, 0.85, 0.2))
