class_name Style
extends RefCounted

## One place for how the game looks, so the screens can be short.
##
## The look is borrowed from the things a photographer handles: the charcoal of
## a camera body, the amber of a film box, the grey of a contact sheet. Type is
## deliberately large - these are numbers a player reads while holding a camera
## up, at a glance, not paragraphs.

const INK := Color(0.93, 0.92, 0.89)
const INK_DIM := Color(0.66, 0.65, 0.62)
const BODY := Color(0.09, 0.09, 0.10)
const PANEL := Color(0.13, 0.13, 0.14, 0.96)
const PANEL_SOFT := Color(0.17, 0.17, 0.18, 0.92)
const AMBER := Color(0.96, 0.70, 0.24)
const GOOD := Color(0.49, 0.78, 0.45)
const BAD := Color(0.88, 0.38, 0.33)
const PAPER := Color(0.91, 0.88, 0.81)
const PAPER_INK := Color(0.13, 0.12, 0.11)

const SIZE_HUGE := 84
const SIZE_TITLE := 54
const SIZE_HEAD := 36
const SIZE_BODY := 26
const SIZE_SMALL := 21
const SIZE_DIAL := 34

static func label(text: String, size: int, colour: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l

static func panel(colour: Color = PANEL, radius: int = 10) -> PanelContainer:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(22)
	p.add_theme_stylebox_override("panel", box)
	return p

static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", SIZE_HEAD)
	b.custom_minimum_size = Vector2(300, 78)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.2, 0.2, 0.21)
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(16)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = AMBER
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.78, 0.55, 0.16)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", BODY)
	b.add_theme_color_override("font_pressed_color", BODY)
	return b

static func separator(colour: Color = Color(1, 1, 1, 0.12)) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 2)
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	p.add_theme_stylebox_override("panel", box)
	return p

## A score bar, used all over the review screen. The colour is the grade, so a
## player reads the shape of a report before reading a word of it.
static func bar(fraction: float, width: float = 320.0) -> Control:
	var track := Panel.new()
	track.custom_minimum_size = Vector2(width, 14)
	var track_box := StyleBoxFlat.new()
	track_box.bg_color = Color(1, 1, 1, 0.1)
	track_box.set_corner_radius_all(7)
	track.add_theme_stylebox_override("panel", track_box)

	var fill := Panel.new()
	fill.anchor_bottom = 1.0
	fill.offset_right = width * clampf(fraction, 0.0, 1.0)
	var fill_box := StyleBoxFlat.new()
	fill_box.bg_color = grade_colour(fraction)
	fill_box.set_corner_radius_all(7)
	fill.add_theme_stylebox_override("panel", fill_box)
	track.add_child(fill)
	return track

static func grade_colour(fraction: float) -> Color:
	if fraction >= 0.85:
		return GOOD
	if fraction >= 0.6:
		return AMBER
	return BAD
