class_name QuestLog
extends Control

const QUEST_ICON := preload("res://Sprites/iconQuest.webp")

var _story: StoryManager
var _button: Button
var _button_icon: TextureRect
var _badge: Label
var _overlay: Control
var _quest_list: VBoxContainer
var _expanded: Dictionary = {}
var _last_signature := ""
var _quest_state_initialized := false
var _previous_interaction_locked := false
var _absorb_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 750
	_build_button()
	_build_overlay()
	call_deferred("_resolve_story")


func _process(_delta: float) -> void:
	_position_button_in_inventory_header()
	if not is_instance_valid(_story):
		_story = get_tree().get_first_node_in_group("story_manager") as StoryManager
	var quests := _get_quests()
	var signature := JSON.stringify(quests)
	if not _quest_state_initialized:
		_quest_state_initialized = true
		_last_signature = signature
		_refresh_badge()
		return
	if signature == _last_signature:
		return
	_last_signature = signature
	_refresh_badge()
	if _overlay.visible:
		_rebuild_quest_list()
	if not quests.is_empty():
		_play_quest_update_feedback()


func _build_button() -> void:
	_button = Button.new()
	_button.name = "QuestLogButton"
	_button.tooltip_text = "Quest Log"
	_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_button.size = Vector2(44, 44)
	_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_quest_button()
	_button.pressed.connect(open)
	add_child(_button)
	_button_icon = TextureRect.new()
	_button_icon.name = "QuestIcon"
	_button_icon.texture = QUEST_ICON
	_button_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_button_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_button_icon.position = Vector2(6, 6)
	_button_icon.size = Vector2(32, 32)
	_button_icon.modulate = Color(1.5, 1.5, 1.5, 1.0)
	_button_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.add_child(_button_icon)
	_badge = Label.new()
	_badge.name = "ActiveQuestCount"
	_badge.position = Vector2(23, 23)
	_badge.size = Vector2(20, 20)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.add_theme_font_size_override("font_size", 11)
	_badge.add_theme_color_override("font_color", Color.WHITE)
	_badge.add_theme_color_override("font_outline_color", Color.BLACK)
	_badge.add_theme_constant_override("outline_size", 3)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.add_child(_badge)
	call_deferred("_position_button_in_inventory_header")


func _style_quest_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("242938")
	normal.border_color = Color("aeb8cc")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	_button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("343b50")
	hover.border_color = Color.WHITE
	_button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("171b26")
	_button.add_theme_stylebox_override("pressed", pressed)
	_button.add_theme_stylebox_override("focus", hover)


func _position_button_in_inventory_header() -> void:
	if not is_instance_valid(_button):
		return
	var inventory := get_parent().get_node_or_null("Inventory") as InventoryPanel
	if inventory == null or inventory.size.x <= 0.0:
		return
	var anchor_rect := inventory.get_quest_anchor_rect()
	if anchor_rect.size.x > 0.0:
		_button.global_position = anchor_rect.position


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.name = "QuestLogOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.hide()
	add_child(_overlay)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.62)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	_overlay.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "QuestLogPanel"
	panel.custom_minimum_size = Vector2(560, 360)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("242938")
	style.border_color = Color("77819a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = "Quest Log"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	header.add_child(title)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(38, 38)
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_quest_list = VBoxContainer.new()
	_quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_quest_list)


func _resolve_story() -> void:
	_story = get_tree().get_first_node_in_group("story_manager") as StoryManager
	_last_signature = JSON.stringify(_get_quests())
	_quest_state_initialized = true
	_refresh_badge()


func open() -> void:
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	if world:
		_previous_interaction_locked = world.interaction_locked
		world.interaction_locked = true
	_overlay.show()
	_rebuild_quest_list()


func close() -> void:
	_overlay.hide()
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	if world:
		world.interaction_locked = _previous_interaction_locked


func _unhandled_key_input(event: InputEvent) -> void:
	if _overlay.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close()
		accept_event()


func _get_quests() -> Array[Dictionary]:
	return _story.get_quest_log_entries() if is_instance_valid(_story) else []


func _refresh_badge() -> void:
	var active_count := 0
	for quest in _get_quests():
		if not bool(quest.get("completed", false)):
			active_count += 1
	_badge.text = str(active_count)
	_badge.visible = active_count > 0


func _play_quest_update_feedback() -> void:
	if not is_instance_valid(_button):
		return
	var dot := Panel.new()
	dot.name = "QuestUpdateDot"
	dot.size = Vector2(14, 14)
	dot.pivot_offset = dot.size * 0.5
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.z_index = 900
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = Color("ef4444")
	dot_style.border_color = Color("2b0808")
	dot_style.set_border_width_all(2)
	dot_style.set_corner_radius_all(7)
	dot.add_theme_stylebox_override("panel", dot_style)
	add_child(dot)
	var start := Vector2(64, 64)
	var player := get_tree().get_first_node_in_group("player") as FoxPlayer
	if is_instance_valid(player):
		start = player.get_viewport().get_canvas_transform() * player.global_position
	dot.global_position = start - dot.size * 0.5
	var destination := _button.get_global_rect().get_center() - dot.size * 0.5
	var travel := dot.create_tween().set_parallel(true)
	travel.tween_property(dot, "global_position", destination, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	travel.tween_property(dot, "scale", Vector2(0.35, 0.35), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	travel.tween_property(dot, "modulate:a", 0.35, 0.55)
	travel.finished.connect(func() -> void:
		if is_instance_valid(dot):
			dot.queue_free()
		_play_absorb_pulse()
	)


func _play_absorb_pulse() -> void:
	if not is_instance_valid(_button):
		return
	if _absorb_tween and _absorb_tween.is_valid():
		_absorb_tween.kill()
	_button.pivot_offset = _button.size * 0.5
	_button.scale = Vector2.ONE
	_button.modulate = Color("ff9a9a")
	_absorb_tween = _button.create_tween()
	_absorb_tween.tween_property(_button, "scale", Vector2(1.34, 1.34), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_absorb_tween.tween_property(_button, "scale", Vector2(0.92, 0.92), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_absorb_tween.tween_property(_button, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_absorb_tween.parallel().tween_property(_button, "modulate", Color.WHITE, 0.24)


func _rebuild_quest_list() -> void:
	for child in _quest_list.get_children():
		_quest_list.remove_child(child)
		child.queue_free()
	var quests := _get_quests()
	if quests.is_empty():
		var empty := Label.new()
		empty.text = "No quests yet."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color("aeb8cc"))
		_quest_list.add_child(empty)
		return
	for quest in quests:
		_add_quest(quest)


func _add_quest(quest: Dictionary) -> void:
	var quest_id := StringName(quest.get("id", &""))
	var quest_completed := bool(quest.get("completed", false))
	var quest_title := str(quest.get("title", "Quest"))
	var location := str(quest.get("location", ""))
	if not location.is_empty():
		quest_title += " (%s)" % location
	var button := Button.new()
	button.name = "Quest_%s" % str(quest_id)
	button.text = "%s%s" % ["       " if quest_completed else "", quest_title]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_color_override("font_color", Color.WHITE)
	button.pressed.connect(_toggle_quest.bind(quest_id))
	_quest_list.add_child(button)
	if quest_completed:
		_add_completed_badge(button)
	if not bool(_expanded.get(quest_id, false)):
		return
	var steps := VBoxContainer.new()
	steps.add_theme_constant_override("separation", 5)
	steps.set_meta("quest_steps", true)
	_quest_list.add_child(steps)
	for raw_step in quest.get("steps", []) as Array:
		if not raw_step is Dictionary:
			continue
		var step := raw_step as Dictionary
		var label := Label.new()
		var step_text := str(step.get("text", ""))
		label.text = "    • %s" % step_text
		label.set_meta("step_text", step_text)
		label.set_meta("step_prefix", "    • ")
		label.add_theme_color_override("font_color", Color("b8c0d4"))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		steps.add_child(label)
		if bool(step.get("completed", false)):
			label.add_theme_color_override("font_color", Color("9aa1b3"))
			call_deferred("_add_crossout", label)
		else:
			# The log reveals the quest only through its current objective.
			break


func _add_completed_badge(button: Button) -> void:
	var badge := Label.new()
	badge.name = "CompletedBadge"
	badge.text = "✓"
	badge.position = Vector2(8, 5)
	badge.size = Vector2(24, 24)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.add_theme_color_override("font_outline_color", Color.BLACK)
	badge.add_theme_constant_override("outline_size", 2)
	badge.add_theme_font_size_override("font_size", 14)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("43a047")
	style.border_color = Color("d9ffd9")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	badge.add_theme_stylebox_override("normal", style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(badge)


func _toggle_quest(quest_id: StringName) -> void:
	_expanded[quest_id] = not bool(_expanded.get(quest_id, false))
	_rebuild_quest_list()


func _add_crossout(label: Label) -> void:
	if not is_instance_valid(label):
		return
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var prefix := str(label.get_meta("step_prefix", ""))
	var step_text := str(label.get_meta("step_text", label.text))
	var text_start := font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var text_width := font.get_string_size(step_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var font_height := font.get_height(font_size)
	# Use the stable rendered font height rather than the label's transient
	# container height; the latter is briefly stretched during layout.
	var strike_y := font_height * 0.56
	var line := Line2D.new()
	line.name = "CompletedCrossout"
	line.points = PackedVector2Array([
		Vector2(text_start, strike_y),
		Vector2(text_start + text_width, strike_y),
	])
	line.width = 2.0
	line.default_color = Color("ef4444")
	line.z_index = 1
	label.add_child(line)
