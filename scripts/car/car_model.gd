class_name CarModel
extends RefCounted
## Dựng hình xe chi tiết bằng code. Hệ trục xe: +Z phía trước, +X bên trái, Y lên; y=0 là mặt đường.
## Các chi tiết cùng vật liệu được gộp thành 1 mesh để máy yếu vẽ nhanh.

const LAYER_EXTERIOR := 2
const LAYER_INTERIOR := 4

static var _shadow_tex: GradientTexture2D


static func dims(spec: Dictionary) -> Dictionary:
	var L: float = spec["len"]
	var W: float = spec["wid"]
	var H: float = spec["hei"]
	var style: String = spec["style"]
	var base := 0.3
	var body_h := 0.58
	var cz := -L * 0.06
	var cl := L * 0.48
	match style:
		"hatch":
			cz = -L * 0.1
			cl = L * 0.56
		"suv":
			base = 0.42
			body_h = 0.62
			cz = -L * 0.1
			cl = L * 0.62
		"pickup":
			base = 0.45
			body_h = 0.62
			cz = L * 0.04
			cl = L * 0.33
		"sport":
			base = 0.2
			body_h = 0.5
			cz = -L * 0.08
			cl = L * 0.42
	var top := base + body_h
	var zf := cz + cl * 0.5
	var ch := H - top
	var fi := ch * 0.95
	var ri := ch * 0.7
	match style:
		"hatch":
			ri = ch * 0.3
		"suv", "pickup":
			fi = ch * 0.8
			ri = ch * 0.15
		"sport":
			fi = ch * 1.4
			ri = ch * 1.1
	return {"L": L, "W": W, "H": H, "base": base, "top": top, "cz": cz, "cl": cl, "zf": zf, "fi": fi, "ri": ri,
		"eye": Vector3(0.37, H - 0.26, zf - 1.0),
		"wheel_r": 0.36 if (style == "suv" or style == "pickup") else 0.32,
		"wheel_front_z": L * 0.5 - 0.85, "wheel_rear_z": -L * 0.5 + 0.8,
		"track": W * 0.5 - 0.17}


static func _m(color: Color, rough: float = 0.5, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _emit(color: Color, energy: float) -> StandardMaterial3D:
	var m := _m(color, 0.3)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


# ======================================================================= bộ gộp hình

class PB:
	var tools: Dictionary = {}     # key -> [SurfaceTool, Material]
	var box_m := BoxMesh.new()
	var cyl_m := CylinderMesh.new()
	var sph_m := SphereMesh.new()

	func _init() -> void:
		box_m.size = Vector3.ONE
		cyl_m.top_radius = 0.5
		cyl_m.bottom_radius = 0.5
		cyl_m.height = 1.0
		cyl_m.radial_segments = 16
		cyl_m.rings = 1
		sph_m.radius = 0.5
		sph_m.height = 1.0
		sph_m.radial_segments = 12
		sph_m.rings = 6

	func _st(mat: Material, kind: String) -> SurfaceTool:
		var key := str(mat.get_instance_id()) + kind
		if not tools.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = [st, mat]
		return tools[key][0]

	## Hộp có tâm, kích thước, và hướng (basis không co giãn).
	func box(mat: Material, pos: Vector3, size: Vector3, basis: Basis = Basis()) -> void:
		_st(mat, "p").append_from(box_m, 0, Transform3D(basis * Basis.from_scale(size), pos))

	## Hộp nối 2 điểm (dạng thanh), độ dày w x h.
	func bar(mat: Material, a: Vector3, b: Vector3, w: float, h: float, up: Vector3 = Vector3.UP) -> void:
		var d := b - a
		if d.length() < 0.001:
			return
		var bs := Basis.looking_at(d.normalized(), up if absf(d.normalized().dot(up)) < 0.98 else Vector3.RIGHT)
		box(mat, (a + b) * 0.5, Vector3(w, h, d.length()), bs)

	func cyl(mat: Material, pos: Vector3, radius: float, height: float, basis: Basis = Basis()) -> void:
		_st(mat, "p").append_from(cyl_m, 0, Transform3D(basis * Basis.from_scale(Vector3(radius * 2.0, height, radius * 2.0)), pos))

	func sphere(mat: Material, pos: Vector3, size: Vector3) -> void:
		_st(mat, "p").append_from(sph_m, 0, Transform3D(Basis.from_scale(size), pos))

	## Khối 8 đỉnh tùy ý: v[0..3] mặt dưới, v[4..7] mặt trên (cùng thứ tự: sau-trái, sau-phải, trước-phải, trước-trái).
	func hull(mat: Material, v: Array) -> void:
		var st := _st(mat, "h")
		var faces := [[0, 1, 2, 3], [4, 5, 6, 7], [3, 2, 6, 7], [0, 1, 5, 4], [0, 3, 7, 4], [1, 2, 6, 5]]
		var center := Vector3.ZERO
		for p in v:
			center += p
		center /= 8.0
		for f in faces:
			var a: Vector3 = v[f[0]]
			var b: Vector3 = v[f[1]]
			var c: Vector3 = v[f[2]]
			var d: Vector3 = v[f[3]]
			var n := (b - a).cross(c - a)
			if n.length() < 0.0001:
				n = (c - a).cross(d - a)
			n = n.normalized()
			if n.dot((a + b + c + d) * 0.25 - center) < 0.0:
				n = -n
			for p in [a, b, c, a, c, d]:
				st.set_normal(n)
				st.add_vertex(p)

	## Ống tròn đi qua dãy điểm (vành vô lăng, vòm bánh...)
	func tube(mat: Material, pts: Array, radius: float, closed: bool = false) -> void:
		var n := pts.size()
		var cnt := n if closed else n - 1
		for i in cnt:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[(i + 1) % n]
			var d := b - a
			var l := d.length()
			if l < 0.0005:
				continue
			var y := d / l
			var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
			var z := x.cross(y)
			var bs := Basis(x, y, z)
			cyl(mat, (a + b) * 0.5, radius, l + radius * 0.6, bs)

	func commit(parent: Node3D, layer: int, shadows: bool = true) -> void:
		for key in tools.keys():
			var pair: Array = tools[key]
			var st: SurfaceTool = pair[0]
			var mi := MeshInstance3D.new()
			mi.mesh = st.commit()
			mi.material_override = pair[1]
			mi.layers = layer
			if not shadows:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)
		tools.clear()


# ======================================================================= thân xe

static func build(spec: Dictionary, color: Color, with_interior: bool, layer_ext: int = 1) -> Dictionary:
	var d := dims(spec)
	var L: float = d["L"]
	var W: float = d["W"]
	var H: float = d["H"]
	var base: float = d["base"]
	var top: float = d["top"]
	var cz: float = d["cz"]
	var cl: float = d["cl"]
	var style: String = spec["style"]
	var hw := W * 0.5

	var paint := _m(color, 0.22, 0.45)
	var glass := _m(Color(0.13, 0.17, 0.21), 0.04, 0.55)
	var black := _m(Color(0.04, 0.04, 0.045), 0.35, 0.2)       # nhựa bóng (cột B, viền)
	var plastic := _m(Color(0.09, 0.09, 0.1), 0.85)            # nhựa nhám (cản, ốp)
	var chrome := _m(Color(0.82, 0.83, 0.86), 0.15, 0.95)
	var plate := _m(Color(0.96, 0.96, 0.94), 0.6)
	var head_mat := _emit(Color(1.0, 0.97, 0.88), 0.6)
	var tail_mat := _emit(Color(0.75, 0.02, 0.02), 0.4)
	var blink_mat := _emit(Color(1.0, 0.55, 0.05), 0.0)
	var blink_mat_r := _emit(Color(1.0, 0.55, 0.05), 0.0)
	var lens := _m(Color(0.75, 0.8, 0.85), 0.05, 0.6)
	var well := _m(Color(0.015, 0.015, 0.015), 1.0)
	var seam := _m(Color(0.02, 0.02, 0.02), 1.0)

	var ext := Node3D.new()
	ext.name = "Exterior"
	var pb := PB.new()

	# --- thân dưới: mũi xe vát, đuôi vát nhẹ, vai xe thu vào
	var zb0 := -L * 0.5 + 0.04
	var zb1 := L * 0.5 - 0.04
	var zt0 := -L * 0.5 + 0.18
	var zt1 := L * 0.5 - 0.3
	var nose_y := top - 0.07
	pb.hull(paint, [Vector3(hw - 0.03, base, zb0), Vector3(-hw + 0.03, base, zb0), Vector3(-hw + 0.03, base, zb1), Vector3(hw - 0.03, base, zb1),
		Vector3(hw - 0.06, top, zt0), Vector3(-hw + 0.06, top, zt0), Vector3(-hw + 0.06, nose_y, zt1), Vector3(hw - 0.06, nose_y, zt1)])
	# mặt trước/sau tại độ cao y (để gắn đèn sát thân)
	var front_z := func(y: float) -> float: return lerpf(zb1, zt1, clampf((y - base) / (top - base), 0.0, 1.0))
	var rear_z := func(y: float) -> float: return lerpf(zb0, zt0, clampf((y - base) / (top - base), 0.0, 1.0))
	var slope_f := Basis(Vector3.RIGHT, -atan2(zb1 - zt1, top - base))
	var slope_r := Basis(Vector3.RIGHT, atan2(zt0 - zb0, top - base))

	# --- ốp cản dưới, ốp sườn
	pb.box(plastic, Vector3(0, base + 0.05, zb1 + 0.01), Vector3(W * 0.92, 0.1, 0.08))
	pb.box(plastic, Vector3(0, base + 0.05, zb0 - 0.01), Vector3(W * 0.92, 0.1, 0.08))
	var wfz: float = d["wheel_front_z"]
	var wrz: float = d["wheel_rear_z"]
	var wr: float = d["wheel_r"]
	for sx: float in [-1.0, 1.0]:
		pb.box(plastic, Vector3(sx * (hw - 0.02), base + 0.05, (wfz + wrz) * 0.5), Vector3(0.05, 0.1, wfz - wrz - wr * 2.4))
		# vòm bánh xe
		for wz in [wfz, wrz]:
			var arc: Array = []
			for k in 11:
				var a := PI * float(k) / 10.0
				arc.append(Vector3(sx * (hw - 0.005), wr + 0.02 + sin(a) * (wr + 0.07), wz + cos(a) * (wr + 0.07)))
			pb.tube(plastic, arc, 0.035)
			pb.box(well, Vector3(sx * (hw - 0.04), wr + 0.08, wz), Vector3(0.02, wr * 1.3, wr * 2.2))

	# --- lưới tản nhiệt, logo, hốc gió
	var gy := top - 0.17
	pb.box(black, Vector3(0, gy, front_z.call(gy) + 0.012), Vector3(W * 0.36, 0.13, 0.03), slope_f)
	for k in 3:
		var yy := gy - 0.045 + k * 0.045
		pb.box(chrome, Vector3(0, yy, front_z.call(yy) + 0.03), Vector3(W * 0.34, 0.008, 0.01), slope_f)
	pb.cyl(chrome, Vector3(0, gy + 0.005, front_z.call(gy) + 0.04), 0.035, 0.015, Basis(Vector3.RIGHT, PI * 0.5))
	var iy := base + 0.17
	pb.box(black, Vector3(0, iy, front_z.call(iy) + 0.01), Vector3(W * 0.55, 0.08, 0.03))
	for sx: float in [-1.0, 1.0]:
		pb.cyl(lens, Vector3(sx * W * 0.36, iy, front_z.call(iy) + 0.02), 0.035, 0.02, Basis(Vector3.RIGHT, PI * 0.5))

	# --- đèn pha (viền đen, thấu kính, dải LED)
	var hy := top - 0.13
	for sx: float in [-1.0, 1.0]:
		var hz: float = front_z.call(hy)
		pb.box(black, Vector3(sx * W * 0.34, hy, hz + 0.005), Vector3(0.42, 0.11, 0.03), slope_f)
		pb.box(head_mat, Vector3(sx * W * 0.35, hy + 0.01, hz + 0.02), Vector3(0.3, 0.06, 0.02), slope_f)
		pb.box(head_mat, Vector3(sx * W * 0.33, hy - 0.04, hz + 0.022), Vector3(0.34, 0.012, 0.02), slope_f)
		pb.box(blink_mat if sx > 0 else blink_mat_r, Vector3(sx * W * 0.465, hy, hz - 0.01), Vector3(0.05, 0.07, 0.03), slope_f)

	# --- đuôi xe: đèn hậu, dải nối, ống xả
	var ty := top - 0.1
	for sx: float in [-1.0, 1.0]:
		var tz: float = rear_z.call(ty)
		pb.box(black, Vector3(sx * W * 0.36, ty, tz - 0.005), Vector3(0.38, 0.12, 0.03), slope_r)
		pb.box(tail_mat, Vector3(sx * W * 0.36, ty + 0.01, tz - 0.02), Vector3(0.34, 0.07, 0.02), slope_r)
		pb.box(blink_mat if sx > 0 else blink_mat_r, Vector3(sx * W * 0.44, ty - 0.04, tz - 0.022), Vector3(0.1, 0.025, 0.02), slope_r)
	pb.box(tail_mat, Vector3(0, ty + 0.01, rear_z.call(ty) - 0.018), Vector3(W * 0.36, 0.015, 0.02), slope_r)
	pb.cyl(chrome, Vector3(-W * 0.3, base + 0.06, zb0 - 0.02), 0.035, 0.1, Basis(Vector3.RIGHT, PI * 0.5))

	# --- biển số
	var py := base + 0.24
	pb.box(plate, Vector3(0, py, front_z.call(py) + 0.035), Vector3(0.52, 0.12, 0.01))
	pb.box(plate, Vector3(0, py + 0.08, rear_z.call(py + 0.08) - 0.035), Vector3(0.52, 0.12, 0.01))

	# --- cabin: kính, mui, các cột
	var ch := H - top
	var cab_w := W * 0.84
	if style == "pickup":
		var bed_z0 := cz - cl * 0.5
		var bed_len := bed_z0 + L * 0.5
		var bz := -L * 0.5 + bed_len * 0.5
		pb.box(paint, Vector3(W * 0.47, top + 0.22, bz), Vector3(0.08, 0.44, bed_len))
		pb.box(paint, Vector3(-W * 0.47, top + 0.22, bz), Vector3(0.08, 0.44, bed_len))
		pb.box(paint, Vector3(0, top + 0.22, -L * 0.5 + 0.2), Vector3(W * 0.9, 0.44, 0.08))
		pb.box(plastic, Vector3(0, top + 0.01, bz), Vector3(W * 0.9, 0.02, bed_len))
	var fi: float = d["fi"]
	var ri: float = d["ri"]
	var z0 := cz - cl * 0.5
	var z1 := cz + cl * 0.5
	var hw0 := cab_w * 0.5
	var hw1 := cab_w * 0.42
	var rt := 0.06
	var k_ := 1.0 - rt / ch
	var zt0c := z0 + ri * k_
	var zt1c := z1 - fi * k_
	var hwt := hw1 + (hw0 - hw1) * rt / ch
	pb.hull(glass, [Vector3(hw0, top - 0.01, z0), Vector3(-hw0, top - 0.01, z0), Vector3(-hw0, top - 0.01, z1), Vector3(hw0, top - 0.01, z1),
		Vector3(hwt, H - rt, zt0c), Vector3(-hwt, H - rt, zt0c), Vector3(-hwt, H - rt, zt1c), Vector3(hwt, H - rt, zt1c)])
	pb.hull(paint, [Vector3(hwt + 0.01, H - rt, zt0c - 0.02), Vector3(-hwt - 0.01, H - rt, zt0c - 0.02), Vector3(-hwt - 0.01, H - rt, zt1c + 0.02), Vector3(hwt + 0.01, H - rt, zt1c + 0.02),
		Vector3(hw1 - 0.02, H, z0 + ri), Vector3(-hw1 + 0.02, H, z0 + ri), Vector3(-hw1 + 0.02, H, z1 - fi), Vector3(hw1 - 0.02, H, z1 - fi)])
	for sx: float in [-1.0, 1.0]:
		# cột A, cột C màu sơn
		pb.bar(paint, Vector3(sx * (hw0 + 0.005), top, z1 - 0.02), Vector3(sx * (hwt + 0.005), H - rt, zt1c + 0.02), 0.07, 0.05)
		pb.bar(paint, Vector3(sx * (hw0 + 0.005), top, z0 + 0.03), Vector3(sx * (hwt + 0.005), H - rt, zt0c - 0.02), 0.1, 0.05)
		# cột B đen bóng
		var bzc := cz - cl * 0.04
		pb.bar(black, Vector3(sx * (hw0 + 0.012), top, bzc), Vector3(sx * (hwt + 0.012), H - rt, bzc), 0.12, 0.012, Vector3(sx, 0, 0))
		# khe cửa, tay nắm
		for zz in [z1 - 0.05, bzc, z0 + 0.15]:
			pb.box(seam, Vector3(sx * (hw - 0.045), (base + top) * 0.5 + 0.02, zz), Vector3(0.01, top - base - 0.08, 0.008))
		for zz in [bzc + 0.38, bzc - 0.48]:
			pb.box(chrome, Vector3(sx * (hw - 0.04), top - 0.1, zz), Vector3(0.025, 0.025, 0.13))
		# gương chiếu hậu ngoài
		var mz := z1 - 0.2
		pb.box(black, Vector3(sx * (hw0 + 0.08), top + 0.04, mz), Vector3(0.12, 0.03, 0.06))
		pb.box(paint, Vector3(sx * (hw + 0.12), top + 0.1, mz), Vector3(0.2, 0.13, 0.1))
		pb.box(glass, Vector3(sx * (hw + 0.12), top + 0.1, mz - 0.052), Vector3(0.17, 0.1, 0.01))
		pb.box(blink_mat if sx > 0 else blink_mat_r, Vector3(sx * (hw + 0.12), top + 0.065, mz + 0.03), Vector3(0.16, 0.012, 0.03))
	# viền kính mạ crôm
	for sx: float in [-1.0, 1.0]:
		pb.box(chrome, Vector3(sx * (hw0 + 0.01), top + 0.005, cz), Vector3(0.015, 0.015, cl))
	# vây cá mập, giá nóc
	pb.hull(black, [Vector3(0.04, H, z0 + ri + 0.12), Vector3(-0.04, H, z0 + ri + 0.12), Vector3(-0.04, H, z0 + ri + 0.3), Vector3(0.04, H, z0 + ri + 0.3),
		Vector3(0.01, H + 0.06, z0 + ri + 0.14), Vector3(-0.01, H + 0.06, z0 + ri + 0.14), Vector3(-0.01, H + 0.01, z0 + ri + 0.28), Vector3(0.01, H + 0.01, z0 + ri + 0.28)])
	if style == "suv":
		for sx: float in [-1.0, 1.0]:
			pb.box(chrome, Vector3(sx * (hw1 - 0.06), H + 0.03, cz), Vector3(0.04, 0.03, cl - fi - ri))

	# Biển "TẬP LÁI"
	if spec.get("sign", false):
		pb.box(plate, Vector3(0, H + 0.13, cz + 0.1), Vector3(0.9, 0.24, 0.05))
		pb.box(black, Vector3(0, H + 0.02, cz + 0.1), Vector3(0.3, 0.04, 0.2))
		for zz: float in [0.03, -0.03]:
			var lb := Label3D.new()
			lb.text = "TẬP LÁI"
			lb.modulate = Color(0.85, 0.05, 0.05)
			lb.outline_size = 0
			lb.font_size = 64
			lb.pixel_size = 0.0028
			lb.position = Vector3(0, H + 0.13, cz + 0.1 + zz)
			if zz < 0:
				lb.rotation.y = PI
			lb.layers = layer_ext
			ext.add_child(lb)

	pb.commit(ext, layer_ext)

	# Bóng mờ dưới gầm
	if _shadow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.55))
		g.set_color(1, Color(0, 0, 0, 0.0))
		_shadow_tex = GradientTexture2D.new()
		_shadow_tex.gradient = g
		_shadow_tex.fill = GradientTexture2D.FILL_RADIAL
		_shadow_tex.fill_from = Vector2(0.5, 0.5)
		_shadow_tex.fill_to = Vector2(1.0, 0.5)
		_shadow_tex.width = 64
		_shadow_tex.height = 64
	var sh := MeshInstance3D.new()
	var qm := PlaneMesh.new()
	qm.size = Vector2(W + 0.5, L + 0.6)
	sh.mesh = qm
	var shm := StandardMaterial3D.new()
	shm.albedo_texture = _shadow_tex
	shm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shm.albedo_color = Color(1, 1, 1, 1)
	sh.material_override = shm
	sh.position.y = 0.03
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sh.layers = 1
	ext.add_child(sh)

	var res := {"exterior": ext, "dims": d, "tail_mat": tail_mat, "head_mat": head_mat, "blink_l": blink_mat, "blink_r": blink_mat_r}
	if with_interior:
		res.merge(_interior(spec, d, color))
	return res


# ======================================================================= nội thất

static func _interior(spec: Dictionary, d: Dictionary, color: Color) -> Dictionary:
	var L: float = d["L"]
	var W: float = d["W"]
	var H: float = d["H"]
	var top: float = d["top"]
	var zf: float = d["zf"]
	var cz: float = d["cz"]
	var cl: float = d["cl"]
	var fi: float = float(d["fi"]) * 0.6   # trong cabin: mép trần đẩy về trước cho kính lái thoáng
	var eye: Vector3 = d["eye"]
	var lay := LAYER_INTERIOR
	var inn := Node3D.new()
	inn.name = "Interior"
	var pb := PB.new()
	var paint := _m(color, 0.22, 0.45)
	var dash_top := _m(Color(0.1, 0.1, 0.105), 0.95)            # taplo trên, nhám chống lóa
	var soft := _m(Color(0.42, 0.37, 0.32), 0.9)                  # da/nỉ màu be
	var trim := _m(Color(0.26, 0.26, 0.27), 0.85)
	var liner := _m(Color(0.72, 0.7, 0.66), 0.95)
	liner.emission_enabled = true
	liner.emission = Color(0.72, 0.7, 0.66)
	liner.emission_energy_multiplier = 0.22
	var black := _m(Color(0.035, 0.035, 0.04), 0.4, 0.2)
	var chrome := _m(Color(0.8, 0.81, 0.84), 0.18, 0.9)
	var leather := _m(Color(0.05, 0.05, 0.055), 0.6)
	var stitch := _m(Color(0.75, 0.08, 0.06), 0.6)
	var screen := _emit(Color(0.12, 0.22, 0.35), 0.9)
	var gauge := _emit(Color(0.2, 0.8, 1.0), 1.2)

	var roof_y := H - 0.02
	# Nắp capo nhìn qua kính
	var hood_len := L * 0.5 - zf - 0.3
	pb.hull(paint, [Vector3(W * 0.47, top - 0.06, zf), Vector3(-W * 0.47, top - 0.06, zf), Vector3(-W * 0.44, top - 0.12, zf + hood_len), Vector3(W * 0.44, top - 0.12, zf + hood_len),
		Vector3(W * 0.46, top - 0.01, zf), Vector3(-W * 0.46, top - 0.01, zf), Vector3(-W * 0.43, top - 0.07, zf + hood_len), Vector3(W * 0.43, top - 0.07, zf + hood_len)])

	# Taplo: mặt trên vát về phía kính lái
	var dz0 := eye.z + 0.62
	var dy := eye.y - 0.3
	pb.hull(dash_top, [Vector3(W * 0.46, dy - 0.25, dz0), Vector3(-W * 0.46, dy - 0.25, dz0), Vector3(-W * 0.46, top - 0.2, zf), Vector3(W * 0.46, top - 0.2, zf),
		Vector3(W * 0.46, dy, dz0 + 0.03), Vector3(-W * 0.46, dy, dz0 + 0.03), Vector3(-W * 0.46, top - 0.005, zf), Vector3(W * 0.46, top - 0.005, zf)])
	# ốp mặt taplo màu be (hai tông)
	pb.box(soft, Vector3(0, dy - 0.08, dz0 - 0.005), Vector3(W * 0.9, 0.07, 0.02))
	pb.box(chrome, Vector3(0, dy - 0.04, dz0 - 0.012), Vector3(W * 0.9, 0.008, 0.008))
	# Mái che cụm đồng hồ + mặt đồng hồ phát sáng
	pb.hull(dash_top, [Vector3(eye.x + 0.24, dy - 0.01, dz0 - 0.02), Vector3(eye.x - 0.24, dy - 0.01, dz0 - 0.02), Vector3(eye.x - 0.24, dy - 0.01, dz0 + 0.2), Vector3(eye.x + 0.24, dy - 0.01, dz0 + 0.2),
		Vector3(eye.x + 0.22, dy + 0.07, dz0 - 0.03), Vector3(eye.x - 0.22, dy + 0.07, dz0 - 0.03), Vector3(eye.x - 0.22, dy + 0.04, dz0 + 0.18), Vector3(eye.x + 0.22, dy + 0.04, dz0 + 0.18)])
	pb.box(black, Vector3(eye.x, dy - 0.04, dz0 + 0.04), Vector3(0.42, 0.13, 0.02), Basis(Vector3.RIGHT, deg_to_rad(-15)))
	for gx in [-0.11, 0.11]:
		var ring: Array = []
		for k in 13:
			var a := PI * 0.85 + float(k) / 12.0 * PI * 1.3
			ring.append(Vector3(eye.x + gx + cos(a) * 0.05, dy - 0.035 + sin(a) * 0.05, dz0 + 0.03))
		pb.tube(gauge, ring, 0.004)
	# Màn hình giữa
	var scr_pos := Vector3(0.0, dy + 0.06, dz0 + 0.1)
	var scr_b := Basis(Vector3.RIGHT, deg_to_rad(-12))
	pb.box(black, scr_pos, Vector3(0.27, 0.15, 0.025), scr_b)
	pb.box(screen, scr_pos + Vector3(0, 0, -0.014), Vector3(0.245, 0.125, 0.005), scr_b)
	# Cửa gió điều hòa
	for vx in [-0.1, 0.1, W * 0.4, -W * 0.4]:
		var vp := Vector3(vx, dy - 0.12, dz0 - 0.02)
		pb.box(black, vp, Vector3(0.12, 0.06, 0.03))
		pb.box(chrome, vp + Vector3(0, 0, -0.017), Vector3(0.125, 0.065, 0.004))
		for k in 3:
			pb.box(trim, vp + Vector3(0, -0.018 + k * 0.018, -0.02), Vector3(0.11, 0.005, 0.01))
	# Bệ trung tâm + cần số
	var cons_z := eye.z + 0.25
	pb.box(trim, Vector3(0, top - 0.2, cons_z), Vector3(0.24, 0.16, 0.7))
	pb.box(black, Vector3(0, top - 0.115, cons_z + 0.05), Vector3(0.16, 0.012, 0.2))
	pb.cyl(chrome, Vector3(0, top - 0.06, cons_z + 0.08), 0.008, 0.12)
	pb.sphere(leather, Vector3(0, top + 0.01, cons_z + 0.08), Vector3(0.06, 0.08, 0.06))
	pb.cyl(chrome, Vector3(0, top - 0.025, cons_z + 0.08), 0.022, 0.012)

	# Cột A, ốp cửa, tấm che nắng, trần
	for sx: float in [-1.0, 1.0]:
		var a := Vector3(sx * W * 0.42, top + 0.02, zf - 0.02)
		var b := Vector3(sx * W * 0.36, roof_y, zf - fi)
		pb.bar(trim, a, b, 0.07, 0.05, Vector3(sx, 0, 0))
		# ốp cửa hai tông + tay vịn + tay mở cửa
		var dx := sx * W * 0.47
		pb.box(dash_top, Vector3(dx, top + 0.02, cz + 0.1), Vector3(0.06, 0.12, cl * 0.95))
		pb.box(soft, Vector3(dx - sx * 0.01, top - 0.12, cz + 0.1), Vector3(0.06, 0.18, cl * 0.9))
		pb.box(trim, Vector3(dx - sx * 0.05, top - 0.07, eye.z + 0.05), Vector3(0.08, 0.05, 0.4))
		pb.box(chrome, Vector3(dx - sx * 0.035, top + 0.0, eye.z + 0.35), Vector3(0.02, 0.03, 0.1))
		# tấm che nắng (gập lên)
		pb.box(liner, Vector3(sx * 0.38, roof_y + 0.0, zf - fi - 0.14), Vector3(0.32, 0.015, 0.15))
	pb.box(trim, Vector3(0, roof_y - 0.005, zf - fi - 0.03), Vector3(W * 0.74, 0.035, 0.08))
	var rz0 := zf - fi - 0.06
	var rz1 := cz - cl * 0.5
	pb.box(liner, Vector3(0, roof_y + 0.02, (rz0 + rz1) * 0.5), Vector3(W * 0.84, 0.025, rz0 - rz1))
	# Gương chiếu hậu trong + chân gương
	var mpos := Vector3(0, eye.y + 0.13, eye.z + 0.62)
	pb.bar(black, Vector3(0, roof_y, zf - fi - 0.02), mpos + Vector3(0, 0.03, 0), 0.02, 0.02)
	pb.box(black, mpos, Vector3(0.25, 0.07, 0.035))
	pb.box(_m(Color(0.5, 0.55, 0.6), 0.05, 0.9), mpos + Vector3(0, 0, -0.018), Vector3(0.235, 0.058, 0.004))

	pb.commit(inn, lay, false)
	# Đèn trần mờ chỉ chiếu nội thất cho dễ nhìn taplo
	var il := OmniLight3D.new()
	il.position = Vector3(0, roof_y - 0.15, eye.z + 0.3)
	il.omni_range = 1.6
	il.light_energy = 0.3
	il.light_cull_mask = lay
	il.shadow_enabled = false
	inn.add_child(il)

	# Vô lăng kiểu thể thao 3 chấu, đáy vát (D-cut), bọc da chỉ đỏ
	var pivot := Node3D.new()
	pivot.name = "SteeringPivot"
	pivot.position = Vector3(eye.x, eye.y - 0.37, eye.z + 0.46)
	pivot.rotation.x = deg_to_rad(-24.0)
	inn.add_child(pivot)
	var wheel := Node3D.new()
	pivot.add_child(wheel)
	var wpb := PB.new()
	var R := 0.185
	var rim: Array = []
	for k in 40:
		var a := TAU * float(k) / 40.0
		var p := Vector3(cos(a) * R, sin(a) * R, 0)
		if p.y < -R * 0.8:
			p.y = -R * 0.8      # đáy vát
		rim.append(p)
	wpb.tube(leather, rim, 0.017, true)
	# vạch đỏ ở đỉnh vô lăng
	wpb.tube(stitch, [Vector3(-0.012, R, 0), Vector3(0.012, R, 0)], 0.0185)
	# chấu ngang (bạc) và chấu dưới (đen)
	for sx: float in [-1.0, 1.0]:
		wpb.box(chrome, Vector3(sx * 0.11, -0.01, 0.0), Vector3(0.13, 0.035, 0.018))
		wpb.box(black, Vector3(sx * 0.1, -0.03, -0.004), Vector3(0.11, 0.025, 0.02))
		for k in 2:
			wpb.box(trim, Vector3(sx * (0.075 + k * 0.035), -0.008, -0.012), Vector3(0.022, 0.018, 0.006))
	wpb.box(black, Vector3(0, -0.11, 0.0), Vector3(0.05, 0.12, 0.018))
	wpb.cyl(black, Vector3(0, 0, 0.0), 0.07, 0.05, Basis(Vector3.RIGHT, PI * 0.5))
	wpb.cyl(chrome, Vector3(0, 0, -0.027), 0.022, 0.006, Basis(Vector3.RIGHT, PI * 0.5))
	wpb.commit(wheel, lay, false)
	# trụ lái
	var colpb := PB.new()
	colpb.cyl(black, Vector3(0, 0, 0.12), 0.04, 0.2, Basis(Vector3.RIGHT, PI * 0.5))
	colpb.commit(pivot, lay, false)
	return {"interior": inn, "steer": wheel}


# ======================================================================= bánh xe

static func make_wheel_mesh(radius: float, layer: int = 1) -> Node3D:
	var n := Node3D.new()
	var pb := PB.new()
	var tire := _m(Color(0.06, 0.06, 0.065), 0.92)
	var rim := _m(Color(0.72, 0.73, 0.76), 0.2, 0.85)
	var disc := _m(Color(0.35, 0.33, 0.32), 0.5, 0.6)
	var side := Basis(Vector3.FORWARD, PI * 0.5)   # trục bánh theo X
	var inner := _m(Color(0.1, 0.1, 0.11), 0.8)
	var hole := _m(Color(0.02, 0.02, 0.02), 1.0)
	pb.cyl(tire, Vector3.ZERO, radius, 0.22, side)
	pb.cyl(inner, Vector3.ZERO, radius * 0.72, 0.226, side)
	pb.cyl(disc, Vector3.ZERO, radius * 0.5, 0.2, side)
	for sxx: float in [-1.0, 1.0]:
		var face := sxx * 0.112
		pb.cyl(rim, Vector3(face, 0, 0), radius * 0.66, 0.012, side)
		pb.cyl(hole, Vector3(face * 1.02, 0, 0), radius * 0.56, 0.012, side)
		for k in 5:
			var a := TAU * float(k) / 5.0
			var dir := Vector3(0, cos(a), sin(a))
			pb.box(rim, Vector3(face * 1.04, 0, 0) + dir * radius * 0.33, Vector3(0.016, radius * 0.5, 0.05), Basis(Vector3.RIGHT, a))
		pb.cyl(rim, Vector3(face * 1.06, 0, 0), radius * 0.15, 0.03, side)
	pb.commit(n, layer)
	return n


## Xe trang trí đơn giản (xe AI, xe đỗ): một node có bánh xe gắn sẵn.
static func build_simple(spec: Dictionary, color: Color) -> Dictionary:
	var r := build(spec, color, false, 1)
	var ext: Node3D = r["exterior"]
	var d: Dictionary = r["dims"]
	var wr: float = d["wheel_r"]
	for z in [d["wheel_front_z"], d["wheel_rear_z"]]:
		for sx: float in [-1.0, 1.0]:
			var w := make_wheel_mesh(wr)
			w.position = Vector3(sx * float(d["track"]), wr, float(z))
			ext.add_child(w)
	return r
