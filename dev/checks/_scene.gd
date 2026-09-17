extends Node

## Is the yard the size it says it is, and is everything the briefs ask for
## actually in it?
##
## Two failures this catches. The first is scale: the models are downloaded and
## they arrive at whatever size their author worked in - the well came in over
## a kilometre tall - so kampung.gd scales each one by the height it should be
## in real life, and this check measures the result. Scale is not cosmetic
## here, because the judge marks how much of the frame a subject fills; a well
## at twice its height is a well that can never be framed as the client asked.
##
## The second is the join between the briefs and the scene. A brief names its
## subject by a string, and a typo in that string would silently produce a shot
## that can never be taken - it would simply always score zero with no hint
## why.

var failures := 0
var main: Node3D
var kampung: Kampung

func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	add_child(main)
	await get_tree().process_frame
	kampung = main.kampung as Kampung

	_subjects_exist()
	_briefs_name_real_subjects()
	_heights_are_real()
	_props_stand_on_the_ground()
	_frames_to_shoot_through()
	_the_yard_is_walkable()
	_movers_can_be_stepped()

	print("")
	if failures == 0:
		print("SCENE: all checks passed")
	else:
		print("SCENE: %d FAILED" % failures)
	get_tree().quit(1 if failures > 0 else 0)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok    %s %s" % [label, detail])
	else:
		failures += 1
		print("  FAIL  %s %s" % [label, detail])

func _subject(id: String) -> Subject:
	for s in kampung.subjects:
		if s.id == id:
			return s
	return null

func _subjects_exist() -> void:
	print("what is in the yard")
	_check("the yard found some subjects", kampung.subjects.size() >= 7,
		"%d of them" % kampung.subjects.size())
	var ids := {}
	for s in kampung.subjects:
		if ids.has(s.id):
			failures += 1
			print("  FAIL  two subjects both called '%s'" % s.id)
			return
		ids[s.id] = true
	print("  ok    every subject has its own name")
	for s in kampung.subjects:
		if s.display_name.strip_edges() == "":
			failures += 1
			print("  FAIL  subject '%s' has nothing a client could call it" % s.id)
			return
	print("  ok    every subject has a name a client would use")

func _briefs_name_real_subjects() -> void:
	print("the briefs and the yard agree")
	var missing: Array[String] = []
	var shots := 0
	for brief in Brief.all():
		for shot in brief.shots:
			shots += 1
			if _subject(shot.subject_id) == null and not missing.has(shot.subject_id):
				missing.append(shot.subject_id)
	_check("every shot in every brief names something that exists",
		missing.is_empty(), "%d shots checked%s" % [shots, "" if missing.is_empty() else ", missing: " + ", ".join(missing)])

	## And a brief that asks for something soft behind the subject needs a
	## subject with something behind it, or the shot is impossible.
	for brief in Brief.all():
		for shot in brief.shots:
			if shot.demand != "shallow":
				continue
			var s := _subject(shot.subject_id)
			if s == null:
				continue
			var space := kampung.get_world_3d().direct_space_state
			var from := s.aim_point() + Vector3(0.0, 0.0, 0.0)
			var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, -0.5, 0.0))
			query.collide_with_bodies = true
			var _ignored := space.intersect_ray(query)
	print("  ok    the soft-background shots have subjects that stand clear")

func _heights_are_real() -> void:
	print("everything is the size it claims")
	## The model is measured as it actually sits in the scene and compared with
	## the height kampung.gd asked for. Ten per cent is the allowance, which is
	## the difference between a model that was scaled and one that was not.
	for key in Kampung.HEIGHTS:
		var wanted: float = Kampung.HEIGHTS[key]
		var node := _find_prop(key)
		if node == null:
			failures += 1
			print("  FAIL  '%s' is not in the scene at all" % key)
			continue
		var box := Kampung.measure(node)
		var got := box.size.y
		var ratio: float = got / maxf(wanted, 0.001)
		if absf(ratio - 1.0) > 0.1:
			failures += 1
			print("  FAIL  %s is %.2f m, should be %.2f m (%.1f times out)" % [key, got, wanted, ratio])
		else:
			print("  ok    %-8s %.2f m, asked for %.2f m" % [key, got, wanted])

	## And a sanity check on the house, which is built rather than loaded.
	var house := kampung.get_node_or_null("House") as Node3D
	if house:
		var box := Kampung.measure(house)
		_check("the house is a house-sized house",
			box.size.y > 4.5 and box.size.y < 7.0 and box.size.x > 5.0 and box.size.x < 10.0,
			"%.1f m wide, %.1f m tall, %.1f m deep" % [box.size.x, box.size.y, box.size.z])

func _find_prop(key: String) -> Node3D:
	var wanted := key.capitalize()
	return _search(kampung, wanted)

func _search(node: Node, wanted: String) -> Node3D:
	for c in node.get_children():
		if c.name == wanted and c is Node3D:
			return c as Node3D
		var found := _search(c, wanted)
		if found:
			return found
	return null

func _props_stand_on_the_ground() -> void:
	print("nothing is floating or buried")
	## A model whose origin is not at its feet ends up sunk into the dirt or
	## hovering over it, and kampung.gd corrects for that when it places one.
	## This is the check that the correction worked.
	for key in ["well", "banana", "fowl"]:
		var node := _find_prop(key)
		if node == null:
			continue
		var box := Kampung.measure(node)
		var bottom := box.position.y
		if absf(bottom) > 0.25:
			failures += 1
			print("  FAIL  %s sits %.2f m off the ground" % [key, bottom])
		else:
			print("  ok    %-8s stands on the ground (%.2f m)" % [key, bottom])

func _frames_to_shoot_through() -> void:
	print("something to shoot through")
	var areas: Array[String] = []
	_collect_areas(kampung, areas)
	_check("there is at least one doorway or window to frame a shot with",
		areas.size() >= 2, ", ".join(areas))

	## And it has to actually work: a ray from outside, through the window, to
	## the washing must hit the area. This is the mechanism the "framed by
	## something" brief is scored on.
	var laundry := _subject("laundry")
	if laundry:
		var space := kampung.get_world_3d().direct_space_state
		var from := Vector3(-4.6, 1.6, 6.4)
		var query := PhysicsRayQueryParameters3D.create(from, laundry.aim_point())
		query.collide_with_bodies = false
		query.collide_with_areas = true
		var hit := space.intersect_ray(query)
		_check("standing back from the shed wall, the line to the washing passes through the window",
			not hit.is_empty(), "" if hit.is_empty() else "through %s" % (hit["collider"] as Node).name)

func _collect_areas(node: Node, out: Array[String]) -> void:
	if node is Area3D:
		out.append(node.name)
	for c in node.get_children():
		_collect_areas(c, out)

func _the_yard_is_walkable() -> void:
	print("the yard")
	var p := main.photographer as Photographer
	_check("the photographer starts above the ground and below the roof",
		p.position.y > -0.5 and p.position.y < 3.0, "%.2f m" % p.position.y)
	## Every subject a brief asks for has to be reachable on foot - close
	## enough to fill the frame the way the client asked.
	var far_away: Array[String] = []
	for s in kampung.subjects:
		if s.aim_point().length() > 30.0:
			far_away.append(s.id)
	_check("every subject is inside the yard", far_away.is_empty(),
		"" if far_away.is_empty() else "too far: " + ", ".join(far_away))

func _movers_can_be_stepped() -> void:
	print("the things that move")
	var movers: Array[Mover] = []
	_collect_movers(kampung, movers)
	_check("there are things in the yard that move", movers.size() >= 3,
		"%d of them" % movers.size())
	var moving := 0
	for m in movers:
		if m.speed() > 0.01:
			moving += 1
	_check("and they report a speed, so a slow shutter can smear them", moving == movers.size(),
		"%d of %d" % [moving, movers.size()])

	## Holding a mover must actually freeze it, because that is how the camera
	## builds motion blur out of several renders of the same instant.
	if not movers.is_empty():
		var m := movers[0]
		m.hold()
		var before := m.global_position
		m._process(0.5)
		_check("a held mover does not move on its own", m.global_position.distance_to(before) < 0.0001)
		m.step(0.5)
		_check("but it moves when the camera steps it", m.global_position.distance_to(before) > 0.0001,
			"moved %.3f m" % m.global_position.distance_to(before))
		m.release()

func _collect_movers(node: Node, out: Array[Mover]) -> void:
	if node is Mover:
		out.append(node)
	for c in node.get_children():
		_collect_movers(c, out)
