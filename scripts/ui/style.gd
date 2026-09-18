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
const SIZE_LEGEND := 24
const SIZE_CAP := 19
const SIZE_CAPTION := 17

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

# -- the menus ------------------------------------------------------------------

const SIZE_MENU := 42

## A menu item the way a camera's own menu draws one: left-aligned, a number
## in front, and an amber bar down the left edge on the item under the cursor.
static func menu_button(text: String, number: int = 0) -> Button:
	var b := Button.new()
	b.text = ("%02d    %s" % [number, text]) if number > 0 else text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", SIZE_MENU)
	b.custom_minimum_size = Vector2(520, 76)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.content_margin_left = 28
	normal.content_margin_right = 20
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(AMBER, 0.14)
	hover.border_color = AMBER
	hover.border_width_left = 8
	hover.content_margin_left = 40
	hover.content_margin_right = 20
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(AMBER, 0.3)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", AMBER)
	b.add_theme_color_override("font_focus_color", AMBER)
	b.add_theme_color_override("font_pressed_color", AMBER)
	b.add_theme_color_override("font_hover_pressed_color", AMBER)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	return b

## The small "back" button every sub-screen has in its top left, with the Esc
## keycap drawn beside the word so the keyboard route is never a secret.
static func back_button(text: String = "Back") -> Button:
	var b := button("<   " + text)
	b.add_theme_font_size_override("font_size", SIZE_BODY)
	b.custom_minimum_size = Vector2(200, 62)
	return b

## A keycap, the same drawing the control legend uses, for any screen that
## wants to name a key.
static func keycap(text: String, size: int = SIZE_CAP) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.custom_minimum_size = Vector2(size * 1.8, size * 1.8)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.08)
	box.border_color = Color(INK, 0.85)
	box.set_border_width_all(2)
	box.border_width_bottom = 4
	box.set_corner_radius_all(6)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_bottom = 2
	cap.add_theme_stylebox_override("panel", box)
	var l := label(text, size, INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.add_child(l)
	return cap

## The dark wash every menu screen sits on, heavier on the left where the
## words are and thinner on the right where the yard shows through.
static func backdrop(left_alpha: float = 0.92, right_alpha: float = 0.55) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.04, 0.04, 0.05, left_alpha))
	gradient.set_color(1, Color(0.04, 0.04, 0.05, right_alpha))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 4
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect

## A screen's heading: a small amber kicker over a large title.
static func heading(kicker: String, title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(label(kicker.to_upper(), SIZE_SMALL, AMBER))
	box.add_child(label(title, SIZE_TITLE, INK))
	return box
