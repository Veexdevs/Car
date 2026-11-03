extends RefCounted
class_name Geo
## Small mesh construction helpers. Dimensions are meters; vehicle forward is -Z.
static func material(path: String) -> StandardMaterial3D:
	return load(path) as StandardMaterial3D

static func mesh(parent: Node3D, name: String, resource: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = resource
	node.position = pos
	if mat:
		node.material_override = mat
	parent.add_child(node)
	return node

static func box(parent: Node3D, name: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var resource := BoxMesh.new()
	resource.size = size
	return mesh(parent, name, resource, pos, mat)

static func sphere(parent: Node3D, name: String, pos: Vector3, scale: Vector3, mat: Material) -> MeshInstance3D:
	var resource := SphereMesh.new()
	resource.radius = 1.0
	resource.height = 2.0
	resource.radial_segments = 20
	resource.rings = 12
	var node := mesh(parent, name, resource, pos, mat)
	node.scale = scale
	return node

static func rod(parent: Node3D, name: String, a: Vector3, b: Vector3, radius: float, mat: Material, segments: int = 12) -> MeshInstance3D:
	var resource := CylinderMesh.new()
	resource.top_radius = radius
	resource.bottom_radius = radius
	resource.height = maxf(a.distance_to(b), 0.001)
	resource.radial_segments = segments
	var node := mesh(parent, name, resource, (a + b) * 0.5, mat)
	if a.distance_to(b) > 0.0001:
		node.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return node

static func cylinder(parent: Node3D, name: String, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var resource := CylinderMesh.new()
	resource.top_radius = radius
	resource.bottom_radius = radius
	resource.height = height
	resource.radial_segments = 20
	return mesh(parent, name, resource, pos, mat)

static func capsule(parent: Node3D, name: String, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var resource := CapsuleMesh.new()
	resource.radius = radius
	resource.height = maxf(height, radius * 2.05)
	resource.radial_segments = 16
	resource.rings = 6
	return mesh(parent, name, resource, pos, mat)

static func label(parent: Node3D, name: String, text: String, pos: Vector3, pixel: float, color: Color) -> Label3D:
	var node := Label3D.new()
	node.name = name
	node.text = text
	node.position = pos
	node.font = load("res://UI/BarlowCondensed-SemiBold.ttf")
	node.font_size = 64
	node.pixel_size = pixel
	node.modulate = color
	node.shaded = false
	node.double_sided = false
	node.outline_size = 0
	parent.add_child(node)
	return node

static func set_rod(node: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	node.position = (a + b) * 0.5
	if a.distance_to(b) > 0.0001:
		node.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
		var cylinder := node.mesh as CylinderMesh
		if cylinder:
			cylinder.height = a.distance_to(b)
