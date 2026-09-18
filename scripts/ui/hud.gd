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
var _dof: Label
var _needle: Panel
var _meter_text: Label
var _grid: Control
var legend: ControlLegend
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
	_build_legend()

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

# -- the camera's settings, along the bottom left ---------------------------

## One cell per dial, like the top screen of a real camera: a small caption
## and a large value. The cell whose value just changed flashes amber, so a
## player pressing 3 sees which number moved without having to read them all.
const CELLS := ["ZOOM", "APERTURE", "SHUTTER", "ISO", "FOCUS"]

var _cells: Array[Label] = []
var _cell_glow: Array[float] = []
var _last_values: Array[String] = []

func _build_dial_bar() -> void:
	var bar := Style.panel(Style.PANEL)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_left = 40
	bar.offset_bottom = -40
	bar.offset_top = -40
	add_child(bar)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	bar.add_child(rows)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 30)
	rows.add_child(line)
	for caption in CELLS:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.custom_minimum_size = Vector2(128 if caption != "FOCUS" else 140, 0)
		line.add_child(cell)
		cell.add_child(Style.label(caption, Style.SIZE_CAPTION, Style.INK_DIM))
		var value := Style.label("", Style.SIZE_DIAL, Style.INK)
		cell.add_child(value)
		_cells.append(value)
		_cell_glow.append(0.0)
		_last_values.append("")

	line.add_child(_build_meter())
	_dof = Style.label("", Style.SIZE_SMALL, Style.INK_DIM)
	rows.add_child(_dof)

# -- the meter, at the end of the settings bar -----------------------------

## Inside the settings bar rather than floating on its own, the way a camera
## shows its meter in the strip along the bottom of the viewfinder.
func _build_meter() -> Control:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	rows.add_child(Style.label("LIGHT", Style.SIZE_CAPTION, Style.INK_DIM))

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
	return rows

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

func _build_legend() -> void:
	legend = ControlLegend.new()
	legend.name = "Legend"
	add_child(legend)

## The blink of the mirror when the shutter fires. Long exposures blink for
## longer, which is a small, free way of teaching what shutter speed is.
func blink(seconds: float) -> void:
	_flash.color = Color(0, 0, 0, 0.85)
	var tween := create_tween()
	tween.tween_property(_flash, "color", Color(0, 0, 0, 0), maxf(seconds, 0.06))

# -- kept up to date every frame ------------------------------------------

func show_shot(index: int) -> void:
	_shot_index = index

func _process(delta: float) -> void:
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

	var values: Array[String] = [
		"%.0f mm" % camera.focal_length_mm,
		"f/%s" % Optics.APERTURE_MARKS[camera.aperture_index],
		"1/%s" % Optics.SHUTTER_MARKS[camera.shutter_index],
		"%d" % roundi(camera.sensitivity()),
		"%.1f m" % camera.focus_distance_m,
	]
	for i in values.size():
		if values[i] != _last_values[i]:
			## The first fill is not a change the player made, so it does not
			## flash.
			if _last_values[i] != "":
				_cell_glow[i] = 1.0
			_last_values[i] = values[i]
			_cells[i].text = values[i]
		_cell_glow[i] = maxf(0.0, _cell_glow[i] - delta / 0.9)
		_cells[i].add_theme_color_override("font_color", Style.INK.lerp(Style.AMBER, _cell_glow[i]))
	var band := camera.depth_of_field()
	var far_text := "the horizon" if band.y == INF else "%.1f m" % band.y
	_dof.text = "sharp from %.1f m to %s     EV %.1f" % [band.x, far_text, camera.exposure_value()]

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
