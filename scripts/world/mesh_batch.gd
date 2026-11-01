class_name MeshBatch
extends RefCounted
## Gộp nhiều khối hộp tĩnh cùng vật liệu thành một mesh để máy yếu vẽ nhanh.

static var _mats: Dictionary = {}

var _tools: Dictionary = {}   # key vật liệu -> SurfaceTool
var _box := BoxMesh.new()
var _cyl := CylinderMesh.new()
var _sph := SphereMesh.new()


func _init() -> void:
	_box.size = Vector3.ONE
	_cyl.top_radius = 0.5
	_cyl.bottom_radius = 0.5
	_cyl.height = 1.0
	_cyl.radial_segments = 10
	_cyl.rings = 1
	_sph.radius = 0.5
	_sph.height = 1.0
	_sph.radial_segments = 10
	_sph.rings = 6


static func mat(key: String, color: Color = Color.WHITE, rough: float = 0.9, emissive: float = 0.0, metal: float = 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


static func unshaded(key: String, color: Color) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


func _tool(key: String) -> SurfaceTool:
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = st
	return _tools[key]


## Hộp: tâm `pos`, kích thước `size`, quay quanh trục Y `yaw`.
func box(key: String, pos: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	var b := Basis(Vector3.UP, yaw) * Basis.from_scale(size)
	_tool(key).append_from(_box, 0, Transform3D(b, pos))


func box_basis(key: String, basis: Basis, pos: Vector3, size: Vector3) -> void:
	_tool(key).append_from(_box, 0, Transform3D(basis * Basis.from_scale(size), pos))


func cyl(key: String, pos: Vector3, radius: float, height: float) -> void:
	var b := Basis.from_scale(Vector3(radius * 2.0, height, radius * 2.0))
	_tool(key).append_from(_cyl, 0, Transform3D(b, pos))


func sphere(key: String, pos: Vector3, size: Vector3) -> void:
	_tool(key).append_from(_sph, 0, Transform3D(Basis.from_scale(size), pos))


## Dải phẳng nằm trên mặt đất từ a đến b (vạch kẻ, mặt đường).
func strip(key: String, a: Vector3, b: Vector3, width: float, y: float = 0.02, thick: float = 0.02) -> void:
	var d := b - a
	d.y = 0.0
	var l := d.length()
	if l < 0.001:
		return
	var yaw := atan2(d.x, d.z)
	var c := (a + b) * 0.5
	c.y = y
	box(key, c, Vector3(width, thick, l), yaw)


func commit(parent: Node, shadows: bool = true) -> void:
	for key in _tools.keys():
		var st: SurfaceTool = _tools[key]
		var m := st.commit()
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = _mats.get(key)
		if not shadows:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	_tools.clear()
