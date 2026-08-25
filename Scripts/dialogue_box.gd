class_name DialogueBox
extends Control

signal dialogue_finished
signal line_shown(index: int)

const TYPE_INTERVAL := 0.018
const COMMA_PAUSE := 0.055
const SENTENCE_PAUSE := 0.11
const OPEN_DURATION := 0.16
const INPUT_DELAY := 0.8
const BOTTOM_TOP := -174.0
const BOTTOM_BOTTOM := -24.0

var _lines: Array[Dictionary] = []
var _line_index := 0
var _portrait: TextureRect
var _name_label: Label
var _text_label: Label
var _continue_label: Label
var _bottom: MarginContainer
var _row: HBoxContainer
var _identity: VBoxContainer
var _copy: VBoxContainer
var _full_text := ""
var _visible_characters := 0
var _type_delay_left := 0.0
var _continue_time := 0.0
var _open_tween: Tween
var _speaker_tween: Tween
var _portrait_bob_time := 0.0
var _input_delay_left := 0.0
var _externally_locked := false


func _ready() -> void:
	add_to_group("dialogue_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	_build_interface()
	hide()


func play(lines: Array[Dictionary]) -> bool:
	if lines.is_empty() or visible:
		return false
	_lines = lines.duplicate(true)
	_line_index = 0
	_fit_width_to_conversation()
	show()
	move_to_front()
	_show_current_line()
	_input_delay_left = INPUT_DELAY
	_animate_open()
	return true


func advance() -> void:
	if not visible:
		return
	if is_typing():
		finish_typing()
		return
	_line_index += 1
	if _line_index >= _lines.size():
		close()
		return
	_show_current_line()


func close() -> void:
	if not visible:
		return
	hide()
	_lines.clear()
	dialogue_finished.emit()


func cancel() -> void:
	if not visible:
		return
	hide()
	_lines.clear()
	_externally_locked = false


func is_open() -> bool:
	return visible


func get_current_speaker() -> String:
	return _name_label.text if is_instance_valid(_name_label) else ""


func get_current_text() -> String:
	return _text_label.text if is_instance_valid(_text_label) else ""


func is_typing() -> bool:
	return visible and _visible_characters < _full_text.length()


func set_input_locked(locked: bool) -> void:
	_externally_locked = locked


func finish_typing() -> void:
	_visible_characters = _full_text.length()
	_text_label.visible_characters = -1
	_show_continue_indicator()


func _process(delta: float) -> void:
	if not visible:
		return
	_input_delay_left = maxf(0.0, _input_delay_left - delta)
	_portrait_bob_time += delta * 3.2
	if _speaker_tween == null or not _speaker_tween.is_running():
		_portrait.position.y = -1.0 + sin(_portrait_bob_time) * 1.4
	if is_typing():
		_type_delay_left -= delta
		while _type_delay_left <= 0.0 and _visible_characters < _full_text.length():
			_visible_characters += 1
			_text_label.visible_characters = _visible_characters
			var revealed := _full_text.substr(_visible_characters - 1, 1)
			_type_delay_left += TYPE_INTERVAL + _punctuation_pause(revealed)
		if not is_typing():
			finish_typing()
	else:
		_continue_time += delta
		_continue_label.modulate.a = 0.62 + sin(_continue_time * 5.5) * 0.28


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	var key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	if not _externally_locked and _input_delay_left <= 0.0 and (key == KEY_SPACE or key == KEY_ENTER or key == KEY_KP_ENTER):
		advance()
	get_viewport().set_input_as_handled()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _externally_locked and _input_delay_left <= 0.0:
			advance()
		accept_event()


func _show_current_line() -> void:
	var line := _lines[_line_index]
	var speaker := str(line.get("speaker", ""))
	var player_speaking := speaker == "Mira"
	_name_label.text = speaker
	_full_text = str(line.get("text", ""))
	_text_label.text = _full_text
	_visible_characters = 0
	_text_label.visible_characters = 0
	_type_delay_left = TYPE_INTERVAL
	_portrait.texture = line.get("portrait") as Texture2D
	_portrait.flip_h = not player_speaking and speaker != "Asha"
	_row.move_child(_identity, 0 if player_speaking else 1)
	_row.move_child(_copy, 1 if player_speaking else 0)
	# Revealed glyphs must always advance from the copy area's left edge, including
	# when an NPC portrait is displayed on the right.
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_label.text = "▼"
	_continue_label.visible = true
	_continue_label.modulate.a = 0.0
	_continue_label.scale = Vector2.ONE
	_continue_time = 0.0
	_portrait_bob_time = 0.0
	_animate_speaker()
	line_shown.emit(_line_index)


func _build_interface() -> void:
	_bottom = MarginContainer.new()
	_bottom.anchor_left = 0.5
	_bottom.anchor_top = 1.0
	_bottom.anchor_right = 0.5
	_bottom.anchor_bottom = 1.0
	_bottom.offset_left = -410.0
	_bottom.offset_top = BOTTOM_TOP
	_bottom.offset_right = 410.0
	_bottom.offset_bottom = BOTTOM_BOTTOM
	_bottom.add_theme_constant_override("margin_left", 12)
	_bottom.add_theme_constant_override("margin_top", 12)
	_bottom.add_theme_constant_override("margin_right", 12)
	_bottom.add_theme_constant_override("margin_bottom", 12)
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bottom)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.045, 0.055, 0.96)
	panel_style.border_color = Color(0.82, 0.72, 0.45, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 26.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_right = 26.0
	panel_style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", panel_style)
	_bottom.add_child(panel)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 18)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_row)

	_identity = VBoxContainer.new()
	_identity.custom_minimum_size = Vector2(108, 116)
	_identity.add_theme_constant_override("separation", 2)
	_identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_identity)

	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.custom_minimum_size = Vector2(98, 88)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_identity.add_child(_portrait)

	_name_label = Label.new()
	_name_label.name = "SpeakerName"
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_color", Color("ffe082"))
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 3)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_identity.add_child(_name_label)

	_copy = VBoxContainer.new()
	_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_copy.add_theme_constant_override("separation", 6)
	_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_copy)

	_text_label = Label.new()
	_text_label.name = "DialogueText"
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("font_size", 20)
	_text_label.add_theme_color_override("font_color", Color.WHITE)
	_text_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_text_label.add_theme_constant_override("outline_size", 3)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_copy.add_child(_text_label)

	_continue_label = Label.new()
	_continue_label.name = "ContinueHint"
	_continue_label.add_theme_font_size_override("font_size", 13)
	_continue_label.add_theme_color_override("font_color", Color(0.72, 0.75, 0.78, 1.0))
	_continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_copy.add_child(_continue_label)


func _fit_width_to_conversation() -> void:
	var text_font := _text_label.get_theme_font("font")
	var text_font_size := _text_label.get_theme_font_size("font_size")
	var text_width := 0.0
	for line in _lines:
		text_width = maxf(text_width, text_font.get_string_size(str(line.get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, text_font_size).x)
	var available_copy_width := maxf(220.0, get_viewport_rect().size.x - 108.0 - 18.0 - 52.0 - 96.0)
	var copy_width := clampf(ceilf(text_width), 220.0, minf(620.0, available_copy_width))
	_copy.custom_minimum_size.x = copy_width
	# Portrait, separation, expanded panel padding, and outer margins total 202 px.
	var panel_width := copy_width + 202.0
	_bottom.offset_left = -panel_width * 0.5
	_bottom.offset_right = panel_width * 0.5


func _animate_open() -> void:
	if _open_tween and _open_tween.is_valid():
		_open_tween.kill()
	_bottom.pivot_offset = _bottom.size * Vector2(0.5, 1.0)
	_bottom.scale = Vector2(0.96, 0.96)
	_bottom.modulate.a = 0.0
	_bottom.offset_top = BOTTOM_TOP + 16.0
	_bottom.offset_bottom = BOTTOM_BOTTOM + 16.0
	_open_tween = create_tween().set_parallel(true)
	_open_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_open_tween.tween_property(_bottom, "scale", Vector2.ONE, OPEN_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(_bottom, "modulate:a", 1.0, 0.10)
	_open_tween.tween_property(_bottom, "offset_top", BOTTOM_TOP, OPEN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(_bottom, "offset_bottom", BOTTOM_BOTTOM, OPEN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _animate_speaker() -> void:
	if _speaker_tween and _speaker_tween.is_valid():
		_speaker_tween.kill()
	_portrait.pivot_offset = _portrait.size * 0.5
	_portrait.scale = Vector2(0.91, 0.91)
	_portrait.position.y = -5.0
	_portrait.modulate = Color(1.18, 1.18, 1.08, 0.76)
	_name_label.modulate = Color(1.25, 1.18, 0.82, 1.0)
	_speaker_tween = create_tween().set_parallel(true)
	_speaker_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_speaker_tween.tween_property(_portrait, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_speaker_tween.tween_property(_portrait, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_speaker_tween.tween_property(_portrait, "modulate", Color.WHITE, 0.20)
	_speaker_tween.tween_property(_name_label, "modulate", Color.WHITE, 0.24)


func _show_continue_indicator() -> void:
	_continue_label.visible = true
	_continue_label.modulate.a = 1.0
	_continue_time = 0.0
	_continue_label.pivot_offset = _continue_label.size * 0.5


func _punctuation_pause(character: String) -> float:
	if character in [".", "!", "?", ":"]:
		return SENTENCE_PAUSE
	if character in [",", ";"]:
		return COMMA_PAUSE
	return 0.0
