class_name EnvBuilder
extends RefCounted
## Bầu trời, ánh sáng, sương, mưa.


static func build(parent: Node3D, night: bool, rain: bool) -> Dictionary:
	var g: int = Game.settings.get("graphics", 1)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	if night:
		sm.sky_top_color = Color(0.02, 0.03, 0.08)
		sm.sky_horizon_color = Color(0.08, 0.09, 0.15)
		sm.ground_horizon_color = Color(0.05, 0.05, 0.07)
		sm.ground_bottom_color = Color(0.01, 0.01, 0.02)
		sm.sun_angle_max = 1.0
	elif rain:
		sm.sky_top_color = Color(0.36, 0.4, 0.45)
		sm.sky_horizon_color = Color(0.55, 0.58, 0.6)
		sm.ground_horizon_color = Color(0.45, 0.47, 0.5)
	else:
		sm.sky_top_color = Color(0.22, 0.45, 0.85)
		sm.sky_horizon_color = Color(0.68, 0.8, 0.92)
		sm.ground_horizon_color = Color(0.6, 0.66, 0.7)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55 if night else 1.0
	if night:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.22, 0.25, 0.38)
		env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = rain or night
	if rain:
		env.fog_light_color = Color(0.55, 0.58, 0.62)
		env.fog_density = 0.012
	elif night:
		env.fog_light_color = Color(0.05, 0.06, 0.1)
		env.fog_density = 0.006
	if g >= 2 and not night:
		env.glow_enabled = false
	we.environment = env
	parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	if night:
		sun.light_energy = 0.25
		sun.light_color = Color(0.6, 0.7, 1.0)
	elif rain:
		sun.light_energy = 0.55
	else:
		sun.light_energy = 1.1
		sun.light_color = Color(1.0, 0.97, 0.9)
	sun.shadow_enabled = g >= 1 and not night
	sun.directional_shadow_max_distance = 60.0 if g == 1 else 110.0
	parent.add_child(sun)

	var res := {"env": env, "sun": sun}
	if rain:
		var p := CPUParticles3D.new()
		p.amount = [350, 700, 1200][g]
		p.lifetime = 0.9
		p.preprocess = 1.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(18, 1, 18)
		p.direction = Vector3(0.05, -1, 0)
		p.spread = 3.0
		p.gravity = Vector3(0, -9.8, 0)
		p.initial_velocity_min = 22.0
		p.initial_velocity_max = 26.0
		p.local_coords = false
		var qm := QuadMesh.new()
		qm.size = Vector2(0.02, 0.5)
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(0.8, 0.85, 0.95, 0.35)
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		qm.material = rm
		p.mesh = qm
		p.position = Vector3(0, 12, 0)
		res["rain"] = p
		var snd := Sfx.make_loop_player("rain")
		parent.add_child(snd)
		snd.volume_db = Sfx.vol_db(-10.0)
		snd.play()
	return res


static func ground(parent: Node3D, size: Vector2, center: Vector3, color: Color) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, 2.0, size.y)
	cs.shape = bs
	cs.position = center + Vector3(0, -1.0, 0)
	sb.add_child(cs)
	parent.add_child(sb)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.position = center + Vector3(0, -0.02, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	mi.material_override = m
	parent.add_child(mi)
