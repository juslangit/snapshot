extends Node

## Is the morning the brightness the camera says it is?
##
## This is the one check that cannot be done on paper. The arithmetic in
## optics.gd is proven against a depth of field table, but whether the *scene*
## is EV 13 depends on the sun, the sky, the haze and the colour of every wall
## in the yard - and all of those move whenever somebody touches the art. If
## they drift, the dials stop meaning what they say, the meter starts lying,
## and the game quietly teaches the wrong thing.
##
## So: stand where the first brief is shot from, set the camera to f/8 at 1/125
## and ISO 100 - which is EV 13, an hour after sunrise - and the frame must
## come out near middle grey. It also checks the other way round, that being
## three stops off really does look three stops off.

## Where the check stands, and what it points at. Fixed on purpose: a moving
## viewpoint would make the number unrepeatable.
const WHERE := Vector3(1.2, 0.1, 2.4)
## How far off correct the calibration is allowed to drift before this fails.
## Two thirds of a stop - inside what a client accepts, and well inside what
## the eye notices.
const TOLERANCE := 0.67

var failures := 0
var main: Node3D
var probe: MeterProbe

func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	add_child(main)
	await get_tree().process_frame
	probe = main.get_node_or_null("MeterProbe") as MeterProbe
	main.enter(main.Stage.SHOOTING)
	main.hud.visible = false
	await _settle()

	await _correct_exposure()
	await _stops_behave()
	await _the_sun_is_doing_the_work()

	print("")
	if failures == 0:
		print("LIGHT: all checks passed")
	else:
		print("LIGHT: %d FAILED" % failures)
	get_tree().quit(1 if failures > 0 else 0)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok    %s %s" % [label, detail])
	else:
		failures += 1
		print("  FAIL  %s %s" % [label, detail])

func _settle() -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw

## Point the camera at the house from the standard spot and set the dials.
func _look(aperture: int, shutter: int, iso: int) -> float:
	var p := main.photographer as Photographer
	var c := main.camera as CameraBody
	p.position = WHERE
	p._yaw = 0.0
	p.rotation.y = 0.0
	p._pitch = 0.0
	c.rotation.x = 0.0
	c.focal_length_mm = 35.0
	c.aperture_index = aperture
	c.shutter_index = shutter
	c.sensitivity_index = iso
	c.apply_settings()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	return Optics.metered_stops(probe.read())

func _correct_exposure() -> void:
	print("the morning is EV 13")
	## f/8 at 1/125, ISO 100. Aperture index 5 and shutter index 5 are those
	## marks; asserted here so a reordered dial cannot silently move them.
	_check("the dial reads f/8 at 1/125",
		Optics.APERTURE_MARKS[5] == "8" and Optics.SHUTTER_MARKS[5] == "125")
	_check("which is EV 13",
		absf(Optics.exposure_value(Optics.APERTURES[5], Optics.SHUTTERS[5]) - 13.0) < 0.01,
		"EV %.2f" % Optics.exposure_value(Optics.APERTURES[5], Optics.SHUTTERS[5]))

	var stops := await _look(5, 5, 0)
	_check("and the yard exposes correctly at it", absf(stops) <= TOLERANCE,
		"%+.2f stops, allowed %.2f" % [stops, TOLERANCE])

func _stops_behave() -> void:
	print("a stop is a stop on screen, not just on paper")
	var correct := await _look(5, 5, 0)
	## Two stops of aperture wider must read about two stops brighter. If the
	## engine's physical camera were ignoring the aperture this would come back
	## flat, and the "background soft" briefs would be unplayable.
	var wider := await _look(3, 5, 0)
	_check("two stops wider is about two stops brighter", (wider - correct) > 1.2,
		"%+.2f against %+.2f" % [wider, correct])
	## And the shutter must do the same, in the other direction.
	## Not a full two stops, and it should not be: the correctly exposed frame
	## has a clipped sky in it, so darkening the frame recovers highlights as
	## well as losing shadows and the measured average moves by less than the
	## dial did. That is what a real meter does with a bright sky too.
	var faster := await _look(5, 7, 0)
	_check("two stops faster is clearly darker", (faster - correct) < -1.0,
		"%+.2f against %+.2f" % [faster, correct])
	## ISO too, which is the third corner of the triangle.
	var pushed := await _look(5, 7, 2)
	_check("two stops of ISO buys the shutter back", absf(pushed - correct) < 0.8,
		"%+.2f against %+.2f" % [pushed, correct])

func _the_sun_is_doing_the_work() -> void:
	print("the sun, not the sky")
	## An early version of this scene was lit almost entirely by ambient sky,
	## and turning the sun off changed nothing - so there was no direction to
	## the light and "the morning light on it" meant nothing. The sun has to be
	## worth at least a stop of what the camera sees.
	var sun := main.kampung.get_node_or_null("Sun") as DirectionalLight3D
	if sun == null:
		_check("there is a sun", false)
		return
	var lit := await _look(5, 5, 0)
	var was := sun.light_intensity_lux
	sun.light_intensity_lux = 0.0
	var unlit := await _look(5, 5, 0)
	sun.light_intensity_lux = was
	_check("turning the sun off costs at least a stop", (lit - unlit) >= 1.0,
		"%+.2f with the sun, %+.2f without" % [lit, unlit])
	_check("the sun is a plausible morning brightness",
		was >= 8000.0 and was <= 40000.0, "%.0f lux" % was)
