extends Node

const PATHS := {
	"house": "res://assets/sketchfab/wooden_house_on_stilts_a_wooden_house_on_stil/wooden_house_on_stilts_a_wooden_house_on_stil.glb",
	"cat": "res://assets/sketchfab/cat_sitting/cat_sitting.glb",
	"banana": "res://assets/sketchfab/banana_tree_low_poly/banana_tree_low_poly.glb",
	"well": "res://assets/sketchfab/old_well_with_hanging_bucket/old_well_with_hanging_bucket.glb",
	"kettle": "res://assets/sketchfab/chinese_kettle/chinese_kettle.glb",
	"fowl": "res://assets/sketchfab/handpainted_rooster_and_hen/handpainted_rooster_and_hen.glb",
}

func _ready() -> void:
	for key in PATHS:
		var scene: PackedScene = load(PATHS[key])
		if scene == null:
			print("%-8s COULD NOT LOAD" % key)
			continue
		var node := scene.instantiate()
		add_child(node)
		var box := _aabb(node)
		print("%-8s size = %6.2f x %6.2f x %6.2f   centre = %6.2f %6.2f %6.2f   meshes=%d" % [
			key, box.size.x, box.size.y, box.size.z,
			box.get_center().x, box.get_center().y, box.get_center().z,
			_count(node)])
		node.queue_free()
	get_tree().quit()

func _aabb(node: Node) -> AABB:
	var box := AABB()
	var first := true
	for m in _meshes(node):
		var world := m.global_transform * m.get_aabb()
		if first:
			box = world
			first = false
		else:
			box = box.merge(world)
	return box

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_meshes(c))
	return out

func _count(node: Node) -> int:
	return _meshes(node).size()
