class_name CarModel
extends RefCounted
## Dựng hình xe từ khối cơ bản. Hệ trục xe: +Z phía trước, +X bên trái, Y lên; y=0 là mặt đường.

const LAYER_EXTERIOR := 2
const LAYER_INTERIOR := 4


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
		"eye": Vector3(0.37, H - 0.2, zf - 1.05),
		"wheel_r": 0.36 if (style == "suv" or style == "pickup") else 0.32,
		"wheel_front_z": L * 0.5 - 0.85, "wheel_rear_z": -L * 0.5 + 0.8,
		"track": W * 0.5 - 0.17}


static func _m(color: Color, rough: float = 0.5, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


static func _emit(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


## Khối lăng trụ thang (mặt trên hẹp hơn mặt dưới) để làm thân, kính, mui xe.
static func _prism(parent: Node3D, mat: StandardMaterial3D, y0: float, y1: float, z0b: float, z1b: float, z0t: float, z1t: float,
		wb: float, wt: float, layer: int = 1) -> MeshInstance3D:
	var v := [Vector3(wb, y0, z0b), Vector3(-wb, y0, z0b), Vector3(-wb, y0, z1b), Vector3(wb, y0, z1b),
		Vector3(wt, y1, z0t), Vector3(-wt, y1, z0t), Vector3(-wt, y1, z1t), Vector3(wt, y1, z1t)]
	var faces := [[0, 1, 2, 3], [4, 5, 6, 7], [3, 2, 6, 7], [0, 1, 5, 4], [0, 3, 7, 4], [1, 2, 6, 5]]
	var center := Vector3(0, (y0 + y1) * 0.5, (z0b + z1b + z0t + z1t) * 0.25)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		var a: Vector3 = v[f[0]]
		var b: Vector3 = v[f[1]]
		var c: Vector3 = v[f[2]]
		var d: Vector3 = v[f[3]]
		var n := (b - a).cross(c - a).normalized()
		if n.length() < 0.01:
			n = (c - a).cross(d - a).normalized()
		var fc := (a + b + c + d) * 0.25
		if n.dot(fc - center) < 0.0:
			n = -n
		for p in [a, b, c, a, c, d]:
			st.set_normal(n)
			st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.layers = layer
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, mat: Material, pos: Vector3, size: Vector3, layer: int = 1) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.layers = layer
	parent.add_child(mi)
	return mi


## Dựng xe. Trả về Dictionary chứa các node cần điều khiển (đèn, vô lăng...).
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

	var paint := _m(color, 0.35, 0.3)
	var glass := _m(Color(0.08, 0.12, 0.16), 0.1, 0.4)
	var dark := _m(Color(0.1, 0.1, 0.11), 0.8)
	var chrome := _m(Color(0.75, 0.75, 0.78), 0.25, 0.8)
	var head_mat := _emit(Color(1.0, 0.97, 0.85), 0.6)
	var tail_mat := _emit(Color(0.75, 0.02, 0.02), 0.4)
	var blink_mat := _emit(Color(1.0, 0.55, 0.05), 0.0)

	var ext := Node3D.new()
	ext.name = "Exterior"
	var lay := layer_ext
	# Thân dưới
	_prism(ext, paint, base, top, -L * 0.5, L * 0.5, -L * 0.5 + 0.12, L * 0.5 - 0.18, W * 0.5, W * 0.48, lay)
	# vòm bánh xe (tối)
	var wr0: float = d["wheel_r"]
	for wz: float in [d["wheel_front_z"], d["wheel_rear_z"]]:
		for sx: float in [-1.0, 1.0]:
			_box(ext, dark, Vector3(sx * W * 0.495, base + 0.02, wz), Vector3(0.03, wr0 * 0.9, wr0 * 2.3), lay)
	# Cản trước/sau
	_box(ext, dark, Vector3(0, base + 0.1, L * 0.5 + 0.02), Vector3(W * 0.98, 0.22, 0.12), lay)
	_box(ext, dark, Vector3(0, base + 0.1, -L * 0.5 - 0.02), Vector3(W * 0.98, 0.22, 0.12), lay)
	# Khoang cabin + kính
	var ch := H - top
	var cab_w := W * 0.84
	if style == "pickup":
		# thùng xe
		var bed_z0 := cz - cl * 0.5
		var bed_len := bed_z0 + L * 0.5
		var bz := -L * 0.5 + bed_len * 0.5
		_box(ext, paint, Vector3(W * 0.47, top + 0.22, bz), Vector3(0.08, 0.44, bed_len), lay)
		_box(ext, paint, Vector3(-W * 0.47, top + 0.22, bz), Vector3(0.08, 0.44, bed_len), lay)
		_box(ext, paint, Vector3(0, top + 0.22, -L * 0.5 + 0.04), Vector3(W, 0.44, 0.08), lay)
		_box(ext, dark, Vector3(0, top + 0.01, bz), Vector3(W * 0.9, 0.02, bed_len), lay)
	var fi: float = d["fi"]
	var ri: float = d["ri"]
	var z0 := cz - cl * 0.5
	var z1 := cz + cl * 0.5
	var hw0 := cab_w * 0.5
	var hw1 := cab_w * 0.42
	var roof_t := 0.07
	# kính bao quanh
	_prism(ext, glass, top - 0.01, H - roof_t, z0, z1, z0 + ri * (1.0 - roof_t / ch), z1 - fi * (1.0 - roof_t / ch), hw0, hw1 + (hw0 - hw1) * roof_t / ch, lay)
	# mui xe
	_prism(ext, paint, H - roof_t, H, z0 + ri * (1.0 - roof_t / ch) - 0.02, z1 - fi * (1.0 - roof_t / ch) + 0.02, z0 + ri, z1 - fi, hw1 + 0.03, hw1, lay)
	# cột B
	var bz := cz - cl * 0.04
	_prism(ext, paint.duplicate(), top - 0.01, H - roof_t, bz - 0.07, bz + 0.07, bz - 0.07, bz + 0.07, hw0 + 0.01, hw1 + 0.02, lay)
	# viền dưới kính
	_box(ext, chrome, Vector3(0, top + 0.01, cz), Vector3(cab_w + 0.04, 0.03, cl), lay)
	# Đèn
	var heads: Array = []
	for sx: float in [-1.0, 1.0]:
		heads.append(_box(ext, head_mat, Vector3(sx * W * 0.34, top - 0.14, L * 0.5 + 0.01), Vector3(0.34, 0.12, 0.04), lay))
	var tails: Array = []
	for sx: float in [-1.0, 1.0]:
		tails.append(_box(ext, tail_mat, Vector3(sx * W * 0.36, top - 0.13, -L * 0.5 - 0.01), Vector3(0.3, 0.12, 0.04), lay))
	var blinks_l: Array = []
	var blinks_r: Array = []
	for z: float in [L * 0.5 + 0.015, -L * 0.5 - 0.015]:
		blinks_l.append(_box(ext, blink_mat, Vector3(W * 0.46, top - 0.14, z), Vector3(0.08, 0.1, 0.04), lay))
	var blink_mat_r := blink_mat.duplicate() as StandardMaterial3D
	for z: float in [L * 0.5 + 0.015, -L * 0.5 - 0.015]:
		blinks_r.append(_box(ext, blink_mat_r, Vector3(-W * 0.46, top - 0.14, z), Vector3(0.08, 0.1, 0.04), lay))
	# Gương chiếu hậu ngoài
	for sx: float in [-1.0, 1.0]:
		_box(ext, paint, Vector3(sx * (W * 0.5 + 0.1), top + 0.12, cz + cl * 0.5 - 0.25), Vector3(0.18, 0.12, 0.1), lay)
	# Biển số
	_box(ext, _m(Color(0.95, 0.95, 0.95), 0.6), Vector3(0, base + 0.28, -L * 0.5 - 0.06), Vector3(0.52, 0.12, 0.01), lay)
	_box(ext, _m(Color(0.95, 0.95, 0.95), 0.6), Vector3(0, base + 0.2, L * 0.5 + 0.09), Vector3(0.52, 0.12, 0.01), lay)
	# Biển "TẬP LÁI"
	if spec.get("sign", false):
		var sign_mat := _m(Color(0.97, 0.97, 0.95), 0.6)
		_box(ext, sign_mat, Vector3(0, H + 0.13, cz + 0.1), Vector3(0.9, 0.24, 0.05), lay)
		for zz: float in [0.035, -0.035]:
			var lb := Label3D.new()
			lb.text = "TẬP LÁI"
			lb.modulate = Color(0.85, 0.05, 0.05)
			lb.outline_size = 0
			lb.font_size = 64
			lb.pixel_size = 0.0028
			lb.position = Vector3(0, H + 0.13, cz + 0.1 + zz)
			if zz < 0:
				lb.rotation.y = PI
			lb.layers = lay
			ext.add_child(lb)

	var res := {"exterior": ext, "dims": d, "heads": heads, "tails": tails, "tail_mat": tail_mat,
		"head_mat": head_mat, "blink_l": blink_mat, "blink_r": blink_mat_r}

	if with_interior:
		res.merge(_interior(spec, d, color))
	return res


static func _interior(spec: Dictionary, d: Dictionary, color: Color) -> Dictionary:
	var L: float = d["L"]
	var W: float = d["W"]
	var H: float = d["H"]
	var top: float = d["top"]
	var zf: float = d["zf"]
	var cz: float = d["cz"]
	var cl: float = d["cl"]
	var eye: Vector3 = d["eye"]
	var lay := LAYER_INTERIOR
	var inn := Node3D.new()
	inn.name = "Interior"
	var paint := _m(color, 0.35, 0.3)
	var dash := _m(Color(0.13, 0.13, 0.14), 0.9)
	var trim := _m(Color(0.34, 0.33, 0.32), 0.9)
	var black := _m(Color(0.05, 0.05, 0.05), 0.7)

	# Nắp capo nhìn qua kính lái
	var hood_len := L * 0.5 - zf
	_box(inn, paint, Vector3(0, top - 0.02, zf + hood_len * 0.5), Vector3(W * 0.98, 0.06, hood_len), lay)
	# Taplo
	_box(inn, dash, Vector3(0, top - 0.02, zf - 0.22), Vector3(W * 0.9, 0.2, 0.46), lay)
	_box(inn, black, Vector3(eye.x, top + 0.1, zf - 0.42), Vector3(0.46, 0.1, 0.1), lay)  # cụm đồng hồ
	# Cột A
	var roof_y := H - 0.04
	for sx: float in [-1.0, 1.0]:
		var fi: float = d["fi"]
		var a := Vector3(sx * W * 0.42, top + 0.02, zf - 0.02)
		var b := Vector3(sx * W * 0.36, roof_y, zf - fi)
		var mid := (a + b) * 0.5
		var mi := _box(inn, trim, mid, Vector3(0.045, 0.06, a.distance_to(b)), lay)
		mi.transform = Transform3D(Basis.looking_at(b - a, Vector3.UP), mid)
		# Bậu cửa
		_box(inn, trim, Vector3(sx * W * 0.45, top + 0.08, cz), Vector3(0.12, 0.18, cl), lay)
	# Mép trần trước + trần
	var fi2: float = d["fi"]
	_box(inn, trim, Vector3(0, roof_y, zf - fi2 - 0.04), Vector3(W * 0.76, 0.05, 0.12), lay)
	var liner := _m(Color(0.62, 0.6, 0.57), 0.95)
	var rz0 := zf - fi2 - 0.08
	var rz1 := cz - cl * 0.5
	_box(inn, liner, Vector3(0, roof_y + 0.04, (rz0 + rz1) * 0.5), Vector3(W * 0.86, 0.03, rz0 - rz1), lay)
	# Gương chiếu hậu trong (khung)
	_box(inn, black, Vector3(0, roof_y - 0.08, zf - fi2 + 0.08), Vector3(0.22, 0.06, 0.03), lay)

	# Vô lăng
	var pivot := Node3D.new()
	pivot.name = "SteeringPivot"
	pivot.position = Vector3(eye.x, eye.y - 0.4, eye.z + 0.5)
	pivot.rotation.x = deg_to_rad(-25.0)
	inn.add_child(pivot)
	var wheel := Node3D.new()
	pivot.add_child(wheel)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.165
	torus.outer_radius = 0.2
	torus.rings = 24
	torus.ring_segments = 8
	var tm := MeshInstance3D.new()
	tm.mesh = torus
	tm.material_override = black
	tm.rotation.x = PI * 0.5
	tm.layers = lay
	wheel.add_child(tm)
	_box(wheel, black, Vector3(0, -0.08, 0), Vector3(0.05, 0.17, 0.03), lay)
	_box(wheel, black, Vector3(0.1, 0.0, 0), Vector3(0.2, 0.05, 0.03), lay)
	_box(wheel, black, Vector3(-0.1, 0.0, 0), Vector3(0.2, 0.05, 0.03), lay)
	var hub := _box(wheel, _m(Color(0.2, 0.2, 0.22), 0.5, 0.5), Vector3(0, 0, -0.01), Vector3(0.09, 0.09, 0.04), lay)
	hub.name = "Hub"
	# Cần số
	_box(inn, trim, Vector3(0, top + 0.02, eye.z + 0.2), Vector3(0.2, 0.12, 0.5), lay)
	_box(inn, black, Vector3(0, top + 0.15, eye.z + 0.28), Vector3(0.04, 0.16, 0.04), lay)
	return {"interior": inn, "steer": wheel}


static func make_wheel_mesh(radius: float, layer: int = 1) -> Node3D:
	var n := Node3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.22
	cm.radial_segments = 14
	cm.rings = 1
	var tire := MeshInstance3D.new()
	tire.mesh = cm
	tire.material_override = _m(Color(0.07, 0.07, 0.07), 0.95)
	tire.rotation.z = PI * 0.5
	tire.layers = layer
	n.add_child(tire)
	var rm := CylinderMesh.new()
	rm.top_radius = radius * 0.6
	rm.bottom_radius = radius * 0.6
	rm.height = 0.235
	rm.radial_segments = 10
	rm.rings = 1
	var rim := MeshInstance3D.new()
	rim.mesh = rm
	rim.material_override = _m(Color(0.7, 0.7, 0.72), 0.3, 0.8)
	rim.rotation.z = PI * 0.5
	rim.layers = layer
	n.add_child(rim)
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
