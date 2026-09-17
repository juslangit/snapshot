class_name Photographer
extends CharacterBody3D

## The person holding the camera.
##
## Walking matters more here than in most games, because in a photography game
## the only way to change the picture is to change where you are standing. So
## the rig is deliberately plain - walk, crouch, look - and every interesting
## control belongs to the camera it carries.

const WALK_SPEED := 2.6
const RUN_SPEED := 4.6
const EYE_HEIGHT := 1.62
const CROUCH_HEIGHT := 0.95
const MOUSE_SENSITIVITY := 0.0022
const ROLL_SPEED := 45.0

@export var look_enabled: bool = true

var camera: CameraBody
var _yaw: float = 0.0
var _pitch: float = 0.0
var _crouching: bool = false

func _ready() -> void:
	camera = get_node_or_null("Camera") as CameraBody
	_yaw = rotation.y

func _unhandled_input(event: InputEvent) -> void:
	if not look_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - motion.relative.y * MOUSE_SENSITIVITY, deg_to_rad(-85.0), deg_to_rad(85.0))

func _physics_process(delta: float) -> void:
	if not look_enabled:
		return
	_walk(delta)
	_roll(delta)
	rotation.y = _yaw
	if camera:
		camera.rotation.x = _pitch
		camera.rotation.z = deg_to_rad(camera.roll_degrees)

func _walk(delta: float) -> void:
	var wanted := Vector2(
		Input.get_action_strength("walk_right") - Input.get_action_strength("walk_left"),
		Input.get_action_strength("walk_back") - Input.get_action_strength("walk_forward"))
	var speed: float = RUN_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
	var direction := (transform.basis * Vector3(wanted.x, 0.0, wanted.y)).normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	## Crouching is a composition tool: a cat photographed from standing height
	## is a picture of the top of a cat.
	var want_crouch := Input.is_action_pressed("crouch")
	if want_crouch != _crouching:
		_crouching = want_crouch
	if camera:
		var target: float = CROUCH_HEIGHT if _crouching else EYE_HEIGHT
		camera.position.y = lerpf(camera.position.y, target, minf(1.0, delta * 10.0))

func _roll(delta: float) -> void:
	if camera == null:
		return
	var roll := 0.0
	if Input.is_key_pressed(KEY_Q):
		roll -= 1.0
	if Input.is_key_pressed(KEY_E):
		roll += 1.0
	if Input.is_key_pressed(KEY_R):
		camera.roll_degrees = 0.0
		return
	camera.roll_degrees = clampf(camera.roll_degrees + roll * ROLL_SPEED * delta, -35.0, 35.0)
