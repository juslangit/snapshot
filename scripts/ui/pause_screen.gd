class_name PauseScreen
extends Control

## Esc in the yard. Before this existed Esc went straight back to the title and
## the brief was lost; now the job waits, and the settings and the guide are a
## press away without leaving it.

signal resume_pressed
signal how_to_pressed
signal settings_pressed
signal leave_pressed

var _first: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Style.backdrop(0.9, 0.45))

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	column.offset_left = 120
	column.offset_right = 820
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	column.add_child(Style.heading("Paused", "The yard can wait"))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	column.add_child(gap)

	var items := [
		["Back to the yard", resume_pressed],
		["How to play", how_to_pressed],
		["Settings", settings_pressed],
		["Leave the job", leave_pressed],
	]
	for i in items.size():
		var b := Style.menu_button(items[i][0], i + 1)
		b.name = String(items[i][0]).replace(" ", "")
		var sig: Signal = items[i][1]
		b.pressed.connect(func() -> void: sig.emit())
		column.add_child(b)
		if i == 0:
			_first = b

	var note := Style.label("Leaving loses the pictures handed in on this job so far.", Style.SIZE_SMALL, Style.INK_DIM)
	column.add_child(note)

func focus_first() -> void:
	if _first:
		_first.grab_focus()
