class_name ControlLegend
extends VBoxContainer

## The list of controls in the bottom right corner, the way a fighting game
## shows its move list: one row per action, the key drawn as a keycap beside
## it, and the row you just used lights up and fades.
##
## The lighting-up is the point. A beginner presses 1, sees "Aperture" glow,
## and watches the picture change at the same moment - the key, the word and
## the effect arrive together, which is how the controls get learned without a
## tutorial.
##
## It listens to input without consuming it, so it can never get in the way of
## the controls it is describing.

const ROW_WIDTH := 430.0
const ROW_HEIGHT := 44.0
const CAP_HEIGHT := 34.0
const FADE_SECONDS := 1.4

## caps: what is drawn. A plain string is a keycap; "@left" is a mouse with the
## left button lit, "@wheel" a mouse with the wheel lit.
## keys / buttons: what lights the row up.
const ROWS := [
	{"caps": ["@left"], "label": "Take the picture", "buttons": [MOUSE_BUTTON_LEFT]},
	{"caps": ["1", "2"], "label": "Aperture", "keys": [KEY_1, KEY_2]},
	{"caps": ["3", "4"], "label": "Shutter speed", "keys": [KEY_3, KEY_4]},
	{"caps": ["5", "6"], "label": "ISO", "keys": [KEY_5, KEY_6]},
	{"caps": ["[", "]", "F"], "label": "Focus  /  autofocus", "keys": [KEY_BRACKETLEFT, KEY_BRACKETRIGHT, KEY_F]},
	{"caps": ["@wheel"], "label": "Zoom", "buttons": [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]},
	{"caps": ["Q", "E", "R"], "label": "Tilt  /  level", "keys": [KEY_Q, KEY_E, KEY_R]},
	{"caps": ["G"], "label": "Thirds grid", "keys": [KEY_G]},
	{"caps": ["Tab"], "label": "Next shot", "keys": [KEY_TAB]},
	{"caps": ["W", "A", "S", "D"], "label": "Walk", "keys": [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]},
	{"caps": ["Shift"], "label": "Hurry", "keys": [KEY_SHIFT]},
	{"caps": ["C"], "label": "Crouch", "keys": [KEY_C, KEY_CTRL]},
	{"caps": ["Esc"], "label": "Pause", "keys": [KEY_ESCAPE]},
]

var _glows: Array[TextureRect] = []
var _bars: Array[ColorRect] = []
var _labels: Array[Label] = []
var _heat: Array[float] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 3)
	## Pinned to the bottom right corner and growing up and to the left, so the
	## list can gain or lose a row without anything else having to move.
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_right = -40
	offset_bottom = -40
	offset_left = -40
	offset_top = -40
	for row in ROWS:
		add_child(_row(row))

func _row(spec: Dictionary) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(ROW_WIDTH, ROW_HEIGHT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Dark at the screen edge and thinning towards the middle of the frame,
	## so the list reads as part of the screen rather than a box stuck on it.
	var shade := _gradient_rect(Color(0.05, 0.05, 0.06, 0.38), Color(0.05, 0.05, 0.06, 0.82))
	row.add_child(shade)
	var glow := _gradient_rect(Color(Style.AMBER, 0.0), Color(Style.AMBER, 0.55))
	glow.modulate.a = 0.0
	row.add_child(glow)
	_glows.append(glow)

	var bar := ColorRect.new()
	bar.color = Color(1, 1, 1, 0.25)
	bar.anchor_left = 1.0
	bar.anchor_right = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -4
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	_bars.append(bar)

	var line := HBoxContainer.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 12
	line.offset_right = -16
	line.alignment = BoxContainer.ALIGNMENT_BEGIN
	line.add_theme_constant_override("separation", 6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)

	## The caps sit in a fixed-width column so every label starts at the same
	## place, the way the move names line up in a fighting game's list.
	var caps := HBoxContainer.new()
	caps.custom_minimum_size = Vector2(172, 0)
	caps.add_theme_constant_override("separation", 5)
	caps.alignment = BoxContainer.ALIGNMENT_END
	caps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(caps)
	for cap in spec["caps"]:
		caps.add_child(_cap(cap))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(12, 0)
	line.add_child(spacer)

	var label := Style.label(spec["label"], Style.SIZE_LEGEND, Style.INK)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	line.add_child(label)
	_labels.append(label)

	_heat.append(0.0)
	return row

func _gradient_rect(left: Color, right: Color) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, left)
	gradient.set_color(1, right)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 4
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

## One key, drawn as a keycap: an outlined rounded square with the key's name
## in it. Mouse controls are drawn as a small mouse instead.
func _cap(text: String) -> Control:
	if text.begins_with("@"):
		var mouse := MouseGlyph.new()
		mouse.lit = text.substr(1)
		mouse.custom_minimum_size = Vector2(26, CAP_HEIGHT)
		mouse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return mouse
	return Style.keycap(text)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code := (event as InputEventKey).physical_keycode
		for i in ROWS.size():
			if code in ROWS[i].get("keys", []):
				light(i)
	elif event is InputEventMouseButton and event.pressed:
		var button := (event as InputEventMouseButton).button_index
		for i in ROWS.size():
			if button in ROWS[i].get("buttons", []):
				light(i)

## Light a row up, as if its key had just been pressed.
func light(index: int) -> void:
	if index >= 0 and index < _heat.size():
		_heat[index] = 1.0

func lit_row() -> int:
	var best := -1
	for i in _heat.size():
		if _heat[i] > 0.0 and (best < 0 or _heat[i] > _heat[best]):
			best = i
	return best

func _process(delta: float) -> void:
	for i in _heat.size():
		## Held keys - walking, hurrying - keep their row lit for as long as
		## they are down, rather than flickering.
		if _held(i):
			_heat[i] = 1.0
		_heat[i] = maxf(0.0, _heat[i] - delta / FADE_SECONDS)
		var h := _heat[i]
		_glows[i].modulate.a = h
		_bars[i].color = Color(1, 1, 1, 0.25).lerp(Style.AMBER, h)
		_labels[i].add_theme_color_override("font_color", Style.INK.lerp(Color(1, 0.93, 0.78), h))

func _held(i: int) -> bool:
	if not is_visible_in_tree():
		return false
	for code in ROWS[i].get("keys", []):
		if code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SHIFT, KEY_Q, KEY_E] and Input.is_physical_key_pressed(code):
			return true
	return false


## A mouse, drawn rather than loaded, with either its left button or its
## wheel lit - the two things this game uses a mouse for.
class MouseGlyph extends Control:
	var lit: String = "left"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var body := Rect2(Vector2(2, 1), Vector2(w - 4, h - 2))
		var ink := Color(Style.INK, 0.85)
		var fill := Style.INK
		## The body: a rounded outline, built from a StyleBoxFlat so the corners
		## match the keycaps beside it.
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1, 1, 1, 0.08)
		box.border_color = ink
		box.set_border_width_all(2)
		box.set_corner_radius_all(int(w * 0.5) - 2)
		draw_style_box(box, body)
		var split_y := body.position.y + body.size.y * 0.42
		draw_line(Vector2(body.position.x + 2, split_y), Vector2(body.end.x - 2, split_y), ink, 2.0)
		draw_line(Vector2(w * 0.5, body.position.y + 2), Vector2(w * 0.5, split_y), ink, 2.0)
		if lit == "left":
			var button := PackedVector2Array([
				Vector2(body.position.x + 4, split_y - 1),
				Vector2(body.position.x + 4, body.position.y + 9),
				Vector2(body.position.x + 7, body.position.y + 4),
				Vector2(w * 0.5 - 1, body.position.y + 3),
				Vector2(w * 0.5 - 1, split_y - 1),
			])
			draw_colored_polygon(button, fill)
		else:
			draw_rect(Rect2(Vector2(w * 0.5 - 3, body.position.y + 5), Vector2(6, 10)), fill)
