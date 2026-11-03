extends Node3D
## Composition root. Systems remain separate and communicate through typed references/signals.
var driving: DrivingInput
var router: InputRouter
var track: SerraTrack
var car: VehicleController
var race: RaceDirector
var hud: RaceHUD
var sun: DirectionalLight3D
var environment: WorldEnvironment
var quality := 1
var motion := 1.0
var volume := 0.8
var _settings_path := "user://serra_rs_settings.cfg"

func _ready() -> void:
	_load_settings()
	driving = DrivingInput.new()
	driving.name = "DrivingInput"
	add_child(driving)
	router = InputRouter.new()
	router.name = "TouchRouter"
	router.driving = driving
	add_child(router)
	track = SerraTrack.new()
	track.name = "SerraInternational"
	add_child(track)
	car = preload("res://Scenes/Vehicle.tscn").instantiate()
	car.name = "RS01"
	car.driving = driving
	car.track = track
	add_child(car)
	car.reset_vehicle(track.spawn_transform())
	race = RaceDirector.new()
	race.name = "RaceDirector"
	add_child(race)
	race.setup(track, car)
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	canvas.layer = 10
	add_child(canvas)
	hud = preload("res://UI/HUD.tscn").instantiate()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.setup(self, router)
	router.camera = car.driver.camera
	driving.control_pressed.connect(_on_control)
	race.toast.connect(hud.show_toast)
	_build_environment()
	apply_quality(quality)
	set_motion(motion)
	set_volume(volume)
	hud.quality_option.select(quality)
	hud.motion_slider.value = motion
	hud.volume_slider.value = volume
	get_tree().auto_accept_quit = false

func _build_environment() -> void:
	environment = WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.20, 0.36, 0.53)
	sky_material.sky_horizon_color = Color(0.72, 0.78, 0.80)
	sky_material.ground_bottom_color = Color(0.24, 0.27, 0.24)
	sky_material.ground_horizon_color = Color(0.62, 0.67, 0.66)
	sky_material.sun_angle_max = 4.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.48
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.69, 0.72)
	env.fog_density = 0.00065
	environment.environment = env
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 150
	sun.shadow_bias = 0.045
	sun.shadow_normal_bias = 1.2
	add_child(sun)

func _on_control(action: StringName) -> void:
	if action == &"pause":
		set_paused(not get_tree().paused)
	elif action == &"recenter":
		driving.reset_look()
		hud.show_toast("OLHAR CENTRALIZADO")

func set_paused(value: bool) -> void:
	get_tree().paused = value
	router.enabled = not value
	driving.enabled = not value
	router.cancel_all()
	hud.set_paused(value)
	car.sound.set_active(not value)

func reset_car() -> void:
	car.reset_vehicle(track.spawn_transform())
	race.invalidate_and_restart()
	router.cancel_all()

func restart_session() -> void:
	reset_car()
	race.lap_number = 0
	race.completed_laps = 0
	race.session_time = 0.0
	set_paused(false)
	hud.show_toast("NOVA SESSÃO — CRUZE A LINHA PARA INICIAR A VOLTA")

func apply_quality(level: int) -> void:
	quality = clampi(level, 0, 2)
	if is_instance_valid(sun):
		sun.shadow_enabled = quality > 0
		sun.directional_shadow_max_distance = [0, 130, 210][quality]
	if is_instance_valid(car):
		car.cockpit.mirrors.set_quality(quality)
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if quality == 0 else Viewport.MSAA_2X
	get_viewport().scaling_3d_scale = [0.72, 0.85, 1.0][quality]
	_save_settings()

func set_motion(value: float) -> void:
	motion = value
	if is_instance_valid(car):
		car.driver.motion_scale = value
	_save_settings()

func set_volume(value: float) -> void:
	volume = value
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.0001)))
	_save_settings()

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(_settings_path) == OK:
		quality = int(config.get_value("graphics", "quality", 1))
		motion = float(config.get_value("comfort", "motion", 1.0))
		volume = float(config.get_value("audio", "volume", 0.8))

func _save_settings() -> void:
	if not is_instance_valid(hud):
		return
	var config := ConfigFile.new()
	config.set_value("graphics", "quality", quality)
	config.set_value("comfort", "motion", motion)
	config.set_value("audio", "volume", volume)
	config.save(_settings_path)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(hud):
			set_paused(not get_tree().paused)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_instance_valid(hud) and OS.has_feature("android"):
			set_paused(true)
