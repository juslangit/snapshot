extends Node

## Does opening the aperture actually blur the background?
##
## The whole "background soft" brief rests on this, so it is worth proving
## rather than assuming. The same view is rendered wide open and stopped down,
## with the shutter compensated so both are exposed the same, and the pixels
## behind the subject are compared. If the two renders agree, no depth of field
## is reaching the screen and the game cannot ask for a soft background.

var main: Node3D

func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	add_child(main)
	await get_tree().process_frame
	main.enter(main.Stage.SHOOTING)
	var p := main.photographer as Photographer
	var c := main.camera as CameraBody
	p.position = Vector3(-5.6, 0.1, -0.2)
	p._yaw = -1.25
	p.rotation.y = -1.25
	c.rotation.x = 0.0
	c.focal_length_mm = 85.0
	c.focus_distance_m = 2.2
	c.sensitivity_index = 0

	## f/1.4 at 1/2000 and f/22 at 1/8 are the same exposure, eight stops apart
	## in aperture, so any difference between the two images is depth of field.
	var wide := await _render(0, 9)
	var narrow := await _render(8, 1)
	wide.save_png(ProjectSettings.globalize_path("res://dev/shots/dof_wide.png"))
	narrow.save_png(ProjectSettings.globalize_path("res://dev/shots/dof_narrow.png"))
	print("difference between f/1.4 and f/22: %.4f (0 means no depth of field is rendering)" % _difference(wide, narrow))
	get_tree().quit()

func _render(aperture: int, shutter: int) -> Image:
	var c := main.camera as CameraBody
	c.aperture_index = aperture
	c.shutter_index = shutter
	c.apply_settings()
	main.hud.visible = false
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.resize(320, 180, Image.INTERPOLATE_BILINEAR)
	return image

func _difference(a: Image, b: Image) -> float:
	var total := 0.0
	for y in a.get_height():
		for x in a.get_width():
			var pa := a.get_pixel(x, y)
			var pb := b.get_pixel(x, y)
			total += absf(pa.r - pb.r) + absf(pa.g - pb.g) + absf(pa.b - pb.b)
	return total / float(a.get_width() * a.get_height() * 3)
