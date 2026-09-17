class_name BriefScreen
extends Control

## The client's letter, on paper.
##
## It is deliberately the only screen in the game that is not charcoal and
## amber: a brief arrives from outside, and it should feel like a thing that
## came in an envelope rather than part of the camera.

signal go_pressed

var _rows: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var wash := ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.05, 0.05, 0.06, 0.88)
	add_child(wash)

	var paper := Style.panel(Style.PAPER, 4)
	paper.set_anchors_preset(Control.PRESET_CENTER)
	paper.offset_left = -520
	paper.offset_right = 520
	paper.offset_top = -400
	paper.offset_bottom = 400
	add_child(paper)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 14)
	paper.add_child(_rows)

func show_brief(brief: Brief) -> void:
	for child in _rows.get_children():
		child.queue_free()

	_rows.add_child(Style.label(brief.client.to_upper(), Style.SIZE_SMALL, Color(0.45, 0.36, 0.22)))
	_rows.add_child(Style.label(brief.title, Style.SIZE_TITLE, Style.PAPER_INK))
	_rows.add_child(Style.separator(Color(0, 0, 0, 0.15)))

	var blurb := Style.label("\"%s\"" % brief.blurb, Style.SIZE_BODY, Color(0.24, 0.22, 0.19))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(960, 0)
	_rows.add_child(blurb)

	_rows.add_child(Style.label("WHAT WE NEED", Style.SIZE_SMALL, Color(0.45, 0.36, 0.22)))

	for i in brief.shots.size():
		var shot := brief.shots[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		_rows.add_child(row)

		var number := Style.label("%d." % (i + 1), Style.SIZE_HEAD, Color(0.55, 0.45, 0.3))
		number.custom_minimum_size = Vector2(48, 0)
		row.add_child(number)

		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 2)
		row.add_child(text)
		text.add_child(Style.label(shot.title, Style.SIZE_HEAD, Style.PAPER_INK))
		var note := Style.label(shot.note, Style.SIZE_SMALL, Color(0.34, 0.31, 0.27))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(820, 0)
		text.add_child(note)
		if shot.demand != "":
			text.add_child(Style.label("- %s" % shot.demand_text(), Style.SIZE_BODY, Color(0.58, 0.32, 0.12)))

	_rows.add_child(Style.separator(Color(0, 0, 0, 0.15)))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	_rows.add_child(buttons)
	var go := Style.button("Go to work")
	go.pressed.connect(func() -> void: go_pressed.emit())
	buttons.add_child(go)
	go.grab_focus()
