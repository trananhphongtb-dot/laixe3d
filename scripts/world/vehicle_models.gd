class_name VehicleModels
extends RefCounted
## Mô hình xe máy, xe đạp, xe tải đơn giản (ít khối để máy yếu vẫn mượt). Hướng đầu xe: +Z.

static var _mats: Dictionary = {}
static var _box := BoxMesh.new()
static var _cyl := CylinderMesh.new()
static var _sph := SphereMesh.new()
static var _ready_meshes := false


static func _prep() -> void:
	if _ready_meshes:
		return
	_ready_meshes = true
	_box.size = Vector3.ONE
	_cyl.top_radius = 0.5
	_cyl.bottom_radius = 0.5
	_cyl.height = 1.0
	_cyl.radial_segments = 12
	_cyl.rings = 1
	_sph.radius = 0.5
	_sph.height = 1.0
	_sph.radial_segments = 8
	_sph.rings = 4


static func _m(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%.1f" % [color.to_html(), glow]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.75
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, size: Vector3, basis: Basis = Basis()) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(basis * Basis.from_scale(size), pos)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func _wheel(parent: Node3D, pos: Vector3, r: float, w: float) -> void:
	_add(parent, _cyl, _m(Color(0.07, 0.07, 0.08)), pos, Vector3(r * 2.0, w, r * 2.0), Basis(Vector3(0, 0, 1), PI * 0.5))


static func _rider(parent: Node3D, pos: Vector3, shirt: Color, helmet: Color) -> void:
	_add(parent, _box, _m(shirt), pos + Vector3(0, 0.3, 0), Vector3(0.42, 0.6, 0.26))
	_add(parent, _sph, _m(helmet), pos + Vector3(0, 0.74, 0.03), Vector3(0.29, 0.3, 0.3))
	_add(parent, _box, _m(Color(0.18, 0.2, 0.3)), pos + Vector3(0, -0.12, 0.12), Vector3(0.36, 0.3, 0.4))


## kind: "moto" | "bike" | "truck". Trả về {"node": Node3D, "W":, "H":, "L":}
static func build(kind: String, color: Color, rng: RandomNumberGenerator) -> Dictionary:
	_prep()
	var n := Node3D.new()
	var shirts := [Color(0.85, 0.2, 0.2), Color(0.2, 0.45, 0.85), Color(0.9, 0.8, 0.2), Color(0.25, 0.65, 0.35), Color(0.9, 0.9, 0.9)]
	var shirt: Color = shirts[rng.randi() % shirts.size()]
	var helm := Color(0.12, 0.12, 0.14) if rng.randf() < 0.5 else Color(0.95, 0.95, 0.95)
	match kind:
		"moto":
			_wheel(n, Vector3(0, 0.3, 0.65), 0.3, 0.1)
			_wheel(n, Vector3(0, 0.3, -0.65), 0.3, 0.12)
			_add(n, _box, _m(color), Vector3(0, 0.55, 0.0), Vector3(0.3, 0.38, 1.1))
			_add(n, _box, _m(Color(0.08, 0.08, 0.09)), Vector3(0, 0.78, -0.3), Vector3(0.3, 0.1, 0.55))
			_add(n, _box, _m(Color(0.6, 0.6, 0.65)), Vector3(0, 0.95, 0.55), Vector3(0.6, 0.05, 0.05))
			_add(n, _box, _m(Color(1.0, 0.95, 0.7), 2.0), Vector3(0, 0.8, 0.8), Vector3(0.16, 0.12, 0.06))
			_add(n, _box, _m(Color(0.9, 0.1, 0.1), 1.0), Vector3(0, 0.75, -0.9), Vector3(0.14, 0.08, 0.05))
			_rider(n, Vector3(0, 0.95, -0.2), shirt, helm)
			return {"node": n, "W": 0.8, "H": 1.7, "L": 1.9}
		"bike":
			_wheel(n, Vector3(0, 0.34, 0.5), 0.34, 0.04)
			_wheel(n, Vector3(0, 0.34, -0.5), 0.34, 0.04)
			_add(n, _box, _m(color), Vector3(0, 0.6, 0.0), Vector3(0.05, 0.06, 1.0))
			_add(n, _box, _m(color), Vector3(0, 0.62, 0.42), Vector3(0.04, 0.55, 0.05), Basis(Vector3.RIGHT, -0.25))
			_add(n, _box, _m(Color(0.6, 0.6, 0.65)), Vector3(0, 1.0, 0.45), Vector3(0.5, 0.04, 0.04))
			_rider(n, Vector3(0, 0.8, -0.12), shirt, helm)
			return {"node": n, "W": 0.6, "H": 1.7, "L": 1.7}
		_:
			var cargo_cols := [Color(0.92, 0.92, 0.92), Color(0.2, 0.4, 0.7), Color(0.85, 0.85, 0.5), Color(0.55, 0.58, 0.6)]
			var cc: Color = cargo_cols[rng.randi() % cargo_cols.size()]
			_add(n, _box, _m(Color(0.12, 0.12, 0.13)), Vector3(0, 0.6, 0.0), Vector3(2.0, 0.4, 6.6))
			_add(n, _box, _m(color), Vector3(0, 1.45, 2.3), Vector3(2.15, 1.9, 1.9))
			_add(n, _box, _m(Color(0.08, 0.1, 0.14)), Vector3(0, 1.85, 3.26), Vector3(1.9, 0.75, 0.05))
			_add(n, _box, _m(cc), Vector3(0, 2.15, -1.05), Vector3(2.3, 2.6, 4.6))
			_add(n, _box, _m(Color(1.0, 0.95, 0.7), 2.0), Vector3(0.75, 0.85, 3.28), Vector3(0.35, 0.2, 0.05))
			_add(n, _box, _m(Color(1.0, 0.95, 0.7), 2.0), Vector3(-0.75, 0.85, 3.28), Vector3(0.35, 0.2, 0.05))
			_add(n, _box, _m(Color(0.9, 0.1, 0.1), 1.0), Vector3(0.8, 0.8, -3.3), Vector3(0.3, 0.2, 0.05))
			_add(n, _box, _m(Color(0.9, 0.1, 0.1), 1.0), Vector3(-0.8, 0.8, -3.3), Vector3(0.3, 0.2, 0.05))
			for z in [2.4, -1.5, -2.8]:
				for sx: float in [-1.0, 1.0]:
					_wheel(n, Vector3(sx * 0.98, 0.5, z), 0.5, 0.34)
			return {"node": n, "W": 2.3, "H": 3.5, "L": 6.8}
