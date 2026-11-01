class_name Icons
extends RefCounted
## Biểu tượng vẽ bằng nét vector (không cần file ảnh, sắc nét mọi độ phân giải).


static func bold_font(weight: float = 0.9) -> Font:
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = weight
	return fv


static func draw(ci: CanvasItem, name: String, c: Vector2, s: float, col: Color, w: float = 0.0) -> void:
	if w <= 0.0:
		w = maxf(2.0, s * 0.09)
	var h := s * 0.5
	match name:
		"arrow_l":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-h, 0), c + Vector2(-h * 0.05, -h * 0.75), c + Vector2(-h * 0.05, -h * 0.3),
				c + Vector2(h * 0.8, -h * 0.3), c + Vector2(h * 0.8, h * 0.3), c + Vector2(-h * 0.05, h * 0.3), c + Vector2(-h * 0.05, h * 0.75)]), col)
		"arrow_r":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(h, 0), c + Vector2(h * 0.05, -h * 0.75), c + Vector2(h * 0.05, -h * 0.3),
				c + Vector2(-h * 0.8, -h * 0.3), c + Vector2(-h * 0.8, h * 0.3), c + Vector2(h * 0.05, h * 0.3), c + Vector2(h * 0.05, h * 0.75)]), col)
		"hazard":
			_tri(ci, c + Vector2(0, h * 0.08), h * 1.0, col, w)
			_tri(ci, c + Vector2(0, h * 0.12), h * 0.45, col, w * 0.8)
		"up":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h * 0.65), c + Vector2(h * 0.7, h * 0.45), c + Vector2(-h * 0.7, h * 0.45)]), col)
		"down":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, h * 0.65), c + Vector2(h * 0.7, -h * 0.45), c + Vector2(-h * 0.7, -h * 0.45)]), col)
		"pause":
			ci.draw_rect(Rect2(c + Vector2(-h * 0.5, -h * 0.6), Vector2(h * 0.32, h * 1.2)), col)
			ci.draw_rect(Rect2(c + Vector2(h * 0.18, -h * 0.6), Vector2(h * 0.32, h * 1.2)), col)
		"horn":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-h * 0.8, -h * 0.25), c + Vector2(-h * 0.35, -h * 0.25), c + Vector2(h * 0.2, -h * 0.7),
				c + Vector2(h * 0.2, h * 0.7), c + Vector2(-h * 0.35, h * 0.25), c + Vector2(-h * 0.8, h * 0.25)]), col)
			ci.draw_arc(c + Vector2(h * 0.2, 0), h * 0.45, -0.7, 0.7, 10, col, w * 0.7, true)
			ci.draw_arc(c + Vector2(h * 0.2, 0), h * 0.75, -0.6, 0.6, 10, col, w * 0.7, true)
		"belt":
			ci.draw_circle(c + Vector2(0, -h * 0.62), h * 0.24, col)
			ci.draw_arc(c + Vector2(0, h * 0.55), h * 0.6, PI, TAU, 14, col, w, true)
			ci.draw_line(c + Vector2(-h * 0.55, -h * 0.2), c + Vector2(h * 0.45, h * 0.75), col, w * 1.2, true)
		"light":
			ci.draw_arc(c + Vector2(-h * 0.15, 0), h * 0.5, PI * 0.5, PI * 1.5, 12, col, w, true)
			ci.draw_line(c + Vector2(-h * 0.15, -h * 0.5), c + Vector2(-h * 0.15, h * 0.5), col, w, true)
			for k in 3:
				var y := -h * 0.4 + k * h * 0.4
				ci.draw_line(c + Vector2(h * 0.15, y), c + Vector2(h * 0.8, y + h * 0.12), col, w * 0.8, true)
		"handbrake":
			ci.draw_arc(c, h * 0.8, 0, TAU, 24, col, w, true)
			var f := bold_font()
			var fs := int(s * 0.62)
			var tw := f.get_string_size("P", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			ci.draw_string(f, c + Vector2(-tw * 0.5, fs * 0.36), "P", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			ci.draw_arc(c, h * 1.05, -0.6, 0.6, 8, col, w * 0.7, true)
			ci.draw_arc(c, h * 1.05, PI - 0.6, PI + 0.6, 8, col, w * 0.7, true)
		"cam":
			ci.draw_rect(Rect2(c + Vector2(-h * 0.8, -h * 0.45), Vector2(h * 1.6, h * 1.05)), col, false, w)
			ci.draw_rect(Rect2(c + Vector2(-h * 0.3, -h * 0.7), Vector2(h * 0.6, h * 0.25)), col)
			ci.draw_arc(c + Vector2(0, h * 0.08), h * 0.3, 0, TAU, 16, col, w * 0.8, true)
		"key":
			ci.draw_arc(c + Vector2(-h * 0.4, 0), h * 0.35, 0, TAU, 16, col, w, true)
			ci.draw_line(c + Vector2(-h * 0.05, 0), c + Vector2(h * 0.85, 0), col, w, true)
			ci.draw_line(c + Vector2(h * 0.5, 0), c + Vector2(h * 0.5, h * 0.3), col, w, true)
			ci.draw_line(c + Vector2(h * 0.75, 0), c + Vector2(h * 0.75, h * 0.3), col, w, true)
		"flag":
			ci.draw_line(c + Vector2(-h * 0.6, h * 0.8), c + Vector2(-h * 0.6, -h * 0.8), col, w, true)
			for i in 3:
				for j in 2:
					if (i + j) % 2 == 0:
						ci.draw_rect(Rect2(c + Vector2(-h * 0.55 + i * h * 0.45, -h * 0.75 + j * h * 0.45), Vector2(h * 0.45, h * 0.45)), col)
			ci.draw_rect(Rect2(c + Vector2(-h * 0.55, -h * 0.75), Vector2(h * 1.35, h * 0.9)), col, false, w * 0.6)
		"road":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-h * 0.25, -h * 0.85), c + Vector2(h * 0.25, -h * 0.85), c + Vector2(h * 0.85, h * 0.85), c + Vector2(-h * 0.85, h * 0.85)]), col)
			var bg := Color(0, 0, 0, 0.55)
			for k in 3:
				var y0 := -h * 0.7 + k * h * 0.55
				ci.draw_line(c + Vector2(0, y0), c + Vector2(0, y0 + h * 0.3), bg, w * (0.6 + k * 0.25))
		"target":
			ci.draw_arc(c, h * 0.85, 0, TAU, 24, col, w, true)
			ci.draw_arc(c, h * 0.5, 0, TAU, 20, col, w, true)
			ci.draw_circle(c, h * 0.17, col)
		"car":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-h * 0.9, h * 0.3), c + Vector2(-h * 0.9, -h * 0.05), c + Vector2(-h * 0.55, -h * 0.15),
				c + Vector2(-h * 0.3, -h * 0.55), c + Vector2(h * 0.35, -h * 0.55), c + Vector2(h * 0.6, -h * 0.15), c + Vector2(h * 0.9, -h * 0.05), c + Vector2(h * 0.9, h * 0.3)]), col)
			ci.draw_circle(c + Vector2(-h * 0.5, h * 0.32), h * 0.22, col)
			ci.draw_circle(c + Vector2(h * 0.5, h * 0.32), h * 0.22, col)
			ci.draw_circle(c + Vector2(-h * 0.5, h * 0.32), h * 0.09, Color(0, 0, 0, 0.6))
			ci.draw_circle(c + Vector2(h * 0.5, h * 0.32), h * 0.09, Color(0, 0, 0, 0.6))
		"gear":
			ci.draw_arc(c, h * 0.55, 0, TAU, 24, col, w * 1.6, true)
			for k in 8:
				var a := k * TAU / 8.0
				var dv := Vector2(cos(a), sin(a))
				ci.draw_line(c + dv * h * 0.6, c + dv * h * 0.9, col, w * 1.8)
			ci.draw_circle(c, h * 0.2, col)
		"book":
			ci.draw_rect(Rect2(c + Vector2(-h * 0.8, -h * 0.6), Vector2(h * 0.75, h * 1.2)), col, false, w)
			ci.draw_rect(Rect2(c + Vector2(h * 0.05, -h * 0.6), Vector2(h * 0.75, h * 1.2)), col, false, w)
			for k in 3:
				var y := -h * 0.3 + k * h * 0.3
				ci.draw_line(c + Vector2(-h * 0.6, y), c + Vector2(-h * 0.25, y), col, w * 0.6)
				ci.draw_line(c + Vector2(h * 0.25, y), c + Vector2(h * 0.6, y), col, w * 0.6)
		"globe":
			ci.draw_arc(c, h * 0.85, 0, TAU, 28, col, w, true)
			ci.draw_line(c + Vector2(-h * 0.85, 0), c + Vector2(h * 0.85, 0), col, w * 0.7)
			ci.draw_line(c + Vector2(0, -h * 0.85), c + Vector2(0, h * 0.85), col, w * 0.7)
			var pts := PackedVector2Array()
			for k in 17:
				var a := -PI * 0.5 + PI * k / 16.0
				pts.append(c + Vector2(cos(a) * h * 0.4, sin(a) * h * 0.85))
			ci.draw_polyline(pts, col, w * 0.7, true)
			var pts2 := PackedVector2Array()
			for p in pts:
				pts2.append(Vector2(2.0 * c.x - p.x, p.y))
			ci.draw_polyline(pts2, col, w * 0.7, true)
		"star":
			var sp := PackedVector2Array()
			for k in 10:
				var a := -PI * 0.5 + k * PI / 5.0
				var r := h * (0.9 if k % 2 == 0 else 0.4)
				sp.append(c + Vector2(cos(a), sin(a)) * r)
			ci.draw_colored_polygon(sp, col)
		"coin":
			ci.draw_circle(c, h * 0.85, col)
			ci.draw_arc(c, h * 0.6, 0, TAU, 20, Color(0, 0, 0, 0.25), w * 0.7, true)
		"back":
			ci.draw_polyline(PackedVector2Array([c + Vector2(h * 0.3, -h * 0.6), c + Vector2(-h * 0.3, 0), c + Vector2(h * 0.3, h * 0.6)]), col, w * 1.3, true)
		"trophy":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-h * 0.55, -h * 0.75), c + Vector2(h * 0.55, -h * 0.75), c + Vector2(h * 0.4, -h * 0.1),
				c + Vector2(h * 0.12, h * 0.15), c + Vector2(-h * 0.12, h * 0.15), c + Vector2(-h * 0.4, -h * 0.1)]), col)
			ci.draw_rect(Rect2(c + Vector2(-h * 0.08, h * 0.1), Vector2(h * 0.16, h * 0.4)), col)
			ci.draw_rect(Rect2(c + Vector2(-h * 0.4, h * 0.5), Vector2(h * 0.8, h * 0.22)), col)
		"play":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-h * 0.45, -h * 0.65), c + Vector2(h * 0.7, 0), c + Vector2(-h * 0.45, h * 0.65)]), col)
		"lock":
			ci.draw_rect(Rect2(c + Vector2(-h * 0.55, -h * 0.05), Vector2(h * 1.1, h * 0.8)), col)
			ci.draw_arc(c + Vector2(0, -h * 0.1), h * 0.38, PI, TAU, 12, col, w, true)
		"steer":
			ci.draw_arc(c, h * 0.8, 0, TAU, 28, col, w * 1.2, true)
			ci.draw_circle(c, h * 0.2, col)
			for ang: float in [PI, 0.0, PI * 0.5]:
				ci.draw_line(c, c + Vector2(cos(ang), sin(ang)) * h * 0.75, col, w, true)
		"check":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-h * 0.6, 0), c + Vector2(-h * 0.15, h * 0.45), c + Vector2(h * 0.65, -h * 0.5)]), col, w * 1.3, true)


static func _tri(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	var p := PackedVector2Array([c + Vector2(0, -r * 0.8), c + Vector2(r * 0.85, r * 0.65), c + Vector2(-r * 0.85, r * 0.65), c + Vector2(0, -r * 0.8)])
	ci.draw_polyline(p, col, w, true)
