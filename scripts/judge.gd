class_name Judge
extends RefCounted

## Marks one photograph against one line of a brief.
##
## The rule this file follows is that a score must always be explainable by a
## number the player set. Every line the review screen prints comes back from
## here with the measurement attached - "the cat at 6.2 m, sharp from 3.4 m to
## 9.2 m" - so a low mark is a lesson rather than a verdict. Nothing here
## touches the scene tree either; the camera does the measuring and hands over
## a Reading, and this file only does arithmetic.

const SENSOR_HEIGHT_MM := 24.0

## Everything the camera measured at the instant the shutter fired. Filled in by
## camera_body.gd, which is the only part of the game that can see the scene.
class Reading extends RefCounted:
	var subject_id: String = ""
	var subject_name: String = ""
	## Was the subject inside the frame at all, and could the lens see it?
	var in_frame: bool = false
	var visible_fraction: float = 0.0
	## How much of the frame's height the subject filled, 0..1.
	var fill: float = 0.0
	## Where it sat in the frame, in normalised screen space: (0,0) is the
	## centre, (-1,-1) the top left corner.
	var screen_offset: Vector2 = Vector2.ZERO
	var distance_m: float = 0.0
	## Distance to whatever is behind the subject, for judging separation.
	var background_m: float = 0.0
	var roll_degrees: float = 0.0
	var framed_through: bool = false
	## The average brightness of the recorded pixels, centre-weighted, in
	## linear light. This is the light meter, and it is read off the photograph
	## itself rather than assumed.
	var measured_luminance: float = 0.0
	## What the camera was set to.
	var aperture: float = 8.0
	var shutter: float = 125.0
	var sensitivity: float = 100.0
	var focus_distance_m: float = 5.0
	var focal_length_mm: float = 35.0
	var viewport_height_px: float = 1080.0
	var fov_degrees: float = 50.0
	## How fast the subject was travelling, from the Subject node.
	var subject_speed: float = 0.0


## One marked line of the report.
class Line extends RefCounted:
	var label: String
	var points: float
	var out_of: float
	var detail: String
	## What to do differently next time, in plain words: which dial, which way,
	## to what, and the key that does it. Empty when the line lost nothing
	## worth mentioning.
	var fix: String = ""
	func _init(l: String, p: float, o: float, d: String) -> void:
		label = l
		points = p
		out_of = o
		detail = d


class Verdict extends RefCounted:
	var score: int = 0
	var lines: Array[Line] = []
	var rejected: bool = false
	var headline: String = ""

	func accepted() -> bool:
		return score >= 60

	func used() -> bool:
		return score >= 85


## The blur circle the background lands on the sensor as, in millimetres. This
## is the number a photographer is buying when they open the aperture up: the
## further the background is from the focus plane and the wider the hole, the
## bigger the smear.
static func background_blur_mm(focal_length_mm: float, aperture: float, focus_m: float, background_m: float) -> float:
	if background_m <= 0.0 or focus_m <= 0.0:
		return 0.0
	var f := focal_length_mm
	var s := focus_m * 1000.0
	var b := background_m * 1000.0
	if s <= f:
		return 0.0
	return absf((f * f / aperture) * absf(b - s) / (b * (s - f)))


## How far the subject smears across the frame while the shutter is open, in
## pixels. Two pixels or less reads as frozen.
static func motion_smear_px(reading: Reading) -> float:
	if reading.subject_speed <= 0.0 or reading.distance_m <= 0.0:
		return 0.0
	var travel := Optics.motion_travel_m(reading.subject_speed, reading.shutter)
	var frame_height_m := 2.0 * reading.distance_m * tan(deg_to_rad(reading.fov_degrees) * 0.5)
	if frame_height_m <= 0.0:
		return 0.0
	return (travel / frame_height_m) * reading.viewport_height_px


## Distance from the nearest rule-of-thirds intersection, 0 at the point and 1
## at the far corner of the frame.
static func thirds_distance(screen_offset: Vector2) -> float:
	var best := INF
	for x in [-1.0 / 3.0, 1.0 / 3.0]:
		for y in [-1.0 / 3.0, 1.0 / 3.0]:
			best = minf(best, screen_offset.distance_to(Vector2(x, y)))
	return clampf(best / 1.2, 0.0, 1.0)


## Sentence case, not title case. GDScript's capitalize() turns "the cat" into
## "The Cat", which reads like a product name rather than an animal.
static func sentence(text: String) -> String:
	if text.is_empty():
		return text
	return text.substr(0, 1).to_upper() + text.substr(1)


static func _falloff(error: float, free: float, zero_at: float) -> float:
	## 1.0 while the error is inside the free band, sliding to 0 at zero_at.
	if error <= free:
		return 1.0
	if error >= zero_at:
		return 0.0
	return 1.0 - (error - free) / (zero_at - free)


static func mark(shot: Brief.Shot, reading: Reading) -> Verdict:
	var v := Verdict.new()
	var band := Optics.depth_of_field_m(reading.focal_length_mm, reading.aperture, reading.focus_distance_m)
	var far_text := "the horizon" if band.y == INF else "%.1f m" % band.y
	var has_demand: bool = shot.demand != ""
	var composition_max: float = 10.0 if has_demand else 20.0

	# 1. Is the subject in the picture at all? Nothing else can rescue a shot
	#    that missed, so this gate comes first and reports honestly.
	if not reading.in_frame or reading.visible_fraction <= 0.05:
		var gone := Line.new("Subject", 0.0, 20.0, "%s is not in the frame" % reading.subject_name)
		gone.fix = "Find %s, put it in the middle of the viewfinder, then take the picture." % reading.subject_name
		v.lines.append(gone)
		v.score = 0
		v.rejected = true
		v.headline = "%s did not make it into the picture." % sentence(reading.subject_name)
		return v

	var subject_points: float = 20.0 * clampf(reading.visible_fraction, 0.0, 1.0)
	var subject_detail: String = "%s in frame" % reading.subject_name
	if reading.visible_fraction < 0.9:
		subject_detail = "%s partly hidden - %d%% of it visible" % [reading.subject_name, roundi(reading.visible_fraction * 100.0)]
	var subject_line := Line.new("Subject", subject_points, 20.0, subject_detail)
	if reading.visible_fraction < 0.9:
		subject_line.fix = "Move until nothing stands between you and %s." % reading.subject_name
	v.lines.append(subject_line)

	# 2. How big it sits in the frame. This is the difference between the shot
	#    the client asked for and a different, possibly better, photograph.
	var fill_error := 0.0
	if reading.fill < shot.fill_min:
		fill_error = shot.fill_min - reading.fill
	elif reading.fill > shot.fill_max:
		fill_error = reading.fill - shot.fill_max
	var fill_points := 20.0 * _falloff(fill_error, 0.0, 0.35)
	var fill_detail := "fills %d%% of the frame (asked for %d-%d%%)" % [
		roundi(reading.fill * 100.0), roundi(shot.fill_min * 100.0), roundi(shot.fill_max * 100.0)]
	if fill_error == 0.0:
		fill_detail = "fills %d%% of the frame, as asked" % roundi(reading.fill * 100.0)
	elif reading.fill < shot.fill_min:
		fill_detail += " - too far away"
	else:
		fill_detail += " - too close"
	var framing_line := Line.new("Framing", fill_points, 20.0, fill_detail)
	if fill_error > 0.0:
		framing_line.fix = _framing_fix(shot, reading)
	v.lines.append(framing_line)

	# 3. Focus. Measured against the real depth of field, so the detail line
	#    doubles as the explanation of what depth of field is.
	var miss := Optics.focus_miss(reading.focal_length_mm, reading.aperture, reading.focus_distance_m, reading.distance_m)
	var focus_points := 20.0 * _falloff(miss, 0.0, 1.0)
	var focus_detail := "%s at %.1f m; sharp from %.1f m to %s" % [
		reading.subject_name, reading.distance_m, band.x, far_text]
	if miss > 0.0:
		focus_detail = "%s at %.1f m is outside the sharp band (%.1f m to %s)" % [
			reading.subject_name, reading.distance_m, band.x, far_text]
	var focus_line := Line.new("Focus", focus_points, 20.0, focus_detail)
	if miss > 0.0:
		focus_line.fix = "The focus was set to %.1f m. Put %s in the middle of the frame and press F, or press %s to focus %s by hand." % [
			reading.focus_distance_m, reading.subject_name,
			"]" if reading.distance_m > reading.focus_distance_m else "[",
			"further away" if reading.distance_m > reading.focus_distance_m else "nearer"]
	v.lines.append(focus_line)

	# 4. Exposure, read off the photograph rather than assumed.
	var stops := Optics.metered_stops(reading.measured_luminance)
	var stops_error: float = absf(stops)
	var exposure_points := 20.0 * _falloff(stops_error, shot.stops_tolerance, shot.stops_tolerance + 2.5)
	var exposure_detail := "within %.1f of a stop of correct" % stops_error
	if stops_error > shot.stops_tolerance:
		exposure_detail = "%.1f stops %s" % [stops_error, "over - washed out" if stops > 0.0 else "under - too dark"]
	var exposure_line := Line.new("Exposure", exposure_points, 20.0, exposure_detail)
	if stops_error > shot.stops_tolerance:
		exposure_line.fix = _exposure_fix(shot, reading, stops)
	v.lines.append(exposure_line)

	# 5. Composition: where the subject sits, and whether the camera was level.
	var thirds := thirds_distance(reading.screen_offset)
	var thirds_score := _falloff(thirds, 0.12, 0.5)
	var roll_error: float = absf(reading.roll_degrees)
	var level_score := _falloff(roll_error, 1.5, 12.0)
	var composition_points := composition_max * (0.6 * thirds_score + 0.4 * level_score)
	var composition_detail := "subject placed well" if thirds_score > 0.6 else "subject sits awkwardly in the frame"
	if roll_error > 1.5:
		composition_detail += ", camera tilted %.1f degrees" % roll_error
	var composition_line := Line.new("Composition", composition_points, composition_max, composition_detail)
	var composition_fixes: Array[String] = []
	if thirds_score <= 0.6:
		composition_fixes.append("Turn so %s sits where two grid lines cross (G shows the grid)." % reading.subject_name)
	if roll_error > 1.5:
		composition_fixes.append("Press R to level the camera.")
	composition_line.fix = " ".join(composition_fixes)
	v.lines.append(composition_line)

	# 6. The one technical thing the client asked for.
	if has_demand:
		var demand_points := 0.0
		var demand_detail := ""
		var demand_fix := ""
		match shot.demand:
			"shallow":
				var blur := background_blur_mm(reading.focal_length_mm, reading.aperture, reading.focus_distance_m, reading.background_m)
				var multiple := blur / Optics.CIRCLE_OF_CONFUSION_MM
				demand_points = 10.0 * clampf((multiple - 1.0) / 2.0, 0.0, 1.0)
				demand_detail = "background %.1f times blurrier than sharp at f/%s" % [multiple, Optics.aperture_mark(reading.aperture)]
				if multiple < 2.0:
					demand_detail = "background still crisp - open the aperture wider than f/%s" % Optics.aperture_mark(reading.aperture)
				if demand_points < 9.5:
					demand_fix = _shallow_fix(reading, multiple)
			"deep":
				var covers_far: bool = band.y == INF or band.y > reading.background_m
				var near_ok: bool = band.x <= 2.5
				demand_points = (6.0 if covers_far else 0.0) + (4.0 if near_ok else 0.0)
				demand_detail = "sharp from %.1f m to %s at f/%s" % [band.x, far_text, Optics.aperture_mark(reading.aperture)]
				if not covers_far:
					demand_detail += " - the back of the yard is soft"
				if demand_points < 9.5:
					demand_fix = _deep_fix(reading)
			"freeze":
				var smear := motion_smear_px(reading)
				demand_points = 10.0 * _falloff(smear, 2.0, 14.0)
				demand_detail = "%s moved %.1f px during 1/%s s" % [reading.subject_name, smear, Optics.shutter_mark(reading.shutter)]
				if smear > 2.0:
					demand_detail += " - a faster shutter would stop it"
					demand_fix = _freeze_fix(reading, smear)
			"clean":
				var grain := Optics.grain_amount(reading.sensitivity)
				demand_points = 10.0 * _falloff(grain, 0.05, 0.5)
				demand_detail = "ISO %d" % roundi(reading.sensitivity)
				if grain > 0.05:
					demand_detail += " - grainy; buy the light with aperture or shutter instead"
					var down := Optics.nearest_stop(Optics.SENSITIVITIES, reading.sensitivity)
					demand_fix = "Lower the ISO to 100 (%s), then get the light back by opening the aperture (1) or slowing the shutter (3)." % _presses("5", down)
			"framed":
				demand_points = 10.0 if reading.framed_through else 0.0
				demand_detail = "shot through a frame" if reading.framed_through else "not shot through anything - try the doorway or the window"
				if not reading.framed_through:
					demand_fix = "Stand a few steps back from the doorway or the window and take the picture through it, so its edges surround %s." % reading.subject_name
			"level":
				demand_points = 10.0 * level_score
				demand_detail = "camera level to within %.1f degrees" % roll_error
				if roll_error > 1.5:
					demand_fix = "Press R to level the camera."
		var demand_line := Line.new(sentence(shot.demand_text()), demand_points, 10.0, demand_detail)
		demand_line.fix = demand_fix
		v.lines.append(demand_line)

	var total := 0.0
	for line in v.lines:
		total += line.points
	v.score = clampi(roundi(total), 0, 100)
	v.rejected = v.score < 60
	v.headline = _headline(v, shot)
	return v


static func _headline(v: Verdict, shot: Brief.Shot) -> String:
	## The client's reaction, which is the only feedback the player reads first.
	var weakest: Line = null
	for line in v.lines:
		if line.out_of <= 0.0:
			continue
		if weakest == null or (line.points / line.out_of) < (weakest.points / weakest.out_of):
			weakest = line
	if v.used():
		return "They are using this one."
	if v.accepted():
		if weakest and weakest.points / weakest.out_of < 0.75:
			return "Accepted - but they mentioned the %s." % weakest.label.to_lower()
		return "Accepted."
	if weakest:
		return "Rejected. The %s is the problem." % weakest.label.to_lower()
	return "Rejected."


## ---------------------------------------------------------------------------
## Advice. Every function below turns a lost mark into an instruction a player
## who has never held a camera can follow: which dial, which way, to what, and
## which key. The settings it names are worked out with the same formulas that
## did the marking, so following the advice really does fix the line.
##
## The keys: 1 opens the aperture (smaller f-number, more light, softer
## background) and 2 closes it; 3 slows the shutter (more light, more blur) and
## 4 speeds it up; 5 lowers the ISO and 6 raises it (more light, more grain).
## ---------------------------------------------------------------------------

static func _presses(key: String, count: int) -> String:
	return "press %s %s" % [key, _times(count)]


## Spelled out, because "press 4 4 times" reads as a typo.
static func _times(count: int) -> String:
	var words := ["", "once", "twice", "three times", "four times", "five times", "six times", "seven times", "eight times", "nine times"]
	return words[count] if count > 0 and count < words.size() else "%d times" % count


static func _stops_text(count: int) -> String:
	return "1 stop" if count == 1 else "%d stops" % count


## Which dials to reach for, in order, when the picture is too dark (want_light)
## or too bright. The order protects whatever the client asked for: a brief
## that wants a soft background never gets told to close the aperture, a brief
## that wants the hen frozen never gets told to slow the shutter, and so on.
static func _dial_order(demand: String, want_light: bool) -> Array[String]:
	if want_light:
		match demand:
			"deep": return ["shutter", "iso", "aperture"]
			"freeze": return ["aperture", "iso", "shutter"]
			"clean": return ["aperture", "shutter", "iso"]
			_: return ["aperture", "shutter", "iso"]
	match demand:
		"shallow": return ["iso", "shutter", "aperture"]
		"freeze": return ["iso", "shutter", "aperture"]
		_: return ["iso", "aperture", "shutter"]


static func _exposure_fix(shot: Brief.Shot, reading: Reading, stops: float) -> String:
	var want_light := stops < 0.0
	var needed: int = maxi(1, roundi(absf(stops)))
	var a := Optics.nearest_stop(Optics.APERTURES, reading.aperture)
	var t := Optics.nearest_stop(Optics.SHUTTERS, reading.shutter)
	var i := Optics.nearest_stop(Optics.SENSITIVITIES, reading.sensitivity)
	var steps: Array[String] = []
	var left := needed
	for dial in _dial_order(shot.demand, want_light):
		if left <= 0:
			break
		match dial:
			"aperture":
				var room: int = a if want_light else Optics.APERTURES.size() - 1 - a
				var n := mini(room, left)
				if n > 0:
					var to: int = a - n if want_light else a + n
					steps.append("%s the aperture from f/%s to f/%s (%s)" % [
						"open" if want_light else "close", Optics.APERTURE_MARKS[a], Optics.APERTURE_MARKS[to],
						_presses("1" if want_light else "2", n)])
					left -= n
			"shutter":
				var room: int = t if want_light else Optics.SHUTTERS.size() - 1 - t
				var n := mini(room, left)
				if n > 0:
					var to: int = t - n if want_light else t + n
					steps.append("%s the shutter from 1/%s to 1/%s (%s)" % [
						"slow" if want_light else "speed up", Optics.SHUTTER_MARKS[t], Optics.SHUTTER_MARKS[to],
						_presses("3" if want_light else "4", n)])
					left -= n
			"iso":
				var room: int = Optics.SENSITIVITIES.size() - 1 - i if want_light else i
				var n := mini(room, left)
				if n > 0:
					var to: int = i + n if want_light else i - n
					steps.append("%s the ISO from %d to %d (%s)" % [
						"raise" if want_light else "lower", roundi(Optics.SENSITIVITIES[i]), roundi(Optics.SENSITIVITIES[to]),
						_presses("6" if want_light else "5", n)])
					left -= n
	var text := "About %s too %s. %s." % [_stops_text(needed), "dark" if want_light else "bright",
		sentence(" and ".join(steps)) if not steps.is_empty() else "Every dial is already at its limit"]
	if left > 0 and not steps.is_empty():
		text += " Even that leaves it %s - try somewhere %s." % ["dark" if want_light else "bright", "brighter" if want_light else "shadier"]
	text += " Watch the LIGHT bar: it goes green when it is right."
	return text


static func _framing_fix(shot: Brief.Shot, reading: Reading) -> String:
	## How big a subject looks scales directly with focal length, so the zoom
	## that would have filled the frame as asked is one multiplication away.
	var target := (shot.fill_min + shot.fill_max) * 0.5
	var ideal := reading.focal_length_mm * target / maxf(reading.fill, 0.001)
	var here := Optics.nearest_stop(Optics.FOCAL_LENGTHS, reading.focal_length_mm)
	var best := Optics.nearest_stop(Optics.FOCAL_LENGTHS, clampf(ideal, 24.0, 135.0))
	var too_small := reading.fill < shot.fill_min
	if too_small:
		var last := Optics.FOCAL_LENGTHS.size() - 1
		if ideal > 135.0 * 1.15:
			if here < last:
				return "Zoom in all the way to 135 mm (scroll up %s) and walk closer to %s as well." % [
					_times(last - here), reading.subject_name]
			return "Walk closer to %s - it is too small in the picture even at full zoom." % reading.subject_name
		if best <= here:
			return "Walk a little closer to %s." % reading.subject_name
		return "Zoom in to about %d mm (scroll up %s), or walk closer." % [
			roundi(Optics.FOCAL_LENGTHS[best]), _times(best - here)]
	if ideal < 24.0 / 1.15:
		if here > 0:
			return "Zoom out all the way to 24 mm (scroll down %s) and step back from %s as well." % [
				_times(here), reading.subject_name]
		return "Step back from %s - it does not fit even at the widest zoom." % reading.subject_name
	if best >= here:
		return "Step back a little from %s." % reading.subject_name
	return "Zoom out to about %d mm (scroll down %s), or step back." % [
		roundi(Optics.FOCAL_LENGTHS[best]), _times(here - best)]


static func _shallow_fix(reading: Reading, multiple: float) -> String:
	## Background blur is inversely proportional to the f-number, so the
	## aperture that triples it is a division away.
	var a := Optics.nearest_stop(Optics.APERTURES, reading.aperture)
	var wanted := reading.aperture * multiple / 3.0
	var to := -1
	for k in range(a - 1, -1, -1):
		to = k
		if Optics.APERTURES[k] <= wanted:
			break
	if to < 0:
		return "The lens is already wide open. Zoom in, get closer to %s, or stand so the background is further behind it." % reading.subject_name
	if to == 0 and Optics.APERTURES[0] > wanted * 1.5:
		return "Open the aperture all the way to f/1.4 (%s), and zoom in or get closer to %s as well - from here the aperture alone is not enough." % [
			_presses("1", a), reading.subject_name]
	return "Open the aperture to f/%s (%s) - a smaller f-number means a softer background. Then speed the shutter up (%s) so the picture is not too bright." % [
		Optics.APERTURE_MARKS[to], _presses("1", a - to), _presses("4", a - to)]


static func _deep_fix(reading: Reading) -> String:
	## Try each smaller aperture in turn with the same focus and lens, and name
	## the first one whose sharp band reaches the back of the yard.
	var a := Optics.nearest_stop(Optics.APERTURES, reading.aperture)
	for k in range(a + 1, Optics.APERTURES.size()):
		var band := Optics.depth_of_field_m(reading.focal_length_mm, Optics.APERTURES[k], reading.focus_distance_m)
		if (band.y == INF or band.y > reading.background_m) and band.x <= 2.5:
			return "Close the aperture to f/%s (%s) - a bigger f-number keeps more of the yard sharp. Then slow the shutter (%s) or raise the ISO (6) to get the light back." % [
				Optics.APERTURE_MARKS[k], _presses("2", k - a), _presses("3", k - a)]
	return "Zoom out to a wider lens (scroll down), close the aperture to f/16 (press 2), and focus a little further away (])."


static func _freeze_fix(reading: Reading, smear: float) -> String:
	## Smear shrinks in step with the shutter time, so the speed that brings it
	## under two pixels is a multiplication away.
	var t := Optics.nearest_stop(Optics.SHUTTERS, reading.shutter)
	var wanted := reading.shutter * smear / 2.0
	for k in range(t + 1, Optics.SHUTTERS.size()):
		if Optics.SHUTTERS[k] >= wanted:
			return "Speed the shutter up to 1/%s (%s) - a faster shutter stops movement. Then open the aperture (1) or raise the ISO (6) to get the light back." % [
				Optics.SHUTTER_MARKS[k], _presses("4", k - t)]
	return "Even 1/2000 cannot stop %s this close. Speed the shutter right up (4), and step back or zoom out." % reading.subject_name
