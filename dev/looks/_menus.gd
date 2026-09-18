extends Node

## Screenshots of every menu screen, into dev/shots/menu_*.png. Uses its own
## throwaway profile, and takes three real photographs first so the album and
## the job board have something on them.

var main: Node3D

func _ready() -> void:
	Profile.root = "user://looks_profile/"
	Profile.erase_all()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	add_child(main)
	await _wait(0.8)
	await _shot("menu_01_main")

	## Play the first job for real, so there are pictures and a best score.
	main._on_job_chosen(0)
	await _wait(0.3)
	for index in 3:
		main.enter(main.Stage.SHOOTING)
		await _aim(["house", "well", "tree"][index], [Vector3(1.6, 0.1, 4.2), Vector3(-3.0, 0.1, -0.6), Vector3(5.0, 0.1, -1.0)][index], [28.0, 35.0, 35.0][index])
		main._shot_index = index
		await main._fire()
		await _wait(0.3)
		if index < 2:
			main._on_keep()
	main._on_keep()
	await _wait(0.5)
	await _shot("menu_02_wrap")

	main.enter(main.Stage.JOBS)
	await _wait(0.4)
	await _shot("menu_03_jobs")
	main.enter(main.Stage.ALBUM)
	await _wait(0.4)
	await _shot("menu_04_album")
	(main._album as AlbumScreen).open_viewer(Profile.album()[0])
	await _wait(0.3)
	await _shot("menu_05_album_viewer")
	main.enter(main.Stage.HOW_TO)
	await _wait(0.3)
	await _shot("menu_06_howto_job")
	for page in [1, 2, 3, 4, 5]:
		(main._how_to as HowToScreen).show_page(page)
		await _wait(0.2)
		await _shot("menu_07_howto_%d" % page)
	main.enter(main.Stage.SETTINGS)
	await _wait(0.3)
	await _shot("menu_08_settings")
	main._on_job_chosen(1)
	await _wait(0.2)
	main.enter(main.Stage.SHOOTING)
	await _wait(0.4)
	main.enter(main.Stage.PAUSED)
	await _wait(0.4)
	await _shot("menu_09_pause")
	Profile.erase_all()
	get_tree().quit()

func _aim(subject_id: String, where: Vector3, focal: float) -> void:
	var p: Photographer = main.photographer
	var c: CameraBody = main.camera
	p.position = where
	var target := Vector3.ZERO
	for s in (main.kampung as Kampung).subjects:
		if s.id == subject_id:
			target = s.aim_point()
	await get_tree().process_frame
	var eye := p.global_position + Vector3(0.0, Photographer.EYE_HEIGHT, 0.0)
	var flat := Vector3(target.x - eye.x, 0.0, target.z - eye.z)
	p._yaw = atan2(-flat.x, -flat.z)
	p.rotation.y = p._yaw
	p._pitch = atan2(target.y - eye.y, flat.length())
	c.rotation.x = p._pitch
	c.focal_length_mm = focal
	c.aperture_index = 5
	c.shutter_index = 5
	c.sensitivity_index = 0
	c.roll_degrees = 0.0
	c.focus_distance_m = maxf(eye.distance_to(target), 0.5)
	c.apply_settings()
	await _wait(0.3)

func _shot(name_text: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://dev/shots/" + name_text + ".png"))
	print("saved ", name_text)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
