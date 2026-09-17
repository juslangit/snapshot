class_name Hud
extends Control

## What the player sees while holding the camera up.
##
## A viewfinder has to answer three questions without being read: what am I
## being paid to photograph, what is the camera set to, and is the light right.
## So the brief sits top left in the client's own words, the dials sit along
## the bottom where a right hand would find them, and the meter is a needle -
## the one instrument a photographer checks by glancing rather than reading.

signal grid_toggled(on: bool)

var camera: CameraBody
var _brief_title: Label
var _shot_title: Label
var _shot_note: Label
var _shot_demand: Label
var _progress: Label
var _dials: Label
var _dof: Label
var _needle: Panel
var _meter_text: Label
var _grid: Control
var _hint: Label
var _flash: ColorRect
var _shot_index: int = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_grid()
	_build_brief_card()
	_build_dial_bar()
	_build_meter()
	_build_flash()
	_build_hint()

# -- the brief, top left ----------------------------------------------------

func _build_brief_card() -> void:
	var card := Style.panel(Style.PANEL)
	card.position = Vector2(48, 44)
	card.custom_minimum_size = Vector2(660, 0)
	add_child(card)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	card.add_child(rows)

	_brief_title = Style.label("", Style.SIZE_SMALL, Style.AMBER)
	_progress = Style.label("", Style.SIZE_SMALL, Style.INK_DIM)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	head.add_child(_brief_title)
	head.add_child(_progress)
	rows.add_child(head)

	_shot_title = Style.label("", Style.SIZE_HEAD)
	rows.add_child(_shot_title)

	_shot_note = Style.label("", Style.SIZE_SMALL, Style.INK_DIM)
	_shot_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shot_note.custom_minimum_size = Vector2(616, 0)
	rows.add_child(_shot_note)

	_shot_demand = Style.label("", Style.SIZE_BODY, Style.AMBER)
	rows.add_child(_shot_demand)

# -- the dials, along the bottom -------------------------------------------

func _build_dial_bar() -> void:
	var bar := Style.panel(Style.PANEL)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 48
	bar.offset_right = -48
	bar.offset_top = -152
	bar.offset_bottom = -40
	add_child(bar)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	bar.add_child(rows)
	_dials = Style.label("", Style.SIZE_DIAL)
	rows.add_child(_dials)
	_dof = Style.label("", Style.SIZE_SMALL, Style.INK_DIM)
	rows.add_child(_dof)

# -- the meter, right of centre -------------------------------------------

func _build_meter() -> void:
	var holder := Style.panel(Style.PANEL_SOFT)
	holder.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	holder.offset_left = -300
	holder.offset_right = -48
	holder.offset_top = -66
	holder.offset_bottom = 66
	add_child(holder)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	holder.add_child(rows)
	rows.add_child(Style.label("LIGHT", Style.SIZE_SMALL, Style.INK_DIM))

	var track := Panel.new()
	track.custom_minimum_size = Vector2(206, 22)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.1)
	box.set_corner_radius_all(11)
	track.add_theme_stylebox_override("panel", box)
	rows.add_child(track)

	## The band in the middle is the stop either side of correct - the width a
	## client will accept. Landing the needle in it is the whole of exposure.
	var good := Panel.new()
	good.position = Vector2(206 * 0.5 - 24, 0)
	good.custom_minimum_size = Vector2(48, 22)
	good.size = Vector2(48, 22)
	var good_box := StyleBoxFlat.new()
	good_box.bg_color = Color(0.49, 0.78, 0.45, 0.35)
	good_box.set_corner_radius_all(11)
	good.add_theme_stylebox_override("panel", good_box)
	track.add_child(good)

	_needle = Panel.new()
	_needle.custom_minimum_size = Vector2(6, 30)
	_needle.size = Vector2(6, 30)
	_needle.position = Vector2(100, -4)
	var needle_box := StyleBoxFlat.new()
	needle_box.bg_color = Style.INK
	needle_box.set_corner_radius_all(3)
	_needle.add_theme_stylebox_override("panel", needle_box)
	track.add_child(_needle)

	_meter_text = Style.label("--", Style.SIZE_SMALL, Style.INK_DIM)
	rows.add_child(_meter_text)

func _build_grid() -> void:
	_grid = Control.new()
	_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.visible = true
	add_child(_grid)
	_grid.draw.connect(_draw_grid)

func _draw_grid() -> void:
	var size := _grid.size
	var line := Color(1, 1, 1, 0.22)
	for i in [1.0 / 3.0, 2.0 / 3.0]:
		_grid.draw_line(Vector2(size.x * i, 0), Vector2(size.x * i, size.y), line, 2.0)
		_grid.draw_line(Vector2(0, size.y * i), Vector2(size.x, size.y * i), line, 2.0)
	## The focus mark: a photographer needs to know where the camera is
	## measuring from, and it is always the middle.
	var centre := size * 0.5
	var arm := 16.0
	var mark := Color(1, 1, 1, 0.5)
	_grid.draw_line(centre - Vector2(arm, 0), centre + Vector2(arm, 0), mark, 2.0)
	_grid.draw_line(centre - Vector2(0, arm), centre + Vector2(0, arm), mark, 2.0)

func set_grid(on: bool) -> void:
	_grid.visible = on
	grid_toggled.emit(on)

func grid_on() -> bool:
	return _grid.visible

func _build_flash() -> void:
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(0, 0, 0, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

func _build_hint() -> void:
	_hint = Style.label("", Style.SIZE_SMALL, Style.INK_DIM)
	_hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hint.offset_left = -560
	_hint.offset_right = -48
	_hint.offset_top = 44
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.text = "1 2  aperture      3 4  shutter      5 6  ISO\n[ ]  focus       F  focus on centre      SCROLL  zoom\nQ E  tilt       R  level       G  grid       TAB  next shot\nCLICK  take the picture"
	add_child(_hint)

## The blink of the mirror when the shutter fires. Long exposures blink for
## longer, which is a small, free way of teaching what shutter speed is.
func blink(seconds: float) -> void:
	_flash.color = Color(0, 0, 0, 0.85)
	var tween := create_tween()
	tween.tween_property(_flash, "color", Color(0, 0, 0, 0), maxf(seconds, 0.06))

# -- kept up to date every frame ------------------------------------------

func show_shot(index: int) -> void:
	_shot_index = index

func _process(_delta: float) -> void:
	if camera == null:
		return
	var shots := Game.current_shots()
	if shots.is_empty():
		return
	var index := clampi(_shot_index, 0, shots.size() - 1)
	var shot := shots[index]
	_brief_title.text = Game.current_brief().client.to_upper()
	_progress.text = "shot %d of %d" % [index + 1, shots.size()]
	_shot_title.text = shot.title
	_shot_note.text = "\"%s\"" % shot.note
	_shot_demand.text = shot.demand_text().to_upper() if shot.demand != "" else ""

	_dials.text = "%.0f mm     f/%s     1/%s s     ISO %d     focus %.1f m" % [
		camera.focal_length_mm, Optics.APERTURE_MARKS[camera.aperture_index],
		Optics.SHUTTER_MARKS[camera.shutter_index],
		roundi(camera.sensitivity()), camera.focus_distance_m]
	var band := camera.depth_of_field()
	var far_text := "the horizon" if band.y == INF else "%.1f m" % band.y
	_dof.text = "sharp from %.1f m to %s        EV %.1f" % [band.x, far_text, camera.exposure_value()]

func set_meter(stops: float) -> void:
	## The needle runs three stops either way, which is as far as a frame is
	## worth looking at.
	var fraction := clampf((stops + 3.0) / 6.0, 0.0, 1.0)
	_needle.position.x = fraction * 200.0
	if absf(stops) <= 1.0:
		_meter_text.text = "good light"
		_meter_text.add_theme_color_override("font_color", Style.GOOD)
	elif stops > 0.0:
		_meter_text.text = "%.1f stops bright" % stops
		_meter_text.add_theme_color_override("font_color", Style.BAD)
	else:
		_meter_text.text = "%.1f stops dark" % absf(stops)
		_meter_text.add_theme_color_override("font_color", Style.BAD)
