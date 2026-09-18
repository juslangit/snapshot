class_name JobsScreen
extends Control

## Choosing a job. Each client is a card, like a letter pinned to a board:
## who they are, what they want, the three shots, and the best you have handed
## them so far. Every job is open from the start - nothing here is locked
## behind another, so a player who only wants to try the fast shutter can go
## straight to the magazine.

signal job_chosen(index: int)
signal back_pressed

var _cards: HBoxContainer
var _back: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Style.backdrop(0.93, 0.8))

	var rows := VBoxContainer.new()
	rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rows.offset_left = 110
	rows.offset_right = -110
	rows.offset_top = 80
	rows.offset_bottom = -90
	rows.add_theme_constant_override("separation", 34)
	add_child(rows)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 40)
	rows.add_child(head)
	_back = Style.back_button()
	_back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(func() -> void: back_pressed.emit())
	head.add_child(_back)
	head.add_child(Style.heading("Play", "Choose a job"))

	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 36)
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(_cards)

## Rebuilt every time the screen opens, so a best score earned a minute ago is
## already on its card.
func refresh(briefs: Array[Brief]) -> void:
	for child in _cards.get_children():
		child.queue_free()
	var first: Button = null
	for i in briefs.size():
		var card := _card(briefs[i], i)
		_cards.add_child(card)
		if first == null:
			first = card.get_meta("button")
	if first:
		first.grab_focus()

func _card(brief: Brief, index: int) -> Control:
	var paper := Style.panel(Style.PAPER, 6)
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	paper.add_child(rows)

	var brown := Color(0.45, 0.36, 0.22)
	rows.add_child(Style.label("JOB %d  -  %s" % [index + 1, brief.client.to_upper()], Style.SIZE_SMALL, brown))
	var title := Style.label(brief.title, Style.SIZE_HEAD, Style.PAPER_INK)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(title)
	rows.add_child(Style.separator(Color(0, 0, 0, 0.15)))

	var blurb := Style.label("\"%s\"" % brief.blurb, Style.SIZE_SMALL, Color(0.26, 0.24, 0.21))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(420, 0)
	rows.add_child(blurb)

	for shot in brief.shots:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		rows.add_child(line)
		line.add_child(Style.label("-", Style.SIZE_BODY, brown))
		var text := Style.label(shot.title, Style.SIZE_SMALL, Style.PAPER_INK)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(text)

	## What the job teaches, in the words of the camera, so a player can pick
	## the lesson they want.
	var lessons := {}
	for shot in brief.shots:
		if shot.demand != "":
			lessons[shot.demand_text()] = true
	if not lessons.is_empty():
		rows.add_child(Style.label("NEEDS:  " + ",  ".join(lessons.keys()).to_upper(), Style.SIZE_CAPTION, Color(0.58, 0.32, 0.12)))

	var spring := Control.new()
	spring.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(spring)

	var best := Profile.best_score(index)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 18)
	rows.add_child(foot)
	if best >= 0:
		var score_box := VBoxContainer.new()
		score_box.add_theme_constant_override("separation", -6)
		score_box.add_child(Style.label("BEST", Style.SIZE_CAPTION, brown))
		score_box.add_child(Style.label("%d" % best, Style.SIZE_TITLE, Style.grade_colour(best / 100.0).darkened(0.25)))
		foot.add_child(score_box)
	else:
		var fresh := Style.label("NEW", Style.SIZE_BODY, Color(0.58, 0.32, 0.12))
		fresh.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		foot.add_child(fresh)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(fill)
	var take := Style.button("Take it" if best < 0 else "Again")
	take.custom_minimum_size = Vector2(220, 70)
	take.name = "Take%d" % index
	take.pressed.connect(func() -> void: job_chosen.emit(index))
	take.mouse_entered.connect(func() -> void: take.grab_focus())
	foot.add_child(take)
	paper.set_meta("button", take)
	return paper
