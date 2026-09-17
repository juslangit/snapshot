class_name Mover
extends Node3D

## Anything in the kampung that moves, driven by a phase rather than by time.
##
## The reason for the phase is motion blur. When the shutter fires, the camera
## needs to render the same instant several times with everything nudged a
## little further along, and average the results - that is what gives a slow
## shutter a real smear instead of a cosmetic one. A mover that reads the clock
## cannot be stepped like that; one that reads a number can.

enum Kind { SWAY, PACE, BOB }

@export var kind: Kind = Kind.SWAY
## Seconds for one full cycle.
@export var period: float = 3.0
## Metres, or degrees for a sway.
@export var amount: float = 0.35
@export var axis: Vector3 = Vector3.RIGHT

var phase: float = 0.0
var _rest: Transform3D
var _running: bool = true

func _ready() -> void:
	_rest = transform
	apply_phase()

func _process(delta: float) -> void:
	if not _running:
		return
	phase += delta
	apply_phase()

## Stop reading the clock, so the camera can step the phase by hand.
func hold() -> void:
	_running = false

func release() -> void:
	_running = true

func step(seconds: float) -> void:
	phase += seconds
	apply_phase()

## The speed the thing is travelling at right now, in metres per second. The
## judge needs this to work out how far it smeared.
func speed() -> float:
	var omega := TAU / maxf(period, 0.001)
	match kind:
		Kind.SWAY:
			## A hanging thing swings through an arc; take the speed at the
			## middle of the swing, which is where it is fastest.
			return deg_to_rad(amount) * omega * 0.7
		Kind.PACE:
			return (2.0 * amount) / maxf(period, 0.001) * 1.4
		Kind.BOB:
			return amount * omega * 0.7
	return 0.0

func apply_phase() -> void:
	var t := fmod(phase, maxf(period, 0.001)) / maxf(period, 0.001)
	var wave := sin(t * TAU)
	match kind:
		Kind.SWAY:
			transform = _rest
			rotate_object_local(axis.normalized(), deg_to_rad(amount * wave))
		Kind.PACE:
			## Walks out and back along the axis, turning at each end.
			var triangle := 1.0 - absf(2.0 * fmod(t * 2.0, 1.0) - 1.0)
			var forward: bool = fmod(t * 2.0, 2.0) < 1.0
			transform = _rest
			position = _rest.origin + axis.normalized() * amount * (triangle * 2.0 - 1.0)
			if not forward:
				rotate_y(PI)
		Kind.BOB:
			transform = _rest
			position = _rest.origin + Vector3.UP * amount * wave
