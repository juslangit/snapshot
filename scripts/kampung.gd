class_name Kampung
extends Node3D

## The one place in the game, built in code.
##
## Building the yard from a script rather than by hand in the editor buys two
## things that matter for a game whose scoring depends on geometry. Every prop
## is scaled by the height it is supposed to be in real life - "a well is two
## and a half metres tall" - so a model downloaded at a hundred times the wrong
## size corrects itself, and dev/checks/_scene.gd can assert afterwards that
## nothing in the yard is the wrong size. And the layout is readable in one
## screen, which is what makes it worth an artist's time to change.
##
## Every prop here is a placeholder for a better one. The names are the slots:
## swap the mesh, keep the height and the position, and the game still scores
## the same way.

## The downloaded models, and the one thing that is not downloaded.
##
## The house is built from boxes in _house() rather than loaded, because the
## only stilt house on offer turned out to be a stylised fantasy treehouse
## standing in front of a painted backdrop - the wrong building, in the wrong
## style, with scenery attached. A plain timber house built here in thirty
## lines has the right proportions, the right roof pitch and a doorway the
## player can stand in, and it is a far better placeholder for a real model
## than something that merely arrived as a file.
const MODELS := {
	"cat": "res://assets/sketchfab/cat_sitting/cat_sitting.glb",
	"banana": "res://assets/sketchfab/banana_tree_low_poly/banana_tree_low_poly.glb",
	"well": "res://assets/sketchfab/old_well_with_hanging_bucket/old_well_with_hanging_bucket.glb",
	"kettle": "res://assets/sketchfab/chinese_kettle/chinese_kettle.glb",
	"fowl": "res://assets/sketchfab/handpainted_rooster_and_hen/handpainted_rooster_and_hen.glb",
}

## Real heights, in metres. These are the numbers that make the yard the right
## size to walk around in, and the numbers the scene check asserts.
const HEIGHTS := {
	"cat": 0.38,
	"banana": 3.6,
	"well": 2.4,
	"kettle": 0.26,
	"fowl": 0.42,
}

## How bright the morning is, in lux, and how much of the sky's light reaches
## the yard. Together these two numbers decide which camera settings expose the
## scene correctly, so they are the calibration the whole exposure lesson hangs
## off, and dev/checks/_light.gd holds them to account.
##
## The pair was found by measuring, not by taste: dev/checks/_light.gd renders
## the yard and insists that f/8 at 1/125 and ISO 100 - EV 13 - comes out near
## middle grey, and that the sun rather than the sky is doing most of the work.
## 35,000 lux is a bright mid-morning sun, which is where those two demands
## meet once the walls of the house are painted a pale colour. The number is
## expected to move again whenever the art does, and the check is what will say
## so.
const SUN_LUX := 35000.0
## How much of the sky's own light reaches the yard. A real sky is a huge soft
## source and this is how much of it the ground sees.
const SKY_ENERGY := 1.0
## How much fill the sky throws into the shadows. Deliberately low against the
## sun: at the first setting that exposed correctly the sky was doing three
## quarters of the work, the shadows were pale and the light had no direction
## at all, so "the morning light on it" was an instruction a player could not
## follow. Splitting it roughly two to one in the sun's favour gives real
## shadows to compose with.
const AMBIENT_ENERGY := 0.084

var subjects: Array[Subject] = []

func _ready() -> void:
	_ground()
	_light()
	_house()
	_yard()
	_laundry()
	_window_wall()
	_fence()
	subjects = collect_subjects()

func collect_subjects() -> Array[Subject]:
	var out: Array[Subject] = []
	_gather(self, out)
	return out

func _gather(node: Node, out: Array[Subject]) -> void:
	if node is Subject:
		out.append(node)
	for c in node.get_children():
		_gather(c, out)


# ---------------------------------------------------------------------------
# The morning
# ---------------------------------------------------------------------------

func _light() -> void:
	## Physical light units are on, so the sun is set in lux and the camera's
	## aperture and shutter mean what they say. Twenty thousand lux is an hour
	## after sunrise - around EV 13, which is a scene that f/8 at 1/125 and ISO
	## 100 will expose correctly. That equivalence is what the whole exposure
	## lesson rests on, and dev/checks/_exposure.gd holds it in place.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_intensity_lux = SUN_LUX
	sun.light_color = Color(1.0, 0.89, 0.72)
	sun.light_angular_distance = 0.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	## Where the sun stands matters more than how bright it is. At this angle
	## it is about 24 degrees up - an hour or so after sunrise - and it comes
	## over the photographer's right shoulder as they face the house, so the
	## front of the building is modelled by it and the shadows run away from
	## the camera. Pointing it the other way lit nothing the player could see
	## and the sky did all the work.
	sun.rotation_degrees = Vector3(-24.0, 38.0, 0.0)
	add_child(sun)

	var env := Environment.new()
	var sky := Sky.new()
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color(0.29, 0.48, 0.74)
	material.sky_horizon_color = Color(0.82, 0.78, 0.68)
	material.ground_bottom_color = Color(0.4, 0.31, 0.22)
	material.ground_horizon_color = Color(0.68, 0.64, 0.56)
	material.sun_angle_max = 8.0
	material.sky_energy_multiplier = SKY_ENERGY
	sky.sky_material = material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	## The sky is left at full brightness because that is what a morning sky
	## looks like, and the fill light is set separately. Dimming the sky itself
	## to control the exposure made the whole scene read as dusk - the first
	## version of this scene looked like evening because of it.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.68, 0.72, 0.8)
	env.ambient_light_energy = AMBIENT_ENERGY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	## Linear tone mapping, deliberately. A filmic curve flatters a badly
	## exposed frame and would quietly lie to the light meter; linear means a
	## blown sky really is blown, and the meter reading is the truth.
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	## A little haze, which does two jobs. It is what a tropical morning looks
	## like, and it hides the seam where the ground plane ends and the painted
	## sky begins - a hard pale line across the horizon in the version before
	## this one. It also gives distance a tone of its own, which is what lets a
	## photograph read as deep rather than flat.
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.8, 0.82)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.12
	env.fog_density = 0.0055
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.3
	env.sdfgi_enabled = false
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.4

	var holder := WorldEnvironment.new()
	holder.name = "WorldEnvironment"
	holder.environment = env
	add_child(holder)

func _ground() -> void:
	## The ground runs well past anything the player can reach, so the sky's
	## own painted ground never shows as a bright band at the horizon.
	var dirt := _flat("Ground", Vector2(240.0, 240.0), Color(0.46, 0.35, 0.23), 0.92)
	dirt.position = Vector3.ZERO
	_scatter()
	var floor_body := StaticBody3D.new()
	floor_body.name = "GroundBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(240.0, 0.4, 240.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.2, 0.0)
	floor_body.add_child(shape)
	add_child(floor_body)

## Tufts of grass, a few stones, and a line of trees far enough away to be
## scenery. None of it is a subject; all of it is there so that a photograph
## taken anywhere in the yard has something in the foreground and something on
## the horizon. An empty plane photographs as an empty plane.
func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260917

	var tufts := Node3D.new()
	tufts.name = "Tufts"
	add_child(tufts)
	var greens := [Color(0.24, 0.34, 0.14), Color(0.3, 0.4, 0.17), Color(0.35, 0.42, 0.2)]
	for i in 420:
		## Clustered rather than even, because grass grows in patches and an
		## even sprinkle reads as a texture rather than as ground.
		var centre := Vector3(rng.randf_range(-16.0, 16.0), 0.0, rng.randf_range(-6.0, 14.0))
		var spread := rng.randf_range(0.2, 1.6)
		var where := centre + Vector3(rng.randfn(0.0, spread), 0.0, rng.randfn(0.0, spread))
		if absf(where.x) < 4.2 and where.z < -4.0:
			continue
		## Cones, not flat cards. The first version used single quads and they
		## read as green tiles lying on the dirt - a flat card has no silhouette
		## from above, and a photography game is looked at from every angle.
		var blade := MeshInstance3D.new()
		blade.name = "Tuft%d" % i
		var cone := CylinderMesh.new()
		var height := rng.randf_range(0.16, 0.38)
		cone.height = height
		cone.top_radius = 0.0
		cone.bottom_radius = rng.randf_range(0.07, 0.15)
		cone.radial_segments = 5
		cone.rings = 1
		blade.mesh = cone
		blade.position = where + Vector3(0.0, height * 0.45, 0.0)
		blade.rotation = Vector3(rng.randf_range(-0.16, 0.16), rng.randf_range(0.0, TAU), rng.randf_range(-0.16, 0.16))
		blade.material_override = _material(greens[rng.randi_range(0, greens.size() - 1)], 0.95)
		tufts.add_child(blade)

	for i in 26:
		var stone := MeshInstance3D.new()
		stone.name = "Stone%d" % i
		var mesh := SphereMesh.new()
		var r := rng.randf_range(0.06, 0.2)
		mesh.radius = r
		mesh.height = r * 1.3
		mesh.radial_segments = 6
		mesh.rings = 3
		stone.mesh = mesh
		stone.position = Vector3(rng.randf_range(-14.0, 14.0), r * 0.25, rng.randf_range(-4.0, 12.0))
		stone.material_override = _material(Color(0.42, 0.4, 0.37), 0.9)
		tufts.add_child(stone)

	## The tree line. Far enough out that nobody walks to it, close enough that
	## it breaks the horizon in every direction.
	var distance := Node3D.new()
	distance.name = "TreeLine"
	add_child(distance)
	for i in 34:
		var angle := (float(i) / 34.0) * TAU + rng.randf_range(-0.05, 0.05)
		var radius := rng.randf_range(26.0, 44.0)
		var tree := _prop("banana", Vector3(sin(angle) * radius, 0.0, cos(angle) * radius),
			rng.randf_range(0.0, 360.0), distance)
		if tree:
			tree.scale = Vector3.ONE * rng.randf_range(1.2, 2.0)


func _flat(name_text: String, size: Vector2, colour: Color, roughness: float) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = name_text
	node.mesh = mesh
	node.material_override = _material(colour, roughness)
	add_child(node)
	return node


# ---------------------------------------------------------------------------
# The house and its porch
# ---------------------------------------------------------------------------

func _house() -> void:
	## A kampung house, in the proportions that make one: lifted off the ground
	## on posts so the air moves under it, a deep verandah in front of the
	## door, tall shuttered windows, and a steep gable roof for the rain. Every
	## measurement here is in metres and meant to be argued with.
	var house := Node3D.new()
	house.name = "House"
	house.position = Vector3(0.0, 0.0, -9.0)
	add_child(house)

	var timber := Color(0.44, 0.32, 0.21)
	var timber_dark := Color(0.33, 0.24, 0.17)
	var plank := Color(0.76, 0.73, 0.6)
	var roof_colour := Color(0.47, 0.26, 0.19)

	const FLOOR_Y := 1.7
	const WIDTH := 7.0
	const DEPTH := 5.4
	const WALL_H := 2.5
	const RIDGE := 2.6
	var wall_top: float = FLOOR_Y + WALL_H

	## The posts it stands on.
	for x in [-3.2, 0.0, 3.2]:
		for z in [-2.4, 2.4]:
			var post := _block(house, "Post%d_%d" % [roundi(x * 10.0), roundi(z * 10.0)],
				Vector3(0.22, FLOOR_Y, 0.22), Vector3(x, FLOOR_Y * 0.5, z), timber_dark, 0.9)
			_collide(post, Vector3(0.22, FLOOR_Y, 0.22))

	## The floor, and the verandah in front of it.
	var deck := _block(house, "Floor", Vector3(WIDTH, 0.22, DEPTH), Vector3(0.0, FLOOR_Y, 0.0), timber, 0.88)
	_collide(deck, Vector3(WIDTH, 0.22, DEPTH))
	var verandah := _block(house, "Verandah", Vector3(WIDTH, 0.22, 2.0), Vector3(0.0, FLOOR_Y, DEPTH * 0.5 + 1.0), timber, 0.88)
	_collide(verandah, Vector3(WIDTH, 0.22, 2.0))

	## Steps down into the yard, wide enough for a cat to sit on.
	for i in 5:
		var step := _block(house, "Step%d" % i, Vector3(1.7, 0.3, 0.34),
			Vector3(0.0, FLOOR_Y - 0.3 * float(i + 1) + 0.12, DEPTH * 0.5 + 2.1 + 0.34 * float(i)), plank, 0.9)
		_collide(step, Vector3(1.7, 0.3, 0.34))

	## The back and side walls, then the front wall with a doorway left in it.
	_wall(house, "BackWall", Vector3(WIDTH, WALL_H, 0.16), Vector3(0.0, FLOOR_Y + WALL_H * 0.5, -DEPTH * 0.5), plank)
	for side in [-1.0, 1.0]:
		## A side wall in three pieces, so a tall shuttered window is left open
		## in the middle of it and the light comes through.
		var x: float = side * WIDTH * 0.5
		_wall(house, "SideLow%d" % roundi(side), Vector3(0.16, 0.9, DEPTH), Vector3(x, FLOOR_Y + 0.45, 0.0), plank)
		_wall(house, "SideHigh%d" % roundi(side), Vector3(0.16, 0.5, DEPTH), Vector3(x, FLOOR_Y + WALL_H - 0.25, 0.0), plank)
		for z in [-1.9, 0.0, 1.9]:
			_wall(house, "SideMullion%d_%d" % [roundi(side), roundi(z * 10.0)],
				Vector3(0.16, 1.1, 0.5), Vector3(x, FLOOR_Y + 1.45, z), plank)

	var door_half := 0.65
	for side in [-1.0, 1.0]:
		var panel_width: float = WIDTH * 0.5 - door_half
		_wall(house, "FrontWall%d" % roundi(side),
			Vector3(panel_width, WALL_H, 0.16),
			Vector3(side * (door_half + panel_width * 0.5), FLOOR_Y + WALL_H * 0.5, DEPTH * 0.5), plank)
	_wall(house, "DoorHead", Vector3(door_half * 2.0, 0.4, 0.16),
		Vector3(0.0, FLOOR_Y + WALL_H - 0.2, DEPTH * 0.5), timber_dark)
	## The doorway itself: standing in it and shooting out is what earns a
	## "framed by something" shot.
	_frame_area(house, "DoorFrame", Vector3(door_half * 2.0, WALL_H - 0.4, 0.3),
		Vector3(0.0, FLOOR_Y + (WALL_H - 0.4) * 0.5, DEPTH * 0.5))

	## Verandah railing, low enough to lean a camera on.
	for x in [-3.0, -1.6, 1.6, 3.0]:
		_block(house, "Rail%d" % roundi(x * 10.0), Vector3(0.1, 0.9, 0.1),
			Vector3(x, FLOOR_Y + 0.55, DEPTH * 0.5 + 1.9), timber_dark, 0.9)
	_block(house, "RailTop", Vector3(WIDTH, 0.09, 0.09), Vector3(0.0, FLOOR_Y + 1.0, DEPTH * 0.5 + 1.9), timber_dark, 0.9)

	## A gable roof: two slabs leaning against each other, with the overhang a
	## tropical roof needs.
	var slope := sqrt(pow(DEPTH * 0.5 + 0.7, 2.0) + pow(RIDGE, 2.0))
	var pitch := atan(RIDGE / (DEPTH * 0.5 + 0.7))
	for side in [-1.0, 1.0]:
		var slab := _block(house, "Roof%d" % roundi(side), Vector3(WIDTH + 1.2, 0.14, slope),
			Vector3(0.0, wall_top + RIDGE * 0.5, side * (DEPTH * 0.5 + 0.7) * 0.5), roof_colour, 0.8)
		slab.rotation = Vector3(side * pitch, 0.0, 0.0)
		_collide(slab, Vector3(WIDTH + 1.2, 0.14, slope))
	_block(house, "Ridge", Vector3(WIDTH + 1.3, 0.16, 0.18), Vector3(0.0, wall_top + RIDGE, 0.0), timber_dark, 0.85)
	## The walls stop level but the roof rises towards the ridge, so above the
	## front and back walls there was an open gap showing the dark inside of
	## the house as a black band right across the building. These close it.
	for side in [-1.0, 1.0]:
		_wall(house, "Fascia%d" % roundi(side), Vector3(WIDTH, 0.75, 0.16),
			Vector3(0.0, wall_top + 0.3, side * DEPTH * 0.5), plank)
	## The gable ends, filled in above the wall.
	for side in [-1.0, 1.0]:
		_wall(house, "Gable%d" % roundi(side), Vector3(0.14, RIDGE * 0.75, 1.6),
			Vector3(side * WIDTH * 0.5, wall_top + RIDGE * 0.38, 0.0), plank)

	var s := _subject(house, "house", "the house", Vector3(0.0, 3.2, 1.0), 5.6)
	s.position = Vector3.ZERO

	## The stove and the kettle, at the near end of the verandah where the
	## light from the east reaches across it.
	var stove := _block(house, "Stove", Vector3(0.85, 0.55, 0.65),
		Vector3(2.1, FLOOR_Y + 0.4, DEPTH * 0.5 + 1.1), Color(0.21, 0.19, 0.18), 0.7)
	_collide(stove, Vector3(0.85, 0.55, 0.65))
	var kettle := _prop("kettle", Vector3(2.1, 0.0, -9.0 + DEPTH * 0.5 + 1.1), 24.0)
	if kettle:
		kettle.position.y = FLOOR_Y + 0.68
		_subject(kettle, "kettle", "the kettle", Vector3(0.0, 0.14, 0.0), 0.26)

	## The cat on the second step, at the height a crouching photographer would
	## want her.
	var cat := _prop("cat", Vector3(-0.55, 0.0, -9.0 + DEPTH * 0.5 + 2.45), -38.0)
	if cat:
		cat.position.y = FLOOR_Y - 0.44
		_subject(cat, "cat", "the cat", Vector3(0.0, 0.2, 0.0), 0.38)


## A wall panel with a collider, since the player must not walk through the
## house and the judge must know when it is in the way.
func _wall(parent: Node3D, name_text: String, size: Vector3, where: Vector3, colour: Color) -> MeshInstance3D:
	var node := _block(parent, name_text, size, where, colour, 0.9)
	_collide(node, size)
	return node


# ---------------------------------------------------------------------------
# The yard
# ---------------------------------------------------------------------------

func _yard() -> void:
	var well := _prop("well", Vector3(-7.4, 0.0, -3.2), 24.0)
	if well:
		_box_collider(well, Vector3(1.6, 2.4, 1.6), Vector3(0.0, 1.2, 0.0))
		_subject(well, "well", "the well", Vector3(0.0, 1.1, 0.0), 2.4)

	## A stand of banana trees to the east, so the sun comes through the
	## leaves. One of them is the subject; the rest are the stand it belongs to.
	var spots := [
		Vector3(9.2, 0.0, -5.0),
		Vector3(11.4, 0.0, -2.4),
		Vector3(8.4, 0.0, -0.6),
		Vector3(12.2, 0.0, 1.8),
	]
	var index := 0
	for spot in spots:
		var tree := _prop("banana", spot, 40.0 * float(index))
		if tree == null:
			index += 1
			continue
		_box_collider(tree, Vector3(0.5, 3.6, 0.5), Vector3(0.0, 1.8, 0.0))
		if index == 0:
			_subject(tree, "tree", "the banana tree", Vector3(0.0, 2.2, 0.0), 3.2)
		index += 1

	## The hen paces across the yard, which is what makes her the shutter-speed
	## lesson. A Mover carries her so the camera can step her mid-exposure.
	var walk := Mover.new()
	walk.name = "HenWalk"
	walk.kind = Mover.Kind.PACE
	walk.period = 7.0
	walk.amount = 2.2
	walk.axis = Vector3.RIGHT
	walk.position = Vector3(3.4, 0.0, -1.0)
	add_child(walk)
	var fowl := _prop("fowl", Vector3.ZERO, 95.0, walk)
	if fowl:
		_subject(fowl, "hen", "the hen", Vector3(0.0, 0.22, 0.0), 0.42)


func _laundry() -> void:
	## Washing on a line: the swaying subject that a slow shutter smears and a
	## fast one freezes, and the thing the window frame is aimed at.
	var line := Node3D.new()
	line.name = "Laundry"
	line.position = Vector3(-4.6, 0.0, 1.4)
	add_child(line)
	for x in [-2.4, 2.4]:
		var pole := _block(line, "Pole%d" % roundi(x), Vector3(0.1, 2.3, 0.1), Vector3(x, 1.15, 0.0), Color(0.4, 0.3, 0.2), 0.9)
		_collide(pole, Vector3(0.1, 2.3, 0.1))
	_block(line, "Rope", Vector3(4.8, 0.02, 0.02), Vector3(0.0, 2.25, 0.0), Color(0.6, 0.55, 0.45), 0.9)

	var colours := [Color(0.82, 0.8, 0.76), Color(0.3, 0.45, 0.62), Color(0.75, 0.35, 0.3), Color(0.85, 0.78, 0.4)]
	var hinges: Array[Mover] = []
	for i in colours.size():
		var hinge := Mover.new()
		hinge.name = "Hang%d" % i
		hinge.kind = Mover.Kind.SWAY
		hinge.period = 2.6 + 0.35 * float(i)
		hinge.amount = 7.0
		hinge.axis = Vector3.RIGHT
		hinge.position = Vector3(-1.7 + 1.15 * float(i), 2.24, 0.0)
		line.add_child(hinge)
		hinges.append(hinge)
		var cloth := MeshInstance3D.new()
		cloth.name = "Cloth%d" % i
		var quad := QuadMesh.new()
		quad.size = Vector2(0.62, 0.85)
		cloth.mesh = quad
		cloth.position = Vector3(0.0, -0.45, 0.0)
		var mat := _material(colours[i], 0.95)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		cloth.material_override = mat
		hinge.add_child(cloth)

	## The subject is the middle of the line, and it hangs off the sway so the
	## judge reads a real speed for it.
	var s := _subject(hinges[1], "laundry", "the washing", Vector3(0.0, -0.45, 0.0), 0.85)
	s.position = Vector3.ZERO


func _window_wall() -> void:
	## A shed wall with a window cut in it, standing between the yard and the
	## line. Shooting the washing through this opening is the "framed by
	## something" shot, and the frame is code-built so the geometry is certain.
	var wall := Node3D.new()
	wall.name = "ShedWall"
	wall.position = Vector3(-4.6, 0.0, 4.6)
	add_child(wall)
	var colour := Color(0.5, 0.42, 0.33)
	var lower := _block(wall, "Below", Vector3(3.6, 1.0, 0.16), Vector3(0.0, 0.5, 0.0), colour, 0.9)
	_collide(lower, Vector3(3.6, 1.0, 0.16))
	var upper := _block(wall, "Above", Vector3(3.6, 0.7, 0.16), Vector3(0.0, 2.35, 0.0), colour, 0.9)
	_collide(upper, Vector3(3.6, 0.7, 0.16))
	for x in [-1.35, 1.35]:
		var side := _block(wall, "Side%d" % roundi(x * 10.0), Vector3(0.9, 1.0, 0.16), Vector3(x, 1.5, 0.0), colour, 0.9)
		_collide(side, Vector3(0.9, 1.0, 0.16))
	_block(wall, "Sill", Vector3(2.0, 0.08, 0.3), Vector3(0.0, 1.02, 0.05), Color(0.42, 0.33, 0.24), 0.85)
	_frame_area(wall, "WindowFrame", Vector3(1.8, 1.0, 0.25), Vector3(0.0, 1.5, 0.0))


func _fence() -> void:
	var fence := Node3D.new()
	fence.name = "Fence"
	fence.position = Vector3(0.0, 0.0, 9.6)
	add_child(fence)
	var x := -12.0
	while x <= 12.0:
		_block(fence, "Slat%d" % roundi(x * 10.0), Vector3(0.09, 1.0, 0.09), Vector3(x, 0.5, 0.0), Color(0.45, 0.36, 0.26), 0.9)
		x += 0.55
	_block(fence, "Rail", Vector3(24.0, 0.08, 0.06), Vector3(0.0, 0.82, 0.0), Color(0.44, 0.35, 0.25), 0.9)


# ---------------------------------------------------------------------------
# Building blocks
# ---------------------------------------------------------------------------

func _material(colour: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = roughness
	mat.metallic = 0.0
	return mat

func _block(parent: Node, name_text: String, size: Vector3, where: Vector3, colour: Color, roughness: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = name_text
	node.mesh = mesh
	node.position = where
	node.material_override = _material(colour, roughness)
	parent.add_child(node)
	return node

func _collide(node: Node3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Body"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	node.add_child(body)

func _box_collider(node: Node3D, size: Vector3, where: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.position = where
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	node.add_child(body)

## A doorway, a window or a gap. The camera asks the physics server whether the
## line of sight to a subject passed through one of these, which is how a shot
## gets credit for being framed by something.
func _frame_area(parent: Node, name_text: String, size: Vector3, where: Vector3) -> void:
	var area := Area3D.new()
	area.name = name_text
	area.position = where
	area.monitoring = false
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	parent.add_child(area)

func _subject(parent: Node3D, id: String, display_name: String, aim_offset: Vector3, height_m: float) -> Subject:
	var s := Subject.new()
	s.name = "Subject_" + id
	s.id = id
	s.display_name = display_name
	s.aim_offset = aim_offset
	s.height_m = height_m
	parent.add_child(s)
	return s

## Load a model and scale it by the height it is supposed to be in real life.
##
## This is the step that makes downloaded assets usable. A Sketchfab model
## arrives at whatever scale its author worked in - the well in this scene came
## in twelve hundred metres tall - and guessing a multiplier leaves a magic
## number in the file that nobody can check. Measuring the mesh and dividing by
## the real height leaves a number anybody can check: a well is 2.4 m tall.
func _prop(key: String, where: Vector3, yaw_degrees: float, parent: Node3D = null) -> Node3D:
	var path: String = MODELS.get(key, "")
	if path == "" or not ResourceLoader.exists(path):
		push_warning("Kampung: no model for '%s'" % key)
		return null
	var scene: PackedScene = load(path)
	if scene == null:
		return null
	var holder := Node3D.new()
	holder.name = key.capitalize()
	holder.position = where
	holder.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	if parent == null:
		add_child(holder)
	else:
		parent.add_child(holder)

	var model := scene.instantiate() as Node3D
	holder.add_child(model)
	var box := measure(model)
	var wanted: float = HEIGHTS.get(key, 1.0)
	if box.size.y > 0.0001:
		var factor := wanted / box.size.y
		model.scale = Vector3.ONE * factor
		## Sit it on the ground and centre it over its own origin, so the
		## position in this file means where the thing stands.
		model.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z) * factor
	return holder

## The bounding box of a model in its own space, merged over every mesh it
## contains. Used to work out the scale factor, and again by the scene check to
## prove the factor took.
static func measure(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var meshes: Array[MeshInstance3D] = []
	_meshes_of(node, meshes)
	for m in meshes:
		var local := node.global_transform.affine_inverse() * m.global_transform if node.is_inside_tree() else m.transform
		var world := local * m.get_aabb()
		if first:
			box = world
			first = false
		else:
			box = box.merge(world)
	return box

static func _meshes_of(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_meshes_of(c, out)
