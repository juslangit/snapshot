class_name SettingsScreen
extends Control

## The settings, each saved the moment it changes - there is no "apply"
## button to forget. Laid out like a camera's setup menu: the name on the left,
## the value on the right, one row per thing.

signal back_pressed

var _back: Button
var _rows: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Style.backdrop(0.94, 0.7))

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 110
	column.offset_right = -110
	column.offset_top = 80
	column.offset_bottom = -90
	column.add_theme_constant_override("separation", 40)
	add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 40)
	column.add_child(head)
	_back = Style.back_button()
	_back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(func() -> void: back_pressed.emit())
	head.add_child(_back)
	head.add_child(Style.heading("Settings", "Set up the camera"))

	var panel := Style.panel(Style.PANEL, 10)
	panel.custom_minimum_size = Vector2(1100, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(panel)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	panel.add_child(_rows)

func refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()
	_slider_row("Look sensitivity", "How fast the view turns with the mouse", "look_sensitivity", 0.3, 2.5, 0.05,
		func(v: float) -> String: return "%.2fx" % v)
	_slider_row("Volume", "Everything - the birds, the shutter, the dials", "volume", 0.0, 1.0, 0.05,
		func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_toggle_row("Full screen", "Fill the whole screen, no window", "fullscreen")
	_toggle_row("Show the controls", "The list of keys in the bottom right corner", "show_legend")
	_toggle_row("Thirds grid on at the start", "The grid can still be switched with G", "grid")
	_back.grab_focus()

func _row(title: String, note: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	row.custom_minimum_size = Vector2(0, 96)
	_rows.add_child(row)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)
	words.add_child(Style.label(title, Style.SIZE_HEAD, Style.INK))
	words.add_child(Style.label(note, Style.SIZE_SMALL, Style.INK_DIM))
	return row

func _slider_row(title: String, note: String, key: String, low: float, high: float, step: float, shown: Callable) -> void:
	var row := _row(title, note)
	var slider := HSlider.new()
	slider.name = key
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size = Vector2(380, 40)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(slider)
	row.add_child(slider)
	var value := Style.label("", Style.SIZE_BODY, Style.AMBER)
	value.custom_minimum_size = Vector2(110, 0)
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value)
	slider.value = float(Profile.setting(key))
	value.text = shown.call(slider.value)
	slider.value_changed.connect(func(v: float) -> void:
		value.text = shown.call(v)
		Profile.set_setting(key, v))
	slider.mouse_entered.connect(func() -> void: slider.grab_focus())

func _toggle_row(title: String, note: String, key: String) -> void:
	var row := _row(title, note)
	var toggle := Style.button("")
	toggle.name = key
	toggle.custom_minimum_size = Vector2(160, 64)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.add_theme_font_size_override("font_size", Style.SIZE_BODY)
	row.add_child(toggle)
	var shown := func() -> void:
		var on: bool = Profile.setting(key)
		toggle.text = "ON" if on else "OFF"
		toggle.add_theme_color_override("font_color", Style.GOOD if on else Style.INK_DIM)
	shown.call()
	toggle.pressed.connect(func() -> void:
		Profile.set_setting(key, not bool(Profile.setting(key)))
		shown.call())
	toggle.mouse_entered.connect(func() -> void: toggle.grab_focus())

## A thick amber track and a round grabber, so the slider reads at the same
## size as everything else on the screen.
func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.14)
	track.set_corner_radius_all(6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = Style.AMBER
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	var knob := Image.create(30, 30, false, Image.FORMAT_RGBA8)
	knob.fill(Color(0, 0, 0, 0))
	for y in 30:
		for x in 30:
			if Vector2(x - 14.5, y - 14.5).length() <= 14.0:
				knob.set_pixel(x, y, Style.INK)
	var texture := ImageTexture.create_from_image(knob)
	slider.add_theme_icon_override("grabber", texture)
	slider.add_theme_icon_override("grabber_highlight", texture)
