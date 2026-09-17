class_name MeterProbe
extends SubViewport

## A second, tiny view of the same scene, used only as a light meter.
##
## The obvious way to meter would be to read the pixels of the main window, but
## the viewfinder overlay is drawn on top of those pixels, so the dark panels
## would fool the meter into calling the morning dark. Rendering a 96 by 54
## copy of exactly what the lens sees, with no overlay on it, costs almost
## nothing and reads the truth.

const WIDTH := 96
const HEIGHT := 54

var probe: Camera3D
var _source: CameraBody

func _ready() -> void:
	size = Vector2i(WIDTH, HEIGHT)
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	own_world_3d = false
	transparent_bg = false
	probe = Camera3D.new()
	probe.name = "Probe"
	probe.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(probe)

func watch(camera: CameraBody) -> void:
	_source = camera
	world_3d = camera.get_world_3d()

func _process(_delta: float) -> void:
	if _source == null or probe == null:
		return
	probe.global_transform = _source.global_transform
	probe.fov = _source.fov
	probe.attributes = _source.attributes
	probe.current = true

## The average brightness of what the lens is pointed at, in linear light,
## centre-weighted the way a camera's meter is. Same arithmetic as the mark on
## the report, so the needle never promises something the client disagrees with.
func read() -> float:
	var texture := get_texture()
	if texture == null:
		return 0.0
	return Optics.meter_image(texture.get_image())
