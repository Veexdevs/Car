extends Node
class_name DrivingInput
## Single source of truth shared by touch, keyboard, physics, UI and animation.
signal gear_requested(gear: int)
signal control_pressed(action: StringName)

var throttle := 0.0
var brake := 0.0
var steer_target := 0.0
var handbrake := 0.0
var horn := false
var look_yaw := 0.0
var look_pitch := 0.0
var look_held := false
var current_gear := 0
var enabled := true

func clear_controls() -> void:
	throttle = 0.0
	brake = 0.0
	steer_target = 0.0
	handbrake = 0.0
	horn = false
	look_held = false

func reset_look() -> void:
	look_yaw = 0.0
	look_pitch = 0.0

func request_gear(gear: int) -> void:
	if enabled and gear >= -1 and gear <= 6:
		gear_requested.emit(gear)
