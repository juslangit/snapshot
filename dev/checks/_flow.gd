extends Node

## Walks the game the way a player would, through the real screens.
##
## Every assertion here is made against the actual nodes the player clicks, not
## a rehearsal of them - the title screen's own button, the brief screen's own
## button, the real shutter, the real review. That is deliberate. The flow is
## the part of a game that breaks when something unrelated is changed, and a
## test that builds its own fake screens would keep passing while the game
## stopped working.

var failures := 0
var main: Node3D
## The verdict from the most recent shutter press, taken off the signal the
## game emits rather than read back out of the career - the career deliberately
## keeps only the best one.
var last_verdict: Judge.Verdict

func _ready() -> void:
	## A throwaway profile, so the checks never write into a real album.
	Profile.root = "user://checks_profile/"
	Profile.erase_all()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	add_child(main)
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	Game.shot_marked.connect(func(_index: int, verdict: Judge.Verdict) -> void: last_verdict = verdict)

	await _starts_at_the_title()
	await _the_brief_comes_first()
	await _taking_a_photograph()
	await _a_reshoot_keeps_the_better_one()
	await _finishing_a_brief()
	await _the_next_job()
	await _walking_out()
	await _the_menus()
	Profile.erase_all()

	print("")
	if failures == 0:
		print("FLOW: all checks passed")
	else:
		print("FLOW: %d FAILED" % failures)
	get_tree().quit(1 if failures > 0 else 0)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok    %s %s" % [label, detail])
	else:
		failures += 1
		print("  FAIL  %s %s" % [label, detail])

func _screen(name_text: String) -> Control:
	return main.get_node_or_null("Screens/" + name_text) as Control

## Find a button by its text and press it, the way a player would. Calling the
## handler directly would not prove the button is wired to it.
func _press(screen: Control, text: String) -> bool:
	var button := _find_button(screen, text)
	if button == null:
		return false
	button.pressed.emit()
	await get_tree().process_frame
	return true

func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for c in node.get_children():
		var found := _find_button(c, text)
		if found:
			return found
	return null

## Press a button found by its node name - the menu's buttons carry a number
## in their text, so the name is the steadier handle.
func _press_named(screen: Control, name_text: String) -> bool:
	var button := screen.find_child(name_text, true, false) as Button
	if button == null or not button.is_visible_in_tree():
		return false
	button.pressed.emit()
	await get_tree().process_frame
	return true

## A real key press through the real input path, as if from the keyboard.
func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	var up := event.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame

func _starts_at_the_title() -> void:
	print("the main menu")
	_check("the game opens on the main menu", main.stage == main.Stage.TITLE)
	_check("the menu is showing", _screen("Menu").visible)
	_check("the viewfinder is not", not main.hud.visible)
	_check("and the mouse is the player's own", Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
	for item in ["Play", "Photoalbum", "Howtoplay", "Settings", "Quit"]:
		_check("it has %s" % item, _screen("Menu").find_child(item, true, false) != null)

func _the_brief_comes_first() -> void:
	print("choosing a job")
	_check("Play opens the job board", await _press_named(_screen("Menu"), "Play"))
	_check("the job board is showing", main.stage == main.Stage.JOBS and _screen("Jobs").visible)
	_check("every client has a card", _has_text(_screen("Jobs"), Game.briefs[0].title)
		and _has_text(_screen("Jobs"), Game.briefs[2].title))
	_check("a new job says so", _has_text(_screen("Jobs"), "NEW"))
	print("the brief")
	_check("taking the first job goes to the brief", await _press_named(_screen("Jobs"), "Take0"))
	_check("the brief screen is showing", main.stage == main.Stage.BRIEFING and _screen("Brief").visible)
	_check("it is the first client's brief", Game.brief_index == 0,
		Game.current_brief().client)
	_check("the brief lists three shots", Game.current_shots().size() == 3)
	## The client's own words have to be on the screen, because that is the
	## only place the player learns what is wanted.
	_check("the client's words are on it", _has_text(_screen("Brief"), Game.current_brief().blurb.substr(0, 24)))
	_check("so is the first shot's title", _has_text(_screen("Brief"), Game.current_shots()[0].title))

	_check("going to work opens the viewfinder", await _press(_screen("Brief"), "Go to work"))
	_check("and the game is now being played", main.stage == main.Stage.SHOOTING and main.hud.visible)
	_check("the mouse is captured for looking around", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	_check("and the photographer can move", (main.photographer as Photographer).look_enabled)

func _has_text(node: Node, needle: String) -> bool:
	if node is Label and (node as Label).text.contains(needle):
		return true
	for c in node.get_children():
		if _has_text(c, needle):
			return true
	return false

func _taking_a_photograph() -> void:
	print("taking a photograph")
	## Stand where the first shot can actually be taken, and fire the real
	## shutter.
	await _stand_for_shot(0)
	main._shot_index = 0
	await main._fire()
	await get_tree().create_timer(0.3).timeout

	_check("the shutter puts us on the review screen", main.stage == main.Stage.REVIEW and _screen("Review").visible)
	_check("something was handed in", Game.handed[0] != null)
	if Game.handed[0] == null:
		return
	var handed = Game.handed[0]
	_check("there is a photograph", handed.photo != null and not handed.photo.is_empty(),
		"%d x %d" % [handed.photo.get_width(), handed.photo.get_height()])
	_check("the photograph is the right shape", handed.photo.get_width() == CameraBody.PHOTO_WIDTH,
		"%d px wide" % handed.photo.get_width())
	_check("it was marked", handed.verdict != null and handed.verdict.lines.size() >= 5,
		"%d lines, scored %d" % [handed.verdict.lines.size(), handed.verdict.score])
	_check("the settings it was taken at were recorded", handed.settings.contains("f/"),
		handed.settings)
	_check("the score is on the screen", _has_text(_screen("Review"), "%d" % handed.verdict.score))
	_check("and so is the client's reaction", _has_text(_screen("Review"), handed.verdict.headline.substr(0, 12)),
		handed.verdict.headline)
	## Every mark must carry its measurement, since that is the whole promise
	## of the review screen.
	var explained := true
	for line in handed.verdict.lines:
		if line.detail.strip_edges() == "" or not _has_text(_screen("Review"), line.label):
			explained = false
	_check("every mark is shown with its reason", explained)
	_check("there is a way to shoot it again", _find_button(_screen("Review"), "Shoot it again") != null)

func _a_reshoot_keeps_the_better_one() -> void:
	print("shooting it again")
	var first: int = Game.handed[0].verdict.score
	_check("shooting again goes back to the viewfinder", await _press(_screen("Review"), "Shoot it again"))
	_check("and we are holding the camera", main.stage == main.Stage.SHOOTING)

	## Take a deliberately terrible version of the same shot: pointed at the
	## sky, wide open, slow, at the top of the ISO dial. It must not replace a
	## better picture, because a player has to be free to experiment.
	var p := main.photographer as Photographer
	var c := main.camera as CameraBody
	p._pitch = 1.2
	c.rotation.x = 1.2
	c.aperture_index = 0
	c.shutter_index = 0
	c.sensitivity_index = 6
	c.apply_settings()
	await get_tree().create_timer(0.3).timeout
	main._shot_index = 0
	await main._fire()
	await get_tree().create_timer(0.3).timeout

	var kept: int = Game.handed[0].verdict.score
	var bad: int = last_verdict.score if last_verdict else -1
	_check("pointing at the sky scores badly", bad < first,
		"the bad one scored %d against %d" % [bad, first])
	_check("but a worse attempt does not replace a better picture", kept == first,
		"still holding the %d" % kept)
	_check("and the client says what went wrong", last_verdict != null and last_verdict.headline != "",
		"" if last_verdict == null else "\"%s\"" % last_verdict.headline)

func _stand_for_shot(index: int) -> void:
	## Put the camera somewhere the shot is possible, aimed and focused, so the
	## flow check is testing the flow and not the player's aim.
	var shots := Game.current_shots()
	var shot := shots[clampi(index, 0, shots.size() - 1)]
	var target := Vector3.ZERO
	var height := 1.0
	for s in (main.kampung as Kampung).subjects:
		if s.id == shot.subject_id:
			target = s.aim_point()
			height = s.height_m
	## Stand back far enough that the subject fills roughly what was asked for.
	var wanted_fill: float = (shot.fill_min + shot.fill_max) * 0.5
	var c := main.camera as CameraBody
	var distance: float = (height / maxf(wanted_fill, 0.05)) / (2.0 * tan(deg_to_rad(c.field_of_view()) * 0.5))
	var p := main.photographer as Photographer
	var away := Vector3(0.0, 0.0, 1.0) * clampf(distance, 1.2, 24.0)
	p.position = Vector3(target.x + away.x, 0.1, target.z + away.z)
	await get_tree().process_frame
	var eye := p.global_position + Vector3(0.0, Photographer.EYE_HEIGHT, 0.0)
	var flat := Vector3(target.x - eye.x, 0.0, target.z - eye.z)
	p._yaw = atan2(-flat.x, -flat.z)
	p.rotation.y = p._yaw
	p._pitch = atan2(target.y - eye.y, flat.length())
	c.rotation.x = p._pitch
	c.roll_degrees = 0.0
	c.aperture_index = 5
	c.shutter_index = 5
	c.sensitivity_index = 0
	c.focus_distance_m = maxf(eye.distance_to(target), 0.5)
	c.apply_settings()
	await get_tree().create_timer(0.3).timeout

func _finishing_a_brief() -> void:
	print("finishing the brief")
	## Hand in the remaining two shots.
	for index in [1, 2]:
		## Whichever way the review screen offered to move on - the wording
		## changes depending on whether the client accepted the picture.
		var moved := await _press(_screen("Review"), "Next shot")
		if not moved:
			moved = await _press(_screen("Review"), "Move on anyway")
		_check("the review screen offers a way on to shot %d" % (index + 1), moved)
		main.enter(main.Stage.SHOOTING)
		await _stand_for_shot(index)
		main._shot_index = index
		await main._fire()
		await get_tree().create_timer(0.25).timeout
		_check("shot %d was marked" % (index + 1), Game.handed[index] != null,
			"scored %d" % (Game.handed[index].verdict.score if Game.handed[index] else -1))

	var button := _find_button(_screen("Review"), "Hand in the brief")
	if button == null:
		button = _find_button(_screen("Review"), "Hand it in anyway")
	_check("the last shot offers to hand in the brief", button != null,
		"" if button == null else "\"%s\"" % button.text)
	if button:
		button.pressed.emit()
		await get_tree().process_frame
	_check("handing it in shows the contact sheet", main.stage == main.Stage.WRAP and _screen("Wrap").visible)
	_check("all three pictures are on it", _has_text(_screen("Wrap"), Game.current_shots()[0].title)
		and _has_text(_screen("Wrap"), Game.current_shots()[2].title))
	_check("and the client is named on it", _has_text(_screen("Wrap"), Game.current_brief().client.to_upper()))

func _the_next_job() -> void:
	print("the next job")
	var was := Game.brief_index
	_check("there is a next job to take", await _press(_screen("Wrap"), "The next job"))
	_check("it is a different client", Game.brief_index == was + 1,
		Game.current_brief().client)
	_check("its brief is on the screen", main.stage == main.Stage.BRIEFING)
	_check("and nothing has been handed in for it yet", Game.next_unfinished() == 0)
	_check("the new brief's shots are its own", _has_text(_screen("Brief"), Game.current_shots()[0].title),
		Game.current_shots()[0].title)

func _walking_out() -> void:
	print("pausing and leaving")
	await _press(_screen("Brief"), "Go to work")
	_check("the controls are listed in the viewfinder", main.hud.legend.is_visible_in_tree())
	await _key(KEY_2)
	_check("pressing a key lights its row", main.hud.legend.lit_row() == 1, "row %d" % main.hud.legend.lit_row())
	await _key(KEY_ESCAPE)
	_check("Esc in the yard pauses", main.stage == main.Stage.PAUSED and _screen("Pause").visible)
	_check("and gives the mouse back", Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
	await _key(KEY_ESCAPE)
	_check("Esc again goes back to the yard", main.stage == main.Stage.SHOOTING)
	await _key(KEY_ESCAPE)
	_check("the pause menu opens the guide", await _press_named(_screen("Pause"), "Howtoplay") and main.stage == main.Stage.HOW_TO)
	await _key(KEY_ESCAPE)
	_check("which goes back to the pause menu, not the main menu", main.stage == main.Stage.PAUSED)
	_check("leaving the job goes to the main menu", await _press_named(_screen("Pause"), "Leavethejob") and main.stage == main.Stage.TITLE and _screen("Menu").visible)
	_check("and the mouse comes back", Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)

func _the_menus() -> void:
	print("the rest of the menu")
	_check("the first job's best score was saved", Profile.best_score(0) >= 0, "best %d" % Profile.best_score(0))
	await _press_named(_screen("Menu"), "Play")
	_check("and the job board shows it", _has_text(_screen("Jobs"), "BEST"))
	await _key(KEY_ESCAPE)
	_check("Esc on the job board goes back", main.stage == main.Stage.TITLE)

	var kept := Profile.album().size()
	## All three shots of the first job were accepted, and the first was
	## reshot badly after a good take - the album must hold the good one.
	_check("every accepted picture went into the album, the best take of each", kept == 3, "%d kept" % kept)
	_check("the album opens", await _press_named(_screen("Menu"), "Photoalbum") and _screen("Album").visible)
	_check("and shows them", _has_text(_screen("Album"), "photograph"))
	await _key(KEY_ESCAPE)

	_check("the guide opens from the menu", await _press_named(_screen("Menu"), "Howtoplay") and main.stage == main.Stage.HOW_TO)
	var pages := 1
	while (_screen("HowTo") as HowToScreen).page < HowToScreen.PAGES.size() - 1 and pages < 20:
		await _press_named(_screen("HowTo"), "NextPage")
		pages += 1
	_check("it has six pages and they all turn", pages == 6, "%d pages" % pages)
	await _press_named(_screen("HowTo"), "NextPage")
	_check("Done on the last page goes back to the menu", main.stage == main.Stage.TITLE)

	_check("settings open", await _press_named(_screen("Menu"), "Settings") and main.stage == main.Stage.SETTINGS)
	var before: bool = Profile.setting("show_legend")
	await _press_named(_screen("Settings"), "show_legend")
	_check("a toggle saves straight away", bool(Profile.setting("show_legend")) != before)
	await _press_named(_screen("Settings"), "show_legend")
	await _key(KEY_ESCAPE)
	_check("Esc leaves the settings", main.stage == main.Stage.TITLE)
