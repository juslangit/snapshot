extends Node3D

## The whole game's flow, in one small state machine.
##
## Title, then the client's letter, then the yard with a camera in your hands,
## then the photograph and what they made of it. Everything the player can
## reach is built here so that dev/checks/_flow.gd can drive the real screens
## rather than a rehearsal of them.

enum Stage { TITLE, BRIEFING, SHOOTING, REVIEW, WRAP }

const SPAWN := Vector3(2.4, 0.1, 5.2)

var stage: Stage = Stage.TITLE
var kampung: Kampung
var photographer: Photographer
var camera: CameraBody
var hud: Hud
var probe: MeterProbe

var _title: TitleScreen
var _brief: BriefScreen
var _review: ReviewScreen
var _wrap: WrapScreen
var _layer: CanvasLayer
var _shot_index: int = 0
var _last_photo: Image
var _meter_clock: float = 0.0

func _ready() -> void:
	kampung = Kampung.new()
	kampung.name = "Kampung"
	add_child(kampung)

	_build_photographer()
	_build_screens()

	probe = MeterProbe.new()
	probe.name = "MeterProbe"
	add_child(probe)
	probe.watch(camera)

	enter(Stage.TITLE)

func _build_photographer() -> void:
	photographer = Photographer.new()
	photographer.name = "Photographer"
	photographer.position = SPAWN
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.7
	capsule.radius = 0.32
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.85, 0.0)
	photographer.add_child(shape)

	camera = CameraBody.new()
	camera.name = "Camera"
	camera.position = Vector3(0.0, Photographer.EYE_HEIGHT, 0.0)
	camera.current = true
	photographer.add_child(camera)
	add_child(photographer)

func _build_screens() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "Screens"
	add_child(_layer)

	hud = Hud.new()
	hud.name = "Hud"
	hud.camera = camera
	_layer.add_child(hud)

	_title = TitleScreen.new()
	_title.name = "Title"
	_title.start_pressed.connect(_on_start)
	_layer.add_child(_title)

	_brief = BriefScreen.new()
	_brief.name = "Brief"
	_brief.go_pressed.connect(func() -> void: enter(Stage.SHOOTING))
	_layer.add_child(_brief)

	_review = ReviewScreen.new()
	_review.name = "Review"
	_review.reshoot_pressed.connect(func() -> void: enter(Stage.SHOOTING))
	_review.next_pressed.connect(_on_keep)
	_layer.add_child(_review)

	_wrap = WrapScreen.new()
	_wrap.name = "Wrap"
	_wrap.next_pressed.connect(_on_next_brief)
	_layer.add_child(_wrap)

# ---------------------------------------------------------------------------
# Stages
# ---------------------------------------------------------------------------

func enter(next: Stage) -> void:
	stage = next
	_title.visible = next == Stage.TITLE
	_brief.visible = next == Stage.BRIEFING
	_review.visible = next == Stage.REVIEW
	_wrap.visible = next == Stage.WRAP
	hud.visible = next == Stage.SHOOTING
	photographer.look_enabled = next == Stage.SHOOTING

	if next == Stage.SHOOTING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Sound.start_ambience()
		hud.show_shot(_shot_index)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	match next:
		Stage.BRIEFING:
			_brief.show_brief(Game.current_brief())
		Stage.WRAP:
			_wrap.show_sheet(Game.current_brief(), Game.handed, not Game.is_last_brief())

func _on_start() -> void:
	_shot_index = 0
	enter(Stage.BRIEFING)

func _on_keep() -> void:
	## Move to the first shot the client has not accepted; if they have taken
	## everything, the brief is done.
	var shots := Game.current_shots()
	if _shot_index + 1 < shots.size():
		_shot_index += 1
		enter(Stage.SHOOTING)
		return
	var unfinished := Game.next_unfinished()
	if unfinished >= 0 and Game.handed[unfinished] == null:
		_shot_index = unfinished
		enter(Stage.SHOOTING)
		return
	enter(Stage.WRAP)

func _on_next_brief() -> void:
	if Game.advance_brief():
		_shot_index = 0
		enter(Stage.BRIEFING)
	else:
		enter(Stage.TITLE)
		Game.reset()

# ---------------------------------------------------------------------------
# The camera in the player's hands
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if stage != Stage.SHOOTING:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var handled := true
		match (event as InputEventKey).physical_keycode:
			KEY_1: camera.nudge_aperture(-1)
			KEY_2: camera.nudge_aperture(1)
			KEY_3: camera.nudge_shutter(-1)
			KEY_4: camera.nudge_shutter(1)
			KEY_5: camera.nudge_sensitivity(-1)
			KEY_6: camera.nudge_sensitivity(1)
			KEY_BRACKETLEFT: camera.nudge_focus(-1)
			KEY_BRACKETRIGHT: camera.nudge_focus(1)
			KEY_F: camera.focus_on_centre()
			KEY_G: hud.set_grid(not hud.grid_on())
			KEY_TAB: _cycle_shot()
			KEY_ESCAPE: enter(Stage.TITLE)
			_: handled = false
		if handled:
			if (event as InputEventKey).physical_keycode != KEY_ESCAPE:
				Sound.play("dial", -8.0)
			return

	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				camera.nudge_focal_length(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				camera.nudge_focal_length(-1)
			MOUSE_BUTTON_LEFT:
				_fire()

func _cycle_shot() -> void:
	var shots := Game.current_shots()
	_shot_index = (_shot_index + 1) % maxi(shots.size(), 1)
	hud.show_shot(_shot_index)

func _process(delta: float) -> void:
	if stage != Stage.SHOOTING:
		return
	## The meter is read three times a second off the probe view, which is
	## often enough to feel live and rare enough to be free.
	Sound.crow_occasionally(delta)
	_meter_clock += delta
	if _meter_clock >= 0.33:
		_meter_clock = 0.0
		hud.set_meter(Optics.metered_stops(probe.read()))

func _fire() -> void:
	var shots := Game.current_shots()
	if shots.is_empty():
		return
	var shot := shots[clampi(_shot_index, 0, shots.size() - 1)]
	Sound.play("shutter")
	hud.blink(minf(1.0 / camera.shutter() * 2.0, 0.5))
	var result: Dictionary = await camera.take_photo(kampung.subjects, [hud])
	if result.is_empty():
		return
	var readings: Dictionary = result["readings"]
	var reading: Judge.Reading = readings.get(shot.subject_id)
	if reading == null:
		reading = Judge.Reading.new()
		reading.subject_name = shot.subject_id
	var verdict := Judge.mark(shot, reading)
	_last_photo = result["photo"]
	Game.hand_in(_shot_index, verdict, _last_photo, camera.settings_text())
	_review.show_verdict(verdict, _last_photo, camera.settings_text(), _shot_index + 1 >= shots.size())
	enter(Stage.REVIEW)
