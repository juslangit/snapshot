class_name CameraBody
extends Camera3D

## The camera the player holds. Aperture, shutter, ISO, focus and focal length
## are real, and Godot's physical camera attributes turn them into the picture,
## so an overexposed frame is overexposed because too much light reached the
## sensor rather than because a number said so.
##
## Two jobs live here. One is being a camera: the dials, the field of view that
## follows the focal length, the depth of field. The other is taking the
## photograph, which means rendering the same instant several times to build a
## real motion blur, averaging those frames, adding the grain the chosen ISO
## would have cost, and measuring the result so the judge has something honest
## to mark.

signal reading_ready(photo: Image, readings: Dictionary)

## A 35 mm frame is 24 mm tall, which is what turns a focal length into a field
## of view.
const SENSOR_HEIGHT_MM := 24.0
const PHOTO_WIDTH := 1280
const GRAIN_TILE := 256

@export var aperture_index: int = 5
@export var shutter_index: int = 5
@export var sensitivity_index: int = 0
@export var focal_length_mm: float = 35.0
@export var focus_distance_m: float = 6.0
@export var roll_degrees: float = 0.0

var _attributes: CameraAttributesPhysical
var _grain: Image
var _busy: bool = false

func _ready() -> void:
	_attributes = CameraAttributesPhysical.new()
	attributes = _attributes
	keep_aspect = Camera3D.KEEP_HEIGHT
	apply_settings()

func aperture() -> float:
	return Optics.APERTURES[clampi(aperture_index, 0, Optics.APERTURES.size() - 1)]

func shutter() -> float:
	return Optics.SHUTTERS[clampi(shutter_index, 0, Optics.SHUTTERS.size() - 1)]

func sensitivity() -> float:
	return Optics.SENSITIVITIES[clampi(sensitivity_index, 0, Optics.SENSITIVITIES.size() - 1)]

## The vertical field of view a focal length gives on a 35 mm frame. This is
## the whole reason a 24 mm lens and a 135 mm lens are different photographs of
## the same thing.
func field_of_view() -> float:
	return rad_to_deg(2.0 * atan((SENSOR_HEIGHT_MM * 0.5) / maxf(focal_length_mm, 1.0)))

func depth_of_field() -> Vector2:
	return Optics.depth_of_field_m(focal_length_mm, aperture(), focus_distance_m)

func exposure_value() -> float:
	return Optics.exposure_value(aperture(), shutter())

## Push the dials into the engine. Everything visible about exposure and depth
## of field comes from these four numbers.
func apply_settings() -> void:
	fov = field_of_view()
	if _attributes == null:
		return
	_attributes.exposure_aperture = aperture()
	_attributes.exposure_shutter_speed = shutter()
	_attributes.exposure_sensitivity = sensitivity()
	_attributes.frustum_focal_length = focal_length_mm
	_attributes.frustum_focus_distance = focus_distance_m

func nudge_aperture(steps: int) -> void:
	aperture_index = clampi(aperture_index + steps, 0, Optics.APERTURES.size() - 1)
	apply_settings()

func nudge_shutter(steps: int) -> void:
	shutter_index = clampi(shutter_index + steps, 0, Optics.SHUTTERS.size() - 1)
	apply_settings()

func nudge_sensitivity(steps: int) -> void:
	sensitivity_index = clampi(sensitivity_index + steps, 0, Optics.SENSITIVITIES.size() - 1)
	apply_settings()

func nudge_focal_length(steps: int) -> void:
	var ladder := Optics.FOCAL_LENGTHS
	var here := ladder.find(focal_length_mm)
	if here < 0:
		here = 2
	focal_length_mm = ladder[clampi(here + steps, 0, ladder.size() - 1)]
	apply_settings()

func nudge_focus(steps: int) -> void:
	## Focus moves in even steps of distance on a log scale, the way a focus
	## ring does - fine near, coarse far.
	var factor := pow(1.25, float(steps))
	focus_distance_m = clampf(focus_distance_m * factor, 0.4, 200.0)
	apply_settings()

## What autofocus does: measure whatever is in the middle of the frame and put
## the focus plane there.
func focus_on_centre() -> bool:
	var hit := _ray(global_position, global_position - global_transform.basis.z * 300.0, true, false)
	if hit.is_empty():
		return false
	focus_distance_m = global_position.distance_to(hit["position"])
	apply_settings()
	return true

func settings_text() -> String:
	return "%.0f mm   f/%s   1/%s s   ISO %d" % [
		focal_length_mm, Optics.APERTURE_MARKS[aperture_index],
		Optics.SHUTTER_MARKS[shutter_index], roundi(sensitivity())]


# ---------------------------------------------------------------------------
# Taking the picture
# ---------------------------------------------------------------------------

## How many times to render the frame. A fast shutter has nothing to smear, so
## one pass will do; a slow one needs several to build the blur out of real
## renders rather than a filter.
func subframes() -> int:
	var seconds := 1.0 / maxf(shutter(), 0.001)
	if seconds <= 1.0 / 200.0:
		return 1
	if seconds <= 1.0 / 60.0:
		return 3
	if seconds <= 1.0 / 20.0:
		return 5
	return 8

## Fire the shutter. Returns the photograph, and a Reading for every Subject in
## the scene, so a brief can be marked against whichever one it names.
func take_photo(subjects: Array, hide_nodes: Array = []) -> Dictionary:
	if _busy:
		return {}
	_busy = true
	for node in hide_nodes:
		if node is CanvasItem:
			node.visible = false

	var movers := _movers()
	for m in movers:
		m.hold()

	var exposure_seconds := 1.0 / maxf(shutter(), 0.001)
	var passes := subframes()
	var photo: Image = null
	var vp := get_viewport()

	for i in passes:
		if i > 0:
			for m in movers:
				m.step(exposure_seconds / float(passes))
		await RenderingServer.frame_post_draw
		var frame := vp.get_texture().get_image()
		if photo == null:
			photo = frame
			photo.convert(Image.FORMAT_RGBA8)
		else:
			frame.convert(Image.FORMAT_RGBA8)
			_average_into(photo, frame, i + 1)

	## The measurements are taken at the end of the exposure, which is the
	## instant the picture was finished.
	var readings := _read_subjects(subjects, photo)

	for m in movers:
		m.release()
	for node in hide_nodes:
		if node is CanvasItem:
			node.visible = true

	photo.resize(PHOTO_WIDTH, roundi(PHOTO_WIDTH * float(photo.get_height()) / float(photo.get_width())), Image.INTERPOLATE_BILINEAR)
	_add_grain(photo)
	_busy = false
	reading_ready.emit(photo, readings)
	return {"photo": photo, "readings": readings}

## A running mean, done with one C++ blend per pass instead of a million
## GDScript pixel reads.
func _average_into(target: Image, frame: Image, count: int) -> void:
	var alpha := 1.0 / float(count)
	var mask := Image.create(target.get_width(), target.get_height(), false, Image.FORMAT_RGBA8)
	mask.fill(Color(1.0, 1.0, 1.0, alpha))
	target.blend_rect_mask(frame, mask, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i.ZERO)

func _add_grain(photo: Image) -> void:
	var amount := Optics.grain_amount(sensitivity())
	if amount <= 0.01:
		return
	if _grain == null:
		_grain = Image.create(GRAIN_TILE, GRAIN_TILE, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for y in GRAIN_TILE:
			for x in GRAIN_TILE:
				var v := clampf(0.5 + rng.randfn(0.0, 0.22), 0.0, 1.0)
				_grain.set_pixel(x, y, Color(v, v, v, 1.0))
	var mask := Image.create(GRAIN_TILE, GRAIN_TILE, false, Image.FORMAT_RGBA8)
	mask.fill(Color(1.0, 1.0, 1.0, amount * 0.45))
	var tile := Rect2i(Vector2i.ZERO, Vector2i(GRAIN_TILE, GRAIN_TILE))
	var y_at := 0
	while y_at < photo.get_height():
		var x_at := 0
		while x_at < photo.get_width():
			photo.blend_rect_mask(_grain, mask, tile, Vector2i(x_at, y_at))
			x_at += GRAIN_TILE
		y_at += GRAIN_TILE

## The light meter, read off the photograph itself. The arithmetic lives in
## Optics so that the live needle in the viewfinder and the mark on the report
## cannot drift apart.
func meter(photo: Image) -> float:
	return Optics.meter_image(photo)


# ---------------------------------------------------------------------------
# Measuring the scene
# ---------------------------------------------------------------------------

func _read_subjects(subjects: Array, photo: Image) -> Dictionary:
	var luminance := meter(photo)
	var out := {}
	for s in subjects:
		if s is Subject:
			out[s.id] = read_subject(s, luminance)
	return out

func read_subject(subject: Subject, luminance: float) -> Judge.Reading:
	var r := Judge.Reading.new()
	r.subject_id = subject.id
	r.subject_name = subject.display_name
	r.aperture = aperture()
	r.shutter = shutter()
	r.sensitivity = sensitivity()
	r.focus_distance_m = focus_distance_m
	r.focal_length_mm = focal_length_mm
	r.roll_degrees = roll_degrees
	r.measured_luminance = luminance
	r.fov_degrees = field_of_view()
	r.viewport_height_px = float(get_viewport().get_visible_rect().size.y)
	r.subject_speed = _subject_speed(subject)

	var aim := subject.aim_point()
	r.distance_m = global_position.distance_to(aim)
	r.in_frame = is_position_in_frustum(aim)

	var size := get_viewport().get_visible_rect().size
	var screen := unproject_position(aim)
	r.screen_offset = Vector2(
		(screen.x / maxf(size.x, 1.0)) * 2.0 - 1.0,
		(screen.y / maxf(size.y, 1.0)) * 2.0 - 1.0)

	## How much of the frame's height it fills: project the top and the bottom
	## of the thing and measure the gap in pixels.
	var top := unproject_position(subject.top_point())
	var bottom := unproject_position(subject.bottom_point())
	r.fill = clampf(absf(bottom.y - top.y) / maxf(size.y, 1.0), 0.0, 4.0)

	r.visible_fraction = _visible_fraction(subject)
	r.background_m = _background_behind(aim)
	r.framed_through = _framed_through(aim)
	return r

## Fire a few rays at the thing and see how many arrive. A cat half behind the
## well should score like a cat half behind the well.
func _visible_fraction(subject: Subject) -> float:
	if not is_position_in_frustum(subject.aim_point()):
		return 0.0
	var aim := subject.aim_point()
	var half := subject.height_m * 0.35
	var right := global_transform.basis.x * half
	var targets := [
		aim,
		aim + Vector3.UP * half,
		aim - Vector3.UP * half,
		aim + right,
		aim - right,
	]
	var seen := 0
	for t in targets:
		if not is_position_in_frustum(t):
			continue
		var hit := _ray(global_position, t, true, false)
		if hit.is_empty():
			seen += 1
			continue
		## Something was hit on the way - but the subjects themselves carry no
		## colliders, so what matters is whether it was hit short of the
		## subject. Anything at or past the subject's own distance was never in
		## the way.
		var blocked_at := global_position.distance_to(hit["position"] as Vector3)
		var target_at := global_position.distance_to(t)
		if blocked_at >= target_at - maxf(subject.height_m * 0.5, 0.2):
			seen += 1
	return float(seen) / float(targets.size())

## What is behind the subject, which is what an open aperture blurs.
func _background_behind(aim: Vector3) -> float:
	var direction := (aim - global_position).normalized()
	var beyond := aim + direction * 0.4
	var hit := _ray(beyond, beyond + direction * 400.0, true, false)
	if hit.is_empty():
		## Open sky behind it - as far away as it gets.
		return 400.0
	return global_position.distance_to(hit["position"])

## Did the line of sight pass through a doorway, a window or a gap? Those are
## marked in the scene as areas, so an artist can add another one without
## touching this file.
func _framed_through(aim: Vector3) -> bool:
	var hit := _ray(global_position, aim, false, true)
	return not hit.is_empty()

func _ray(from: Vector3, to: Vector3, bodies: bool, areas: bool) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = bodies
	query.collide_with_areas = areas
	query.collision_mask = 0xFFFFFFFF
	return space.intersect_ray(query)

func _subject_speed(subject: Subject) -> float:
	var node: Node = subject
	while node != null:
		if node is Mover:
			return (node as Mover).speed()
		node = node.get_parent()
	for child in subject.get_children():
		if child is Mover:
			return (child as Mover).speed()
	return subject.speed_m_per_s

func _movers() -> Array[Mover]:
	var out: Array[Mover] = []
	_collect_movers(get_tree().current_scene, out)
	return out

func _collect_movers(node: Node, out: Array[Mover]) -> void:
	if node == null:
		return
	if node is Mover:
		out.append(node)
	for c in node.get_children():
		_collect_movers(c, out)
