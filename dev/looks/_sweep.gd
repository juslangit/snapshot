extends Node

## A one-off calibration sweep: how bright does the morning have to be for a
## real camera's settings to expose it? Left in the repo because the answer
## needs re-finding whenever the ground, the sky or the walls change colour.

var main: Node3D
var probe: MeterProbe

func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	add_child(main)
	await get_tree().process_frame
	probe = main.get_node_or_null("MeterProbe") as MeterProbe
	main.enter(main.Stage.SHOOTING)
	var camera := main.camera as CameraBody
	var sun := main.kampung.get_node("Sun") as DirectionalLight3D
	var sky := ((main.kampung.get_node("WorldEnvironment") as WorldEnvironment).environment.sky.sky_material as ProceduralSkyMaterial)

	## Stood in the yard looking at the house, which is the view the first
	## brief is shot from and so the one worth calibrating against.
	var p := main.photographer as Photographer
	p.position = Vector3(1.2, 0.1, 2.4)
	p._yaw = 0.0
	p.rotation.y = 0.0
	camera.rotation.x = 0.0
	camera.focal_length_mm = 35.0
	camera.aperture_index = 5   # f/8
	camera.shutter_index = 5    # 1/125
	camera.sensitivity_index = 0
	camera.apply_settings()

	print("target: middle grey is %.4f, so 0.00 stops" % Optics.MIDDLE_GREY)
	print("%-10s %-10s %-10s %s" % ["sun lux", "sky", "metered", "stops"])
	for lux in [18000.0, 12000.0, 9000.0, 6000.0]:
		for sky_energy in [0.45, 0.3, 0.2]:
			sun.light_intensity_lux = lux
			var env := (main.kampung.get_node("WorldEnvironment") as WorldEnvironment).environment
			env.ambient_light_energy = sky_energy
			await get_tree().create_timer(0.25).timeout
			await RenderingServer.frame_post_draw
			var lit := probe.read()
			print("%-10.0f %-10.2f %-10.4f %+.2f" % [lux, sky_energy, lit, Optics.metered_stops(lit)])
	get_tree().quit()
