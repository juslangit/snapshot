class_name Brief
extends RefCounted

## A client, and the pictures they are paying for.
##
## The brief is the whole game design in one object. A photograph on its own
## cannot be right or wrong - it is only right or wrong against what somebody
## asked for - so every rule the judge applies comes from here, and the review
## screen can always point at the line of the brief that a score came from.

class Shot extends RefCounted:
	## Which Subject in the scene this shot is about.
	var subject_id: String
	## The shot's name on the client's list: "The cat on the roof".
	var title: String
	## What the client said they want, in their own words. Shown in the
	## viewfinder so the player never has to guess the intent.
	var note: String
	## How much of the frame's height the subject should fill, as a fraction.
	## A portrait is a big number; a landscape with a house in it is a small
	## one. This is what stops every photograph being taken from the same spot.
	var fill_min: float = 0.10
	var fill_max: float = 0.90
	## How many stops off middle grey the client will still accept.
	var stops_tolerance: float = 1.0
	## The one technical demand that makes this shot a puzzle rather than a
	## walk. Exactly one of these per shot, so the lesson is never muddled.
	##   ""            - no extra demand
	##   "shallow"     - the background must fall away; needs a wide aperture
	##   "deep"        - everything sharp front to back; needs a small one
	##   "freeze"      - the movement must be stopped; needs a fast shutter
	##   "clean"       - no grain; forbids leaning on ISO
	##   "framed"      - shot through a doorway, window or gap
	##   "level"       - the horizon has to be straight
	var demand: String = ""

	func demand_text() -> String:
		match demand:
			"shallow": return "background soft"
			"deep": return "sharp front to back"
			"freeze": return "movement frozen"
			"clean": return "clean, no grain"
			"framed": return "framed by something"
			"level": return "horizon straight"
			_: return ""

var client: String
var title: String
var blurb: String
var shots: Array[Shot] = []

static func _shot(subject_id: String, title: String, note: String, fill_min: float, fill_max: float, demand: String, stops_tolerance: float = 1.0) -> Shot:
	var s := Shot.new()
	s.subject_id = subject_id
	s.title = title
	s.note = note
	s.fill_min = fill_min
	s.fill_max = fill_max
	s.demand = demand
	s.stops_tolerance = stops_tolerance
	return s

static func _brief(client: String, title: String, blurb: String, shots: Array[Shot]) -> Brief:
	var b := Brief.new()
	b.client = client
	b.title = title
	b.blurb = blurb
	b.shots = shots
	return b


## The three jobs in the kampung. They are ordered so that each one introduces
## one control of the camera and then asks for it under pressure: the first
## brief is about exposure, the second about aperture and depth of field, the
## third about shutter speed and the cost of ISO.
static func all() -> Array[Brief]:
	var out: Array[Brief] = []

	out.append(_brief(
		"Kampung Heritage Trust",
		"The house, properly",
		"We are printing a booklet about the old houses. We want them to look like somebody lives there, not like a survey photograph. Get the light right - that is all we ask this time.",
		[
			_shot("house", "The house from the yard", "The whole house in the frame, straight, with the morning light on it.", 0.35, 0.85, "level", 1.0),
			_shot("well", "The old well", "Closer. The well should own the picture.", 0.40, 0.90, "", 1.0),
			_shot("tree", "A banana tree against the sky", "Something green and alive. Keep it bright without blowing out the sky.", 0.45, 0.95, "", 0.8),
		] as Array[Shot]))

	out.append(_brief(
		"Selera Kampung (cafe)",
		"Breakfast, but make it warm",
		"We are opening a cafe in town and we want three pictures for the wall. Make them feel close. Blur what is behind - that is the look we are after.",
		[
			_shot("kettle", "The kettle on the stove", "Right up close. The kettle sharp, everything behind it soft.", 0.35, 0.85, "shallow", 1.0),
			_shot("cat", "The cat, in her own world", "She sits on the step every morning. Soft background again.", 0.25, 0.70, "shallow", 1.0),
			_shot("laundry", "Washing on the line", "Shot through the doorway if you can - we like the frame it gives.", 0.30, 0.85, "framed", 1.0),
		] as Array[Shot]))

	out.append(_brief(
		"Majalah Desa (magazine)",
		"Hold still",
		"Our last photographer sent us blurred chickens. We need the movement stopped, and we need it clean - the printer hates grain. You have the whole morning; use the light you have.",
		[
			_shot("hen", "The hen, mid-step", "Frozen. Not a smear. Not grainy.", 0.30, 0.80, "freeze", 1.0),
			_shot("laundry", "The washing moving in the wind", "Frozen too, so you can see the creases.", 0.30, 0.85, "freeze", 1.0),
			_shot("house", "The yard, everything sharp", "From the fence to the house, all of it sharp. A record shot, but a nice one.", 0.25, 0.70, "deep", 1.0),
		] as Array[Shot]))

	return out
