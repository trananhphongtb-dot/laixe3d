class_name TouchThrottle
extends TouchCtl
## Thanh kéo dùng cho GA và PHANH.
## - Kéo tới vị trí rồi dừng tay (giữ yên ~0,25 s) rồi thả: mức CỐ ĐỊNH ở đó, không trôi.
## - Vuốt nhanh rồi thả (nhấp): mức tụt về 0 trong khoảng 0,5 s.
## - Muốn giảm/nhả: đặt tay kéo xuống, kéo hẳn xuống đáy là 0.

const DWELL := 0.25          # giây đứng yên để coi là "dừng tay"
const TAP_DECAY := 0.5       # giây để mức nhấp về 0

var value: float = 0.0       # mức hiện tại 0..1
var locked: bool = false     # true = mức đang cố định sau khi thả tay
var fill_color := Color(0.2, 0.85, 0.4)
var hot_color := Color(1.0, 0.45, 0.15)
var top_label := ""          # chữ nhỏ ở đỉnh (vd "mạnh")
var bottom_label := ""       # chữ nhỏ ở đáy (vd "rà")
var speed_scale: float = 0.0 # > 0: hiện tốc độ tương ứng (km/h) thay cho %
var _last_y: float = 0.0
var _still_t: float = 0.0
var _decay_from: float = 0.0
var _decay_t: float = -1.0


func touch_down(id: int, pos: Vector2) -> void:
	super.touch_down(id, pos)
	_last_y = pos.y
	_still_t = 0.0
	_decay_t = -1.0
	locked = false


func touch_move(_id: int, pos: Vector2) -> void:
	var dy := pos.y - _last_y
	_last_y = pos.y
	if absf(dy) > 1.5:
		_still_t = 0.0
	var track := maxf(size.y - 70.0, 40.0)
	value = clampf(value - dy / track, 0.0, 1.0)
	if value < 0.02:
		value = 0.0
	queue_redraw()


func touch_up(id: int) -> void:
	super.touch_up(id)
	if value <= 0.0:
		locked = false
	elif _still_t >= DWELL:
		locked = true            # dừng tay rồi mới thả -> cố định
	else:
		locked = false           # vuốt nhanh -> nhấp, trôi về 0
		_decay_from = value
		_decay_t = 0.0
	queue_redraw()


func set_value(v: float) -> void:
	value = clampf(v, 0.0, 1.0)
	locked = value > 0.0
	_decay_t = -1.0
	queue_redraw()


func _process(delta: float) -> void:
	if held:
		_still_t += delta
		if _still_t >= DWELL and _still_t - delta < DWELL:
			queue_redraw()
	elif _decay_t >= 0.0:
		_decay_t += delta
		var k := clampf(_decay_t / TAP_DECAY, 0.0, 1.0)
		# nhả nhanh lúc đầu, chậm dần cuối (giống nhấc chân)
		value = _decay_from * pow(1.0 - k, 2.0)
		if k >= 1.0:
			value = 0.0
			_decay_t = -1.0
		queue_redraw()


func _draw() -> void:
	if _bold == null:
		_bold = Icons.bold_font(0.7)
	var r := Rect2(Vector2(10, 4), Vector2(size.x - 20, size.y - 8))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.55)
	sb.set_corner_radius_all(int(r.size.x * 0.5))
	sb.border_color = Color(1, 1, 1, 0.35 if held else 0.2)
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	var top := r.position.y + 34.0
	var bottom := r.end.y - 52.0
	for k in 11:
		var y := lerpf(bottom, top, k / 10.0)
		var wdt := 12.0 if k % 5 == 0 else 6.0
		draw_line(Vector2(r.position.x + 8, y), Vector2(r.position.x + 8 + wdt, y), Color(1, 1, 1, 0.4), 2.0)
	var level_y := lerpf(bottom, top, value)
	if value > 0.0:
		var fill := StyleBoxFlat.new()
		var g := fill_color.lerp(hot_color, clampf((value - 0.5) * 2.0, 0.0, 1.0))
		fill.bg_color = Color(g.r, g.g, g.b, 0.6)
		fill.set_corner_radius_all(int(r.size.x * 0.5) - 6)
		fill.anti_aliasing = true
		draw_style_box(fill, Rect2(Vector2(r.position.x + 6, level_y), Vector2(r.size.x - 12, r.end.y - 6 - level_y)))
	# tay nắm: viền vàng khi đang cố định
	var hb := StyleBoxFlat.new()
	hb.bg_color = Color(0.95, 0.96, 0.98, 0.95) if held else Color(0.85, 0.87, 0.9, 0.9)
	hb.set_corner_radius_all(14)
	hb.shadow_color = Color(0, 0, 0, 0.35)
	hb.shadow_size = 5
	var fixing := locked or (held and _still_t >= DWELL and value > 0.0)
	if fixing:
		hb.border_color = Color(1.0, 0.8, 0.15)
		hb.set_border_width_all(4)
	hb.anti_aliasing = true
	var hr := Rect2(Vector2(r.position.x - 5, level_y - 16), Vector2(r.size.x + 10, 32))
	draw_style_box(hb, hr)
	for k in 3:
		var yy := level_y - 6 + k * 6
		draw_line(Vector2(hr.position.x + 18, yy), Vector2(hr.end.x - 18, yy), Color(0, 0, 0, 0.25), 2.0)
	var pct := "%d%%" % int(round(value * 100.0))
	if speed_scale > 0.0:
		pct = "%d km/h" % int(round(value * speed_scale))
	var fs := 22 if speed_scale <= 0.0 else 19
	var tw := _bold.get_string_size(pct, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ty := level_y - 24 if level_y - 24 > top - 6 else level_y + 42
	draw_string(_bold, Vector2(size.x * 0.5 - tw * 0.5, ty), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.85, 0.3) if fixing else Color.WHITE)
	var f := get_theme_default_font()
	var lw := _bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(_bold, Vector2(size.x * 0.5 - lw * 0.5, r.end.y - 9), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.9))
	if top_label != "":
		var w1 := f.get_string_size(top_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(f, Vector2(size.x * 0.5 - w1 * 0.5, r.position.y + 22), top_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.65))
	if bottom_label != "":
		var by := lerpf(bottom, top, 0.22)
		draw_string(f, Vector2(r.end.x - 34, by + 5), bottom_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.55))
	if value == 0.0 and not held and top_label == "":
		Icons.draw(self, "up", Vector2(size.x * 0.5, top + 14), 24, Color(1, 1, 1, 0.5))
