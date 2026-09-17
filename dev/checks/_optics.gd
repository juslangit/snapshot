extends Node

## Does the photography add up?
##
## The numbers in scripts/optics.gd are the ones a photographer would use, so
## they can be checked against answers that exist outside this game: a depth of
## field table, the sunny 16 rule, a hyperfocal chart. That is the point of
## checking them. If the formulas drift, a player who has learned to expose a
## picture here would be learning something untrue.

var failures := 0

func _ready() -> void:
	_exposure_value()
	_sunny_sixteen()
	_iso_trade()
	_depth_of_field()
	_hyperfocal()
	_focus_miss()
	_motion()
	_grain()
	_metering()
	_dials()
	print("")
	if failures == 0:
		print("OPTICS: all checks passed")
	else:
		print("OPTICS: %d FAILED" % failures)
	get_tree().quit(1 if failures > 0 else 0)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok    %s %s" % [label, detail])
	else:
		failures += 1
		print("  FAIL  %s %s" % [label, detail])

func _close(label: String, got: float, want: float, tolerance: float) -> void:
	_check(label, absf(got - want) <= tolerance, "got %.4f, wanted %.4f +- %.4f" % [got, want, tolerance])

func _exposure_value() -> void:
	print("exposure value")
	## f/1.0 at one second is EV 0 by definition.
	_close("f/1 at 1 s is EV 0", Optics.exposure_value(1.0, 1.0), 0.0, 0.001)
	## Every full stop of aperture or shutter is one EV.
	_close("f/1.4 at 1 s is EV 1", Optics.exposure_value(1.4, 1.0), 1.0, 0.03)
	_close("f/8 at 1/125 is EV 13", Optics.exposure_value(8.0, 128.0), 13.0, 0.01)
	_close("f/16 at 1/125 is EV 15", Optics.exposure_value(16.0, 128.0), 15.0, 0.01)
	## Closing the aperture one stop and halving the shutter cancel out - the
	## single most important fact about the exposure triangle.
	var a := Optics.exposure_value(Optics.APERTURES[4], Optics.SHUTTERS[6])
	var b := Optics.exposure_value(Optics.APERTURES[5], Optics.SHUTTERS[5])
	_close("one stop of aperture cancels one stop of shutter", a, b, 0.0001)
	## And it holds all the way along both dials, which is the promise the
	## exposure triangle makes.
	for i in 8:
		var left := Optics.exposure_value(Optics.APERTURES[i], Optics.SHUTTERS[i + 1])
		var right := Optics.exposure_value(Optics.APERTURES[i + 1], Optics.SHUTTERS[i])
		if absf(left - right) > 0.0001:
			failures += 1
			print("  FAIL  f/%s at 1/%s is not f/%s at 1/%s" % [
				Optics.APERTURE_MARKS[i], Optics.SHUTTER_MARKS[i + 1],
				Optics.APERTURE_MARKS[i + 1], Optics.SHUTTER_MARKS[i]])
			return
	print("  ok    every trade along the dials is even")

func _sunny_sixteen() -> void:
	print("the sunny 16 rule")
	## In full sun, f/16 at 1/ISO is correct - EV 15 at ISO 100.
	_close("f/16, 1/125, ISO 100 in full sun", Optics.exposure_offset_stops(16.0, 128.0, 100.0, 15.0), 0.0, 0.01)
	## And the equivalents of it are equally correct.
	_close("f/11, 1/250 is the same exposure", Optics.exposure_offset_stops(Optics.APERTURES[6], 256.0, 100.0, 15.0), 0.0, 0.01)
	_close("f/8, 1/500 is the same exposure", Optics.exposure_offset_stops(8.0, 512.0, 100.0, 15.0), 0.0, 0.01)
	## Shooting a sunny scene at the settings for an overcast one blows it out.
	_close("full sun at overcast settings is 3 stops over", Optics.exposure_offset_stops(16.0, 128.0, 100.0, 18.0), 3.0, 0.01)

func _iso_trade() -> void:
	print("what ISO buys")
	## Doubling ISO is worth exactly one stop of light.
	var at_100 := Optics.exposure_offset_stops(8.0, 128.0, 100.0, 13.0)
	var at_200 := Optics.exposure_offset_stops(8.0, 128.0, 200.0, 13.0)
	_close("ISO 200 is one stop brighter than ISO 100", at_200 - at_100, 1.0, 0.02)
	var at_1600 := Optics.exposure_offset_stops(8.0, 128.0, 1600.0, 13.0)
	_close("ISO 1600 is four stops brighter", at_1600 - at_100, 4.0, 0.02)

func _depth_of_field() -> void:
	print("depth of field")
	## Checked against a standard full-frame depth of field table: a 50 mm lens
	## at f/8 focused at 5 m is sharp from about 3.4 m to about 9.2 m.
	var band := Optics.depth_of_field_m(50.0, 8.0, 5.0)
	_close("50 mm f/8 at 5 m - near edge", band.x, 3.43, 0.08)
	_close("50 mm f/8 at 5 m - far edge", band.y, 9.25, 0.25)

	## Opening up makes the band narrower. This is the whole of the "blur the
	## background" lesson in one assertion.
	var wide := Optics.depth_of_field_m(50.0, 1.4, 5.0)
	var narrow := Optics.depth_of_field_m(50.0, 16.0, 5.0)
	_check("f/1.4 gives a thinner band than f/16",
		(wide.y - wide.x) < (narrow.y - narrow.x),
		"f/1.4 spans %.2f m, f/16 spans %s" % [wide.y - wide.x, "the horizon" if narrow.y == INF else "%.2f m" % (narrow.y - narrow.x)])

	## A longer lens at the same aperture and distance is also thinner, which
	## is why a portrait lens separates a face from a wall.
	var short_lens := Optics.depth_of_field_m(28.0, 4.0, 3.0)
	var long_lens := Optics.depth_of_field_m(85.0, 4.0, 3.0)
	_check("85 mm separates more than 28 mm",
		(long_lens.y - long_lens.x) < (short_lens.y - short_lens.x),
		"85 mm spans %.2f m, 28 mm spans %s" % [long_lens.y - long_lens.x, "the horizon" if short_lens.y == INF else "%.2f m" % (short_lens.y - short_lens.x)])

	## Focusing at or past the hyperfocal distance reaches the horizon.
	var h := Optics.hyperfocal_m(35.0, 11.0)
	var far_band := Optics.depth_of_field_m(35.0, 11.0, h + 1.0)
	_check("focused past hyperfocal, the far edge is the horizon", far_band.y == INF,
		"hyperfocal is %.2f m" % h)

func _hyperfocal() -> void:
	print("hyperfocal distance")
	## Standard values for full frame: 35 mm at f/11 is about 3.85 m; 24 mm at
	## f/16 is about 1.27 m.
	_close("35 mm at f/11", Optics.hyperfocal_m(35.0, 11.0), 3.87, 0.12)
	_close("24 mm at f/16", Optics.hyperfocal_m(24.0, 16.0), 1.26, 0.06)
	## And the half-of-hyperfocal rule: the near edge lands there.
	var h := Optics.hyperfocal_m(35.0, 11.0)
	var band := Optics.depth_of_field_m(35.0, 11.0, h)
	_close("focused at hyperfocal, near edge is half of it", band.x, h * 0.5, 0.06)

func _focus_miss() -> void:
	print("how badly out of focus")
	_close("a subject inside the band is a clean zero", Optics.focus_miss(50.0, 8.0, 5.0, 5.0), 0.0, 0.0001)
	_close("the near edge is still sharp", Optics.focus_miss(50.0, 8.0, 5.0, 3.5), 0.0, 0.0001)
	_check("closer than the near edge misses", Optics.focus_miss(50.0, 8.0, 5.0, 1.2) > 0.0)
	_check("further than the far edge misses", Optics.focus_miss(50.0, 8.0, 5.0, 40.0) > 0.0)
	_check("a bigger mistake scores worse",
		Optics.focus_miss(50.0, 2.0, 5.0, 30.0) > Optics.focus_miss(50.0, 2.0, 5.0, 8.0))

func _motion() -> void:
	print("motion")
	## A hen at one metre per second travels 8 mm during 1/125 s.
	_close("1 m/s for 1/125 s", Optics.motion_travel_m(1.0, 125.0), 0.008, 0.0001)
	_check("a faster shutter travels less",
		Optics.motion_travel_m(1.0, 1000.0) < Optics.motion_travel_m(1.0, 60.0))

func _grain() -> void:
	print("grain")
	_close("ISO 100 is clean", Optics.grain_amount(100.0), 0.0, 0.001)
	_check("ISO 6400 is grainy", Optics.grain_amount(6400.0) > 0.5,
		"%.2f" % Optics.grain_amount(6400.0))
	_check("grain only ever grows with ISO",
		Optics.grain_amount(400.0) > Optics.grain_amount(200.0)
		and Optics.grain_amount(3200.0) > Optics.grain_amount(1600.0))

func _metering() -> void:
	print("the light meter")
	_close("middle grey reads as correct", Optics.metered_stops(Optics.MIDDLE_GREY), 0.0, 0.0001)
	_close("twice as bright is one stop over", Optics.metered_stops(Optics.MIDDLE_GREY * 2.0), 1.0, 0.001)
	_close("half as bright is one stop under", Optics.metered_stops(Optics.MIDDLE_GREY * 0.5), -1.0, 0.001)
	_check("black does not crash the meter", Optics.metered_stops(0.0) < -10.0)

func _dials() -> void:
	print("the dials")
	_check("apertures are a full-stop ladder", Optics.APERTURES.size() == 9)
	for i in Optics.APERTURES.size() - 1:
		var step: float = log(Optics.APERTURES[i + 1] / Optics.APERTURES[i]) / log(2.0)
		if absf(step - 0.5) > 0.06:
			failures += 1
			print("  FAIL  f/%.1f to f/%.1f is %.2f stops, should be half a stop of area" % [
				Optics.APERTURES[i], Optics.APERTURES[i + 1], step * 2.0])
			return
	print("  ok    every aperture step is one stop of light")
	for i in Optics.SHUTTERS.size() - 1:
		var ratio: float = Optics.SHUTTERS[i + 1] / Optics.SHUTTERS[i]
		if absf(ratio - 2.0) > 0.12:
			failures += 1
			print("  FAIL  1/%d to 1/%d is not one stop" % [roundi(Optics.SHUTTERS[i]), roundi(Optics.SHUTTERS[i + 1])])
			return
	print("  ok    every shutter step is one stop of light")
	_check("nearest stop snaps to the dial", Optics.nearest_stop(Optics.APERTURES, 5.7) == 4,
		"f/5.7 snaps to f/%s" % Optics.aperture_mark(5.7))
	_check("the dial marks read like a camera",
		Optics.aperture_mark(11.313708) == "11" and Optics.shutter_mark(128.0) == "125",
		"f/11.31 prints as f/%s, 1/128 s prints as 1/%s" % [Optics.aperture_mark(11.313708), Optics.shutter_mark(128.0)])
