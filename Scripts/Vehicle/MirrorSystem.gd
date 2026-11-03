extends Node3D
class_name MirrorSystem
## Real, low-resolution rear-view render textures. Updates are staggered, not three full cameras every frame.
var entries: Array[Dictionary] = []
var frame := 0
var quality := 1
var vehicle: VehicleController

func setup(car: VehicleController) -> void:
	vehicle = car
	_make_mirror("CenterMirror", Vector3(0, 1.135, -0.28), Vector2(0.265, 0.075), 0.0, Vector2i(256, 80), 0)
	_make_mirror("LeftMirror", Vector3(-1.015, 0.86, -0.52), Vector2(0.16, 0.085), -0.22, Vector2i(160, 80), 1)
	_make_mirror("RightMirror", Vector3(1.015, 0.86, -0.52), Vector2(0.16, 0.085), 0.22, Vector2i(160, 80), 1)

func _make_mirror(name: String, pos: Vector3, size: Vector2, angle: float, resolution: Vector2i, tier: int) -> void:
	var housing := Geo.box(self, name + "Housing", pos + Vector3(0, 0, -0.012), Vector3(size.x + 0.022, size.y + 0.018, 0.032), Geo.material("res://Assets/Materials/carbon.tres"))
	housing.rotation.y = angle
	var viewport := SubViewport.new()
	viewport.name = name + "Viewport"
	viewport.size = resolution
	viewport.own_world_3d = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(viewport)
	var camera := Camera3D.new()
	camera.name = name + "Camera"
	camera.position = pos + Vector3(0, 0, 0.02)
	camera.rotation.y = PI + angle
	camera.fov = 58
	camera.near = 0.15
	camera.far = 350
	camera.cull_mask = 1
	camera.current = false
	viewport.add_child(camera)
	var screen := QuadMesh.new()
	screen.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = viewport.get_texture()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := Geo.mesh(self, name + "Glass", screen, pos + Vector3(0, 0, 0.008), mat)
	instance.rotation.y = angle
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	entries.append({"viewport": viewport, "tier": tier, "offset": entries.size() * 2})

func _process(_delta: float) -> void:
	frame += 1
	for entry in entries:
		var enabled: bool = quality > 0 or int(entry["tier"]) == 0
		entry["viewport"].render_target_update_mode = SubViewport.UPDATE_DISABLED
		if enabled and frame % (6 if quality >= 2 else 10) == int(entry["offset"]):
			entry["viewport"].render_target_update_mode = SubViewport.UPDATE_ONCE

func set_quality(level: int) -> void:
	quality = level
