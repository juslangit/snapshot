extends Node3D

## The whole game's flow, in one small state machine.
##
## The main menu and its screens (jobs, album, guide, settings), then the
## client's letter, then the yard with a camera in your hands, then the
## photograph and what they made of it - with a pause menu over the yard. Everything the player can
## reach is built here so that dev/checks/_flow.gd can drive the real screens
## rather than a rehearsal of them.

## TITLE is the main menu.
enum Stage { TITLE, JOBS, ALBUM, HOW_TO, SETTINGS, PAUSED, BRIEFING, SHOOTING, REVIEW, WRAP }

## The screens the yard drifts slowly behind.
const MENU_STAGES := [Stage.TITLE, Stage.JOBS, Stage.ALBUM, Stage.HOW_TO, Stage.SETTINGS]

const SPAWN := Vector3(2.4, 0.1, 5.2)

var stage: Stage = Stage.TITLE
var kampung: Kampung
var photographer: Photographer
var camera: CameraBody
var hud: Hud
var probe: MeterProbe

var _menu: MenuScreen
var _jobs: JobsScreen
var _album: AlbumScreen
var _how_to: HowToScreen
var _settings: SettingsScreen
var _pause: PauseScreen
## Where the guide and the settings go back to: the main menu, or the pause
## menu if they were opened from the yard.
var _return_stage: Stage = Stage.TITLE
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

	Profile.apply_settings()
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

	_menu = MenuScreen.new()
	_menu.name = "Menu"
	_menu.play_pressed.connect(func() -> void: enter(Stage.JOBS))
	_menu.album_pressed.connect(func() -> void: enter(Stage.ALBUM))
	_menu.how_to_pressed.connect(func() -> void: _open_side(Stage.HOW_TO, Stage.TITLE))
	_menu.settings_pressed.connect(func() -> void: _open_side(Stage.SETTINGS, Stage.TITLE))
	_layer.add_child(_menu)

	_jobs = JobsScreen.new()
	_jobs.name = "Jobs"
	_jobs.job_chosen.connect(_on_job_chosen)
	_jobs.back_pressed.connect(func() -> void: enter(Stage.TITLE))
	_layer.add_child(_jobs)

	_album = AlbumScreen.new()
	_album.name = "Album"
	_album.back_pressed.connect(func() -> void: enter(Stage.TITLE))
	_layer.add_child(_album)

	_how_to = HowToScreen.new()
	_how_to.name = "HowTo"
	_how_to.back_pressed.connect(func() -> void: enter(_return_stage))
	_layer.add_child(_how_to)

	_settings = SettingsScreen.new()
	_settings.name = "Settings"
	_settings.back_pressed.connect(func() -> void: enter(_return_stage))
	_layer.add_child(_settings)

	_pause = PauseScreen.new()
	_pause.name = "Pause"
	_pause.resume_pressed.connect(func() -> void: enter(Stage.SHOOTING))
	_pause.how_to_pressed.connect(func() -> void: _open_side(Stage.HOW_TO, Stage.PAUSED))
	_pause.settings_pressed.connect(func() -> void: _open_side(Stage.SETTINGS, Stage.PAUSED))
	_pause.leave_pressed.connect(func() -> void: enter(Stage.TITLE))
	_layer.add_child(_pause)

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
	_wrap.menu_pressed.connect(func() -> void: enter(Stage.TITLE))
	_layer.add_child(_wrap)

# ---------------------------------------------------------------------------
# Stages
# ---------------------------------------------------------------------------

func enter(next: Stage) -> void:
	var from := stage
	stage = next
	_menu.visible = next == Stage.TITLE
	_jobs.visible = next == Stage.JOBS
	_album.visible = next == Stage.ALBUM
	_how_to.visible = next == Stage.HOW_TO
	_settings.visible = next == Stage.SETTINGS
	_pause.visible = next == Stage.PAUSED
	_brief.visible = next == Stage.BRIEFING
	_review.visible = next == Stage.REVIEW
	_wrap.visible = next == Stage.WRAP
	hud.visible = next == Stage.SHOOTING
	photographer.look_enabled = next == Stage.SHOOTING

	if next == Stage.SHOOTING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Sound.start_ambience()
		hud.show_shot(_shot_index)
		hud.legend.visible = bool(Profile.setting("show_legend"))
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	match next:
		Stage.TITLE:
			if from not in MENU_STAGES:
				_stand_at_the_gate()
			_menu.focus_first()
		Stage.JOBS:
			_jobs.refresh(Game.briefs)
		Stage.ALBUM:
			_album.refresh()
		Stage.HOW_TO:
			_how_to.open()
		Stage.SETTINGS:
			_settings.refresh()
		Stage.PAUSED:
			_pause.focus_first()
		Stage.BRIEFING:
			_brief.show_brief(Game.current_brief())
		Stage.WRAP:
			var best := Profile.record_score(Game.brief_index, Game.brief_score())
			_wrap.show_sheet(Game.current_brief(), Game.handed, not Game.is_last_brief(), best)

## The guide and the settings can be opened from the main menu or from the
## pause menu, and go back to whichever it was.
func _open_side(side: Stage, back_to: Stage) -> void:
	_return_stage = back_to
	enter(side)

## Back where a job starts, facing the house, with a fresh camera - used when
## a job begins and when the player leaves one for the menu.
func _stand_at_the_gate() -> void:
	photographer.position = SPAWN
	photographer._yaw = 0.0
	photographer.rotation.y = 0.0
	photographer._pitch = 0.0
	camera.rotation.x = 0.0

func _on_job_chosen(index: int) -> void:
	Game.start_brief(index)
	_shot_index = 0
	_stand_at_the_gate()
	hud.set_grid(bool(Profile.setting("grid")))
	enter(Stage.BRIEFING)

func _on_keep() -> void:
	## The album keeps the picture the client is keeping - the best attempt at
	## this shot, not the last one - once the player moves on from it, and only
	## if it was accepted.
	var index := clampi(_shot_index, 0, Game.current_shots().size() - 1)
	var kept: Game.Handed = Game.handed[index]
	if kept and kept.verdict.accepted():
		Profile.keep_photo(kept.photo, Game.current_brief().client, Game.current_shots()[index].title, kept.verdict.score, kept.settings)

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
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_ESCAPE and stage != Stage.SHOOTING:
		_escape()
		return
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
			KEY_ESCAPE: enter(Stage.PAUSED)
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
	if stage in MENU_STAGES:
		## Behind the menus the camera turns slowly on the spot, so the yard
		## goes by like the opening of a film.
		photographer._yaw += delta * 0.05
		photographer.rotation.y = photographer._yaw
		camera.rotation.x = deg_to_rad(4.0)
		return
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

## Esc anywhere but the yard means "back".
func _escape() -> void:
	match stage:
		Stage.PAUSED:
			enter(Stage.SHOOTING)
		Stage.JOBS:
			enter(Stage.TITLE)
		Stage.ALBUM:
			if _album.is_viewing():
				_album.close_viewer()
			else:
				enter(Stage.TITLE)
		Stage.HOW_TO, Stage.SETTINGS:
			enter(_return_stage)
		Stage.BRIEFING:
			enter(Stage.JOBS)
