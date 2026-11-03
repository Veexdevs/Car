extends RefCounted
class_name Powertrain
## Deterministic, unit-testable engine + clutch + six-speed manual transmission.
## Speeds are signed m/s along the vehicle's forward axis. Force is newtons at rear tires.
const RATIOS := [3.10, 2.20, 1.65, 1.30, 1.05, 0.86]
const FINAL_DRIVE := 3.44
const REVERSE_RATIO := 3.30
const WHEEL_RADIUS := 0.34
const IDLE := 950.0
const LIMITER := 9000.0
const MAX_TORQUE := 470.0

var gear := 0
var rpm := IDLE
var throttle := 0.0
var clutch := 1.0
var shift_timer := 0.0
var shift_age := 10.0
var limiter_active := false
var engine_brake_force := 0.0
var last_shift_valid := false
var shift_message := ""

func ratio() -> float:
	if gear == -1:
		return -REVERSE_RATIO
	if gear == 0:
		return 0.0
	return RATIOS[gear - 1] * FINAL_DRIVE

func gear_label() -> String:
	return "R" if gear == -1 else ("N" if gear == 0 else str(gear))

func request_shift(next_gear: int, signed_speed: float, brake: float) -> bool:
	last_shift_valid = false
	shift_message = ""
	if next_gear < -1 or next_gear > 6 or next_gear == gear:
		return false
	if next_gear == -1 and (signed_speed > 0.7 or brake < 0.15):
		shift_message = "PARE E PRESSIONE O FREIO PARA ENGATAR RÉ"
		return false
	if next_gear > 0 and signed_speed < -0.7:
		shift_message = "PARE ANTES DE ENGATAR UMA MARCHA À FRENTE"
		return false
	# A short automatic clutch lift makes mobile H-shifts usable without a clutch pedal.
	gear = next_gear
	shift_timer = 0.38
	shift_age = 0.0
	clutch = 0.0
	last_shift_valid = true
	shift_message = "RÉ ENGATADA" if gear == -1 else ("PONTO MORTO" if gear == 0 else "MARCHA " + str(gear))
	return true

func torque_at(engine_rpm: float) -> float:
	# Naturally aspirated V8 approximation: low-rpm tractability, peak at 6500 rpm.
	if engine_rpm <= 3000:
		return lerpf(235, 365, clampf((engine_rpm - 950) / 2050.0, 0, 1))
	if engine_rpm <= 6500:
		return lerpf(365, 470, (engine_rpm - 3000) / 3500.0)
	return lerpf(470, 390, clampf((engine_rpm - 6500) / 2500.0, 0, 1))

func step(delta: float, accelerator: float, signed_speed: float) -> float:
	throttle = clampf(accelerator, 0, 1)
	shift_timer = maxf(0, shift_timer - delta)
	shift_age += delta
	clutch = move_toward(clutch, 1.0 if shift_timer <= 0 else 0.0, delta * 5.0)
	var coupled := absf(signed_speed) / WHEEL_RADIUS * absf(ratio()) * 60.0 / TAU
	var coupling := clutch
	if gear != 0:
		# Standing starts slip the clutch; they do not command an impossible engine speed.
		coupling *= smoothstep(0.3, 4.5, absf(signed_speed))
	var free_rpm := lerpf(IDLE, LIMITER - 250.0, throttle)
	var target := lerpf(free_rpm, maxf(IDLE, coupled), coupling)
	if gear == 0:
		target = free_rpm
	rpm = lerpf(rpm, clampf(target, IDLE - 80, LIMITER + 150), 1.0 - exp(-delta * 12.0))
	limiter_active = rpm > LIMITER - 120
	engine_brake_force = 0.0
	if gear == 0 or clutch < 0.05 or limiter_active:
		return 0.0
	var direction := signf(ratio())
	var moving_against_engine := signed_speed * direction < -0.5
	if throttle < 0.03 and absf(signed_speed) > 0.8:
		engine_brake_force = minf(650.0, rpm * 0.075 * absf(ratio())) * clutch
	if moving_against_engine:
		return 0.0
	var torque := torque_at(rpm) * throttle * ratio() * 0.91 / WHEEL_RADIUS
	# Smooth, physical speed ceiling in sixth, rather than an abrupt velocity clamp.
	var top_speed := 82.0 if gear != -1 else 12.0
	torque *= 1.0 - smoothstep(top_speed - 5.0, top_speed, absf(signed_speed))
	return torque * clutch

func reset() -> void:
	gear = 0
	rpm = IDLE
	clutch = 1.0
	shift_timer = 0.0
	shift_age = 10.0
	limiter_active = false
