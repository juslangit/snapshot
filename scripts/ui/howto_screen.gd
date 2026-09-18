class_name HowToScreen
extends Control

## How to play, for somebody who has never touched a camera. One idea per
## page, a drawing of it, and the keys that do it. The drawings are made in
## code rather than loaded, so they are always in step with the game's own
## numbers: f/2 against f/16, 1/30 against 1/1000, ISO 100 against 3200.

signal back_pressed

const PAGES := [
	{
		"kicker": "The job",
		"title": "A client wants three pictures",
		"body": "Each job is a letter from a client asking for three photographs. Walk round the yard, find what they asked for, and take it.\n\nEvery picture is marked out of 100. At 60 the client accepts it; at 85 they print it. After each shot the review tells you what cost you marks - and what to change next time.",
		"keys": [["@left", "Take the picture"], ["Tab", "Next shot on the brief"]],
	},
	{
		"kicker": "Aperture",
		"title": "How big the hole in the lens is",
		"body": "A small f-number like f/2 is a big hole: lots of light, and only a thin slice of the picture is sharp - the background melts away.\n\nA big f-number like f/16 is a small hole: less light, and everything from front to back stays sharp.\n\nWant a soft background? Open up (small number). Want the whole yard sharp? Close down (big number).",
		"keys": [["1", "Open up - smaller number, more light"], ["2", "Close down - bigger number, less light"]],
	},
	{
		"kicker": "Shutter speed",
		"title": "How long the camera looks",
		"body": "1/1000 means the camera looks for a thousandth of a second - fast enough to freeze a hen mid-step, but it lets in very little light.\n\n1/30 looks thirty times longer. Lots of light, but anything that moves becomes a smear.\n\nSomething moving? Speed up. Everything still? You can slow down and take the light.",
		"keys": [["3", "Slower - more light, more blur"], ["4", "Faster - less light, freezes movement"]],
	},
	{
		"kicker": "ISO",
		"title": "How sensitive the camera is",
		"body": "ISO 100 is clean and smooth. Every step up doubles the brightness - but adds grain, like sand over the picture.\n\nISO is how you buy back light when the aperture and shutter cannot give you any more. Use it last, and use as little as you can.",
		"keys": [["5", "Lower - cleaner, darker"], ["6", "Higher - brighter, grainier"]],
	},
	{
		"kicker": "The light meter",
		"title": "Keep the needle in the green",
		"body": "The LIGHT bar next to your settings is the camera's meter. Left is too dark, right is too bright, the green band is right.\n\nThis is the whole game: aperture, shutter and ISO all change the light. Open the aperture two steps for a soft background, and the picture gets two steps brighter - so speed the shutter up two steps to pay for it. Every choice is a trade.",
		"keys": [["1", "Aperture"], ["3", "Shutter"], ["5", "ISO"]],
	},
	{
		"kicker": "Focus and framing",
		"title": "Sharp where it matters, placed with care",
		"body": "Point the cross in the middle at your subject and press F - the camera focuses there, like autofocus.\n\nThe thirds grid splits the frame into nine. Pictures look best with the subject where two lines cross, not dead centre. Scroll to zoom, and crouch to shoot small things at their own height.",
		"keys": [["F", "Focus on the middle"], ["@wheel", "Zoom"], ["G", "Thirds grid"], ["C", "Crouch"]],
	},
]

var page: int = 0
var _back: Button
var _kicker: Label
var _title: Label
var _body: Label
var _keys: VBoxContainer
var _drawing: Diagram
var _dots: HBoxContainer
var _prev: Button
var _next: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Style.backdrop(0.95, 0.88))

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 110
	column.offset_right = -110
	column.offset_top = 80
	column.offset_bottom = -80
	column.add_theme_constant_override("separation", 36)
	add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 40)
	column.add_child(head)
	_back = Style.back_button()
	_back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(func() -> void: back_pressed.emit())
	head.add_child(_back)
	head.add_child(Style.heading("How to play", "The camera, in six pages"))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 60)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	var picture := Style.panel(Style.PANEL, 10)
	picture.custom_minimum_size = Vector2(760, 0)
	body.add_child(picture)
	_drawing = Diagram.new()
	_drawing.custom_minimum_size = Vector2(700, 520)
	picture.add_child(_drawing)

	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 16)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(words)
	_kicker = Style.label("", Style.SIZE_BODY, Style.AMBER)
	words.add_child(_kicker)
	_title = Style.label("", Style.SIZE_TITLE, Style.INK)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_title)
	_body = Style.label("", Style.SIZE_BODY, Color(Style.INK, 0.86))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_body)
	_keys = VBoxContainer.new()
	_keys.add_theme_constant_override("separation", 10)
	words.add_child(_keys)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 24)
	column.add_child(foot)
	_prev = Style.button("<   Back a page")
	_prev.pressed.connect(func() -> void: show_page(page - 1))
	foot.add_child(_prev)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(fill)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 14)
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_dots)
	var fill2 := Control.new()
	fill2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(fill2)
	_next = Style.button("Next page   >")
	_next.name = "NextPage"
	_next.pressed.connect(func() -> void:
		if page + 1 < PAGES.size():
			show_page(page + 1)
		else:
			back_pressed.emit())
	foot.add_child(_next)

func open() -> void:
	show_page(0)

func show_page(index: int) -> void:
	page = clampi(index, 0, PAGES.size() - 1)
	var spec: Dictionary = PAGES[page]
	_kicker.text = "%d / %d     %s" % [page + 1, PAGES.size(), spec["kicker"].to_upper()]
	_title.text = spec["title"]
	_body.text = spec["body"]
	_drawing.kind = page
	_drawing.queue_redraw()

	for child in _keys.get_children():
		child.queue_free()
	for pair in spec["keys"]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 16)
		_keys.add_child(line)
		if String(pair[0]).begins_with("@"):
			var mouse := ControlLegend.MouseGlyph.new()
			mouse.lit = String(pair[0]).substr(1)
			mouse.custom_minimum_size = Vector2(30, 40)
			line.add_child(mouse)
		else:
			line.add_child(Style.keycap(pair[0], 22))
		var text := Style.label(pair[1], Style.SIZE_BODY, Style.INK)
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(text)

	for child in _dots.get_children():
		child.queue_free()
	for i in PAGES.size():
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(34 if i == page else 14, 14)
		var box := StyleBoxFlat.new()
		box.bg_color = Style.AMBER if i == page else Color(1, 1, 1, 0.25)
		box.set_corner_radius_all(7)
		dot.add_theme_stylebox_override("panel", box)
		_dots.add_child(dot)

	_prev.disabled = page == 0
	_next.text = "Next page   >" if page + 1 < PAGES.size() else "Done"
	_next.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.pressed:
		return
	match (event as InputEventKey).physical_keycode:
		KEY_RIGHT, KEY_D:
			show_page(page + 1)
		KEY_LEFT, KEY_A:
			show_page(page - 1)


## The drawing for each page, all in code.
class Diagram extends Control:
	var kind: int = 0

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		match kind:
			0: _job(font)
			1: _aperture(font)
			2: _shutter(font)
			3: _iso(font)
			4: _meter(font)
			5: _framing(font)

	func _caption(font: Font, text: String, at: Vector2, colour: Color = Style.INK, size_px: int = 30) -> void:
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		draw_string(font, at - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, colour)

	## A little yard to put in every frame: a sky, the ground, two trees and a
	## house, at whatever softness the page needs.
	func _scene(r: Rect2, blur: float) -> void:
		draw_rect(r, Color(0.55, 0.68, 0.82))
		var ground := Rect2(r.position + Vector2(0, r.size.y * 0.62), Vector2(r.size.x, r.size.y * 0.38))
		draw_rect(ground, Color(0.45, 0.34, 0.23))
		## Blur is faked by drawing each shape several times, spread out and
		## faint - enough to read as out of focus in a diagram.
		var passes := 1 if blur <= 0.0 else 7
		for p in passes:
			var off := Vector2.ZERO if passes == 1 else Vector2.from_angle(TAU * p / passes) * blur
			var a := 1.0 if passes == 1 else 0.22
			var house := Rect2(r.position + Vector2(r.size.x * 0.58, r.size.y * 0.34) + off, Vector2(r.size.x * 0.3, r.size.y * 0.3))
			draw_rect(house, Color(0.78, 0.66, 0.46, a))
			draw_colored_polygon(PackedVector2Array([
				house.position + Vector2(-12, 0), house.position + Vector2(house.size.x + 12, 0),
				house.position + Vector2(house.size.x * 0.5, -house.size.y * 0.45)]), Color(0.55, 0.26, 0.2, a))
			for tx in [0.12, 0.36]:
				var base := r.position + Vector2(r.size.x * tx, r.size.y * 0.62) + off
				draw_rect(Rect2(base - Vector2(4, 50), Vector2(8, 50)), Color(0.35, 0.28, 0.2, a))
				draw_circle(base - Vector2(0, 62), r.size.y * 0.12, Color(0.3, 0.55, 0.28, a))

	func _iris(c: Vector2, r: float, opening: float) -> void:
		draw_circle(c, r, Style.AMBER)
		draw_circle(c, r * 0.9, Color(0.18, 0.18, 0.18))
		var hole := r * 0.9 * opening
		draw_circle(c, hole, Color(0.62, 0.8, 0.95))
		for i in 6:
			var a := TAU * i / 6.0
			var b := TAU * (i + 1) / 6.0
			draw_line(c + Vector2.from_angle(a) * hole, c + Vector2.from_angle(a + 0.6) * r * 0.9, Color(0, 0, 0, 0.6), 2.0)
			draw_line(c + Vector2.from_angle(a) * hole, c + Vector2.from_angle(b) * hole, Color(0.1, 0.1, 0.1), 2.0)

	func _job(font: Font) -> void:
		var paper := Rect2(Vector2(60, 40), Vector2(300, 400))
		draw_rect(paper, Style.PAPER)
		draw_string(font, paper.position + Vector2(24, 50), "THE BRIEF", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.45, 0.36, 0.22))
		for i in 3:
			var y := paper.position.y + 110 + i * 90
			draw_string(font, Vector2(paper.position.x + 24, y), "%d." % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0.55, 0.45, 0.3))
			draw_rect(Rect2(paper.position.x + 70, y - 24, 190, 12), Color(0, 0, 0, 0.25))
			draw_rect(Rect2(paper.position.x + 70, y - 4, 140, 10), Color(0, 0, 0, 0.14))
		## The score scale: where accepted and printed begin.
		var bar := Rect2(Vector2(420, 180), Vector2(240, 30))
		draw_rect(bar, Color(1, 1, 1, 0.1))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * 0.6, bar.size.y)), Style.BAD)
		draw_rect(Rect2(bar.position + Vector2(bar.size.x * 0.6, 0), Vector2(bar.size.x * 0.25, bar.size.y)), Style.AMBER)
		draw_rect(Rect2(bar.position + Vector2(bar.size.x * 0.85, 0), Vector2(bar.size.x * 0.15, bar.size.y)), Style.GOOD)
		_caption(font, "60", bar.position + Vector2(bar.size.x * 0.6, 70), Style.AMBER)
		_caption(font, "85", bar.position + Vector2(bar.size.x * 0.85, 70), Style.GOOD)
		_caption(font, "accepted", bar.position + Vector2(bar.size.x * 0.5, 130), Style.AMBER, 24)
		_caption(font, "printed", bar.position + Vector2(bar.size.x * 0.9, 170), Style.GOOD, 24)

	func _aperture(font: Font) -> void:
		for side in 2:
			var x := 190.0 + side * 330.0
			var wide := side == 0
			_iris(Vector2(x, 130), 90, 0.78 if wide else 0.2)
			_caption(font, "f/2" if wide else "f/16", Vector2(x, 265), Style.AMBER, 38)
			_scene(Rect2(Vector2(x - 140, 300), Vector2(280, 170)), 10.0 if wide else 0.0)
			## The subject stays sharp in both - only what is behind changes.
			draw_circle(Vector2(x - 60, 420), 24, Color(0.9, 0.55, 0.2))
			draw_circle(Vector2(x - 60, 392), 14, Color(0.9, 0.55, 0.2))
			_caption(font, "background soft" if wide else "all of it sharp", Vector2(x, 510), Style.INK_DIM, 24)

	func _shutter(font: Font) -> void:
		for side in 2:
			var x := 190.0 + side * 330.0
			var slow := side == 0
			var frame := Rect2(Vector2(x - 140, 90), Vector2(280, 250))
			draw_rect(frame, Color(0.45, 0.34, 0.23))
			draw_rect(Rect2(frame.position, Vector2(frame.size.x, 90)), Color(0.55, 0.68, 0.82))
			## The hen: a smear of faint copies at 1/30, one sharp bird at 1/1000.
			var copies := 9 if slow else 1
			for i in copies:
				var t := float(i) / maxf(copies - 1, 1)
				var p := Vector2(frame.position.x + 80 + (t * 110.0 if slow else 60.0), frame.position.y + 180)
				var a := 0.22 if slow else 1.0
				draw_circle(p, 28, Color(0.95, 0.93, 0.88, a))
				draw_circle(p + Vector2(22, -26), 14, Color(0.95, 0.93, 0.88, a))
				draw_circle(p + Vector2(26, -38), 6, Color(0.85, 0.2, 0.15, a))
			_caption(font, "1/30" if slow else "1/1000", Vector2(x, 60), Style.AMBER, 38)
			_caption(font, "a smear" if slow else "frozen mid-step", Vector2(x, 390), Style.INK_DIM, 24)
		## The clock: how long each one looks.
		_caption(font, "longer look = more light", Vector2(355, 470), Style.INK, 26)

	func _iso(font: Font) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for side in 2:
			var x := 190.0 + side * 330.0
			var high := side == 1
			var frame := Rect2(Vector2(x - 140, 90), Vector2(280, 250))
			_scene(frame, 0.0)
			if high:
				for i in 1400:
					var p := frame.position + Vector2(rng.randf() * frame.size.x, rng.randf() * frame.size.y)
					var v := rng.randf()
					draw_rect(Rect2(p, Vector2(3, 3)), Color(v, v, v, 0.4))
			_caption(font, "ISO 3200" if high else "ISO 100", Vector2(x, 60), Style.AMBER, 38)
			_caption(font, "bright but grainy" if high else "clean", Vector2(x, 390), Style.INK_DIM, 24)

	func _meter(font: Font) -> void:
		var track := Rect2(Vector2(100, 90), Vector2(520, 40))
		draw_rect(track, Color(1, 1, 1, 0.1))
		draw_rect(Rect2(Vector2(track.position.x + track.size.x * 0.5 - 45, track.position.y), Vector2(90, 40)), Color(0.49, 0.78, 0.45, 0.45))
		draw_rect(Rect2(Vector2(track.position.x + track.size.x * 0.5 - 5, track.position.y - 10), Vector2(10, 60)), Style.INK)
		_caption(font, "too dark", track.position + Vector2(60, 90), Style.INK_DIM, 24)
		_caption(font, "right", track.position + Vector2(track.size.x * 0.5, 90), Style.GOOD, 24)
		_caption(font, "too bright", track.position + Vector2(track.size.x - 60, 90), Style.INK_DIM, 24)
		## The triangle: three dials, one amount of light.
		var top := Vector2(360, 250)
		var left := Vector2(200, 480)
		var right := Vector2(520, 480)
		draw_polyline(PackedVector2Array([top, right, left, top]), Color(Style.AMBER, 0.8), 4.0)
		for pair in [[top, "APERTURE", Vector2(0, -20)], [left, "SHUTTER", Vector2(-10, 50)], [right, "ISO", Vector2(10, 50)]]:
			draw_circle(pair[0], 16, Style.AMBER)
			_caption(font, pair[1], pair[0] + pair[2], Style.INK, 26)
		_caption(font, "one amount of light", Vector2(360, 420), Style.INK_DIM, 22)

	func _framing(font: Font) -> void:
		var frame := Rect2(Vector2(70, 50), Vector2(580, 400))
		_scene(frame, 0.0)
		for i in [1.0 / 3.0, 2.0 / 3.0]:
			draw_line(Vector2(frame.position.x + frame.size.x * i, frame.position.y), Vector2(frame.position.x + frame.size.x * i, frame.end.y), Color(1, 1, 1, 0.6), 2.0)
			draw_line(Vector2(frame.position.x, frame.position.y + frame.size.y * i), Vector2(frame.end.x, frame.position.y + frame.size.y * i), Color(1, 1, 1, 0.6), 2.0)
		## The cat, on a crossing point.
		var cat := frame.position + frame.size * Vector2(1.0 / 3.0, 2.0 / 3.0)
		draw_circle(cat, 26, Color(0.9, 0.55, 0.2))
		draw_circle(cat + Vector2(0, -32), 16, Color(0.9, 0.55, 0.2))
		draw_arc(cat, 46, 0, TAU, 40, Style.AMBER, 3.0)
		var c := frame.get_center()
		draw_line(c - Vector2(16, 0), c + Vector2(16, 0), Color(1, 1, 1, 0.8), 2.0)
		draw_line(c - Vector2(0, 16), c + Vector2(0, 16), Color(1, 1, 1, 0.8), 2.0)
		_caption(font, "put it where the lines cross", Vector2(360, 500), Style.INK_DIM, 24)
