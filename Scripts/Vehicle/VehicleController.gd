extends VehicleBody3D
class_name VehicleController
## Four raycast suspension wheels, RWD, manual gearbox, aero loads and rear handbrake.
signal impacted(strength: float)
signal shifted(gear: int)

const MASS_KG := 1350.0
var driving: DrivingInput
var powertrain := Powertrain.new()
var track: Node3D
var spawn_transform := Transform3D.IDENTITY
var signed_speed := 0.0
var speed_kmh := 0.0
var slip_amount := 0.0
var lateral_g := 0.0
var longitudinal_g := 0.0
var steer_normalized := 0.0
var offroad := false
var grounded_wheels := 0
var impact_strength := 0.0
var distance_m := 0.0
var rear_slip := 0.0
var wheels: Array[VehicleWheel3D] = []
var _previous_velocity := Vector3.ZERO
var _impact_cooldown := 0.0
var _local_previous_velocity := Vector3.ZERO
var _wheel_meshes: Array[Node3D] = []
var _tire_smoke: Array[CPUParticles3D] = []
@onready var model: Node3D = $Model
@onready var driver: RobotDriver = $Driver
@onready var cockpit: Cockpit = $Cockpit
@onready var sound: VehicleAudio = $Audio

func _ready() -> void:
	mass = MASS_KG
	center_of_mass_mode = VehicleBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.38, 0.12)
	contact_monitor = true
	max_contacts_reported = 8
	linear_damp = 0.0
	angular_damp = 0.35
	for node_name in ["FL", "FR", "RL", "RR"]:
		wheels.append(get_node(node_name))
	_attach_visuals()
	_build_tire_smoke()
	if not is_instance_valid(driving):
		driving = DrivingInput.new()
		add_child(driving)
	driving.gear_requested.connect(_shift)
	cockpit.setup(self)
	driver.setup(self)
	sound.setup(self)
	previous_velocity = linear_velocity

var previous_velocity := Vector3.ZERO

func _attach_visuals() -> void:
	var paint := _material("res://Assets/Materials/body_paint.tres")
	var leather := _material("res://Assets/Materials/alcantara.tres")
	var carbon := _material("res://Assets/Materials/carbon.tres")
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		if not mi.mesh:
			continue
		for surface in range(mi.mesh.get_surface_count()):
			var original := mi.get_active_material(surface)
			var mat_name := original.resource_name.to_lower() if original else ""
			if mat_name.contains("body_color"):
				mi.set_surface_override_material(surface, paint)
			elif mat_name.contains("leather") and not mat_name.contains("steering"):
				mi.set_surface_override_material(surface, leather)
			elif mat_name.contains("carbon"):
				mi.set_surface_override_material(surface, carbon)
			elif mat_name.contains("glass") and not mat_name.contains("light"):
				var glass := StandardMaterial3D.new()
				glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				glass.albedo_color = Color(0.63, 0.74, 0.78, 0.075)
				glass.metallic = 0.0
				glass.roughness = 0.09
				glass.refraction_enabled = false
				glass.cull_mode = BaseMaterial3D.CULL_DISABLED
				mi.set_surface_override_material(surface, glass)
	for pair in [["wheel_fl", "FL"], ["wheel_fr", "FR"], ["wheel_rl", "RL"], ["wheel_rr", "RR"]]:
		var visual := model.find_child(pair[0], true, false) as Node3D
		var wheel := get_node(pair[1]) as VehicleWheel3D
		if visual:
			visual.reparent(wheel, false)
			# VehicleWheel3D's synchronized transform is the wheel center, with X as axle.
			visual.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO)
			_wheel_meshes.append(visual)

func _build_tire_smoke() -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = load("res://Assets/Textures/tire_smoke.png")
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.72, 0.73, 0.72, 0.28))
	ramp.set_color(1, Color(0.65, 0.66, 0.65, 0.0))
	for side in [-1.0, 1.0]:
		var particles := CPUParticles3D.new()
		particles.name = "RearTireSmoke"
		particles.position = Vector3(side * 0.82, 0.12, 1.50)
		particles.amount = 18
		particles.lifetime = 0.9
		particles.local_coords = false
		particles.emitting = false
		particles.direction = Vector3(0, 1, 0.4)
		particles.spread = 28
		particles.gravity = Vector3(0, 0.5, 0)
		particles.initial_velocity_min = 0.4
		particles.initial_velocity_max = 1.3
		particles.scale_amount_min = 0.35
		particles.scale_amount_max = 0.85
		particles.color_ramp = ramp
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		particles.mesh = quad
		particles.material_override = mat
		add_child(particles)
		_tire_smoke.append(particles)

func _material(path: String) -> Material:
	return load(path) as Material

func _shift(gear: int) -> void:
	if powertrain.request_shift(gear, signed_speed, driving.brake):
		driving.current_gear = gear
		shifted.emit(gear)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(driving):
		return
	var forward := -global_basis.z
	signed_speed = linear_velocity.dot(forward)
	speed_kmh = absf(signed_speed) * 3.6
	var speed := linear_velocity.length()
	var local_velocity := global_basis.inverse() * linear_velocity
	var local_accel := (local_velocity - _local_previous_velocity) / delta
	_local_previous_velocity = local_velocity
	lateral_g = lerpf(lateral_g, clampf(-local_accel.x / 9.81, -2, 2), 0.12)
	longitudinal_g = lerpf(longitudinal_g, clampf(-local_accel.z / 9.81, -2, 2), 0.12)
	var max_steer := lerpf(0.48, 0.16, clampf(speed / 55.0, 0, 1))
	var target := -driving.steer_target * max_steer if driving.enabled else 0.0
	steering = move_toward(steering, target, delta * (1.6 if absf(target) > absf(steering) else 2.4))
	steer_normalized = -steering / 0.48
	var accelerator := driving.throttle if driving.enabled else 0.0
	var service_brake := driving.brake if driving.enabled else 1.0
	var parking_brake := driving.handbrake if driving.enabled else 0.0
	var drive_force := powertrain.step(delta, accelerator, signed_speed)
	engine_force = -drive_force * 0.5
	if service_brake > 0.02 or parking_brake > 0.05 or not driving.enabled:
		drive_force = 0.0
	elif powertrain.engine_brake_force > 0:
		drive_force = -signf(signed_speed) * powertrain.engine_brake_force
	grounded_wheels = 0
	rear_slip = 0.0
	for i in range(wheels.size()):
		var wheel := wheels[i]
		if wheel.is_in_contact():
			grounded_wheels += 1
		var rear := i >= 2
		var grip := 3.15 if not rear else 3.0
		if offroad:
			grip *= 0.42
		if rear and parking_brake > 0.05:
			grip *= lerpf(1.0, 0.20, parking_brake)
		wheel.wheel_friction_slip = lerpf(wheel.wheel_friction_slip, grip, 0.15)
		# VehicleWheel3D.brake is an impulse budget per physics tick, not a 0–1 pedal.
		wheel.brake = service_brake * (66.0 if not rear else 42.0)
		if rear:
			wheel.brake += parking_brake * 95.0
			rear_slip = maxf(rear_slip, 1.0 - wheel.get_skidinfo())
		if absf(signed_speed) < 0.2 and service_brake < 0.05 and accelerator < 0.05:
			wheel.brake = 12.0
	slip_amount = lerpf(slip_amount, clampf(rear_slip + absf(local_velocity.x) / maxf(speed, 3.0), 0, 1), 0.16)
	for smoke in _tire_smoke:
		smoke.emitting = slip_amount > 0.24 and speed > 3.0
	constant_force = Vector3.ZERO
	if grounded_wheels > 0:
		var planar := Vector3(linear_velocity.x, 0, linear_velocity.z)
		var drag := planar.normalized() * (0.64 * speed * speed + 165.0)
		if offroad:
			drag += planar * 210.0
		constant_force = -drag + Vector3.DOWN * minf(6500.0, 0.88 * speed * speed)
	_impact_cooldown = maxf(0, _impact_cooldown - delta)
	var unexpected: Vector3 = linear_velocity - previous_velocity
	unexpected.y = 0
	if unexpected.length() > 1.6 and speed > 2.0 and _impact_cooldown <= 0:
		impact_strength = clampf(unexpected.length() / 9.0, 0.12, 1.0)
		impacted.emit(impact_strength)
		_impact_cooldown = 0.3
		if OS.has_feature("android"):
			Input.vibrate_handheld(int(20 + impact_strength * 45), 0.5)
	impact_strength = move_toward(impact_strength, 0, delta * 2.5)
	previous_velocity = linear_velocity
	distance_m += speed * delta

func update_surface(is_offroad: bool) -> void:
	offroad = is_offroad

func reset_vehicle(at: Transform3D) -> void:
	spawn_transform = at
	freeze = true
	global_transform = at
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	constant_force = Vector3.ZERO
	engine_force = 0.0
	steering = 0.0
	powertrain.reset()
	driving.current_gear = 0
	driving.clear_controls()
	signed_speed = 0
	speed_kmh = 0
	slip_amount = 0
	previous_velocity = Vector3.ZERO
	_local_previous_velocity = Vector3.ZERO
	freeze = false
	if is_instance_valid(cockpit):
		cockpit.on_reset()
