class_name Pedestrian
extends Node3D
## Người đi bộ băng qua đường ở vạch dành cho người đi bộ (bài nhường đường).
## Đứng chờ ở lề trái, khi được gọi `start()` thì đi ngang qua đường sang lề phải.

const WALK := 1.3

var from_x: float = 5.0
var to_x: float = -5.0
var half_w: float = 3.5
var state: String = "idle"          # idle | walk | done
var _t: float = 0.0
var _body: Node3D


func setup(p_from: float, p_to: float, p_half_w: float, shirt: Color) -> void:
	from_x = p_from
	to_x = p_to
	half_w = p_half_w
	_body = Node3D.new()
	add_child(_body)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.88, 0.7, 0.55)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = shirt
	var pants := StandardMaterial3D.new()
	pants.albedo_color = Color(0.18, 0.2, 0.3)
	var legs := MeshInstance3D.new()
	var lm := CapsuleMesh.new()
	lm.radius = 0.13
	lm.height = 0.85
	legs.mesh = lm
	legs.material_override = pants
	legs.position.y = 0.43
	_body.add_child(legs)
	var torso := MeshInstance3D.new()
	var tm := CapsuleMesh.new()
	tm.radius = 0.19
	tm.height = 0.62
	torso.mesh = tm
	torso.material_override = cloth
	torso.position.y = 1.15
	_body.add_child(torso)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.12
	hm.height = 0.24
	head.mesh = hm
	head.material_override = skin
	head.position.y = 1.58
	_body.add_child(head)
	reset()


func reset() -> void:
	state = "idle"
	_t = 0.0
	position.x = from_x
	rotation.y = -PI * 0.5 if to_x < from_x else PI * 0.5
	if _body:
		_body.position = Vector3.ZERO
		_body.rotation.z = 0.0


func get_state() -> Array:
	return [state, position.x, _t]


func set_state(a: Array) -> void:
	state = String(a[0])
	position.x = float(a[1])
	_t = float(a[2])


func start() -> void:
	if state == "idle":
		state = "walk"


## Người đang ở trên mặt đường (kể cả mép đường)
func on_road() -> bool:
	return state == "walk" and absf(position.x) < half_w + 0.4


func _physics_process(delta: float) -> void:
	if state != "walk":
		return
	_t += delta
	var dir := signf(to_x - from_x)
	position.x += dir * WALK * delta
	_body.position.y = absf(sin(_t * 7.0)) * 0.05
	_body.rotation.z = sin(_t * 7.0) * 0.04
	if (to_x - position.x) * dir <= 0.0:
		position.x = to_x
		state = "done"
