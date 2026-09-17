extends Node

## The career: which brief is open, what has been handed in, and what it scored.
##
## Kept in one autoload so the screens stay dumb. A screen asks this what to
## draw and tells it what the player did; it never works anything out for
## itself, which is what makes the flow checkable headless.

signal brief_changed
signal shot_marked(index: int, verdict: Judge.Verdict)

class Handed extends RefCounted:
	var verdict: Judge.Verdict
	var photo: Image
	var settings: String

var briefs: Array[Brief] = []
var brief_index: int = 0
## One entry per shot in the current brief; null until the player hands one in.
var handed: Array = []

func _ready() -> void:
	reset()

func reset() -> void:
	briefs = Brief.all()
	brief_index = 0
	_clear_handed()

func _clear_handed() -> void:
	handed = []
	for _i in current_brief().shots.size():
		handed.append(null)

func current_brief() -> Brief:
	return briefs[clampi(brief_index, 0, briefs.size() - 1)]

func current_shots() -> Array[Brief.Shot]:
	return current_brief().shots

## The first shot the client has not accepted yet - what the viewfinder should
## be nagging the player about.
func next_unfinished() -> int:
	for i in handed.size():
		var h: Handed = handed[i]
		if h == null or not h.verdict.accepted():
			return i
	return -1

func hand_in(index: int, verdict: Judge.Verdict, photo: Image, settings: String) -> void:
	var h := Handed.new()
	h.verdict = verdict
	h.photo = photo
	h.settings = settings
	## A reshoot only replaces the picture if it beat the old one, so
	## experimenting is never punished.
	var existing: Handed = handed[index]
	if existing == null or verdict.score > existing.verdict.score:
		handed[index] = h
	shot_marked.emit(index, verdict)

func brief_complete() -> bool:
	for h in handed:
		if h == null or not h.verdict.accepted():
			return false
	return true

func brief_score() -> int:
	var total := 0
	var count := 0
	for h in handed:
		if h != null:
			total += h.verdict.score
		count += 1
	return 0 if count == 0 else roundi(float(total) / float(count))

func advance_brief() -> bool:
	if brief_index + 1 >= briefs.size():
		return false
	brief_index += 1
	_clear_handed()
	brief_changed.emit()
	return true

func is_last_brief() -> bool:
	return brief_index + 1 >= briefs.size()
