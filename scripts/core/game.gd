extends Node
## Trạng thái chung của game: cài đặt, lưu tiến trình, ngôn ngữ, danh sách xe, nhiệm vụ.

const SAVE_PATH := "user://save.cfg"
const PACKAGE := "com.trananhphong.laixe3d"
const I18N := preload("res://scripts/core/i18n.gd")

signal language_changed
signal money_changed

var lang: String = "vi"
var settings: Dictionary = {
	"control": "wheel",        # wheel / tilt / buttons
	"tilt_invert": false,
	"steer_sens": 1.0,
	"transmission": "auto",    # auto / manual
	"graphics": 1,             # 0 thấp, 1 trung bình, 2 cao
	"engine_vol": 0.8,
	"sfx_vol": 0.9,
	"mirrors": true,
}
var money: int = 0
var cars_owned: Array = ["training", "sedan"]
var car_id: String = "training"
var car_color: int = 0
var exam_best: int = 0
var exam_passes: int = 0
var exam_tries: int = 0
var lessons_done: Dictionary = {}
var missions_done: Dictionary = {}
var rate_asked: bool = false
var tutorial_done: bool = false
var pending_mode: String = ""

# Tham số cho lượt chơi sắp vào
var mode: String = "exam"          # exam / practice / free / mission
var practice_lesson: int = 1
var free_night: bool = false
var free_rain: bool = false
var mission_id: int = 0

const CARS := {
	"training": {"vi": "Xe tập lái", "en": "Driving school car", "price": 0, "mass": 1150.0, "power": 3800.0, "top": 150.0,
		"len": 4.3, "wid": 1.75, "hei": 1.45, "style": "sedan", "sign": true},
	"sedan": {"vi": "Sedan", "en": "Sedan", "price": 0, "mass": 1250.0, "power": 4300.0, "top": 175.0,
		"len": 4.5, "wid": 1.78, "hei": 1.45, "style": "sedan", "sign": false},
	"hatch": {"vi": "Hatchback", "en": "Hatchback", "price": 1500, "mass": 1050.0, "power": 3700.0, "top": 165.0,
		"len": 3.9, "wid": 1.7, "hei": 1.5, "style": "hatch", "sign": false},
	"suv": {"vi": "SUV 7 chỗ", "en": "7-seat SUV", "price": 3000, "mass": 1700.0, "power": 5600.0, "top": 180.0,
		"len": 4.7, "wid": 1.86, "hei": 1.78, "style": "suv", "sign": false},
	"pickup": {"vi": "Bán tải", "en": "Pickup", "price": 4500, "mass": 1850.0, "power": 6000.0, "top": 175.0,
		"len": 5.2, "wid": 1.86, "hei": 1.8, "style": "pickup", "sign": false},
	"sport": {"vi": "Xe thể thao", "en": "Sports car", "price": 8000, "mass": 1350.0, "power": 8200.0, "top": 240.0,
		"len": 4.5, "wid": 1.88, "hei": 1.25, "style": "sport", "sign": false},
}
const CAR_ORDER := ["training", "sedan", "hatch", "suv", "pickup", "sport"]

const COLORS := [
	Color(0.93, 0.93, 0.93), Color(0.75, 0.08, 0.08), Color(0.1, 0.28, 0.7), Color(0.08, 0.08, 0.09),
	Color(0.62, 0.64, 0.67), Color(0.95, 0.75, 0.1), Color(0.1, 0.5, 0.25), Color(0.95, 0.42, 0.08),
]

# Nhiệm vụ: kind park / taxi / delivery / parallel
const MISSIONS := [
	{"kind": "park", "time": 90, "reward": 150, "night": false, "rain": false, "points": 1},
	{"kind": "taxi", "time": 120, "reward": 200, "night": false, "rain": false, "points": 2},
	{"kind": "delivery", "time": 180, "reward": 300, "night": false, "rain": false, "points": 3},
	{"kind": "park", "time": 70, "reward": 250, "night": false, "rain": true, "points": 1},
	{"kind": "taxi", "time": 100, "reward": 300, "night": true, "rain": false, "points": 2},
	{"kind": "delivery", "time": 200, "reward": 400, "night": false, "rain": false, "points": 4},
	{"kind": "parallel", "time": 90, "reward": 400, "night": false, "rain": false, "points": 1},
	{"kind": "taxi", "time": 110, "reward": 450, "night": true, "rain": true, "points": 2},
	{"kind": "delivery", "time": 240, "reward": 600, "night": false, "rain": true, "points": 5},
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()
	apply_audio()


func t(key: String) -> String:
	var table: Dictionary = I18N.STR.get(lang, I18N.STR["vi"])
	if table.has(key):
		return table[key]
	var vi: Dictionary = I18N.STR["vi"]
	return vi.get(key, key)


func tf(key: String, args: Array) -> String:
	return t(key) % args


func set_language(l: String) -> void:
	lang = l
	save_game()
	language_changed.emit()


func car_spec(id: String = "") -> Dictionary:
	if id == "":
		id = car_id
	return CARS.get(id, CARS["training"])


func car_name(id: String) -> String:
	var c: Dictionary = CARS[id]
	return c[lang] if c.has(lang) else c["vi"]


func add_money(v: int) -> void:
	money = max(0, money + v)
	save_game()
	money_changed.emit()


func set_setting(key: String, value) -> void:
	settings[key] = value
	save_game()
	if key == "engine_vol" or key == "sfx_vol":
		apply_audio()


func apply_audio() -> void:
	var sfx_bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(sfx_bus, 0.0)


func save_game() -> void:
	var c := ConfigFile.new()
	c.set_value("main", "lang", lang)
	c.set_value("main", "settings", settings)
	c.set_value("main", "money", money)
	c.set_value("main", "cars_owned", cars_owned)
	c.set_value("main", "car_id", car_id)
	c.set_value("main", "car_color", car_color)
	c.set_value("main", "exam_best", exam_best)
	c.set_value("main", "exam_passes", exam_passes)
	c.set_value("main", "exam_tries", exam_tries)
	c.set_value("main", "lessons_done", lessons_done)
	c.set_value("main", "missions_done", missions_done)
	c.set_value("main", "rate_asked", rate_asked)
	c.set_value("main", "tutorial_done", tutorial_done)
	c.save(SAVE_PATH)


func load_game() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) != OK:
		var loc := OS.get_locale_language()
		lang = "vi" if loc == "vi" or loc == "" else "en"
		return
	lang = c.get_value("main", "lang", "vi")
	var s: Dictionary = c.get_value("main", "settings", {})
	for k in s.keys():
		settings[k] = s[k]
	money = c.get_value("main", "money", 0)
	cars_owned = c.get_value("main", "cars_owned", ["training", "sedan"])
	car_id = c.get_value("main", "car_id", "training")
	if not CARS.has(car_id):
		car_id = "training"
	car_color = c.get_value("main", "car_color", 0)
	exam_best = c.get_value("main", "exam_best", 0)
	exam_passes = c.get_value("main", "exam_passes", 0)
	exam_tries = c.get_value("main", "exam_tries", 0)
	lessons_done = c.get_value("main", "lessons_done", {})
	missions_done = c.get_value("main", "missions_done", {})
	rate_asked = c.get_value("main", "rate_asked", false)
	tutorial_done = c.get_value("main", "tutorial_done", false)


func mission_unlocked(i: int) -> bool:
	return i == 0 or missions_done.has(i - 1)


func open_rate_page() -> void:
	rate_asked = true
	save_game()
	if OS.get_name() == "Android":
		if OS.shell_open("market://details?id=" + PACKAGE) == OK:
			return
	OS.shell_open("https://play.google.com/store/apps/details?id=" + PACKAGE)


func goto_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func start_drive(m: String) -> void:
	# Lần đầu chơi: vào phần hướng dẫn có lái thử trước
	if m != "tutorial" and not tutorial_done:
		pending_mode = m
		m = "tutorial"
	mode = m
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/drive.tscn")
