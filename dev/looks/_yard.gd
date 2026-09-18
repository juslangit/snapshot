extends Node

## Drives the real game, stands the photographer in a few places and saves what
## the camera sees into dev/shots.
##
## Claude cannot see the game, so this is how the art gets checked at all: run
## it, then look at the PNGs. It also proves that the depth of field and the
## exposure a player would get are the ones the code intends, because these are
## the real screens taking real photographs.

const OUT := "res://dev/shots/"

var main: Node3D
var probe: MeterProbe

func _ready() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate() as Node3D
	add_child(main)
	await get_tree().process_frame
	probe = main.get_node_or_null("MeterProbe") as MeterProbe
	await get_tree().process_frame
	_run()

func _run() -> void:
	await _wait(0.4)
	await _shot("01_title")

	main.enter(main.Stage.BRIEFING)
	await _wait(0.3)
	await _shot("02_brief")

	main.enter(main.Stage.SHOOTING)
	await _wait(0.3)

	## Standing in the yard, looking at the house - the first shot of the first
	## brief, at the settings the light was calibrated for.
	await _aim("house", Vector3(1.6, 0.1, 4.2), 28.0, 5, 5, 0)
	await _shot("03_yard_house")

	## The well, close, wide open, so the depth of field is unmistakable.
	await _aim("well", Vector3(-3.0, 0.1, -0.6), 50.0, 0, 9, 0)
	await _shot("04_well_wide_open")

	## The same well stopped right down: if the physical camera is doing its
	## job these two pictures look obviously different behind the subject.
	await _aim("well", Vector3(-3.0, 0.1, -0.6), 50.0, 8, 1, 0)
	await _shot("05_well_stopped_down")

	## Crouched at the steps for the cat.
	await _aim("cat", Vector3(-0.5, 0.1, -1.1), 85.0, 1, 7, 0)
	await _shot("06_cat_close")

	## The kettle on the verandah.
	await _aim("kettle", Vector3(2.4, 0.1, -0.4), 85.0, 1, 7, 0)
	await _shot("07_kettle")

	## The washing, seen through the shed window.
	await _aim("laundry", Vector3(-4.6, 0.1, 6.4), 50.0, 4, 6, 0)
	await _shot("08_laundry_framed")

	## Wide open at a slow shutter on a high ISO: three stops over, washed out,
	## which is the mistake the meter exists to warn about.
	await _aim("house", Vector3(1.6, 0.1, 4.2), 28.0, 0, 0, 6)
	await _shot("09_blown_out")

	## The banana trees, and the hen in the yard.
	await _aim("tree", Vector3(5.0, 0.1, -1.0), 35.0, 5, 5, 0)
	await _shot("10_banana")
	await _aim("hen", Vector3(3.4, 0.1, 2.6), 85.0, 3, 8, 0)
	await _shot("11_hen")

	## Standing in the doorway, shooting out - the view a framed shot is taken
	## from.
	await _aim("laundry", Vector3(0.0, 1.9, -6.0), 35.0, 5, 5, 0)
	await _shot("12_from_doorway")

	## And a photograph taken through the real pipeline, with its review.
	Game.brief_index = 1
	main._shot_index = 1
	await _aim("cat", Vector3(-0.5, 0.1, -1.1), 85.0, 1, 7, 0)
	await main._fire()
	await _wait(0.6)
	await _shot("13_review")

	## A bad photograph of the same cat - too dark, too small, out of focus and
	## tilted - so the review screen is seen with advice on every line, which is
	## its fullest and the one most likely to run off the bottom.
	main.enter(main.Stage.SHOOTING)
	await _wait(0.3)
	await _aim("cat", Vector3(-0.5, 0.1, -1.1), 24.0, 8, 9, 0)
	main.camera.focus_distance_m = 30.0
	main.camera.roll_degrees = 9.0
	main.camera.apply_settings()
	await _wait(0.3)
	await main._fire()
	await _wait(0.6)
	await _shot("13b_review_bad")

	main.enter(main.Stage.WRAP)
	await _wait(0.4)
	await _shot("14_contact_sheet")

	print("shots written to dev/shots")
	get_tree().quit()

## Stand somewhere and point the camera at a named subject, focusing on it the
## way autofocus would. Guessing yaw angles by hand put the well off the side
## of the frame in the first run; asking the scene where a thing is cannot.
func _aim(subject_id: String, where: Vector3, focal: float, aperture: int, shutter: int, iso: int) -> void:
	var p: Photographer = main.photographer as Photographer
	var c: CameraBody = main.camera as CameraBody
	p.position = where
	var target := Vector3.ZERO
	for s in (main.kampung as Kampung).subjects:
		if s.id == subject_id:
			target = s.aim_point()
	await get_tree().process_frame
	var eye := p.global_position + Vector3(0.0, Photographer.EYE_HEIGHT, 0.0)
	var flat := Vector3(target.x - eye.x, 0.0, target.z - eye.z)
	var yaw := atan2(-flat.x, -flat.z)
	p._yaw = yaw
	p.rotation.y = yaw
	var pitch := atan2(target.y - eye.y, flat.length())
	p._pitch = pitch
	c.rotation.x = pitch
	c.focal_length_mm = focal
	c.aperture_index = aperture
	c.shutter_index = shutter
	c.sensitivity_index = iso
	c.roll_degrees = 0.0
	c.focus_distance_m = maxf(eye.distance_to(target), 0.5)
	c.apply_settings()
	await _wait(0.35)

func _stand(where: Vector3, yaw: float, pitch: float, focal: float, aperture: int, shutter: int, iso: int, focus: float) -> void:
	var p: Photographer = main.photographer
	p.position = where
	p.rotation.y = yaw
	p._yaw = yaw
	p._pitch = pitch
	var c: CameraBody = main.camera
	c.rotation.x = pitch
	c.focal_length_mm = focal
	c.aperture_index = aperture
	c.shutter_index = shutter
	c.sensitivity_index = iso
	c.focus_distance_m = focus
	c.roll_degrees = 0.0
	c.apply_settings()
	await _wait(0.35)

func _shot(name_text: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OUT + name_text + ".png"
	image.save_png(ProjectSettings.globalize_path(path))
	var lit: float = probe.read() if probe else 0.0
	print("%-22s metered %.4f  =  %+.2f stops   %s" % [
		name_text, lit, Optics.metered_stops(lit), main.camera.settings_text()])

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
