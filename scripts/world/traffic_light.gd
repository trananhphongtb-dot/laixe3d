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
## Đèn cỡ lớn (cao 4 m, hộp 0.6 x 1.6 m có tấm nền viền trắng và mái che từng bóng) để dừng sát vạch vẫn thấy.
## `back_mats`: thêm 1 mặt đèn quay ngược lại (cho hướng đi ngược chiều nhìn từ phía xa ngã tư).
static func build(batch: MeshBatch, parent: Node3D, pos: Vector3, face_dir: Vector3, mats: Dictionary, height: float = 4.0, back_mats: Dictionary = {}) -> void:
	MeshBatch.mat("tl_pole", Color(0.25, 0.27, 0.3), 0.6, 0.0, 0.4)
	MeshBatch.mat("tl_box", Color(0.08, 0.08, 0.09), 0.7)
	MeshBatch.mat("tl_plate", Color(0.05, 0.05, 0.06), 0.8)
	MeshBatch.mat("tl_rim", Color(0.92, 0.92, 0.9), 0.6)
	batch.cyl("tl_pole", pos + Vector3(0, height * 0.5, 0), 0.1, height)
	batch.cyl("tl_pole", pos + Vector3(0, 0.12, 0), 0.2, 0.24)
	_head(batch, parent, pos, face_dir, mats, height)
	if not back_mats.is_empty():
		_head(batch, parent, pos, -face_dir, back_mats, height)


static func _head(batch: MeshBatch, parent: Node3D, pos: Vector3, face_dir: Vector3, mats: Dictionary, height: float) -> void:
	var yaw := atan2(face_dir.x, face_dir.z)
	var box_c := pos + Vector3(0, height + 0.8, 0) + face_dir * 0.2
	batch.box("tl_rim", box_c - face_dir * 0.03, Vector3(1.0, 2.0, 0.04), yaw)
	batch.box("tl_plate", box_c - face_dir * 0.01, Vector3(0.9, 1.9, 0.05), yaw)
	batch.box("tl_box", box_c + face_dir * 0.14, Vector3(0.56, 1.6, 0.3), yaw)
	if _lamp_mesh == null:
		_lamp_mesh = SphereMesh.new()
		_lamp_mesh.radius = 0.2
		_lamp_mesh.height = 0.4
		_lamp_mesh.radial_segments = 12
		_lamp_mesh.rings = 6
	var side := face_dir.rotated(Vector3.UP, PI * 0.5)
	var keys := ["R", "Y", "G"]
	for i in 3:
		var lc := box_c + Vector3(0, 0.5 - i * 0.5, 0) + face_dir * 0.27
		# mái che phía trên bóng
		batch.box("tl_box", lc + Vector3(0, 0.23, 0) + face_dir * 0.12, Vector3(0.46, 0.04, 0.26), yaw)
		for sx: float in [-1.0, 1.0]:
			batch.box("tl_box", lc + side * 0.23 * sx + Vector3(0, 0.08, 0) + face_dir * 0.1, Vector3(0.03, 0.3, 0.22), yaw)
		var mi := MeshInstance3D.new()
		mi.mesh = _lamp_mesh
		mi.material_override = mats[keys[i]]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = lc
		mi.scale = Vector3(1, 1, 0.45)
		mi.rotation.y = yaw
		parent.add_child(mi)
