class_name WrapScreen
extends Control

## The contact sheet at the end of a brief: the three pictures the client got,
## side by side, with what each one scored. Seeing them together is the moment
## a player notices that the shot they fought hardest for is not the one that
## worked.

signal next_pressed
signal menu_pressed

var _rows: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var wash := ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.04, 0.04, 0.05, 0.95)
	add_child(wash)

	_rows = VBoxContainer.new()
	_rows.anchor_right = 1.0
	_rows.anchor_bottom = 1.0
	_rows.offset_left = 70
	_rows.offset_right = -70
	_rows.offset_top = 60
	_rows.offset_bottom = -60
	_rows.add_theme_constant_override("separation", 22)
	add_child(_rows)

func show_sheet(brief: Brief, handed: Array, more_briefs: bool, new_best: bool = false) -> void:
	for child in _rows.get_children():
		child.queue_free()

	_rows.add_child(Style.label(brief.client.to_upper(), Style.SIZE_SMALL, Style.AMBER))
	var title_line := HBoxContainer.new()
	title_line.add_theme_constant_override("separation", 26)
	_rows.add_child(title_line)
	title_line.add_child(Style.label(brief.title, Style.SIZE_TITLE))
	if new_best:
		## The one moment the game says well done out loud.
		var badge := Style.panel(Style.AMBER, 8)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.add_child(Style.label("NEW BEST", Style.SIZE_BODY, Style.BODY))
		title_line.add_child(badge)

	var accepted := 0
	var used := 0
	for h in handed:
		if h != null and h.verdict.accepted():
			accepted += 1
		if h != null and h.verdict.used():
			used += 1
	_rows.add_child(Style.label("%d of %d accepted, %d good enough to print - average %d" % [
		accepted, handed.size(), used, Game.brief_score()], Style.SIZE_BODY, Style.INK_DIM))
	_rows.add_child(Style.separator())

	var sheet := HBoxContainer.new()
	sheet.add_theme_constant_override("separation", 30)
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows.add_child(sheet)

	for i in handed.size():
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 10)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sheet.add_child(column)

		var handed_shot = handed[i]
		var mount := Style.panel(Color(0.92, 0.91, 0.88), 3)
		column.add_child(mount)
		if handed_shot != null:
			var frame := TextureRect.new()
			frame.texture = ImageTexture.create_from_image(handed_shot.photo)
			frame.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			frame.custom_minimum_size = Vector2(0, 260)
			mount.add_child(frame)
		else:
			var blank := Style.label("not taken", Style.SIZE_BODY, Color(0.5, 0.48, 0.45))
			blank.custom_minimum_size = Vector2(0, 260)
			blank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			blank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			mount.add_child(blank)

		column.add_child(Style.label(brief.shots[i].title, Style.SIZE_BODY))
		if handed_shot != null:
			var score := Style.label("%d" % handed_shot.verdict.score, Style.SIZE_TITLE,
				Style.grade_colour(float(handed_shot.verdict.score) / 100.0))
			column.add_child(score)
			var note := Style.label(handed_shot.verdict.headline, Style.SIZE_SMALL, Style.INK_DIM)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			column.add_child(note)
			column.add_child(Style.label(handed_shot.settings, Style.SIZE_SMALL, Color(0.45, 0.44, 0.42)))

	_rows.add_child(Style.separator())
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 20)
	_rows.add_child(buttons)
	var menu := Style.button("Main menu")
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	buttons.add_child(menu)
	var go := Style.button("The next job" if more_briefs else "Finish")
	go.pressed.connect(func() -> void: next_pressed.emit())
	buttons.add_child(go)
	go.grab_focus()
