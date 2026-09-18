class_name AlbumScreen
extends Control

## Every photograph the player chose to keep, newest first, as prints on a
## dark table. Clicking one opens it large with what it was, what it scored
## and the settings it was taken at - so the album doubles as a record of what
## worked.

signal back_pressed

const COLUMNS := 4
const THUMB := Vector2(380, 214)

var _grid: GridContainer
var _empty: Label
var _count: Label
var _back: Button
var _viewer: Control
var _viewer_photo: TextureRect
var _viewer_title: Label
var _viewer_detail: Label
var _viewer_entry: Dictionary
var _remove: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Style.backdrop(0.95, 0.9))

	var rows := VBoxContainer.new()
	rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rows.offset_left = 110
	rows.offset_right = -110
	rows.offset_top = 80
	rows.offset_bottom = -60
	rows.add_theme_constant_override("separation", 30)
	add_child(rows)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 40)
	rows.add_child(head)
	_back = Style.back_button()
	_back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(func() -> void: back_pressed.emit())
	head.add_child(_back)
	head.add_child(Style.heading("Photo album", "Your pictures"))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(fill)
	_count = Style.label("", Style.SIZE_BODY, Style.INK_DIM)
	_count.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_count)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 34)
	_grid.add_theme_constant_override("v_separation", 34)
	scroll.add_child(_grid)

	_empty = Style.label("No photographs yet.\n\nEvery picture a client accepts lands here when you move on from it.", Style.SIZE_BODY, Style.INK_DIM)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.set_anchors_preset(Control.PRESET_CENTER)
	_empty.offset_left = -480
	_empty.offset_right = 480
	_empty.offset_top = -80
	_empty.offset_bottom = 80
	add_child(_empty)

	_build_viewer()

func refresh() -> void:
	close_viewer()
	for child in _grid.get_children():
		child.queue_free()
	var entries := Profile.album()
	_empty.visible = entries.is_empty()
	_count.text = "" if entries.is_empty() else ("1 photograph" if entries.size() == 1 else "%d photographs" % entries.size())
	for entry in entries:
		_grid.add_child(_print(entry))
	_back.grab_focus()

func is_viewing() -> bool:
	return _viewer.visible

## One print: the photograph with a white border, and a caption under it.
func _print(entry: Dictionary) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)

	var button := Button.new()
	button.custom_minimum_size = THUMB + Vector2(20, 20)
	button.focus_mode = Control.FOCUS_ALL
	var mount := StyleBoxFlat.new()
	mount.bg_color = Color(0.93, 0.92, 0.89)
	mount.set_content_margin_all(10)
	mount.set_corner_radius_all(3)
	var lit := mount.duplicate() as StyleBoxFlat
	lit.bg_color = Style.AMBER
	button.add_theme_stylebox_override("normal", mount)
	button.add_theme_stylebox_override("hover", lit)
	button.add_theme_stylebox_override("focus", lit)
	button.add_theme_stylebox_override("pressed", lit)
	column.add_child(button)

	var picture := TextureRect.new()
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.offset_left = 10
	picture.offset_top = 10
	picture.offset_right = -10
	picture.offset_bottom = -10
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := Profile.album_image(entry)
	if image:
		image.resize(int(THUMB.x), int(THUMB.x * image.get_height() / maxf(image.get_width(), 1)), Image.INTERPOLATE_BILINEAR)
		picture.texture = ImageTexture.create_from_image(image)
	button.add_child(picture)
	button.pressed.connect(func() -> void: open_viewer(entry))
	button.mouse_entered.connect(func() -> void: button.grab_focus())

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	column.add_child(line)
	var score: int = entry.get("score", 0)
	line.add_child(Style.label("%d" % score, Style.SIZE_HEAD, Style.grade_colour(score / 100.0)))
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -2)
	line.add_child(words)
	words.add_child(Style.label(entry.get("shot", ""), Style.SIZE_SMALL, Style.INK))
	words.add_child(Style.label(entry.get("client", ""), Style.SIZE_CAPTION, Style.INK_DIM))
	return column

# -- the viewer ---------------------------------------------------------------

func _build_viewer() -> void:
	_viewer = Control.new()
	_viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewer.visible = false
	add_child(_viewer)
	var wash := ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.02, 0.02, 0.03, 0.96)
	_viewer.add_child(wash)

	var rows := VBoxContainer.new()
	rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rows.offset_left = 160
	rows.offset_right = -160
	rows.offset_top = 60
	rows.offset_bottom = -60
	rows.add_theme_constant_override("separation", 20)
	_viewer.add_child(rows)

	var mount := Style.panel(Color(0.93, 0.92, 0.89), 3)
	mount.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(mount)
	_viewer_photo = TextureRect.new()
	_viewer_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_viewer_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_viewer_photo.custom_minimum_size = Vector2(0, 600)
	mount.add_child(_viewer_photo)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 24)
	rows.add_child(foot)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(words)
	_viewer_title = Style.label("", Style.SIZE_HEAD, Style.INK)
	words.add_child(_viewer_title)
	_viewer_detail = Style.label("", Style.SIZE_SMALL, Style.INK_DIM)
	words.add_child(_viewer_detail)

	## Deleting is for good - the file goes too - so it takes two presses.
	_remove = Style.button("Delete")
	var remove := _remove
	remove.custom_minimum_size = Vector2(260, 70)
	remove.pressed.connect(func() -> void:
		if remove.text == "Delete":
			remove.text = "Sure? Press again"
			return
		Profile.forget_photo(_viewer_entry)
		refresh())
	foot.add_child(remove)
	var close := Style.button("Close")
	close.name = "Close"
	close.custom_minimum_size = Vector2(190, 70)
	close.pressed.connect(close_viewer)
	foot.add_child(close)

func open_viewer(entry: Dictionary) -> void:
	_viewer_entry = entry
	var image := Profile.album_image(entry)
	_viewer_photo.texture = ImageTexture.create_from_image(image) if image else null
	_viewer_title.text = "%s  -  %d" % [entry.get("shot", ""), entry.get("score", 0)]
	_viewer_detail.text = "%s     %s     %s" % [entry.get("client", ""), entry.get("settings", ""), entry.get("date", "")]
	_remove.text = "Delete"
	_viewer.visible = true
	(_viewer.find_child("Close", true, false) as Button).grab_focus()

func close_viewer() -> void:
	if _viewer:
		_viewer.visible = false
