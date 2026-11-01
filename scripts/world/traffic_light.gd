class_name TrafficLight
extends RefCounted
## Cột đèn giao thông. Phần tĩnh gộp vào MeshBatch, bóng đèn dùng vật liệu chung để đổi màu nhanh.

const COLORS := {"R": Color(1.0, 0.1, 0.05), "Y": Color(1.0, 0.75, 0.05), "G": Color(0.1, 1.0, 0.35)}

static var _lamp_mesh: SphereMesh


## Tạo bộ 3 vật liệu (đỏ, vàng, xanh) cho một hướng đèn.
static func make_mats() -> Dictionary:
	var d := {}
	for k in ["R", "Y", "G"]:
		var m := StandardMaterial3D.new()
		var c: Color = COLORS[k]
		m.albedo_color = c * 0.25
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.0
		d[k] = m
	return d


static func set_state(mats: Dictionary, state: String) -> void:
	for k in ["R", "Y", "G"]:
		var m: StandardMaterial3D = mats[k]
		var on: bool = k == state
		m.emission_energy_multiplier = 4.0 if on else 0.0
		var c: Color = COLORS[k]
		m.albedo_color = c if on else c * 0.22


## Dựng cột đèn tại `pos`, mặt đèn hướng về `face_dir` (hướng về phía xe đang tới).
static func build(batch: MeshBatch, parent: Node3D, pos: Vector3, face_dir: Vector3, mats: Dictionary, height: float = 3.2) -> void:
	MeshBatch.mat("tl_pole", Color(0.25, 0.27, 0.3), 0.6, 0.0, 0.4)
	MeshBatch.mat("tl_box", Color(0.08, 0.08, 0.09), 0.7)
	batch.cyl("tl_pole", pos + Vector3(0, height * 0.5, 0), 0.07, height)
	var yaw := atan2(face_dir.x, face_dir.z)
	var box_c := pos + Vector3(0, height + 0.45, 0)
	batch.box("tl_box", box_c, Vector3(0.36, 1.0, 0.3), yaw)
	if _lamp_mesh == null:
		_lamp_mesh = SphereMesh.new()
		_lamp_mesh.radius = 0.12
		_lamp_mesh.height = 0.24
		_lamp_mesh.radial_segments = 10
		_lamp_mesh.rings = 5
	var keys := ["R", "Y", "G"]
	for i in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = _lamp_mesh
		mi.material_override = mats[keys[i]]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = box_c + Vector3(0, 0.3 - i * 0.3, 0) + face_dir * 0.16
		parent.add_child(mi)
