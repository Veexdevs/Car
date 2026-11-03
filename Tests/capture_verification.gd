extends SceneTree
## Software-rendered verification captures. Run under Xvfb with gl_compatibility.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var main := load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	main.apply_quality(1)
	for i in range(90):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/verification")
	root.get_texture().get_image().save_png("res://docs/verification/cockpit.png")
	main.driving.look_pitch = -0.82
	main.driving.look_yaw = 0.18
	main.car.driver.update_pose(0.5)
	for i in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/verification/pilot_body.png")
	print("Verification captures saved.")
	quit(0)
