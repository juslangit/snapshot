extends Node

## Does the marking behave like a client?
##
## The judge is the part of this game that can most easily be unfair without
## anyone noticing, because a photograph is subjective and a number looks
## objective. So the checks here are about the shape of the marking rather than
## exact totals: a shot that meets the brief must beat one that does not, a
## near miss must beat a bad miss, and no honest attempt may ever score zero
## for a reason the review screen cannot name.

var failures := 0

func _ready() -> void:
	_missing_subject()
	_a_good_photograph()
	_framing()
	_focus()
	_exposure()
	_shallow()
	_deep()
	_freeze()
	_clean()
	_framed()
	_level()
	_every_line_explains_itself()
	print("")
	if failures == 0:
		print("JUDGE: all checks passed")
	else:
		print("JUDGE: %d FAILED" % failures)
	get_tree().quit(1 if failures > 0 else 0)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok    %s %s" % [label, detail])
	else:
		failures += 1
		print("  FAIL  %s %s" % [label, detail])

## A photograph that does everything right, as the baseline everything else is
## compared against.
func _good_reading() -> Judge.Reading:
	var r := Judge.Reading.new()
	r.subject_id = "cat"
	r.subject_name = "the cat"
	r.in_frame = true
	r.visible_fraction = 1.0
	r.fill = 0.45
	r.screen_offset = Vector2(-1.0 / 3.0, 1.0 / 3.0)
	r.distance_m = 3.0
	r.background_m = 30.0
	r.roll_degrees = 0.2
	r.framed_through = false
	r.measured_luminance = Optics.MIDDLE_GREY
	r.aperture = Optics.APERTURES[5]
	r.shutter = Optics.SHUTTERS[5]
	r.sensitivity = 100.0
	r.focus_distance_m = 3.0
	r.focal_length_mm = 50.0
	r.viewport_height_px = 1080.0
	r.fov_degrees = 27.0
	r.subject_speed = 0.0
	return r

func _shot(demand: String = "") -> Brief.Shot:
	var s := Brief.Shot.new()
	s.subject_id = "cat"
	s.title = "The cat"
	s.note = "A picture of the cat."
	s.fill_min = 0.25
	s.fill_max = 0.70
	s.demand = demand
	s.stops_tolerance = 1.0
	return s

func _missing_subject() -> void:
	print("a subject that is not there")
	var r := _good_reading()
	r.in_frame = false
	var v := Judge.mark(_shot(), r)
	_check("scores nothing", v.score == 0, "scored %d" % v.score)
	_check("is rejected", v.rejected)
	_check("says which subject was missed", v.headline.contains("cat"), "\"%s\"" % v.headline)

	## Half hidden behind the well is half a photograph, not none of one.
	var half := _good_reading()
	half.visible_fraction = 0.4
	var half_verdict := Judge.mark(_shot(), half)
	_check("half hidden still scores something", half_verdict.score > 0 and half_verdict.score < Judge.mark(_shot(), _good_reading()).score,
		"scored %d against %d" % [half_verdict.score, Judge.mark(_shot(), _good_reading()).score])

func _a_good_photograph() -> void:
	print("a photograph that meets the brief")
	var v := Judge.mark(_shot(), _good_reading())
	_check("is worth printing", v.used(), "scored %d" % v.score)
	_check("is accepted", v.accepted())
	_check("is not rejected", not v.rejected)
	var total := 0.0
	for line in v.lines:
		total += line.out_of
	_check("the marks add up to 100", absf(total - 100.0) < 0.01, "they add up to %.0f" % total)

	## And with a demand attached the total is still 100, so briefs are
	## comparable with each other.
	var with_demand := Judge.mark(_shot("shallow"), _good_reading())
	var demand_total := 0.0
	for line in with_demand.lines:
		demand_total += line.out_of
	_check("a brief with a demand also adds up to 100", absf(demand_total - 100.0) < 0.01,
		"they add up to %.0f" % demand_total)

func _framing() -> void:
	print("how big the subject sits")
	var right := Judge.mark(_shot(), _good_reading())
	var too_far := _good_reading()
	too_far.fill = 0.06
	var far_verdict := Judge.mark(_shot(), too_far)
	_check("standing too far back loses marks", far_verdict.score < right.score,
		"%d against %d" % [far_verdict.score, right.score])
	_check("and says so", far_verdict.lines[1].detail.contains("too far away"),
		"\"%s\"" % far_verdict.lines[1].detail)

	var too_close := _good_reading()
	too_close.fill = 1.4
	var close_verdict := Judge.mark(_shot(), too_close)
	_check("standing too close loses marks", close_verdict.score < right.score,
		"%d against %d" % [close_verdict.score, right.score])
	_check("and says so", close_verdict.lines[1].detail.contains("too close"),
		"\"%s\"" % close_verdict.lines[1].detail)

	## A near miss must beat a bad miss, or the player learns nothing from
	## trying again.
	var nearly := _good_reading()
	nearly.fill = 0.22
	_check("a near miss beats a bad miss",
		Judge.mark(_shot(), nearly).score > far_verdict.score,
		"%d against %d" % [Judge.mark(_shot(), nearly).score, far_verdict.score])

func _focus() -> void:
	print("focus")
	var sharp := Judge.mark(_shot(), _good_reading())
	var soft := _good_reading()
	soft.focus_distance_m = 25.0
	var soft_verdict := Judge.mark(_shot(), soft)
	_check("focusing past the subject loses marks", soft_verdict.score < sharp.score,
		"%d against %d" % [soft_verdict.score, sharp.score])
	_check("the detail names the sharp band", soft_verdict.lines[2].detail.contains("outside the sharp band"),
		"\"%s\"" % soft_verdict.lines[2].detail)

	## Stopping down rescues a focus mistake, exactly as it would in life.
	var stopped := _good_reading()
	stopped.focus_distance_m = 5.0
	stopped.aperture = Optics.APERTURES[8]
	var open := _good_reading()
	open.focus_distance_m = 5.0
	open.aperture = Optics.APERTURES[0]
	_check("a small aperture forgives a focus mistake",
		Judge.mark(_shot(), stopped).score > Judge.mark(_shot(), open).score,
		"f/22 scored %d, f/1.4 scored %d" % [Judge.mark(_shot(), stopped).score, Judge.mark(_shot(), open).score])

func _exposure() -> void:
	print("exposure")
	var correct := Judge.mark(_shot(), _good_reading())
	var dark := _good_reading()
	dark.measured_luminance = Optics.MIDDLE_GREY / 8.0
	var bright := _good_reading()
	bright.measured_luminance = Optics.MIDDLE_GREY * 8.0
	var dark_verdict := Judge.mark(_shot(), dark)
	var bright_verdict := Judge.mark(_shot(), bright)
	_check("three stops under loses marks", dark_verdict.score < correct.score,
		"%d against %d" % [dark_verdict.score, correct.score])
	_check("three stops over loses marks", bright_verdict.score < correct.score,
		"%d against %d" % [bright_verdict.score, correct.score])
	_check("under is described as dark", dark_verdict.lines[3].detail.contains("under"),
		"\"%s\"" % dark_verdict.lines[3].detail)
	_check("over is described as washed out", bright_verdict.lines[3].detail.contains("over"),
		"\"%s\"" % bright_verdict.lines[3].detail)

	## Within the tolerance the client does not notice, which is what makes the
	## meter's green band honest.
	var slight := _good_reading()
	slight.measured_luminance = Optics.MIDDLE_GREY * 1.6
	_check("two thirds of a stop is still full marks",
		Judge.mark(_shot(), slight).lines[3].points >= 19.99,
		"%.1f of 20" % Judge.mark(_shot(), slight).lines[3].points)

func _shallow() -> void:
	print("a soft background")
	var shot := _shot("shallow")
	var wide := _good_reading()
	wide.aperture = Optics.APERTURES[0]
	var narrow := _good_reading()
	narrow.aperture = Optics.APERTURES[8]
	var wide_line: Judge.Line = Judge.mark(shot, wide).lines[5]
	var narrow_line: Judge.Line = Judge.mark(shot, narrow).lines[5]
	_check("f/1.4 earns the soft background", wide_line.points >= 9.5,
		"%.1f of 10 - %s" % [wide_line.points, wide_line.detail])
	_check("f/22 does not", narrow_line.points <= 2.0,
		"%.1f of 10 - %s" % [narrow_line.points, narrow_line.detail])
	_check("and tells the player to open up", narrow_line.detail.contains("open the aperture"),
		"\"%s\"" % narrow_line.detail)

	## A subject with nothing behind it cannot have a soft background, however
	## wide the aperture - which is a real lesson about where to stand.
	var flat := _good_reading()
	flat.aperture = Optics.APERTURES[0]
	flat.background_m = flat.distance_m + 0.05
	_check("a background right behind the subject stays sharp",
		Judge.mark(shot, flat).lines[5].points < wide_line.points,
		"%.1f against %.1f" % [Judge.mark(shot, flat).lines[5].points, wide_line.points])

func _deep() -> void:
	print("sharp front to back")
	var shot := _shot("deep")
	var stopped := _good_reading()
	stopped.aperture = Optics.APERTURES[7]
	stopped.focal_length_mm = 28.0
	stopped.focus_distance_m = 6.0
	stopped.background_m = 40.0
	var wide := _good_reading()
	wide.aperture = Optics.APERTURES[0]
	wide.focal_length_mm = 85.0
	wide.background_m = 40.0
	_check("f/16 on a wide lens gets the marks", Judge.mark(shot, stopped).lines[5].points >= 9.0,
		"%.1f of 10 - %s" % [Judge.mark(shot, stopped).lines[5].points, Judge.mark(shot, stopped).lines[5].detail])
	_check("f/1.4 on a long lens does not", Judge.mark(shot, wide).lines[5].points < 6.0,
		"%.1f of 10 - %s" % [Judge.mark(shot, wide).lines[5].points, Judge.mark(shot, wide).lines[5].detail])

func _freeze() -> void:
	print("stopping movement")
	var shot := _shot("freeze")
	var fast := _good_reading()
	fast.subject_speed = 1.2
	fast.shutter = Optics.SHUTTERS[9]
	var slow := _good_reading()
	slow.subject_speed = 1.2
	slow.shutter = Optics.SHUTTERS[0]
	_check("1/2000 freezes the hen", Judge.mark(shot, fast).lines[5].points >= 9.0,
		"%.1f of 10 - %s" % [Judge.mark(shot, fast).lines[5].points, Judge.mark(shot, fast).lines[5].detail])
	_check("1/4 does not", Judge.mark(shot, slow).lines[5].points <= 1.0,
		"%.1f of 10 - %s" % [Judge.mark(shot, slow).lines[5].points, Judge.mark(shot, slow).lines[5].detail])
	_check("and suggests a faster shutter", Judge.mark(shot, slow).lines[5].detail.contains("faster shutter"))

	## Something standing still cannot be blurred, whatever the shutter does.
	var still := _good_reading()
	still.subject_speed = 0.0
	still.shutter = Optics.SHUTTERS[0]
	_check("a still subject is frozen at any shutter", Judge.mark(shot, still).lines[5].points >= 9.99,
		"%.1f of 10" % Judge.mark(shot, still).lines[5].points)

func _clean() -> void:
	print("grain")
	var shot := _shot("clean")
	var low := _good_reading()
	low.sensitivity = 100.0
	var high := _good_reading()
	high.sensitivity = 6400.0
	_check("ISO 100 is clean", Judge.mark(shot, low).lines[5].points >= 9.99,
		"%.1f of 10" % Judge.mark(shot, low).lines[5].points)
	_check("ISO 6400 is not", Judge.mark(shot, high).lines[5].points <= 0.5,
		"%.1f of 10 - %s" % [Judge.mark(shot, high).lines[5].points, Judge.mark(shot, high).lines[5].detail])

func _framed() -> void:
	print("framed by something")
	var shot := _shot("framed")
	var through := _good_reading()
	through.framed_through = true
	_check("shooting through the window earns it", Judge.mark(shot, through).lines[5].points >= 9.99)
	_check("shooting round it does not", Judge.mark(shot, _good_reading()).lines[5].points <= 0.01)
	_check("and says where to try", Judge.mark(shot, _good_reading()).lines[5].detail.contains("window"),
		"\"%s\"" % Judge.mark(shot, _good_reading()).lines[5].detail)

func _level() -> void:
	print("a straight horizon")
	var shot := _shot("level")
	var straight := _good_reading()
	straight.roll_degrees = 0.4
	var tilted := _good_reading()
	tilted.roll_degrees = 18.0
	_check("level earns the marks", Judge.mark(shot, straight).lines[5].points >= 9.99)
	_check("eighteen degrees of tilt does not", Judge.mark(shot, tilted).lines[5].points <= 0.01,
		"%.1f of 10" % Judge.mark(shot, tilted).lines[5].points)
	_check("composition notices the tilt too",
		Judge.mark(_shot(), tilted).lines[4].detail.contains("tilted"),
		"\"%s\"" % Judge.mark(_shot(), tilted).lines[4].detail)

func _every_line_explains_itself() -> void:
	print("every mark can be explained")
	## The promise this game makes to a player is that a score always comes
	## with a reason. That is worth asserting across every demand, because an
	## empty detail line is a silent shrug.
	var demands := ["", "shallow", "deep", "freeze", "clean", "framed", "level"]
	var bad := 0
	for demand in demands:
		for reading in [_good_reading(), _wrecked_reading()]:
			var v := Judge.mark(_shot(demand), reading)
			for line in v.lines:
				if line.label.strip_edges() == "" or line.detail.strip_edges() == "":
					bad += 1
					print("  FAIL  demand '%s' left a line with no explanation" % demand)
			if v.headline.strip_edges() == "":
				bad += 1
				print("  FAIL  demand '%s' produced no headline" % demand)
	failures += bad
	if bad == 0:
		print("  ok    all %d demands explain every mark, good shot and bad" % demands.size())

func _wrecked_reading() -> Judge.Reading:
	var r := _good_reading()
	r.fill = 0.02
	r.focus_distance_m = 80.0
	r.measured_luminance = Optics.MIDDLE_GREY * 20.0
	r.roll_degrees = 24.0
	r.sensitivity = 6400.0
	r.subject_speed = 3.0
	r.shutter = Optics.SHUTTERS[0]
	r.aperture = Optics.APERTURES[8]
	r.visible_fraction = 0.3
	return r
