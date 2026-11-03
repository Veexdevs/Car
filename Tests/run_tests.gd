extends SceneTree
## Run: godot --headless --path . --script Tests/run_tests.gd
var results: Array[Dictionary] = []
var main

func _initialize() -> void:
	call_deferred("_run")
	create_timer(100.0).timeout.connect(func(): _write_report(); quit(1))

func check(name: String, condition: bool, detail := "") -> void:
	results.append({"name": name, "pass": condition, "detail": detail})
	print(("PASS " if condition else "FAIL ") + name + (" — " + detail if detail != "" else ""))

func _run() -> void:
	main = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	if not is_instance_valid(main.car):
		check("Main scene instantiated", false, "vehicle missing")
		_write_report()
		quit(1)
		return
	var car: VehicleController = main.car
	var input: DrivingInput = main.driving
	var router: InputRouter = main.router
	check("Main scene / vehicle / camera", is_instance_valid(car) and car.driver.camera.current)
	check("Four suspension wheels", car.wheels.size() == 4)
	check("Track collision and closed spline", main.track.points.size() > 300 and main.track.length_m > 1000)
	var sample: Dictionary = main.track.nearest(main.track.points[10])
	check("Track nearest-point query", float(sample.distance) < 0.1)
	_test_powertrain()
	_test_touch(router, input, car)
	await _test_driving(car, input, router)
	await _test_driver(car, input, router)
	_test_pause()
	_write_report()
	quit(0 if failed_count() == 0 else 1)

func _test_powertrain() -> void:
	var p := Powertrain.new()
	p.step(0.016, 1.0, 0)
	check("Neutral revs without drive force", absf(p.step(0.016, 1.0, 0)) < 0.01 and p.rpm > 950)
	check("Reverse interlock requires stop + brake", not p.request_shift(-1, 8, 0) and p.gear == 0)
	check("First gear engages", p.request_shift(1, 0, 1) and p.gear == 1)
	var force := p.step(0.016, 1.0, 0)
	check("Clutch lifts during shift", force == 0)
	for i in range(60):
		force = p.step(1.0/60.0, 1.0, 2.0)
	check("First gear produces forward traction", force > 1000, str(int(force)) + " N")
	p.request_shift(-1, 0, 1)
	for i in range(60):
		force = p.step(1.0/60.0, 1.0, 0)
	check("Reverse produces negative traction", force < -1000)
	check("Six forward ratios + reverse + neutral", Powertrain.RATIOS.size() == 6 and p.ratio() < 0)
	p.reset()
	check("Reset returns to neutral", p.gear == 0 and p.rpm == Powertrain.IDLE)

func _test_touch(router: InputRouter, input: DrivingInput, car: VehicleController) -> void:
	router.cancel_all()
	var throttle: Rect2 = main.hud.control_rect(&"throttle")
	var brake: Rect2 = main.hud.control_rect(&"brake")
	var steer: Rect2 = main.hud.control_rect(&"steer")
	router.touch(1, throttle.get_center(), true)
	router.touch(2, brake.get_center(), true)
	router.touch(3, steer.get_center(), true)
	router.drag(3, steer.get_center() + Vector2(100, 0))
	router._process(0.016)
	check("Independent throttle + brake + steering fingers", input.throttle == 1 and input.brake == 1 and input.steer_target > 0.5)
	router.release(3)
	router._process(0.016)
	check("Steering release does not release pedals", input.steer_target == 0 and input.throttle == 1 and input.brake == 1)
	router.cancel_all()
	router._process(0.016)
	check("Focus loss clears every held control", input.throttle == 0 and input.brake == 0 and input.handbrake == 0 and not input.horn)
	var gear_rect: Rect2 = main.hud.control_rect(&"gear")
	car.powertrain.reset()
	car.signed_speed = 0
	input.current_gear = 0
	router.touch(4, gear_rect.position + gear_rect.size * Vector2(0.5, 0.5), true)
	router.drag(4, gear_rect.position + gear_rect.size * Vector2(0.14, 0.22))
	router._process(0.12)
	check("H-gate drag engages first", car.powertrain.gear == 1)
	router.release(4)
	router.cancel_all()

func _test_driving(car: VehicleController, input: DrivingInput, router: InputRouter) -> void:
	router.enabled = false
	router.cancel_all()
	car.reset_vehicle(main.track.spawn_transform())
	input.current_gear = 0
	input.request_gear(1)
	input.throttle = 1.0
	for i in range(210):
		await physics_frame
	var wheel_debug := []
	for w in car.wheels:
		wheel_debug.append({"force": w.engine_force, "brake": w.brake, "contact": w.is_in_contact(), "rpm": w.get_rpm(), "skid": w.get_skidinfo(), "normal": str(w.get_contact_normal()), "traction": w.use_as_traction})
	var debug := {"kmh": car.speed_kmh, "gear": car.powertrain.gear, "rpm": car.powertrain.rpm, "signed": car.signed_speed, "body_force": car.engine_force, "clutch": car.powertrain.clutch, "throttle": input.throttle, "freeze": car.freeze, "sleeping": car.sleeping, "pos": str(car.global_position), "vel": str(car.linear_velocity), "wheels": wheel_debug}
	check("Vehicle accelerates under real physics", car.speed_kmh > 18 and car.distance_m > 4, JSON.stringify(debug))
	check("Rear traction wheels receive engine force", absf(car.wheels[2].engine_force) > 100 and absf(car.wheels[3].engine_force) > 100, str([car.wheels[2].engine_force, car.wheels[3].engine_force]))
	check("Suspension remains in contact", car.grounded_wheels >= 3, str(car.grounded_wheels))
	input.steer_target = 0.8
	for i in range(45):
		await physics_frame
	check("Right steering yaws the chassis right", car.angular_velocity.y < -0.01, "%.3f rad/s" % car.angular_velocity.y)
	input.steer_target = 0
	var before := car.speed_kmh
	input.throttle = 0
	input.brake = 1
	for i in range(100):
		await physics_frame
	check("Service brake reduces speed", car.speed_kmh < before * 0.6, "%.1f -> %.1f" % [before, car.speed_kmh])
	input.handbrake = 1
	await physics_frame
	await physics_frame
	check("Handbrake loads rear wheels only", car.wheels[2].brake > car.wheels[0].brake and car.wheels[3].brake > car.wheels[1].brake)
	input.handbrake = 0
	input.brake = 1
	input.throttle = 0
	for i in range(160):
		await physics_frame
	input.request_gear(-1)
	check("Reverse engages after stopping with brake", car.powertrain.gear == -1)
	input.brake = 0
	input.throttle = 1
	for i in range(100):
		await physics_frame
	check("Reverse moves the vehicle backwards", car.signed_speed < -0.5, "%.2f m/s" % car.signed_speed)
	input.throttle = 0
	input.brake = 1
	router.enabled = true

func _test_driver(car: VehicleController, input: DrivingInput, router: InputRouter) -> void:
	router.enabled = false
	car.reset_vehicle(main.track.spawn_transform())
	input.request_gear(1)
	await physics_frame
	var driver: RobotDriver = car.driver
	var wheel_before: Quaternion = car.cockpit.wheel_pivot.quaternion
	input.steer_target = 0.8
	for i in range(30):
		await physics_frame
	check("Physical steering wheel follows input", not car.cockpit.wheel_pivot.quaternion.is_equal_approx(wheel_before))
	var grip: Vector3 = driver.right_anchor.global_position
	input.request_gear(2)
	for i in range(20):
		await physics_frame
	check("Shift animation reaches away from wheel", driver.hand_action == &"shift" and driver.right_hand.global_position.distance_to(grip) > 0.08)
	for i in range(65):
		await physics_frame
	check("Hand returns after shift", driver.hand_action == &"steering")
	input.horn = true
	for i in range(20):
		await physics_frame
	check("Horn has a hand action and audio player", driver.hand_action == &"horn" and is_instance_valid(car.sound.horn))
	input.horn = false
	input.handbrake = 1
	for i in range(25):
		await physics_frame
	check("Handbrake has a hand action", driver.hand_action == &"handbrake")
	input.handbrake = 0
	input.steer_target = 0
	input.look_pitch = -0.8
	for i in range(30):
		await physics_frame
	check("Pilot can look down at the body", driver.head.rotation.x < -0.5)
	check("Full body has individual finger chains", driver.left_fingers.size() == 5 and driver.right_fingers.size() == 5)
	input.reset_look()
	router.enabled = true

func _test_pause() -> void:
	main.set_paused(true)
	check("Pause freezes tree and releases controls", paused and not main.router.enabled and main.driving.throttle == 0)
	main.set_paused(false)
	check("Resume restores input", not paused and main.router.enabled)

func failed_count() -> int:
	var count := 0
	for result in results:
		if not result["pass"]:
			count += 1
	return count

func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/verification")
	var report := {"engine": Engine.get_version_info().string, "tests": results, "passed": results.size() - failed_count(), "failed": failed_count()}
	var file := FileAccess.open("res://docs/verification/test_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	var md := "# Verificação automática — Godot %s\n\n" % Engine.get_version_info().string
	md += "**%d/%d verificações aprovadas.**\n\n" % [results.size() - failed_count(), results.size()]
	md += "Executado no player Godot real, em Linux headless. Não substitui teste em aparelho Android físico.\n\n"
	md += "| Verificação | Resultado |\n|---|---|\n"
	for result in results:
		md += "| %s | %s |\n" % [result.name, "PASS" if result["pass"] else "FAIL"]
	var markdown := FileAccess.open("res://docs/verification/TEST_RESULTS.md", FileAccess.WRITE)
	markdown.store_string(md)
	print("RESULT: %d passed, %d failed" % [results.size() - failed_count(), failed_count()])
