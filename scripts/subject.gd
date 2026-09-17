class_name Subject
extends Node3D

## Something in the kampung worth photographing.
##
## A brief names its subjects by id, and the judge finds them by walking the
## scene for these nodes. Keeping the aim point and the size on the subject
## itself - rather than guessing them from the mesh - means an artist can swap
## the model for a better one without the scoring changing underneath.

## How the brief refers to it: "cat", "house", "kettle".
@export var id: String = ""

## How the client refers to it, in a sentence: "the cat".
@export var display_name: String = ""

## The point a photographer would aim at - the cat's head, not the middle of
## the cat.
@export var aim_offset: Vector3 = Vector3.ZERO

## Roughly how tall the thing is, in metres. Used to work out how much of the
## frame it fills, which is what the difference between a portrait and a
## landscape comes down to.
@export var height_m: float = 1.0

## How fast it moves when it moves, in metres per second. Zero for a house.
## This is what decides whether a slow shutter smears it.
@export var speed_m_per_s: float = 0.0

func aim_point() -> Vector3:
	return global_position + aim_offset

func top_point() -> Vector3:
	return aim_point() + Vector3.UP * (height_m * 0.5)

func bottom_point() -> Vector3:
	return aim_point() - Vector3.UP * (height_m * 0.5)
