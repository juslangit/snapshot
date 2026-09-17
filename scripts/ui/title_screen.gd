class_name TitleScreen
extends Control

signal start_pressed

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var wash := ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.05, 0.05, 0.06, 0.82)
	add_child(wash)

	var rows := VBoxContainer.new()
	rows.set_anchors_preset(Control.PRESET_CENTER)
	rows.offset_left = -520
	rows.offset_right = 520
	rows.offset_top = -280
	rows.offset_bottom = 280
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 20)
	add_child(rows)

	var title := Style.label("SNAPSHOT", Style.SIZE_HUGE, Style.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)

	var line := Style.label("One kampung morning. A camera with real settings. A client who wants three pictures.", Style.SIZE_BODY, Style.AMBER)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(line)

	rows.add_child(Style.separator())

	var how := Style.label("Aperture, shutter speed and ISO do here what they do on a real camera - and they are judged the same way. Open the aperture and the background falls away, but the frame fills with light. Speed the shutter up to stop the hen mid-step, and the light drains out again. Buy it back with ISO and the picture goes grainy.\n\nThat trade is the game. Walk, crouch, frame, and make the picture the client asked for.", Style.SIZE_SMALL, Style.INK_DIM)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(how)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	rows.add_child(buttons)

	var start := Style.button("Take the job")
	start.pressed.connect(func() -> void: start_pressed.emit())
	buttons.add_child(start)

	var quit := Style.button("Quit")
	quit.custom_minimum_size = Vector2(180, 78)
	quit.pressed.connect(func() -> void: get_tree().quit())
	buttons.add_child(quit)

	start.grab_focus()
