extends Node
class_name RaceDirector
## Ordered, signed track progress: reversing cannot farm checkpoints; resets invalidate a lap.
signal lap_completed(lap_number: int, seconds: float, valid: bool)
signal toast(message: String)
var track: SerraTrack
var car: VehicleController
var timing := false
var lap_time := 0.0
var best_time := 0.0
var last_time := 0.0
var lap_number := 0
var completed_laps := 0
var valid_lap := true
var offroad_time := 0.0
var race_progress := -0.01
var session_time := 0.0
var _last_progress := 0.0
var _sample_tick := 0.0
var _save_path := "user://serra_rs_records.cfg"

func setup(circuit: SerraTrack, vehicle: VehicleController) -> void:
	track = circuit
	car = vehicle
	_load_best()
	invalidate_and_restart(false)

func _process(delta: float) -> void:
	if not is_instance_valid(car) or not is_instance_valid(track):
		return
	session_time += delta
	if timing:
		lap_time += delta
	_sample_tick += delta
	if _sample_tick < 0.05:
		return
	_sample_tick = 0
	var sample := track.nearest(car.global_position)
	car.update_surface(float(sample.distance) > 7.6)
	var progress: float = sample.progress
	var change := progress - _last_progress
	if change < -0.5:
		change += 1.0
	elif change > 0.5:
		change -= 1.0
	_last_progress = progress
	if absf(change) > 0.15:
		return
	race_progress += change
	if car.offroad and timing:
		offroad_time += 0.05
		if offroad_time > 1.2 and valid_lap:
			valid_lap = false
			toast.emit("VOLTA INVALIDADA — RETORNE À PISTA")
	if not timing and race_progress >= 0.0 and car.speed_kmh > 2.0:
		timing = true
		lap_time = 0.0
		race_progress = 0.0
		valid_lap = true
		offroad_time = 0.0
		lap_number += 1
		toast.emit("VOLTA %02d — CRONÔMETRO EM CURSO" % lap_number)
	elif timing and race_progress >= 1.0:
		_complete_lap()

func _complete_lap() -> void:
	last_time = lap_time
	completed_laps += 1
	var is_new_best := valid_lap and (best_time <= 0 or lap_time < best_time)
	if is_new_best:
		best_time = lap_time
		_save_best()
	lap_completed.emit(lap_number, lap_time, valid_lap)
	toast.emit(("NOVO RECORDE  " if is_new_best else "VOLTA COMPLETA  ") + format_time(lap_time) + ("  •  VÁLIDA" if valid_lap else "  •  INVÁLIDA"))
	timing = false
	race_progress = 0.0
	lap_time = 0.0
	valid_lap = true
	offroad_time = 0.0
	lap_number += 1
	timing = true

func invalidate_and_restart(announce := true) -> void:
	timing = false
	lap_time = 0.0
	race_progress = -12.0 / maxf(track.length_m, 1) if track else -0.01
	_last_progress = track.nearest(car.global_position).progress if track and car else 0.0
	valid_lap = true
	offroad_time = 0.0
	if announce:
		toast.emit("CARRO REPOSICIONADO — VOLTA REINICIADA")

func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load(_save_path) == OK:
		best_time = float(config.get_value("records", "serra_international", 0.0))

func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("records", "serra_international", best_time)
	config.save(_save_path)

static func format_time(seconds: float) -> String:
	if seconds <= 0:
		return "--:--.---"
	var minutes := int(seconds / 60.0)
	var remainder := seconds - minutes * 60.0
	return "%02d:%06.3f" % [minutes, remainder]
