extends Node3D
class_name Cockpit
## Physical controls inside the imported cockpit: steering, gated lever, hydraulic handbrake, horn and instruments.
var car: VehicleController
var wheel_pivot: Node3D
var wheel_base_rotation := Quaternion.IDENTITY
var gear_pivot: Node3D
var gear_knob: Node3D
var handbrake_pivot: Node3D
var horn_button: MeshInstance3D
var dash_speed: Label3D
var dash_gear: Label3D
var dash_rpm: Label3D
var mirrors: MirrorSystem
var shift_light_meshes: Array[MeshInstance3D] = []
var shift_age := 10.0
var _dash_tick := 0.0
var _led_off: StandardMaterial3D
var _led_green: StandardMaterial3D
var _led_amber: StandardMaterial3D
var _led_red: StandardMaterial3D
const WHEEL_CENTER := Vector3(-0.346, 0.799, -0.346)
const GEAR_BASE := Vector3(0.015, 0.49, 0.10)
const HANDBRAKE_BASE := Vector3(0.10, 0.46, 0.38)

func setup(vehicle: VehicleController) -> void:
	car = vehicle
	wheel_pivot = car.model.find_child("steering_wheel", true, false) as Node3D
	if wheel_pivot:
		wheel_base_rotation = wheel_pivot.quaternion
		var area := Area3D.new()
		area.name = "SteeringTouchTarget"
		area.collision_layer = 4
		area.collision_mask = 0
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.205
		shape.shape = sphere
		area.add_child(shape)
		wheel_pivot.add_child(area)
		horn_button = Geo.cylinder(wheel_pivot, "PhysicalHorn", Vector3(0, 0.027, 0), 0.041, 0.009, Geo.material("res://Assets/Materials/joint.tres"))
		Geo.label(wheel_pivot, "HornMark", "S", Vector3(0, 0.034, 0.0), 0.00045, Color(0.8, 0.82, 0.8)).rotation.x = -PI / 2
	_build_shifter()
	_build_handbrake()
	_build_instruments()
	_build_cage()
	mirrors = MirrorSystem.new()
	mirrors.name = "Mirrors"
	add_child(mirrors)
	mirrors.setup(car)
	car.shifted.connect(func(_gear): shift_age = 0.0)

func _build_shifter() -> void:
	var metal := Geo.material("res://Assets/Materials/titanium.tres")
	var carbon := Geo.material("res://Assets/Materials/carbon.tres")
	var rubber := Geo.material("res://Assets/Materials/rubber.tres")
	Geo.box(self, "ConsoleBridge", Vector3(0.015, 0.40, 0.13), Vector3(0.23, 0.12, 0.65), carbon)
	Geo.box(self, "GatePlate", GEAR_BASE + Vector3(0, 0.012, 0), Vector3(0.15, 0.016, 0.19), metal)
	for x in [-0.048, -0.016, 0.016, 0.048]:
		Geo.box(self, "GateSlot", GEAR_BASE + Vector3(x, 0.022, 0), Vector3(0.009, 0.004, 0.145), rubber)
	Geo.box(self, "NeutralSlot", GEAR_BASE + Vector3(0, 0.023, 0), Vector3(0.112, 0.004, 0.01), rubber)
	gear_pivot = Node3D.new()
	gear_pivot.name = "GearLeverPivot"
	gear_pivot.position = GEAR_BASE + Vector3(0, 0.025, 0)
	add_child(gear_pivot)
	Geo.rod(gear_pivot, "GearShaft", Vector3.ZERO, Vector3(0, 0.155, 0), 0.009, metal)
	gear_knob = Geo.sphere(gear_pivot, "GearKnob", Vector3(0, 0.17, 0), Vector3(0.029, 0.034, 0.029), rubber)
	var cap := Geo.label(gear_pivot, "ShiftPattern", "1 3 5 R\n2 4 6", Vector3(0, 0.203, 0), 0.00032, Color(0.9, 0.9, 0.87))
	cap.rotation.x = -PI / 2
	for i in range(6):
		var x := [-0.048, -0.048, -0.016, -0.016, 0.016, 0.016][i]
		var z := -0.075 if i % 2 == 0 else 0.075
		Geo.label(self, "GateNumber" + str(i + 1), str(i + 1), GEAR_BASE + Vector3(x, 0.025, z), 0.00035, Color(0.8, 0.82, 0.8)).rotation.x = -PI / 2

func _build_handbrake() -> void:
	var metal := Geo.material("res://Assets/Materials/titanium.tres")
	handbrake_pivot = Node3D.new()
	handbrake_pivot.name = "HandbrakePivot"
	handbrake_pivot.position = HANDBRAKE_BASE
	add_child(handbrake_pivot)
	Geo.rod(handbrake_pivot, "HydraulicLever", Vector3.ZERO, Vector3(0, 0.20, 0.06), 0.012, metal)
	Geo.rod(handbrake_pivot, "HandbrakeGrip", Vector3(0, 0.12, 0.036), Vector3(0, 0.23, 0.069), 0.021, Geo.material("res://Assets/Materials/orange.tres"))
	Geo.cylinder(self, "HandbrakeBase", HANDBRAKE_BASE, 0.035, 0.045, Geo.material("res://Assets/Materials/dark_metal.tres"))

func _build_instruments() -> void:
	var carbon := Geo.material("res://Assets/Materials/carbon.tres")
	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.008, 0.015, 0.019)
	screen_mat.roughness = 0.38
	Geo.box(self, "DigitalCluster", Vector3(-0.346, 0.91, -0.565), Vector3(0.28, 0.10, 0.025), carbon)
	Geo.box(self, "ClusterScreen", Vector3(-0.346, 0.91, -0.549), Vector3(0.255, 0.078, 0.004), screen_mat)
	dash_speed = Geo.label(self, "Speed", "000", Vector3(-0.405, 0.918, -0.544), 0.00075, Color(0.89, 0.94, 0.94))
	dash_gear = Geo.label(self, "Gear", "N", Vector3(-0.265, 0.918, -0.544), 0.0011, Color(1, 0.36, 0.12))
	dash_rpm = Geo.label(self, "RPM", "950 RPM", Vector3(-0.365, 0.884, -0.544), 0.00038, Color(0.55, 0.67, 0.68))
	Geo.label(self, "ClusterUnit", "KM/H", Vector3(-0.405, 0.891, -0.544), 0.00028, Color(0.5, 0.6, 0.62))
	_led_off = StandardMaterial3D.new()
	_led_off.albedo_color = Color(0.025, 0.04, 0.035)
	_led_green = _led(Color(0.15, 0.85, 0.45))
	_led_amber = _led(Color(1.0, 0.55, 0.08))
	_led_red = _led(Color(1.0, 0.08, 0.025))
	for i in range(10):
		var led := Geo.sphere(self, "ShiftLED" + str(i), Vector3(-0.45 + i * 0.023, 0.974, -0.535), Vector3(0.007, 0.005, 0.004), _led_off)
		led.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shift_light_meshes.append(led)
	Geo.label(self, "ConsoleBadge", "SERRA  /  RS-01", Vector3(0.02, 0.47, -0.14), 0.00045, Color(0.66, 0.7, 0.7)).rotation.x = -PI / 2

func _led(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _build_cage() -> void:
	var mat := Geo.material("res://Assets/Materials/dark_metal.tres")
	for side in [-1.0, 1.0]:
		Geo.rod(self, "APillarCage", Vector3(side * 0.77, 0.52, -0.78), Vector3(side * 0.66, 1.17, -0.12), 0.024, mat)
		Geo.rod(self, "DoorBar", Vector3(side * 0.78, 0.48, 0.55), Vector3(side * 0.78, 0.73, -0.55), 0.022, mat)
		Geo.rod(self, "RearStay", Vector3(side * 0.66, 1.17, 0.55), Vector3(side * 0.76, 0.45, -0.55), 0.024, mat)
	Geo.rod(self, "RoofBar", Vector3(-0.66, 1.17, -0.12), Vector3(0.66, 1.17, -0.12), 0.025, mat)
	Geo.rod(self, "RearHoop", Vector3(-0.66, 1.17, 0.55), Vector3(0.66, 1.17, 0.55), 0.025, mat)

func _process(delta: float) -> void:
	if not is_instance_valid(car) or not is_instance_valid(wheel_pivot):
		return
	shift_age += delta
	# Rotate about the original steering-column axis, preserving its factory rake.
	wheel_pivot.quaternion = wheel_base_rotation * Quaternion(Vector3.UP, car.steering * 6.5)
	var gear := car.powertrain.gear
	var column := 0.0
	var row := 0.0
	if gear > 0:
		column = float((gear - 1) / 2 - 1) * 0.22
		row = -0.22 if gear % 2 == 1 else 0.22
	elif gear == -1:
		column = 0.30
		row = -0.22
	gear_pivot.rotation.z = lerpf(gear_pivot.rotation.z, -column, 1.0 - exp(-delta * 16))
	gear_pivot.rotation.x = lerpf(gear_pivot.rotation.x, row, 1.0 - exp(-delta * 16))
	handbrake_pivot.rotation.x = lerpf(handbrake_pivot.rotation.x, -car.driving.handbrake * 0.48, 1.0 - exp(-delta * 12))
	if horn_button:
		horn_button.position.y = lerpf(horn_button.position.y, 0.022 if car.driving.horn else 0.027, 0.3)
	_dash_tick += delta
	if _dash_tick >= 0.08:
		_dash_tick = 0
		dash_speed.text = "%03d" % int(car.speed_kmh)
		dash_gear.text = car.powertrain.gear_label()
		dash_rpm.text = "%d RPM" % int(car.powertrain.rpm)
		var lit := int((car.powertrain.rpm - 1800.0) / 700.0)
		for i in range(shift_light_meshes.size()):
			shift_light_meshes[i].material_override = (_led_green if i < 5 else (_led_amber if i < 8 else _led_red)) if i < lit else _led_off

func gear_knob_position() -> Vector3:
	return gear_knob.global_position if is_instance_valid(gear_knob) else global_position + GEAR_BASE + Vector3.UP * 0.19

func handbrake_grip_position() -> Vector3:
	return handbrake_pivot.to_global(Vector3(0, 0.20, 0.06)) if is_instance_valid(handbrake_pivot) else global_position + HANDBRAKE_BASE

func horn_position() -> Vector3:
	return wheel_pivot.to_global(Vector3(0, 0.035, 0)) if is_instance_valid(wheel_pivot) else global_position + WHEEL_CENTER

func on_reset() -> void:
	shift_age = 10.0
