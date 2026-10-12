@tool
class_name SurfaceBody
extends StaticBody3D

## Shared body for Climbable and Unclimbable.
##
## Pick how collision is built:
## - Primitive: an analytic box, sphere, capsule, or cylinder.
## - Convex: the convex hull of the visible mesh. An L-shaped corner gets its
##   notch filled in, so you cannot stand inside it.
## - Concave: a trimesh of that same mesh. The corner notch stays open.
##
## Size depends on the primitive:
## - Box: full width, height, and depth (x, y, z).
## - Sphere: radius in x.
## - Capsule: radius in x, total height in y (at least twice the radius).
## - Cylinder: radius in x, height in y.
##
## corner_mesh ignores the primitive and builds an L. Shape mode still applies,
## which is the easiest way to feel concave versus convex.

enum ShapeMode { PRIMITIVE, CONVEX, CONCAVE }
enum Primitive { BOX, SPHERE, CAPSULE, CYLINDER }

@export var shape_mode: ShapeMode = ShapeMode.PRIMITIVE:
	set(value):
		# Box math, a convex hull, or triangle soup. Dealer's choice.
		shape_mode = value
		_rebuild()

@export var primitive: Primitive = Primitive.BOX:
	set(value):
		# Sphere, box, capsule, cylinder. The greatest hits.
		primitive = value
		_rebuild()

@export var size: Vector3 = Vector3(2, 2, 2):
	set(value):
		# No paper-thin walls. Five centimeters is the floor.
		size = value.max(Vector3(0.05, 0.05, 0.05))
		_rebuild()

@export var corner_mesh: bool = false:
	set(value):
		# Turns the block into an L, notch included.
		corner_mesh = value
		_rebuild()

@export var albedo: Color = Color(0.58, 0.6, 0.64, 1):
	set(value):
		# Paint job. The collision couldn't care less.
		albedo = value
		_rebuild()

@export_range(0.0, 1.0) var roughness: float = 0.92:
	set(value):
		# Shiny and wet, or honest rock.
		roughness = value
		_rebuild()


func _ready() -> void:
	# World collision, then build whatever shape we were asked for.
	collision_layer = 1
	collision_mask = 1
	_rebuild()


func _rebuild() -> void:
	# Throws out the old mesh and collision and makes new ones.
	if not is_inside_tree():
		return
	var doomed: Array[Node] = []
	for child in get_children():
		if str(child.name).begins_with("Generated"):
			doomed.append(child)
	for child in doomed:
		remove_child(child)
		child.free()
	var mesh := _make_mesh()
	var visual := MeshInstance3D.new()
	visual.name = "GeneratedMesh"
	visual.mesh = mesh
	add_child(visual)
	_add_collision(mesh)


func _make_mesh() -> Mesh:
	# Picks a primitive, or the L, and paints it.
	var mat := _material()
	if corner_mesh:
		var mesh := _corner_array_mesh()
		mesh.surface_set_material(0, mat)
		return mesh
	match primitive:
		Primitive.SPHERE:
			var sphere := SphereMesh.new()
			sphere.radius = size.x
			sphere.height = size.x * 2.0
			sphere.material = mat
			return sphere
		Primitive.CAPSULE:
			var capsule := CapsuleMesh.new()
			capsule.radius = size.x
			capsule.height = maxf(size.y, size.x * 2.0)
			capsule.material = mat
			return capsule
		Primitive.CYLINDER:
			var cylinder := CylinderMesh.new()
			cylinder.bottom_radius = size.x
			cylinder.top_radius = size.x
			cylinder.height = size.y
			cylinder.material = mat
			return cylinder
		_:
			var box := BoxMesh.new()
			box.size = size
			box.material = mat
			return box


func _material() -> StandardMaterial3D:
	# Color and shine. The corner gets both faces, because winding is a liar.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = roughness
	# The corner is hand-wound. Disabling cull keeps a flipped face visible.
	if corner_mesh:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _add_collision(mesh: Mesh) -> void:
	# Hull, trimesh, or a tidy analytic shape. Same mesh, different manners.
	if shape_mode == ShapeMode.CONVEX:
		_add_shape(mesh.create_convex_shape(), Vector3.ZERO)
		return
	if shape_mode == ShapeMode.CONCAVE:
		_add_shape(mesh.create_trimesh_shape(), Vector3.ZERO)
		return
	if corner_mesh:
		var index := 0
		for part in _corner_boxes():
			var shape := BoxShape3D.new()
			shape.size = part["size"]
			_add_shape(shape, part["center"], index)
			index += 1
		return
	match primitive:
		Primitive.SPHERE:
			var sphere := SphereShape3D.new()
			sphere.radius = size.x
			_add_shape(sphere, Vector3.ZERO)
		Primitive.CAPSULE:
			var capsule := CapsuleShape3D.new()
			capsule.radius = size.x
			capsule.height = maxf(size.y, size.x * 2.0)
			_add_shape(capsule, Vector3.ZERO)
		Primitive.CYLINDER:
			var cylinder := CylinderShape3D.new()
			cylinder.radius = size.x
			cylinder.height = size.y
			_add_shape(cylinder, Vector3.ZERO)
		_:
			var box := BoxShape3D.new()
			box.size = size
			_add_shape(box, Vector3.ZERO)


func _add_shape(shape: Shape3D, at: Vector3, index: int = 0) -> void:
	# Hangs a collision shape on the body and pretends it was always there.
	var collision := CollisionShape3D.new()
	collision.name = "GeneratedCollision" if index == 0 else "GeneratedCollision%d" % index
	collision.shape = shape
	collision.position = at
	add_child(collision)


func _corner_boxes() -> Array[Dictionary]:
	# Two boxes that make an L. The missing quadrant is the fun part.
	# An L in the XZ plane. The missing +X/+Z quadrant is the notch.
	var stem_size := Vector3(size.x * 0.42, size.y, size.z)
	var foot_size := Vector3(size.x, size.y, size.z * 0.42)
	return [
		{"center": Vector3(-size.x * 0.29, 0.0, 0.0), "size": stem_size},
		{"center": Vector3(0.0, 0.0, -size.z * 0.29), "size": foot_size},
	]


func _corner_array_mesh() -> ArrayMesh:
	# Stitches those two boxes into one mesh the trimesh can chew on.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in _corner_boxes():
		var center: Vector3 = part["center"]
		var part_size: Vector3 = part["size"]
		_add_box_triangles(tool, center, part_size * 0.5)
	tool.generate_normals()
	return tool.commit()


func _add_box_triangles(tool: SurfaceTool, center: Vector3, half: Vector3) -> void:
	# Six clockwise faces. Godot likes its fronts that way.
	# Each quad is clockwise when viewed from outside (Godot's front face).
	var faces: Array = [
		[Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1)],
		[Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(-1, 1, -1)],
		[Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(-1, 1, -1)],
		[Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1)],
		[Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)],
		[Vector3(1, -1, -1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1)],
	]
	for face in faces:
		var quad: Array = face
		for corner in [0, 1, 2, 0, 2, 3]:
			var unit: Vector3 = quad[corner]
			tool.add_vertex(center + Vector3(unit.x * half.x, unit.y * half.y, unit.z * half.z))
