extends RefCounted
class_name MotionSpring
## Critically damped, analytic spring. Stable at variable frame rates and under impacts.
var value := 0.0
var velocity := 0.0
var frequency := 2.5

func _init(hz: float = 2.5) -> void:
	frequency = hz

func step(target: float, delta: float) -> float:
	var omega := TAU * frequency
	var decay := exp(-omega * delta)
	var offset := value - target
	var temp := (velocity + omega * offset) * delta
	value = target + (offset + temp) * decay
	velocity = (velocity - omega * temp) * decay
	return value

func impulse(amount: float) -> void:
	velocity += amount

func reset() -> void:
	value = 0.0
	velocity = 0.0
