extends Node
class_name InputRouter
## Pointer-ID ownership prevents a released steering finger from releasing the throttle.
## The same path handles real multitouch and Godot's mouse-to-touch emulation.
var driving: DrivingInput
var camera: Camera3D
var enabled := true
var controls: Array[Dictionary] = []
var fingers: Dictionary = {}
var gear_candidate := 0
var gear_candidate_time := 0.0
var gear_finger := -1
var steer_pixels := 150.0
var keyboard_enabled := true
var touch_values := {"throttle": 0.0, "brake": 0.0, "handbrake": 0.0, "horn": 0.0, "steer": 0.0}

func register_control(id: StringName, rect_provider: Callable) -> void:
	controls.append({"id": id, "rect": rect_provider})

func _process(delta: float) -> void:
	if not is_instance_valid(driving):
		return
	if not enabled:
		return
	var key_throttle := 0.0
	var key_brake := 0.0
	var key_steer := 0.0
	if keyboard_enabled and not OS.has_feature("android"):
		key_throttle = float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
		key_brake = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
		key_steer = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	driving.throttle = maxf(float(touch_values["throttle"]), key_throttle)
	driving.brake = maxf(float(touch_values["brake"]), key_brake)
	driving.handbrake = maxf(float(touch_values["handbrake"]), float(Input.is_physical_key_pressed(KEY_SPACE) and keyboard_enabled))
	driving.horn = float(touch_values["horn"]) > 0 or (Input.is_physical_key_pressed(KEY_H) and keyboard_enabled)
	driving.steer_target = clampf(float(touch_values["steer"]) + key_steer, -1, 1)
	if gear_finger >= 0:
		gear_candidate_time += delta
		if gear_candidate_time > 0.09 and gear_candidate != driving.current_gear:
			driving.request_gear(gear_candidate)
			gear_candidate_time = -0.4

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		drag(event.index, event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_6:
			driving.request_gear(event.physical_keycode - KEY_0)
		elif event.physical_keycode == KEY_R:
			driving.request_gear(-1)
		elif event.physical_keycode == KEY_N:
			driving.request_gear(0)
		elif event.physical_keycode == KEY_ESCAPE:
			driving.control_pressed.emit(&"pause")
		elif event.physical_keycode == KEY_C:
			driving.reset_look()

func hit_control(point: Vector2) -> StringName:
	for i in range(controls.size() - 1, -1, -1):
		var rect: Rect2 = controls[i]["rect"].call()
		if rect.has_point(point):
			return controls[i]["id"]
	return &""

func touch(index: int, point: Vector2, pressed: bool) -> void:
	if not pressed:
		release(index)
		return
	if not enabled or fingers.has(index):
		return
	var id := hit_control(point)
	var role := String(id)
	var start := point
	if id == &"":
		if _hits_steering_wheel(point):
			role = "steer"
		else:
			role = "look"
			driving.look_held = true
	fingers[index] = {"role": role, "start": start, "last": point}
	if role == "gear":
		gear_finger = index
		gear_candidate = _gate(point)
		gear_candidate_time = 0.0
	elif role == "steer":
		touch_values["steer"] = 0.0
	elif touch_values.has(role):
		touch_values[role] = 1.0
	elif role == "reverse":
		driving.request_gear(-1)
	elif id != &"":
		driving.control_pressed.emit(id)

func drag(index: int, point: Vector2) -> void:
	if not fingers.has(index) or not enabled:
		return
	var finger: Dictionary = fingers[index]
	var role: String = finger["role"]
	if role == "steer":
		touch_values["steer"] = clampf((point.x - float(finger["start"].x)) / steer_pixels, -1, 1)
	elif role == "look":
		var change: Vector2 = point - finger["last"]
		driving.look_yaw = clampf(driving.look_yaw - change.x * 0.004, -1.35, 1.35)
		driving.look_pitch = clampf(driving.look_pitch - change.y * 0.003, -1.05, 0.42)
	elif role == "gear":
		gear_candidate = _gate(point)
	finger["last"] = point

func release(index: int) -> void:
	if not fingers.has(index):
		return
	var role: String = fingers[index]["role"]
	fingers.erase(index)
	if role == "gear":
		if gear_candidate != driving.current_gear:
			driving.request_gear(gear_candidate)
		gear_finger = -1
		gear_candidate_time = 0.0
	elif role == "look":
		driving.look_held = driving.enabled and has_role("look")
	elif touch_values.has(role):
		touch_values[role] = 1.0 if has_role(role) else 0.0

func has_role(role: String) -> bool:
	for finger in fingers.values():
		if finger["role"] == role:
			return true
	return false

func cancel_all() -> void:
	fingers.clear()
	gear_finger = -1
	for key in touch_values:
		touch_values[key] = 0.0
	if is_instance_valid(driving):
		driving.clear_controls()

func _gate(point: Vector2) -> int:
	var rect := Rect2()
	for control in controls:
		if control["id"] == &"gear":
			rect = control["rect"].call()
			break
	if rect.size.x <= 0:
		return 0
	var p := (point - rect.position) / rect.size
	if absf(p.y - 0.5) < 0.14:
		return 0
	var columns := [0.14, 0.38, 0.62, 0.86]
	var nearest := 0
	for i in range(1, 4):
		if absf(p.x - columns[i]) < absf(p.x - columns[nearest]):
			nearest = i
	if absf(p.x - columns[nearest]) > 0.115:
		return driving.current_gear
	return ([1, 3, 5, -1][nearest] if p.y < 0.5 else [2, 4, 6, 0][nearest])

func _hits_steering_wheel(point: Vector2) -> bool:
	if not is_instance_valid(camera) or not camera.is_inside_tree():
		return false
	var world := camera.get_world_3d()
	if not is_instance_valid(world):
		return false
	var from := camera.project_ray_origin(point)
	var to := from + camera.project_ray_normal(point) * 2.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 4)
	return not world.direct_space_state.intersect_ray(query).is_empty()
