class_name MenuScreen
extends Control

## The main menu. The yard is behind it, with the camera drifting slowly round
## it, so the first thing a player sees is the place they are about to
## photograph rather than a picture of a menu.
##
## Dressed as a camera's viewfinder: corner brackets, the exposure the yard is
## lit for in the corner, and a menu that reads like a camera's own - numbered,
## left-aligned, an amber bar on the item under the cursor.

signal play_pressed
signal album_pressed
signal how_to_pressed
signal settings_pressed

var _first: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Style.backdrop(0.9, 0.15))

	var brackets := ViewfinderFrame.new()
	add_child(brackets)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	column.offset_left = 120
	column.offset_right = 820
	column.offset_top = 120
	column.offset_bottom = -120
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var logo := HBoxContainer.new()
	logo.add_theme_constant_override("separation", 26)
	column.add_child(logo)
	var iris := ApertureIcon.new()
	iris.custom_minimum_size = Vector2(104, 104)
	iris.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo.add_child(iris)
	var title := Style.label("SNAPSHOT", 104, Style.INK)
	title.add_theme_constant_override("outline_size", 0)
	logo.add_child(title)

	var tagline := Style.label("A photography game in one kampung morning", Style.SIZE_BODY, Style.AMBER)
	column.add_child(tagline)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 50)
	column.add_child(gap)

	var items := [
		["Play", play_pressed],
		["Photo album", album_pressed],
		["How to play", how_to_pressed],
		["Settings", settings_pressed],
	]
	for i in items.size():
		var b := Style.menu_button(items[i][0], i + 1)
		b.name = items[i][0].replace(" ", "")
		var sig: Signal = items[i][1]
		b.pressed.connect(func() -> void: sig.emit())
		column.add_child(b)
		if i == 0:
			_first = b
	var quit := Style.menu_button("Quit", items.size() + 1)
	quit.name = "Quit"
	quit.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(quit)

	## What a camera shows in the corner of its viewfinder: the settings the
	## yard is lit for. It is also a quiet promise about the game - these are
	## the real numbers.
	var corner := Style.label("f/8     1/125     ISO 100     EV 13", Style.SIZE_SMALL, Color(Style.INK, 0.7))
	corner.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corner.offset_right = -110
	corner.offset_bottom = -92
	add_child(corner)

	visibility_changed.connect(func() -> void:
		if visible and _first:
			_first.grab_focus())

func focus_first() -> void:
	if _first:
		_first.grab_focus()


## Four corner brackets, the marks a camera draws round the edge of the frame.
class ViewfinderFrame extends Control:
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var inset := 56.0
		var arm := 70.0
		var ink := Color(Style.INK, 0.55)
		var r := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
		for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var dx := arm if corner.x < size.x * 0.5 else -arm
			var dy := arm if corner.y < size.y * 0.5 else -arm
			draw_line(corner, corner + Vector2(dx, 0), ink, 3.0)
			draw_line(corner, corner + Vector2(0, dy), ink, 3.0)


## A six-bladed aperture, drawn: the logo is the thing the game is about.
class ApertureIcon extends Control:
	var opening: float = 0.42

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		draw_circle(c, r, Style.AMBER)
		draw_circle(c, r * 0.86, Style.BODY)
		## Six blades, each a triangle from the rim to a point on the edge of
		## the hexagonal opening, turned a little so they read as blades.
		var hole := r * 0.86 * opening
		for i in 6:
			var a := TAU * i / 6.0
			var b := TAU * (i + 1) / 6.0
			var p1 := c + Vector2.from_angle(a) * hole
			var p2 := c + Vector2.from_angle(b) * hole
			var rim := c + Vector2.from_angle(a + 0.55) * r * 0.86
			var shade := Color(0.26, 0.25, 0.24) if i % 2 == 0 else Color(0.2, 0.2, 0.19)
			draw_colored_polygon(PackedVector2Array([p1, p2, rim]), shade)
			draw_line(p1, rim, Color(0, 0, 0, 0.5), 2.0)
