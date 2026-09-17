class_name Optics
extends RefCounted

## The photography in this game is the real photography, not a resemblance of it.
##
## Everything a player can change on the camera - aperture, shutter, ISO, focus -
## is fed through the formulas a photographer would use, and the same formulas
## decide whether a picture is any good. That matters for two reasons. It means
## the depth of field you see in the viewfinder is the depth of field the judge
## measured, so a score can always be explained by a number the player set. And
## it means what the game teaches is transferable: someone who learns to expose
## a shot here has learned to expose a shot.
##
## Nothing in this file touches the scene tree, so all of it is checked headless
## by dev/checks/_optics.gd.

## A 35 mm frame. The circle of confusion is the standard 0.029 mm for full
## frame - the blur spot small enough that a print looks sharp to the eye.
const CIRCLE_OF_CONFUSION_MM := 0.029

## Middle grey in linear light. A camera's meter is built to render whatever it
## points at as this, which is why a photograph of snow comes out grey unless
## the photographer overrides it.
const MIDDLE_GREY := 0.18

## The full stops of each control, coarse on purpose: a player turning a dial
## should feel one stop of light per click, the way a real camera clicks.
##
## The values are the exact ones and the marks are what is printed on the dial.
## Real cameras do this too, and the difference matters: f/11 is really f/11.31,
## and 1/125 s is really 1/128 s. Keeping the exact numbers means a stop of
## aperture cancels a stop of shutter perfectly, the way it must; keeping the
## marks means the camera still reads like a camera.
const APERTURES: Array[float] = [1.414214, 2.0, 2.828427, 4.0, 5.656854, 8.0, 11.313708, 16.0, 22.627417]
const APERTURE_MARKS: Array[String] = ["1.4", "2", "2.8", "4", "5.6", "8", "11", "16", "22"]
const SHUTTERS: Array[float] = [4.0, 8.0, 16.0, 32.0, 64.0, 128.0, 256.0, 512.0, 1024.0, 2048.0]
const SHUTTER_MARKS: Array[String] = ["4", "8", "15", "30", "60", "125", "250", "500", "1000", "2000"]
const SENSITIVITIES: Array[float] = [100.0, 200.0, 400.0, 800.0, 1600.0, 3200.0, 6400.0]


## What the dial says, for a value that may have come from anywhere.
static func aperture_mark(aperture: float) -> String:
	return APERTURE_MARKS[nearest_stop(APERTURES, aperture)]

static func shutter_mark(shutter_denominator: float) -> String:
	return SHUTTER_MARKS[nearest_stop(SHUTTERS, shutter_denominator)]


## The exposure value a pair of settings delivers, ignoring how bright the scene
## is. EV = log2(N^2 / t). Shutter is carried around as its denominator, the way
## it is written on a dial: 125 means 1/125 s.
static func exposure_value(aperture: float, shutter_denominator: float) -> float:
	return log(aperture * aperture * shutter_denominator) / log(2.0)


## How far the settings are from correctly exposing a scene of a given
## brightness, in stops. Positive is overexposed - too much light - and negative
## is dark. ISO shifts the answer because a more sensitive sensor needs less
## light to reach the same brightness.
static func exposure_offset_stops(aperture: float, shutter_denominator: float, sensitivity: float, scene_ev100: float) -> float:
	var iso_gain := log(sensitivity / 100.0) / log(2.0)
	return scene_ev100 + iso_gain - exposure_value(aperture, shutter_denominator)


## The same question asked of a photograph that already exists: how far is its
## average brightness from middle grey? This is the honest meter, because it
## reads the pixels that were actually recorded and so it already knows about
## the sun, the shade under the house, and where the player happened to point.
static func metered_stops(measured_luminance: float) -> float:
	if measured_luminance <= 0.0:
		return -99.0
	return log(measured_luminance / MIDDLE_GREY) / log(2.0)


## The hyperfocal distance, in metres: focus here and everything from half this
## distance to the horizon is acceptably sharp. It is the number that makes a
## landscape possible.
static func hyperfocal_m(focal_length_mm: float, aperture: float) -> float:
	var h_mm := (focal_length_mm * focal_length_mm) / (aperture * CIRCLE_OF_CONFUSION_MM) + focal_length_mm
	return h_mm / 1000.0


## The near and far edges of the depth of field, in metres, for a lens focused
## at a given distance. INF for the far edge means the depth of field runs to
## the horizon, which happens at or beyond the hyperfocal distance.
##
## These are the standard thin-lens formulas:
##   near = s(H - f) / (H + s - 2f)
##   far  = s(H - f) / (H - s)
static func depth_of_field_m(focal_length_mm: float, aperture: float, focus_distance_m: float) -> Vector2:
	var f := focal_length_mm
	var h := hyperfocal_m(focal_length_mm, aperture) * 1000.0
	var s := maxf(focus_distance_m, 0.001) * 1000.0
	var near_mm := (s * (h - f)) / (h + s - 2.0 * f)
	var near_m := maxf(near_mm / 1000.0, 0.0)
	if s >= h:
		return Vector2(near_m, INF)
	var far_mm := (s * (h - f)) / (h - s)
	return Vector2(near_m, far_mm / 1000.0)


## Is something at this distance sharp, given where the lens is focused?
static func is_sharp(focal_length_mm: float, aperture: float, focus_distance_m: float, subject_distance_m: float) -> bool:
	var band := depth_of_field_m(focal_length_mm, aperture, focus_distance_m)
	return subject_distance_m >= band.x and subject_distance_m <= band.y


## How badly out of focus something is, as a fraction of the depth of field it
## sits outside. 0.0 is sharp; 1.0 is one depth-of-field's worth beyond the
## edge. Used for scoring, because a near miss should not read like a disaster.
static func focus_miss(focal_length_mm: float, aperture: float, focus_distance_m: float, subject_distance_m: float) -> float:
	var band := depth_of_field_m(focal_length_mm, aperture, focus_distance_m)
	if subject_distance_m >= band.x and subject_distance_m <= band.y:
		return 0.0
	var far_edge: float = band.y if band.y < INF else band.x * 4.0
	var width: float = maxf(far_edge - band.x, 0.05)
	if subject_distance_m < band.x:
		return (band.x - subject_distance_m) / width
	return (subject_distance_m - band.y) / width


## How far a subject moving at this speed smears across the frame while the
## shutter is open, in metres of travel. A player who wants the chicken frozen
## has to buy a fast shutter with either light or grain, which is the whole
## trade the exposure triangle exists to make.
static func motion_travel_m(speed_m_per_s: float, shutter_denominator: float) -> float:
	return speed_m_per_s / maxf(shutter_denominator, 0.001)


## Grain, as a 0..1 nuisance. A hundred ISO is clean; the top of the dial is
## visibly gritty. Real sensors are not linear in this and neither is this
## curve - the first few stops cost almost nothing.
static func grain_amount(sensitivity: float) -> float:
	var stops := log(maxf(sensitivity, 100.0) / 100.0) / log(2.0)
	return clampf(pow(stops / 6.0, 1.6), 0.0, 1.0)


## Read a photograph the way a camera's meter reads the scene: average the
## brightness in linear light, weighted hard towards the middle of the frame.
##
## The weighting is the whole of it. A flat average is fooled by a bright sky -
## point at a house with sky above it and a flat meter calls the house
## correctly exposed when it is two stops dark, which is the single most common
## way a real photograph goes wrong. A camera answers this with centre-weighted
## metering, so this does too: the middle of the frame is worth roughly eight
## times the corners. It means pointing the camera at the subject meters the
## subject, which is what a player expects and what makes the needle worth
## trusting.
static func meter_image(image: Image) -> float:
	if image == null or image.is_empty():
		return 0.0
	var small := image.duplicate() as Image
	if small.get_width() > METER_WIDTH:
		small.resize(METER_WIDTH, METER_HEIGHT, Image.INTERPOLATE_BILINEAR)
	small.srgb_to_linear()
	var w := small.get_width()
	var h := small.get_height()
	var total := 0.0
	var weight_total := 0.0
	for y in h:
		for x in w:
			var px := small.get_pixel(x, y)
			var luma: float = 0.2126 * px.r + 0.7152 * px.g + 0.0722 * px.b
			var dx := (float(x) / float(maxi(w - 1, 1))) * 2.0 - 1.0
			var dy := (float(y) / float(maxi(h - 1, 1))) * 2.0 - 1.0
			var weight := centre_weight(sqrt(dx * dx + dy * dy))
			total += luma * weight
			weight_total += weight
	return 0.0 if weight_total <= 0.0 else total / weight_total


## How much a pixel counts, by how far it is from the middle of the frame.
static func centre_weight(radius: float) -> float:
	var middle: float = maxf(0.0, 1.0 - clampf(radius, 0.0, 1.4))
	return 0.15 + 8.0 * pow(middle, 3.0)


## The grid the meter reads. Coarse on purpose - a meter measures light, not
## detail, and a thumbnail is what makes it cheap enough to run live.
const METER_WIDTH := 48
const METER_HEIGHT := 27


## Snap a value onto its dial, so the UI and the judge always agree on what the
## camera is set to. Returns the index in the ladder.
static func nearest_stop(ladder: Array[float], value: float) -> int:
	var best := 0
	var best_gap := INF
	for i in ladder.size():
		var gap: float = absf(log(ladder[i] / value) / log(2.0))
		if gap < best_gap:
			best_gap = gap
			best = i
	return best
