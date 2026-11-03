extends Node3D
class_name SerraTrack
## Original closed circuit. One collision mesh for the road, batched scenery, no runtime downloads.
const HALF_WIDTH := 7.0
const SAMPLES_PER_LEG := 24
var points := PackedVector3Array()
var tangents := PackedVector3Array()
var cumulative := PackedFloat32Array()
var length_m := 0.0
var map_bounds := Rect2()
var _last_hint := 0
var _road_body: StaticBody3D

func _ready() -> void:
	_build_curve()
	_build_terrain()
	_build_road()
	_build_barriers()
	_build_pit_complex()
	_build_vegetation()
	_build_distance_boards()

func _build_curve() -> void:
	var controls := PackedVector3Array([
		Vector3(0, 0, 0), Vector3(0, 0, -150), Vector3(45, 0, -245),
		Vector3(145, 0, -270), Vector3(235, 0, -215), Vector3(260, 0, -120),
		Vector3(215, 0, -55), Vector3(250, 0, 35), Vector3(205, 0, 125),
		Vector3(105, 0, 155), Vector3(25, 0, 115), Vector3(-65, 0, 150),
		Vector3(-155, 0, 90), Vector3(-170, 0, -10), Vector3(-110, 0, -70), Vector3(-45, 0, -40)
	])
	var count := controls.size()
	for i in range(count):
		var p0 := controls[(i - 1 + count) % count]
		var p1 := controls[i]
		var p2 := controls[(i + 1) % count]
		var p3 := controls[(i + 2) % count]
		for j in range(SAMPLES_PER_LEG):
			var t := float(j) / SAMPLES_PER_LEG
			var point := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0*p0 - 5.0*p1 + 4.0*p2 - p3)*t*t + (-p0 + 3.0*p1 - 3.0*p2 + p3)*t*t*t)
			points.append(point)
	for i in range(points.size()):
		var tangent := (points[(i + 1) % points.size()] - points[(i - 1 + points.size()) % points.size()]).normalized()
		tangents.append(tangent)
		if i > 0:
			length_m += points[i].distance_to(points[i - 1])
		cumulative.append(length_m)
		map_bounds = map_bounds.expand(points[i])
	length_m += points[-1].distance_to(points[0])
	map_bounds = map_bounds.grow(20)

func _flat_material(color: Color, roughness := 0.9) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv_scale := 4.0) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for vertex in [a, b, c, a, c, d]:
		st.set_normal(normal)
		st.set_uv(Vector2(vertex.x / uv_scale, vertex.z / uv_scale))
		st.add_vertex(vertex)

func _commit(st: SurfaceTool, parent: Node3D, name: String, mat: Material, collision := false) -> MeshInstance3D:
	st.index()
	var instance := Geo.mesh(parent, name, st.commit(), Vector3.ZERO, mat)
	if collision:
		var body := StaticBody3D.new()
		body.name = name + "Collision"
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		shape.shape = instance.mesh.create_trimesh_shape()
		body.add_child(shape)
		add_child(body)
	return instance

func _build_terrain() -> void:
	var ground := Geo.box(self, "Ground", Vector3(30, -0.22, -50), Vector3(1400, 0.4, 1400), _flat_material(Color(0.22, 0.29, 0.16)))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1400, 0.4, 1400)
	shape.shape = box
	shape.position = Vector3(30, -0.22, -50)
	body.add_child(shape)
	add_child(body)
	# Distant hills hide the finite ground edge without expensive volumetrics.
	var hill_mat := _flat_material(Color(0.28, 0.34, 0.29))
	for i in range(18):
		var angle := float(i) / 18.0 * TAU
		var pos := Vector3(40 + cos(angle) * 610, -22, -50 + sin(angle) * 610)
		var hill := Geo.sphere(self, "DistantHill", pos, Vector3(randf_range(95, 170), randf_range(45, 95), randf_range(95, 170)), hill_mat)
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_road() -> void:
	var runoff := SurfaceTool.new()
	runoff.begin(Mesh.PRIMITIVE_TRIANGLES)
	var road := SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge := SurfaceTool.new()
	edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curb_red := SurfaceTool.new()
	curb_red.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curb_white := SurfaceTool.new()
	curb_white.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := points.size()
	for i in range(n):
		var j := (i + 1) % n
		var r0 := tangents[i].cross(Vector3.UP).normalized()
		var r1 := tangents[j].cross(Vector3.UP).normalized()
		var p := points[i]
		var q := points[j]
		_quad(runoff, p-r0*11.3+Vector3.DOWN*.015, q-r1*11.3+Vector3.DOWN*.015, q+r1*11.3+Vector3.DOWN*.015, p+r0*11.3+Vector3.DOWN*.015)
		_quad(road, p-r0*HALF_WIDTH, q-r1*HALF_WIDTH, q+r1*HALF_WIDTH, p+r0*HALF_WIDTH)
		for side in [-1.0, 1.0]:
			var a := p + r0 * side * (HALF_WIDTH - 0.18) + Vector3.UP * 0.012
			var b := q + r1 * side * (HALF_WIDTH - 0.18) + Vector3.UP * 0.012
			var c := q + r1 * side * (HALF_WIDTH + 0.02) + Vector3.UP * 0.012
			var d := p + r0 * side * (HALF_WIDTH + 0.02) + Vector3.UP * 0.012
			_quad(edge, a, b, c, d)
			var ca := p + r0 * side * HALF_WIDTH + Vector3.UP * 0.018
			var cb := q + r1 * side * HALF_WIDTH + Vector3.UP * 0.018
			var cc := q + r1 * side * (HALF_WIDTH + 0.85) + Vector3.UP * 0.045
			var cd := p + r0 * side * (HALF_WIDTH + 0.85) + Vector3.UP * 0.045
			_quad(curb_red if i % 2 == 0 else curb_white, ca, cb, cc, cd)
	_commit(runoff, self, "Runoff", _flat_material(Color(0.16, 0.17, 0.17)), true)
	_commit(road, self, "Asphalt", Geo.material("res://Assets/Materials/asphalt.tres"), true)
	_commit(edge, self, "WhiteLines", _flat_material(Color(0.83, 0.84, 0.80)))
	_commit(curb_red, self, "CurbsRed", _flat_material(Color(0.60, 0.075, 0.045)))
	_commit(curb_white, self, "CurbsWhite", _flat_material(Color(0.82, 0.82, 0.77)))
	_build_start_grid()

func _build_start_grid() -> void:
	var origin := points[0]
	var forward := tangents[0]
	var right := forward.cross(Vector3.UP)
	var white := _flat_material(Color(0.88, 0.88, 0.83))
	var dark := _flat_material(Color(0.035, 0.04, 0.045))
	for row in range(2):
		for col in range(14):
			var pos := origin + forward * (row * 0.5) + right * (col - 6.5)
			var tile := Geo.box(self, "StartTile", pos + Vector3.UP * 0.018, Vector3(1.0, 0.008, 0.5), white if (row + col) % 2 == 0 else dark)
			tile.basis = Basis.looking_at(forward, Vector3.UP)
	for i in range(8):
		var pos := origin - forward * (8.0 + i * 7.0) + right * (-3.2 if i % 2 == 0 else 3.2)
		var slot := Geo.box(self, "GridSlot", pos + Vector3.UP * 0.015, Vector3(2.3, 0.008, 0.12), white)
		slot.basis = Basis.looking_at(forward, Vector3.UP)
	var gantry := Node3D.new()
	gantry.name = "StartGantry"
	gantry.position = origin
	gantry.basis = Basis.looking_at(forward, Vector3.UP)
	add_child(gantry)
	var metal := Geo.material("res://Assets/Materials/dark_metal.tres")
	Geo.box(gantry, "PostL", Vector3(-9, 3, 0), Vector3(0.35, 6, 0.35), metal)
	Geo.box(gantry, "PostR", Vector3(9, 3, 0), Vector3(0.35, 6, 0.35), metal)
	Geo.box(gantry, "Beam", Vector3(0, 5.8, 0), Vector3(18.5, 0.45, 0.45), metal)
	var banner_mat := StandardMaterial3D.new()
	banner_mat.albedo_texture = load("res://Assets/Textures/banner.png")
	banner_mat.roughness = 0.8
	Geo.box(gantry, "Banner", Vector3(0, 5.25, 0.05), Vector3(16, 1.15, 0.08), banner_mat)
	var title := Geo.label(gantry, "CircuitName", "SERRA  INTERNATIONAL", Vector3(0, 5.28, 0.11), 0.011, Color(0.95, 0.95, 0.91))

func _build_barriers() -> void:
	var rail := SurfaceTool.new()
	rail.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := _flat_material(Color(0.55, 0.58, 0.58), 0.48)
	mat.metallic = 0.65
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := StaticBody3D.new()
	body.name = "BarrierCollision"
	body.collision_layer = 1
	add_child(body)
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.12, 0.9, 0.14)
	var posts := MultiMesh.new()
	posts.transform_format = MultiMesh.TRANSFORM_3D
	posts.mesh = post_mesh
	posts.instance_count = points.size() * 2
	var index := 0
	for i in range(points.size()):
		var j := (i + 1) % points.size()
		for side in [-1.0, 1.0]:
			var r0 := tangents[i].cross(Vector3.UP)
			var r1 := tangents[j].cross(Vector3.UP)
			var a := points[i] + r0 * side * 11.6
			var b := points[j] + r1 * side * 11.6
			_quad(rail, a + Vector3.UP*.42, b + Vector3.UP*.42, b + Vector3.UP*.86, a + Vector3.UP*.86)
			var mid := (a + b) * 0.5
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(0.25, 0.95, a.distance_to(b) + 0.15)
			shape.shape = box
			shape.position = mid + Vector3.UP * 0.48
			shape.basis = Basis.looking_at((b - a).normalized(), Vector3.UP)
			body.add_child(shape)
			posts.set_instance_transform(index, Transform3D(Basis.looking_at(tangents[i], Vector3.UP), a + Vector3.UP*.45))
			index += 1
	_commit(rail, self, "Armco", mat)
	var post_instance := MultiMeshInstance3D.new()
	post_instance.name = "BarrierPosts"
	post_instance.multimesh = posts
	post_instance.material_override = Geo.material("res://Assets/Materials/dark_metal.tres")
	add_child(post_instance)

func _build_pit_complex() -> void:
	var concrete := _flat_material(Color(0.47, 0.48, 0.46))
	var glass := _flat_material(Color(0.10, 0.17, 0.20), 0.18)
	glass.metallic = 0.55
	var roof := Geo.material("res://Assets/Materials/dark_metal.tres")
	var building := Node3D.new()
	building.name = "PitBuilding"
	building.position = Vector3(24, 0, -55)
	add_child(building)
	Geo.box(building, "PitBlock", Vector3(0, 2.4, 0), Vector3(12, 4.8, 90), concrete)
	Geo.box(building, "PitRoof", Vector3(0, 5.0, 0), Vector3(14, 0.35, 94), roof)
	for i in range(12):
		var z := -40.0 + i * 7.2
		Geo.box(building, "GarageDoor", Vector3(-6.05, 1.5, z), Vector3(0.1, 2.7, 5.5), roof)
		Geo.box(building, "HospitalityGlass", Vector3(-6.08, 3.8, z), Vector3(0.1, 1.35, 6.0), glass)
		Geo.box(building, "PitNumber", Vector3(-6.13, 2.95, z), Vector3(0.05, 0.25, 1.0), Geo.material("res://Assets/Materials/orange.tres"))
	var stand := Node3D.new()
	stand.name = "Grandstand"
	stand.position = Vector3(-25, 0, -55)
	add_child(stand)
	for tier in range(6):
		Geo.box(stand, "Terrace", Vector3(-tier * 1.4, 0.45 + tier * 0.65, 0), Vector3(1.5, 0.5 + tier * 0.1, 78), concrete)
	Geo.box(stand, "StandRoof", Vector3(-4, 6.2, 0), Vector3(13, 0.25, 82), roof)
	for z in [-38, -19, 0, 19, 38]:
		Geo.rod(stand, "RoofColumn", Vector3(-9, 0, z), Vector3(-9, 6.2, z), 0.12, roof)
	var seat_mesh := BoxMesh.new()
	seat_mesh.size = Vector3(0.5, 0.55, 0.5)
	var seats := MultiMesh.new()
	seats.transform_format = MultiMesh.TRANSFORM_3D
	seats.mesh = seat_mesh
	seats.instance_count = 6 * 100
	var seat_mat := _flat_material(Color(0.16, 0.19, 0.20))
	var idx := 0
	for tier in range(6):
		for s in range(100):
			seats.set_instance_transform(idx, Transform3D(Basis.IDENTITY, Vector3(-25 - tier*1.4, 1.0 + tier*.65, -93 + s*.77)))
			idx += 1
	var seat_instance := MultiMeshInstance3D.new()
	seat_instance.multimesh = seats
	seat_instance.material_override = seat_mat
	add_child(seat_instance)

func _build_vegetation() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.3
	trunk_mesh.height = 3.5
	trunk_mesh.radial_segments = 6
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 1
	canopy_mesh.height = 2
	canopy_mesh.radial_segments = 8
	canopy_mesh.rings = 5
	var count := 260
	var trunks := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.mesh = trunk_mesh
	trunks.instance_count = count
	var crowns := MultiMesh.new()
	crowns.transform_format = MultiMesh.TRANSFORM_3D
	crowns.mesh = canopy_mesh
	crowns.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 45801
	var placed := 0
	var attempts := 0
	while placed < count and attempts < 4000:
		attempts += 1
		var pos := Vector3(rng.randf_range(-330, 420), 0, rng.randf_range(-430, 320))
		if nearest(pos).distance < 18:
			continue
		var scale := rng.randf_range(2.5, 5.5)
		trunks.set_instance_transform(placed, Transform3D(Basis.IDENTITY.scaled(Vector3(1, scale/3.5, 1)), pos + Vector3.UP * 1.75))
		crowns.set_instance_transform(placed, Transform3D(Basis.IDENTITY.scaled(Vector3(scale, scale*1.25, scale)), pos + Vector3.UP * (3.5 + scale*.6)))
		placed += 1
	trunks.instance_count = placed
	crowns.instance_count = placed
	var trunk_instance := MultiMeshInstance3D.new()
	trunk_instance.multimesh = trunks
	trunk_instance.material_override = _flat_material(Color(0.22, 0.17, 0.12))
	add_child(trunk_instance)
	var crown_instance := MultiMeshInstance3D.new()
	crown_instance.multimesh = crowns
	crown_instance.material_override = _flat_material(Color(0.12, 0.23, 0.13))
	add_child(crown_instance)

func _build_distance_boards() -> void:
	for fraction in [0.08, 0.22, 0.39, 0.57, 0.74, 0.90]:
		var at := point_at(fraction)
		var right := tangent_at(fraction).cross(Vector3.UP)
		for side in [-1.0, 1.0]:
			var pos := at + right * side * 9.3
			var board := Geo.box(self, "BrakeBoard", pos + Vector3.UP * 1.1, Vector3(1.1, 0.7, 0.08), _flat_material(Color(0.9, 0.88, 0.8)))
			board.basis = Basis.looking_at(tangent_at(fraction), Vector3.UP)
			var label := Geo.label(self, "Distance", "100", pos + Vector3.UP * 1.1 - tangent_at(fraction)*0.06, 0.006, Color(0.08, 0.1, 0.11))
			label.basis = Basis.looking_at(tangent_at(fraction), Vector3.UP)

func nearest(pos: Vector3, hint := -1) -> Dictionary:
	var best_distance := INF
	var best_index := 0
	var best_t := 0.0
	var n := points.size()
	var start := 0
	var end := n
	if hint >= 0:
		start = hint - 14
		end = hint + 15
	for k in range(start, end):
		var i := (k % n + n) % n
		var a := points[i]
		var b := points[(i + 1) % n]
		var ab := b - a
		ab.y = 0
		var ap := pos - a
		ap.y = 0
		var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.001), 0, 1)
		var distance := ap.distance_squared_to(ab * t)
		if distance < best_distance:
			best_distance = distance
			best_index = i
			best_t = t
	if hint >= 0 and best_distance > 900:
		return nearest(pos, -1)
	var segment_length := points[best_index].distance_to(points[(best_index + 1) % n])
	var progress := (cumulative[best_index] + segment_length * best_t) / length_m
	return {"distance": sqrt(best_distance), "progress": fposmod(progress, 1.0), "index": best_index, "tangent": tangents[best_index]}

func point_at(fraction: float) -> Vector3:
	var index := int(fposmod(fraction, 1.0) * points.size())
	return points[index]

func tangent_at(fraction: float) -> Vector3:
	var index := int(fposmod(fraction, 1.0) * points.size())
	return tangents[index]

func spawn_transform(before_line_m := 12.0) -> Transform3D:
	var fraction := fposmod(1.0 - before_line_m / length_m, 1.0)
	var pos := point_at(fraction) + Vector3.UP * 0.08
	var forward := tangent_at(fraction)
	return Transform3D(Basis.looking_at(forward, Vector3.UP), pos)
