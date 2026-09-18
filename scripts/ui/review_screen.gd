class_name ReviewScreen
extends Control

## The photograph, and what the client made of it.
##
## The picture is shown large and first, because that is what the player made
## and it is the only reward the game has. The marking sits beside it as a
## column of bars with the measurement written underneath each one, so a bad
## score is always a sentence a player can act on - "the cat at 6.2 m is
## outside the sharp band" - rather than a number.

signal reshoot_pressed
signal next_pressed

var _photo_rect: TextureRect
var _headline: Label
var _total: Label
var _settings: Label
var _lines: VBoxContainer
var _scroll: ScrollContainer
var _next: Button
var _reshoot: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var wash := ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.04, 0.04, 0.05, 0.96)
	add_child(wash)

	var split := HBoxContainer.new()
	split.anchor_right = 1.0
	split.anchor_bottom = 1.0
	split.offset_left = 56
	split.offset_right = -56
	split.offset_top = 48
	split.offset_bottom = -48
	split.add_theme_constant_override("separation", 36)
	add_child(split)

	## The print, with a white border, the way a photograph comes back from a
	## lab. It is given a real size rather than left to a container, because a
	## TextureRect that is told to fit its width has no minimum size of its own
	## and collapses to nothing - which is exactly what the first version did.
	var mount := Style.panel(Color(0.93, 0.92, 0.89), 3)
	mount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	split.add_child(mount)
	_photo_rect = TextureRect.new()
	_photo_rect.custom_minimum_size = Vector2(960, 540)
	_photo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mount.add_child(_photo_rect)

	var report := Style.panel(Style.PANEL)
	report.custom_minimum_size = Vector2(760, 0)
	report.size_flags_vertical = Control.SIZE_FILL
	split.add_child(report)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	report.add_child(rows)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	rows.add_child(head)
	_total = Style.label("", Style.SIZE_HUGE, Style.INK)
	head.add_child(_total)
	var out_of := Style.label("out of 100", Style.SIZE_SMALL, Style.INK_DIM)
	out_of.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(out_of)

	_headline = Style.label("", Style.SIZE_BODY, Style.AMBER)
	_headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_headline.custom_minimum_size = Vector2(680, 0)
	rows.add_child(_headline)
	_settings = Style.label("", Style.SIZE_SMALL, Style.INK_DIM)
	rows.add_child(_settings)
	rows.add_child(Style.separator())

	## The lines scroll rather than push the buttons off the screen. A badly
	## taken photograph has advice on every line, and without this the last
	## mark and "Shoot it again" fell off the bottom of a 1080p screen.
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 12)
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_lines)

	rows.add_child(Style.separator())
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	rows.add_child(buttons)
	_reshoot = Style.button("Shoot it again")
	_reshoot.custom_minimum_size = Vector2(270, 70)
	_reshoot.pressed.connect(func() -> void: reshoot_pressed.emit())
	buttons.add_child(_reshoot)
	_next = Style.button("Keep it")
	_next.custom_minimum_size = Vector2(250, 70)
	_next.pressed.connect(func() -> void: next_pressed.emit())
	buttons.add_child(_next)

func show_verdict(verdict: Judge.Verdict, photo: Image, settings: String, last_shot: bool) -> void:
	_photo_rect.texture = ImageTexture.create_from_image(photo)
	_total.text = "%d" % verdict.score
	_total.add_theme_color_override("font_color", Style.grade_colour(float(verdict.score) / 100.0))
	_headline.text = verdict.headline
	_settings.text = settings

	for child in _lines.get_children():
		child.queue_free()
	_scroll.scroll_vertical = 0

	for line in verdict.lines:
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 4)
		_lines.add_child(block)

		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 12)
		block.add_child(head)
		var label := Style.label(line.label, Style.SIZE_BODY, Style.INK)
		label.custom_minimum_size = Vector2(180, 0)
		head.add_child(label)
		var fraction: float = 0.0 if line.out_of <= 0.0 else line.points / line.out_of
		head.add_child(Style.bar(fraction, 230.0))
		head.add_child(Style.label("%d/%d" % [roundi(line.points), roundi(line.out_of)], Style.SIZE_SMALL, Style.INK_DIM))

		var detail := Style.label(line.detail, Style.SIZE_SMALL, Style.INK_DIM)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.custom_minimum_size = Vector2(680, 0)
		block.add_child(detail)

		## What to do about it, in amber so it reads as the instruction and
		## the grey line above it reads as the evidence.
		if line.fix != "":
			var fix := Style.label("Next time: " + line.fix, Style.SIZE_SMALL, Style.AMBER)
			fix.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			fix.custom_minimum_size = Vector2(680, 0)
			block.add_child(fix)

	if verdict.accepted():
		_next.text = "Hand in the brief" if last_shot else "Next shot"
	else:
		_next.text = "Hand it in anyway" if last_shot else "Move on anyway"
	_reshoot.grab_focus()
