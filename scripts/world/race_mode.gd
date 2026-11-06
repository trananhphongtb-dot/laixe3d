class_name RaceMode
extends Node
## Luật cuộc đua luyện tập: đếm ngược, đi theo mũi tên, tính vòng/hạng, phạt ra khỏi đường, về đích.

signal race_finished(rank: int, time: float, reward: int)

const REWARD := [150, 100, 60, 40]

var track: RaceTrack
var car: PlayerCar
var hud: Hud
var bots: Array = []
var laps: int = 2
var level: int = 1
var state: int = 0              # 0 đếm ngược · 1 đang đua · 2 xong
var time: float = 0.0
var p_idx: int = 0
var p_s: float = 0.0
var _cd: float = 3.2
var _cd_shown: int = 4
var _off_t: float = 0.0
var _flip_t: float = 0.0
var _wrong_cool: float = 0.0
var _off_toast: float = 0.0
var _info_t: float = 0.0
var _grid_xf: Transform3D


func setup(p_track: RaceTrack, p_car: PlayerCar, p_hud: Hud, p_bots: Array, p_laps: int, p_level: int) -> void:
	track = p_track
	car = p_car
	hud = p_hud
	bots = p_bots
	laps = p_laps
	level = p_level
	process_physics_priority = 100
	# chỗ xuất phát: hàng sau, bên phải
	p_s = -12.0
	_grid_xf = track.transform_at(p_s, 2.3, 0.2)
	car.global_transform = _grid_xf
	p_idx = track.nearest_index(car.global_position, 0, 40, 40)
	car.seatbelt = true
	car.auto_mode = "D"
	car.auto_gear = 1
	car.handbrake = true
	hud.set_controls_enabled(false)
	hud.target_hide_dist = true
	hud.set_target(track.point_at(p_s + 40.0), "")
	for b: RaceBot in bots:
		b.others = bots + [car]
		b.band = [0.6, 1.0, 1.3][clampi(level, 0, 2)]
	if car.manual:
		hud.toast(Game.t("race_manual"), UiTheme.ACCENT, 4.0)


func rank() -> int:
	var r := 1
	for b: RaceBot in bots:
		if b.s > p_s:
			r += 1
	return r


func _physics_process(delta: float) -> void:
	if car == null or state == 2:
		return
	if state == 0:
		car.linear_velocity = Vector3.ZERO
		car.angular_velocity = Vector3.ZERO
		_cd -= delta
		var n := ceili(_cd)
		if n != _cd_shown and n >= 1 and n <= 3:
			_cd_shown = n
			hud.toast(str(n), Color(1.0, 0.85, 0.3), 0.9)
			Sfx.play("tick", -4.0)
		if _cd <= 0.0:
			state = 1
			car.handbrake = false
			hud.set_controls_enabled(true)
			for b: RaceBot in bots:
				b.active = true
			hud.toast(Game.t("rw_go"), Color(0.5, 1.0, 0.5), 1.5)
			hud.toast(Game.t("race_hint"), UiTheme.ACCENT, 5.0)
			Sfx.play("ding", -4.0)
		return
	time += delta
	# tiến độ người chơi
	var ni := track.nearest_index(car.global_position, p_idx)
	var di := ni - p_idx
	if di > track.n / 2:
		di -= track.n
	elif di < -track.n / 2:
		di += track.n
	p_s += di * track.step
	p_idx = ni
	for b: RaceBot in bots:
		b.ref_s = p_s
	hud.set_target(track.point_at(p_s + 45.0), "")
	# ra khỏi đường: chậm dần + nhắc
	var lat := track.lateral(car.global_position, p_idx)
	var off := absf(lat) - RaceTrack.HW - 1.8
	if off > 0.0:
		car.linear_velocity *= maxf(0.0, 1.0 - 0.5 * delta)
		_off_toast -= delta
		if _off_toast <= 0.0:
			_off_toast = 3.0
			hud.toast(Game.t("race_off"), Color(1.0, 0.6, 0.3), 1.6)
	if off > 35.0:
		_off_t += delta
	else:
		_off_t = 0.0
	if car.global_transform.basis.y.y < 0.25 and car.speed_kmh < 3.0:
		_flip_t += delta
	else:
		_flip_t = 0.0
	if _off_t > 3.0 or _flip_t > 3.0:
		_respawn()
	# đi ngược chiều
	_wrong_cool -= delta
	var fw := car.forward()
	fw.y = 0
	if car.speed_kmh > 6.0 and fw.normalized().dot(track.tang[p_idx]) < -0.3 and _wrong_cool <= 0.0:
		_wrong_cool = 3.0
		hud.toast(Game.t("race_wrong"), Color(1.0, 0.4, 0.3), 1.8)
	_info_t -= delta
	if _info_t <= 0.0:
		_info_t = 0.25
		_update_info()
	if p_s >= laps * track.total:
		_finish()


func _respawn() -> void:
	_off_t = 0.0
	_flip_t = 0.0
	car.global_transform = track.transform_at(p_s, 0.0, 0.3)
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	hud.reset_steering()
	hud.toast(Game.t("race_back"), UiTheme.ACCENT, 1.8)


func _update_info() -> void:
	var lap := clampi(int(maxf(p_s, 0.0) / track.total) + 1, 1, laps)
	var t := int(time)
	hud.set_info(Game.tf("race_info", [lap, laps, rank(), bots.size() + 1, t / 60, t % 60]))


func _finish() -> void:
	state = 2
	var r := rank()
	var base: int = REWARD[clampi(r - 1, 0, REWARD.size() - 1)]
	var reward := int(round(base * (0.8 + 0.2 * level) * (1.0 + 0.25 * (laps - 1))))
	Game.add_money(reward)
	Game.save_game()
	hud.set_target(null)
	for b: RaceBot in bots:
		b.cruise *= 0.7
	Sfx.play("win" if r == 1 else "ding", 0.0)
	race_finished.emit(r, time, reward)
