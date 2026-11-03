extends Node3D
class_name VehicleAudio
## RPM/load-driven engine layers and genuinely spatial mechanical feedback.
var car: VehicleController
var engine: AudioStreamPlayer3D
var engine_low: AudioStreamPlayer3D
var skid: AudioStreamPlayer3D
var wind: AudioStreamPlayer3D
var horn: AudioStreamPlayer3D
var shift: AudioStreamPlayer3D
var latch: AudioStreamPlayer3D
var impacts: Array[AudioStreamPlayer3D] = []
var _impact_index := 0
var _horn_was_down := false
var _brake_was_down := false
var _enabled := true

func setup(vehicle: VehicleController) -> void:
	car = vehicle
	engine = _loop("Engine", "res://Assets/Audio/engine.ogg", Vector3(0, 0.65, -1.25), -11.0)
	engine_low = _loop("EngineHarmonic", "res://Assets/Audio/engine.ogg", Vector3(0, 0.45, -0.8), -20.0)
	skid = _loop("TireScrub", "res://Assets/Audio/skid.ogg", Vector3(0, 0.20, 1.35), -60.0)
	wind = _loop("WindAndTrack", "res://Assets/Audio/wind.wav", Vector3(0, 1.0, 0), -32.0)
	wind.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	horn = _player("Horn", "res://Assets/Audio/horn.wav", Vector3(0, 0.75, -1.65), -9.0)
	shift = _player("GearEngagement", "res://Assets/Audio/shift.wav", Vector3(0.015, 0.65, 0.1), -8.0)
	latch = _player("HandbrakeLatch", "res://Assets/Audio/latch.wav", Vector3(0.1, 0.6, 0.38), -10.0)
	for i in range(3):
		var impact := _player("Impact" + str(i), "res://Assets/Audio/impact.ogg", Vector3(0, 0.5, -1.8), -5.0)
		impact.max_polyphony = 2
		impacts.append(impact)
	car.shifted.connect(_on_shift)
	car.impacted.connect(_on_impact)

func _player(name: String, path: String, pos: Vector3, volume: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = name
	player.stream = load(path)
	player.position = pos
	player.volume_db = volume
	player.max_distance = 35
	player.unit_size = 3.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(player)
	return player

func _loop(name: String, path: String, pos: Vector3, volume: float) -> AudioStreamPlayer3D:
	var player := _player(name, path, pos, volume)
	var stream := player.stream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	player.play()
	return player

func _process(delta: float) -> void:
	if not is_instance_valid(car) or not is_instance_valid(engine):
		return
	var rpm := car.powertrain.rpm
	var load := car.powertrain.throttle
	var pitch := 0.48 + rpm / 9000.0 * 1.62
	engine.pitch_scale = lerpf(engine.pitch_scale, pitch, 1.0 - exp(-delta * 10))
	engine_low.pitch_scale = engine.pitch_scale * 0.503
	engine.volume_db = lerpf(engine.volume_db, -13.0 + load * 5.0 + rpm / 9000.0 * 2.0, 0.12)
	engine_low.volume_db = engine.volume_db - 8.0
	var scrub := clampf(car.slip_amount * 1.5 + car.driving.handbrake * 0.5, 0, 1) if car.speed_kmh > 6 else 0.0
	skid.volume_db = lerpf(skid.volume_db, -48.0 + scrub * 43.0, 0.15)
	skid.pitch_scale = 0.85 + minf(car.speed_kmh / 180.0, 0.6)
	wind.volume_db = lerpf(wind.volume_db, -38.0 + minf(car.speed_kmh * 0.16, 28.0), 0.08)
	if car.driving.horn and not _horn_was_down:
		horn.play()
	elif not car.driving.horn and _horn_was_down:
		horn.stop()
	_horn_was_down = car.driving.horn
	var brake_down := car.driving.handbrake > 0.1
	if brake_down != _brake_was_down:
		latch.play()
	_brake_was_down = brake_down

func _on_shift(_gear: int) -> void:
	shift.pitch_scale = randf_range(0.94, 1.06)
	shift.play()

func _on_impact(strength: float) -> void:
	var player := impacts[_impact_index % impacts.size()]
	_impact_index += 1
	player.volume_db = -12.0 + strength * 12.0
	player.pitch_scale = randf_range(0.8, 1.15)
	player.play()

func set_active(active: bool) -> void:
	_enabled = active
	for player in [engine, engine_low, skid, wind]:
		if is_instance_valid(player):
			player.stream_paused = not active
	if not active and is_instance_valid(horn):
		horn.stop()
