class_name LeadCar
extends AnimatableBody3D
## Xe chạy phía trước trong bài tập (vượt xe, phanh khẩn cấp).
## Chạy đều với `cruise`; khi `brake_after` đếm về 0 thì phanh gấp, đứng `hold` giây rồi chạy lại.

var speed: float = 5.0
var cruise: float = 5.0
var end_z: float = 1000.0
var length: float = 3.9
var brake_after: float = -1.0
var hold: float = 0.0
var braking: bool = false


func setup(color: Color, p_cruise: float = 5.0) -> void:
	cruise = p_cruise
	speed = p_cruise
	sync_to_physics = true
	var spec: Dictionary = Game.CARS["hatch"]
	length = float(spec["len"])
	var r := CarModel.build_simple(spec, color)
	add_child(r["exterior"])
	var dm: Dictionary = r["dims"]
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(float(dm["W"]), float(dm["H"]) - 0.25, float(dm["L"]))
	cs.shape = bs
	cs.position = Vector3(0, 0.25 + (float(dm["H"]) - 0.25) * 0.5, 0)
	add_child(cs)


## Phanh gấp sau `after` giây, đứng yên `stay` giây rồi chạy tiếp
func brake_in(after: float, stay: float) -> void:
	brake_after = after
	hold = stay
	braking = false


func get_state() -> Array:
	return [position.z, speed, brake_after, hold, braking]


func set_state(s: Array) -> void:
	position.z = float(s[0])
	speed = float(s[1])
	brake_after = float(s[2])
	hold = float(s[3])
	braking = bool(s[4])


func _physics_process(delta: float) -> void:
	if brake_after > 0.0:
		brake_after -= delta
		if brake_after <= 0.0:
			braking = true
	if braking:
		speed = maxf(speed - 8.0 * delta, 0.0)
		if speed <= 0.0:
			hold -= delta
			if hold <= 0.0:
				braking = false
	else:
		speed = move_toward(speed, cruise, 3.0 * delta)
	if position.z < end_z:
		position.z += speed * delta
