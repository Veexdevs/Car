extends Node3D
class_name RobotDriver
## Seated, full-body titanium pilot. Rigid armor is driven by an analytic two-bone IK rig.
## Hands are not glued to the wheel: shifting, horn and handbrake have independent reach/return states.
var car: VehicleController
var camera: Camera3D
var head: Node3D
var torso: Node3D
var hips: Node3D
var left_hand: Node3D
var right_hand: Node3D
var left_anchor: Node3D
var right_anchor: Node3D
var hand_action := &"steering"
var motion_scale := 1.0
var time := 0.0
var left_fingers: Array[Node3D] = []
var right_fingers: Array[Node3D] = []
var _arms: Dictionary = {}
var _legs: Dictionary = {}
var _lean := MotionSpring.new(2.2)
var _pitch := MotionSpring.new(2.6)
var _head_x := MotionSpring.new(3.4)
var _head_z := MotionSpring.new(3.2)
var _look_yaw := MotionSpring.new(3.8)
var _look_pitch := MotionSpring.new(3.8)
var _right_target := Vector3.ZERO
var _right_initialized := false
var _horn_blend := 0.0
var _brake_blend := 0.0
var _shift_blend := 0.0
var _impact_roll := MotionSpring.new(4.0)
var _titanium: StandardMaterial3D
var _carbon: StandardMaterial3D
var _joint: StandardMaterial3D
var _orange: StandardMaterial3D
const HIP := Vector3(-0.346, 0.46, 0.40)
const EYE := Vector3(0, 0.125, -0.035)

func setup(vehicle: VehicleController) -> void:
	car = vehicle
	_titanium = Geo.material("res://Assets/Materials/titanium.tres")
	_carbon = Geo.material("res://Assets/Materials/carbon.tres")
	_joint = Geo.material("res://Assets/Materials/joint.tres")
	_orange = Geo.material("res://Assets/Materials/orange.tres")
	_build_body()
	_build_arm("Left", -1.0)
	_build_arm("Right", 1.0)
	_build_leg("Left", -1.0)
	_build_leg("Right", 1.0)
	left_hand = _build_hand("Left", -1.0)
	right_hand = _build_hand("Right", 1.0)
	left_anchor = Node3D.new()
	left_anchor.name = "LeftGrip"
	left_anchor.position = Vector3(-0.153, 0.024, 0.012)
	car.cockpit.wheel_pivot.add_child(left_anchor)
	right_anchor = Node3D.new()
	right_anchor.name = "RightGrip"
	right_anchor.position = Vector3(0.153, 0.024, 0.012)
	car.cockpit.wheel_pivot.add_child(right_anchor)
	camera = Camera3D.new()
	camera.name = "PilotCamera"
	camera.position = EYE
	camera.fov = 74
	camera.near = 0.025
	camera.far = 650
	camera.cull_mask = 1
	camera.current = true
	head.add_child(camera)
	var listener := AudioListener3D.new()
	listener.name = "PilotEars"
	camera.add_child(listener)
	listener.make_current()
	car.impacted.connect(_on_impact)
	_right_target = to_local(right_anchor.global_position)
	_right_initialized = true
	update_pose(0.016)

func _build_body() -> void:
	hips = Node3D.new()
	hips.name = "Pelvis"
	hips.position = HIP
	add_child(hips)
	Geo.sphere(hips, "PelvisArmor", Vector3.ZERO, Vector3(0.17, 0.105, 0.135), _carbon)
	Geo.box(hips, "BeltBuckle", Vector3(0, 0.015, -0.13), Vector3(0.075, 0.05, 0.025), _titanium)
	torso = Node3D.new()
	torso.name = "Spine"
	hips.add_child(torso)
	Geo.capsule(torso, "Abdomen", Vector3(0, 0.14, -0.035), 0.115, 0.25, _joint)
	var chest := Geo.sphere(torso, "Thorax", Vector3(0, 0.30, -0.085), Vector3(0.185, 0.175, 0.115), _carbon)
	chest.rotation.x = -0.10
	Geo.box(torso, "ChestPlate", Vector3(0, 0.31, -0.185), Vector3(0.27, 0.20, 0.035), _titanium)
	Geo.box(torso, "ChestInset", Vector3(0, 0.31, -0.207), Vector3(0.10, 0.10, 0.012), _carbon)
	Geo.label(torso, "PilotID", "RS\n01", Vector3(0, 0.31, -0.215), 0.00065, Color(0.85, 0.87, 0.85)).rotation.y = PI
	for side in [-1.0, 1.0]:
		Geo.rod(torso, "SpinePiston", Vector3(side * 0.075, 0.04, 0.04), Vector3(side * 0.09, 0.32, -0.025), 0.016, _titanium)
		var strap := Geo.box(torso, "Harness", Vector3(side * 0.105, 0.23, -0.205), Vector3(0.047, 0.36, 0.014), _orange)
		strap_rotation(strap, side)
		Geo.sphere(torso, "ShoulderJoint", Vector3(side * 0.205, 0.36, -0.18), Vector3.ONE * 0.063, _joint)
		Geo.sphere(torso, "ShoulderCap", Vector3(side * 0.215, 0.375, -0.18), Vector3(0.078, 0.06, 0.075), _titanium)
	Geo.rod(torso, "Neck", Vector3(0, 0.40, -0.11), Vector3(0, 0.49, -0.13), 0.047, _titanium)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.49, -0.13)
	torso.add_child(head)
	var skull := Geo.sphere(head, "HelmetShell", Vector3(0, 0.085, 0.012), Vector3(0.108, 0.132, 0.118), _titanium)
	var visor := Geo.sphere(head, "Visor", Vector3(0, 0.09, -0.082), Vector3(0.099, 0.061, 0.047), Geo.material("res://Assets/Materials/visor.tres"))
	var chin := Geo.box(head, "ChinGuard", Vector3(0, 0.005, -0.055), Vector3(0.13, 0.055, 0.09), _carbon)
	for mesh in [skull, visor, chin]:
		mesh.layers = 2
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for side in [-1.0, 1.0]:
		var ear := Geo.cylinder(head, "HelmetFastener", Vector3(side * 0.105, 0.08, 0.01), 0.026, 0.012, _orange)
	ear_rotation()

func strap_rotation(strap: MeshInstance3D, side: float) -> void:
	strap.rotation.z = side * 0.13
	strap.rotation.x = -0.10

func ear_rotation() -> void:
	for ear in head.find_children("HelmetFastener", "MeshInstance3D", false, false):
		ear.rotation.z = PI / 2

func _build_arm(name: String, side: float) -> void:
	var upper := Geo.capsule(self, name + "UpperArm", Vector3.ZERO, 0.052, 0.31, _titanium)
	var lower := Geo.capsule(self, name + "Forearm", Vector3.ZERO, 0.043, 0.29, _carbon)
	var upper_plate := Geo.box(self, name + "UpperArmor", Vector3.ZERO, Vector3(0.072, 0.19, 0.065), _titanium)
	var lower_plate := Geo.box(self, name + "ForearmArmor", Vector3.ZERO, Vector3(0.064, 0.17, 0.058), _titanium)
	var piston := Geo.rod(self, name + "ArmPiston", Vector3.ZERO, Vector3.UP * 0.2, 0.009, _titanium, 8)
	var elbow := Geo.sphere(self, name + "Elbow", Vector3.ZERO, Vector3.ONE * 0.052, _joint)
	var elbow_cap := Geo.sphere(self, name + "ElbowCap", Vector3.ZERO, Vector3(0.057, 0.04, 0.057), _orange)
	_arms[name] = {"upper": upper, "lower": lower, "upper_plate": upper_plate, "lower_plate": lower_plate, "piston": piston, "elbow": elbow, "elbow_cap": elbow_cap, "side": side}

func _build_leg(name: String, side: float) -> void:
	var thigh := Geo.capsule(self, name + "Thigh", Vector3.ZERO, 0.079, 0.43, _carbon)
	var shin := Geo.capsule(self, name + "Shin", Vector3.ZERO, 0.058, 0.40, _titanium)
	var knee := Geo.sphere(self, name + "Knee", Vector3.ZERO, Vector3.ONE * 0.068, _joint)
	var knee_cap := Geo.sphere(self, name + "KneeArmor", Vector3.ZERO, Vector3(0.065, 0.07, 0.04), _titanium)
	var foot := Geo.box(self, name + "Foot", Vector3.ZERO, Vector3(0.095, 0.065, 0.22), _carbon)
	var sole := Geo.box(self, name + "Sole", Vector3.ZERO, Vector3(0.098, 0.018, 0.225), _joint)
	_legs[name] = {"thigh": thigh, "shin": shin, "knee": knee, "knee_cap": knee_cap, "foot": foot, "sole": sole, "side": side}

func _build_hand(name: String, side: float) -> Node3D:
	var hand := Node3D.new()
	hand.name = name + "Hand"
	add_child(hand)
	Geo.sphere(hand, "Wrist", Vector3(0, 0, 0.045), Vector3.ONE * 0.032, _joint)
	Geo.box(hand, "Palm", Vector3.ZERO, Vector3(0.074, 0.028, 0.078), _carbon)
	Geo.box(hand, "MetacarpalPlate", Vector3(0, 0.019, 0.003), Vector3(0.066, 0.012, 0.064), _titanium)
	var fingers: Array[Node3D] = []
	for i in range(4):
		var root := Node3D.new()
		root.name = "Digit" + str(i + 1)
		root.position = Vector3(-0.027 + i * 0.018, -0.003, -0.036)
		hand.add_child(root)
		var lengths := [0.027, 0.023, 0.019]
		var parent: Node3D = root
		for j in range(3):
			var joint := Node3D.new()
			joint.name = "Phalanx" + str(j + 1)
			joint.position = Vector3(0, 0, 0 if j == 0 else -lengths[j - 1])
			joint.rotation.x = [-0.48, -0.82, -0.68][j]
			parent.add_child(joint)
			Geo.capsule(joint, "MetalSegment", Vector3(0, 0, -lengths[j] * 0.5), 0.0068, lengths[j] + 0.008, _titanium).rotation.x = PI / 2
			Geo.sphere(joint, "Knuckle", Vector3.ZERO, Vector3.ONE * 0.008, _joint)
			parent = joint
		fingers.append(root)
	var thumb := Node3D.new()
	thumb.name = "Thumb"
	thumb.position = Vector3(side * 0.043, -0.004, 0.012)
	thumb.rotation.y = side * 0.75
	thumb.rotation.x = -0.45
	hand.add_child(thumb)
	for j in range(2):
		var segment := Geo.capsule(thumb, "ThumbPhalanx" + str(j), Vector3(0, -j * 0.008, -0.014 - j * 0.023), 0.0085, 0.032, _titanium)
		segment.rotation.x = PI / 2 - 0.35
	fingers.append(thumb)
	if side < 0:
		left_fingers = fingers
	else:
		right_fingers = fingers
	return hand

func _on_impact(strength: float) -> void:
	_head_x.impulse(strength * 0.18)
	_head_z.impulse(-strength * 0.12)
	_impact_roll.impulse(strength * 0.22)

func _process(delta: float) -> void:
	if is_instance_valid(car):
		update_pose(delta)

func update_pose(delta: float) -> void:
	time += delta
	var speed_factor := clampf(car.speed_kmh / 120.0, 0, 1)
	var lateral := clampf(car.lateral_g * 0.055 + car.steer_normalized * speed_factor * 0.035, -0.065, 0.065)
	var pitch := clampf(car.longitudinal_g * 0.038, -0.055, 0.045)
	torso.rotation.z = _lean.step(-lateral * motion_scale, delta)
	torso.rotation.x = _pitch.step(pitch * motion_scale, delta)
	var anticipation := car.steer_normalized * (0.035 + speed_factor * 0.07)
	_look_yaw.step(car.driving.look_yaw + anticipation * motion_scale, delta)
	_look_pitch.step(car.driving.look_pitch + pitch * 0.45 * motion_scale, delta)
	head.rotation.y = _look_yaw.value
	head.rotation.x = _look_pitch.value
	head.rotation.z = -lateral * 0.28 * motion_scale + _impact_roll.step(0, delta) * motion_scale
	var engine_hz := car.powertrain.rpm / 60.0
	var vibration := (0.00035 + car.powertrain.throttle * 0.00065) * motion_scale
	camera.position = EYE + Vector3(
		sin(time * engine_hz * 0.51) * vibration + _head_z.step(0, delta) * motion_scale,
		sin(time * engine_hz) * vibration * 0.6,
		clampf(car.longitudinal_g * 0.012, -0.018, 0.015) * motion_scale + _head_x.step(0, delta) * motion_scale)
	camera.rotation.z = -lateral * 0.12 * motion_scale
	_update_legs(delta)
	_update_hands(delta)

func _update_legs(delta: float) -> void:
	for name in _legs:
		var leg: Dictionary = _legs[name]
		var side: float = leg["side"]
		var hip := Vector3(HIP.x + side * 0.105, HIP.y - 0.025, HIP.z - 0.03)
		var pedal := 0.0
		if name == "Right":
			pedal = car.driving.throttle * 0.025 - car.driving.brake * 0.035
		else:
			pedal = -sin(clampf(car.powertrain.shift_age / 0.38, 0, 1) * PI) * 0.035
		var ankle := Vector3(HIP.x + side * 0.12, 0.16 + pedal, -0.43)
		var knee := _solve_elbow(hip, ankle, 0.43, 0.40, hip + Vector3(0, 0.12, -0.45))
		_segment(leg["thigh"], hip, knee)
		_segment(leg["shin"], knee, ankle)
		leg["knee"].position = knee
		leg["knee_cap"].position = knee + Vector3(0, 0.015, -0.045)
		leg["foot"].position = ankle + Vector3(0, -0.035, -0.075)
		leg["foot"].rotation.x = -0.22 + pedal * 2.0
		leg["sole"].position = leg["foot"].position + Vector3(0, -0.037, 0)
		leg["sole"].rotation.x = leg["foot"].rotation.x

func _update_hands(delta: float) -> void:
	var wheel_basis: Basis = car.cockpit.wheel_pivot.global_basis
	var left_target := to_local(left_anchor.global_position)
	var wheel_right := to_local(right_anchor.global_position)
	var shift_t := clampf(car.cockpit.shift_age / 0.72, 0, 1)
	var shifting := shift_t < 1.0
	_shift_blend = move_toward(_shift_blend, 1.0 if shifting else 0.0, delta * 9.0)
	_brake_blend = move_toward(_brake_blend, 1.0 if car.driving.handbrake > 0.05 and not shifting else 0.0, delta * 7.0)
	_horn_blend = move_toward(_horn_blend, 1.0 if car.driving.horn and not shifting and _brake_blend < 0.1 else 0.0, delta * 8.0)
	var target := wheel_right
	var hand_basis := wheel_basis * _grip_basis(1.0)
	if _shift_blend > 0.01:
		var reach := smoothstep(0.0, 0.24, shift_t) * (1.0 - smoothstep(0.68, 1.0, shift_t))
		var knob := to_local(car.cockpit.gear_knob_position()) + Vector3(0, 0.025, 0)
		target = target.lerp(knob, reach * _shift_blend)
		hand_basis = hand_basis.slerp(Basis(Vector3.RIGHT, -0.8), reach * _shift_blend)
		hand_action = &"shift" if reach > 0.2 else &"steering"
	elif _brake_blend > 0.01:
		target = target.lerp(to_local(car.cockpit.handbrake_grip_position()), _brake_blend)
		hand_basis = hand_basis.slerp(Basis(Vector3.RIGHT, -1.1), _brake_blend)
		hand_action = &"handbrake"
	elif _horn_blend > 0.01:
		target = target.lerp(to_local(car.cockpit.horn_position()) + Vector3(0, 0.025, 0), _horn_blend)
		hand_basis = hand_basis.slerp(wheel_basis, _horn_blend)
		hand_action = &"horn"
	else:
		hand_action = &"steering"
	if not _right_initialized:
		_right_target = target
		_right_initialized = true
	_right_target = _right_target.lerp(target, 1.0 - exp(-delta * 24.0))
	_place_arm("Left", left_target, wheel_basis * _grip_basis(-1.0))
	_place_arm("Right", _right_target, hand_basis)
	left_hand.position = left_target
	left_hand.basis = to_global_transform_basis(wheel_basis * _grip_basis(-1.0))
	right_hand.position = _right_target
	right_hand.basis = to_global_transform_basis(hand_basis)
	var curl := maxf(_shift_blend, maxf(_brake_blend, _horn_blend * 0.5))
	for finger in right_fingers:
		finger.rotation.x = lerpf(finger.rotation.x, -0.18 - curl * 0.35, 0.2)

func to_global_transform_basis(basis: Basis) -> Basis:
	return global_basis.inverse() * basis

func _grip_basis(side: float) -> Basis:
	# Local -Z points toward the wheel center; four fingers curl over the rim.
	var z := Vector3(side, 0, 0)
	var x := Vector3.UP.cross(z)
	return Basis(x, Vector3.UP, z).orthonormalized()

func _place_arm(name: String, target: Vector3, _basis: Basis) -> void:
	var arm: Dictionary = _arms[name]
	var side: float = arm["side"]
	var shoulder := to_local(torso.to_global(Vector3(side * 0.205, 0.36, -0.18)))
	var pole := shoulder + Vector3(side * 0.20, -0.30, 0.10)
	var elbow := _solve_elbow(shoulder, target, 0.315, 0.295, pole)
	_segment(arm["upper"], shoulder, elbow)
	_segment(arm["lower"], elbow, target)
	arm["elbow"].position = elbow
	arm["elbow_cap"].position = elbow + Vector3(side * 0.018, -0.012, 0)
	arm["upper_plate"].position = shoulder.lerp(elbow, 0.48) + Vector3(0, 0, -0.025)
	arm["upper_plate"].quaternion = Quaternion(Vector3.UP, (elbow - shoulder).normalized())
	arm["lower_plate"].position = elbow.lerp(target, 0.50) + Vector3(0, 0.018, 0)
	arm["lower_plate"].quaternion = Quaternion(Vector3.UP, (target - elbow).normalized())
	Geo.set_rod(arm["piston"], shoulder.lerp(elbow, 0.25) + Vector3(side * 0.035, 0, 0), elbow.lerp(target, 0.30) + Vector3(side * 0.03, 0, 0))

func _segment(node: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	node.position = (a + b) * 0.5
	if a.distance_to(b) > 0.0001:
		node.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	var capsule := node.mesh as CapsuleMesh
	if capsule:
		capsule.height = maxf(a.distance_to(b), capsule.radius * 2.05)

func _solve_elbow(a: Vector3, b: Vector3, upper: float, lower: float, pole: Vector3) -> Vector3:
	var delta := b - a
	var distance := clampf(delta.length(), 0.025, upper + lower - 0.002)
	var direction := delta.normalized() if delta.length() > 0.001 else Vector3.FORWARD
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var height_squared := maxf(0.0, upper * upper - along * along)
	var bend := pole - a - direction * (pole - a).dot(direction)
	if bend.length_squared() < 0.0001:
		bend = Vector3.DOWN
	bend = bend.normalized()
	return a + direction * along + bend * sqrt(height_squared)
