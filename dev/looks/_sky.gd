extends Node

## Finds where the sun in the photographed sky really is, and says how far the
## sky needs turning so it stands where the Sun node's light comes from.
##
## Turns the camera a full circle at the photograph's sun height with the HUD
## hidden, finds the brightest patch in each frame, and converts the best one
## back into a compass direction. Run it after changing SKY_HDRI or the Sun's
## rotation; saves dev/shots/sky_sun.png looking straight at the light.

var main: Node3D

func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	add_child(main)
	await get_tree().process_frame
	main.enter(main.Stage.SHOOTING)
	await get_tree().create_timer(0.3).timeout
	for layer in main.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false

	var sun := main.find_child("Sun", true, false) as DirectionalLight3D
	var to_sun: Vector3 = sun.global_transform.basis.z.normalized()
	var light_yaw := rad_to_deg(atan2(-to_sun.x, -to_sun.z))
	var p: Photographer = main.photographer
	var c: CameraBody = main.camera
	c.focal_length_mm = 24.0
	c.aperture_index = 8
	c.shutter_index = 9
	c.sensitivity_index = 0
	c.apply_settings()

	var best_value := -1.0
	var best_yaw := 0.0
	var best_pitch := 0.0
	for step in 12:
		var yaw := float(step) * 30.0
		var found := await _brightest(p, c, yaw, 30.0)
		if found.z > best_value:
			best_value = found.z
			best_yaw = yaw + found.x
			best_pitch = 30.0 + found.y
	## Refine by looking straight at it.
	var fine := await _brightest(p, c, best_yaw, best_pitch)
	best_yaw += fine.x
	best_pitch += fine.y
	var turn := wrapf(light_yaw - best_yaw, -180.0, 180.0)
	print("SKY: photographed sun at yaw %.1f, %.1f up; light comes from yaw %.1f, %.1f up; turn the sky by %+.1f degrees" % [
		wrapf(best_yaw, -180.0, 180.0), best_pitch, light_yaw, rad_to_deg(asin(to_sun.y)), turn])

	await _look(p, c, light_yaw, rad_to_deg(asin(to_sun.y)) + 6.0)
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://dev/shots/sky_sun.png"))
	get_tree().quit()

func _look(p: Photographer, c: CameraBody, yaw_deg: float, pitch_deg: float) -> void:
	p._yaw = deg_to_rad(yaw_deg)
	p.rotation.y = p._yaw
	p._pitch = deg_to_rad(pitch_deg)
	c.rotation.x = p._pitch
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw

## Returns the brightest patch's offset from the centre in degrees (x to the
## left is positive yaw, y up is positive pitch) and its brightness in z.
func _brightest(p: Photographer, c: CameraBody, yaw_deg: float, pitch_deg: float) -> Vector3:
	await _look(p, c, yaw_deg, pitch_deg)
	var image := get_viewport().get_texture().get_image()
	image.resize(image.get_width() / 8, image.get_height() / 8)
	var top := 0.0
	var at := Vector2.ZERO
	for y in image.get_height():
		for x in image.get_width():
			var v := image.get_pixel(x, y).get_luminance()
			if v > top:
				top = v
				at = Vector2(x, y)
	var half := Vector2(image.get_size()) * 0.5
	var focal_px := half.y / tan(deg_to_rad(c.field_of_view()) * 0.5)
	return Vector3(rad_to_deg(atan((half.x - at.x) / focal_px)), rad_to_deg(atan((half.y - at.y) / focal_px)), top)
