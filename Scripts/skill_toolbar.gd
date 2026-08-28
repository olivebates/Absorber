class_name SkillToolbar
extends Control

const BOOK_ICON := preload("res://Sprites/IconSkillBook.webp")
const HEAL_ICON := preload("res://Sprites/skillHeal.webp")
const PLAYER_PORTRAIT := preload("res://Sprites/Fox.webp")
const ASHA_HEAL := &"asha_healing_smooch"
const SKILL_SWAP_TUTORIAL_TEXT := "I can swap skills by clicking the icon to the right of my skill bar."
const PLAYER_SHORTCUT_KEYS := [KEY_Q, KEY_W, KEY_E, KEY_R]
const PLAYER_SHORTCUT_LABELS := ["Q", "W", "E", "R"]
const SKILL_SNAP_DISTANCE := 24.0

var _player: FoxPlayer
var _asha: FoxAsha
var _bars: HBoxContainer
var _player_row: HBoxContainer
var _asha_panel: PanelContainer
var _asha_row: HBoxContainer
var _picker: PanelContainer
var _picker_list: GridContainer
var _picker_status := ""
var _tooltip: PanelContainer
var _tooltip_icon: TextureRect
var _tooltip_name: Label
var _tooltip_description: Label
var _tooltip_stats: Label
var _picker_button: Button
var _picker_glow_tween: Tween
var _drag_active := false
var _ignore_next_drag_end := false
var _arranging_skills := false
var _active_drag_data: Dictionary = {}
var _hovered_target: SkillSlot
var _cursor_drag_preview: TextureRect
var _cursor_drag_source: SkillSlot
var _last_asha_recruited := false
var _swap_tutorial_pending := false
var _swap_tutorial_active := false
var _swap_tutorial_dialogue_active := false
var _tutorial_target_slot := 0
var _tutorial_world: WorldNavigation
var _tutorial_world_was_paused := false


func _ready() -> void:
	add_to_group("skill_toolbar")
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -300.0
	offset_top = -72.0
	offset_right = 300.0
	offset_bottom = -10.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_bars()
	_build_picker()
	_build_tooltip()
	call_deferred("_connect_player")


func _process(_delta: float) -> void:
	if _drag_active and is_instance_valid(_cursor_drag_preview):
		_update_cursor_skill_drag(get_viewport().get_mouse_position())
	if _player == null:
		return
	visible = _player.has_unlocked_player_skill()
	if not visible:
		_picker.hide()
		_tooltip.hide()
		return
	if not is_instance_valid(_asha):
		_asha = get_tree().get_first_node_in_group("story_characters") as FoxAsha
	var recruited := is_instance_valid(_asha) and _asha.is_recruited()
	if recruited != _last_asha_recruited:
		_last_asha_recruited = recruited
		_refresh()


func _input(event: InputEvent) -> void:
	if not _arranging_skills or not _picker.visible:
		return
	if _drag_active and is_instance_valid(_cursor_drag_preview):
		if event is InputEventMouseMotion:
			_update_cursor_skill_drag((event as InputEventMouseMotion).position)
		elif event is InputEventMouseButton and not event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_finish_cursor_skill_drag((event as InputEventMouseButton).position)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		_close_picker()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not _drag_active:
		var point := (event as InputEventMouseButton).position
		if not _picker.get_global_rect().has_point(point) and not _player_row.get_global_rect().has_point(point):
			_close_picker()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _player == null or not event is InputEventKey or not event.pressed or event.echo:
		return
	if _arranging_skills:
		return
	var key_event := event as InputEventKey
	if key_event.shift_pressed or key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed:
		return
	var key := key_event.keycode if key_event.keycode != 0 else key_event.physical_keycode
	var slot := PLAYER_SHORTCUT_KEYS.find(key)
	if slot >= 0:
		_try_cast_player_skill(slot)
		get_viewport().set_input_as_handled()


func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as FoxPlayer
	for node in get_tree().get_nodes_in_group("story_characters"):
		if node is FoxAsha:
			_asha = node as FoxAsha
			break
	if _player:
		_player.skills_changed.connect(_on_player_skills_changed)
		_player.mana_changed.connect(_refresh_tooltip_if_visible)
		_refresh()
		_consider_skill_swap_tutorial()


func _on_player_skills_changed() -> void:
	_refresh()
	_consider_skill_swap_tutorial()


func _consider_skill_swap_tutorial() -> void:
	if _player == null or _player.skill_swap_tutorial_seen or _player.unlocked_player_skills.size() < 2 \
			or not _player.unlocked_player_skills.has(FoxPlayer.SKILL_ROLL_BACK) \
			or _swap_tutorial_pending or _swap_tutorial_active:
		return
	_swap_tutorial_pending = true
	call_deferred("_wait_for_skill_swap_tutorial")


func _wait_for_skill_swap_tutorial() -> void:
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui") as DialogueBox
	if dialogue == null:
		_swap_tutorial_pending = false
		return
	if dialogue.is_open():
		await dialogue.dialogue_finished
	await get_tree().create_timer(2.0).timeout
	# A final skill chest may be lifting Mira out of the dungeon. Let that
	# transition finish before the swap tutorial pauses and targets the new world.
	var dungeon_manager := get_tree().get_first_node_in_group("dungeon_manager") as DungeonManager
	if dungeon_manager and dungeon_manager.is_transitioning():
		await dungeon_manager.dungeon_left
	if _player == null or _player.skill_swap_tutorial_seen or _player.unlocked_player_skills.size() < 2 \
			or not _player.unlocked_player_skills.has(FoxPlayer.SKILL_ROLL_BACK):
		_swap_tutorial_pending = false
		return
	if dialogue.is_open():
		await dialogue.dialogue_finished
	if not dialogue.play([{
		"speaker": "Mira",
		"text": SKILL_SWAP_TUTORIAL_TEXT,
		"portrait": PLAYER_PORTRAIT,
		"continue_hint": "Click the yellow button to continue.",
	}]):
		_swap_tutorial_pending = false
		return
	_swap_tutorial_pending = false
	_swap_tutorial_active = true
	_swap_tutorial_dialogue_active = true
	_tutorial_target_slot = _find_tutorial_target_slot()
	_pause_for_swap_tutorial()
	dialogue.set_input_locked(true)
	dialogue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_picker_button_glow()


func _build_bars() -> void:
	_bars = HBoxContainer.new()
	_bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bars.alignment = BoxContainer.ALIGNMENT_CENTER
	_bars.add_theme_constant_override("separation", 8)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bars)
	var player_panel := _make_panel()
	_bars.add_child(player_panel)
	_player_row = HBoxContainer.new()
	_player_row.add_theme_constant_override("separation", 4)
	player_panel.add_child(_player_row)
	_asha_panel = _make_panel()
	_bars.add_child(_asha_panel)
	_asha_row = HBoxContainer.new()
	_asha_row.add_theme_constant_override("separation", 4)
	_asha_panel.add_child(_asha_row)


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.38, 0.4, 0.44, 0.76)
	style.border_color = Color.BLACK
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _refresh() -> void:
	if _player == null:
		return
	visible = _player.has_unlocked_player_skill()
	_clear_container(_player_row)
	for index in range(4):
		var skill_id := _player.equipped_player_skills[index]
		var data := _player.get_player_skill_data(skill_id)
		var slot := SkillSlot.new()
		slot.configure(self, index, skill_id, data.get("icon") as Texture2D if not data.is_empty() else BOOK_ICON, not bool(_player.player_skill_slots_unlocked[index]), PLAYER_SHORTCUT_LABELS[index], "player", _arranging_skills)
		_player_row.add_child(slot)
	_picker_button = Button.new()
	_picker_button.name = "OpenSkillPicker"
	_picker_button.text = "≡"
	_picker_button.custom_minimum_size = SkillSlot.ARRANGE_SIZE if _arranging_skills else SkillSlot.COMPACT_SIZE
	_picker_button.tooltip_text = "Arrange skills"
	_picker_button.pressed.connect(_toggle_picker)
	_player_row.add_child(_picker_button)
	if _swap_tutorial_active:
		if _swap_tutorial_dialogue_active:
			_apply_picker_button_glow()
		else:
			call_deferred("_apply_back_roll_glow")
	_clear_container(_asha_row)
	_asha_panel.visible = is_instance_valid(_asha) and _asha.is_recruited()
	if _asha_panel.visible:
		for index in range(4):
			var slot := SkillSlot.new()
			var skill_id := ASHA_HEAL if index == 0 else &""
			slot.configure(self, index, skill_id, HEAL_ICON if index == 0 else BOOK_ICON, index != 0, "", "asha")
			_asha_row.add_child(slot)
	_refresh_picker()
	if _arranging_skills:
		_apply_selection_highlights()


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _build_picker() -> void:
	_picker = _make_panel()
	_picker.name = "SkillPicker"
	_picker.custom_minimum_size = Vector2.ZERO
	add_child(_picker)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	_picker.add_child(content)
	_picker_list = GridContainer.new()
	_picker_list.columns = 5
	_picker_list.add_theme_constant_override("h_separation", 4)
	_picker_list.add_theme_constant_override("v_separation", 4)
	content.add_child(_picker_list)
	_picker_status = "Select a skill, then choose Q, W, E, or R."
	_picker.hide()


func _refresh_picker() -> void:
	if _picker_list == null or _player == null:
		return
	_clear_container(_picker_list)
	for skill_id in _player.unlocked_player_skills:
		var data := _player.get_player_skill_data(skill_id)
		var slot := SkillSlot.new()
		slot.configure(self, -1, skill_id, data.get("icon") as Texture2D, false, "", "picker", true)
		_picker_list.add_child(slot)
	_apply_selection_highlights()


func _toggle_picker() -> void:
	if _swap_tutorial_active and _swap_tutorial_dialogue_active:
		_swap_tutorial_dialogue_active = false
		_stop_picker_button_glow()
		var dialogue := get_tree().get_first_node_in_group("dialogue_ui") as DialogueBox
		if dialogue:
			dialogue.set_input_locked(false)
			dialogue.mouse_filter = Control.MOUSE_FILTER_STOP
			dialogue.close()
		_open_picker()
		_apply_back_roll_glow()
		return
	if _swap_tutorial_active:
		_open_picker()
		return
	if _picker.visible:
		_close_picker()
	else:
		_open_picker()


func _open_picker() -> void:
	_arranging_skills = true
	_active_drag_data.clear()
	_picker.show()
	_refresh()
	_picker.show()
	_picker_status = "Select a skill, then choose Q, W, E, or R."
	_position_picker()


func _close_picker() -> void:
	if _swap_tutorial_active:
		return
	if _drag_active and is_instance_valid(_cursor_drag_preview):
		_cancel_cursor_skill_drag()
	_arranging_skills = false
	_active_drag_data.clear()
	_hovered_target = null
	_picker.hide()
	hide_skill_tooltip()
	_refresh()


func _apply_picker_button_glow() -> void:
	if not is_instance_valid(_picker_button):
		return
	_stop_picker_button_glow()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.24, 0.20, 0.03, 0.98)
	style.border_color = Color(1.0, 0.86, 0.12, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(6)
	_picker_button.add_theme_stylebox_override("normal", style)
	_picker_button.add_theme_color_override("font_color", Color(1.0, 0.94, 0.35))
	_picker_glow_tween = _picker_button.create_tween().set_loops()
	_picker_glow_tween.tween_property(_picker_button, "modulate", Color(1.35, 1.25, 0.45), 0.42)
	_picker_glow_tween.tween_property(_picker_button, "modulate", Color.WHITE, 0.42)


func _stop_picker_button_glow() -> void:
	if _picker_glow_tween and _picker_glow_tween.is_valid():
		_picker_glow_tween.kill()
	_picker_glow_tween = null
	if is_instance_valid(_picker_button):
		_picker_button.modulate = Color.WHITE
		_picker_button.remove_theme_stylebox_override("normal")
		_picker_button.remove_theme_color_override("font_color")


func begin_skill_drag(skill_id: StringName, source: SkillSlot) -> void:
	_drag_active = true
	_active_drag_data = {"source_kind": source.source_kind, "source_index": source.slot_index, "skill_id": skill_id}
	_set_target_highlights(_active_drag_data)
	if _swap_tutorial_active and not _swap_tutorial_dialogue_active and skill_id == FoxPlayer.SKILL_ROLL_BACK:
		_clear_tutorial_slot_glows()
		var target := _get_player_slot(_tutorial_target_slot)
		if target:
			target.set_tutorial_glow(true)


func start_cursor_skill_drag(skill_id: StringName, source: SkillSlot) -> void:
	if not _arranging_skills or source == null or source.source_kind != "picker" or skill_id.is_empty():
		return
	begin_skill_drag(skill_id, source)
	_cursor_drag_source = source
	if is_instance_valid(source._icon):
		source._icon.hide()
	_cursor_drag_preview = TextureRect.new()
	_cursor_drag_preview.name = "CursorSkillDragPreview"
	_cursor_drag_preview.texture = source._icon.texture
	_cursor_drag_preview.size = SkillSlot.ICON_SIZE
	_cursor_drag_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cursor_drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cursor_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_drag_preview.z_index = 200
	add_child(_cursor_drag_preview)
	_update_cursor_skill_drag(get_viewport().get_mouse_position())


func _update_cursor_skill_drag(cursor_position: Vector2) -> void:
	if not is_instance_valid(_cursor_drag_preview):
		return
	_cursor_drag_preview.global_position = cursor_position - SkillSlot.ICON_SIZE * 0.5
	var target := _nearest_snap_slot(cursor_position)
	_hovered_target = target
	_set_target_highlights(_active_drag_data)
	if target:
		target.set_interaction_state("hover")


func _finish_cursor_skill_drag(cursor_position: Vector2) -> void:
	var target := _nearest_snap_slot(cursor_position)
	if target and can_drop_skill(_active_drag_data, target):
		drop_skill(_active_drag_data, target)
	else:
		_cancel_cursor_skill_drag()


func _cancel_cursor_skill_drag() -> void:
	if is_instance_valid(_cursor_drag_preview):
		_cursor_drag_preview.queue_free()
	_cursor_drag_preview = null
	if is_instance_valid(_cursor_drag_source) and is_instance_valid(_cursor_drag_source._icon):
		_cursor_drag_source._icon.show()
	_cursor_drag_source = null
	end_skill_drag()


func _nearest_snap_slot(cursor_position: Vector2) -> SkillSlot:
	var nearest: SkillSlot
	var nearest_distance := SKILL_SNAP_DISTANCE
	for index in range(4):
		var slot := _get_player_slot(index)
		if slot == null or slot.locked or not can_drop_skill(_active_drag_data, slot):
			continue
		var distance := cursor_position.distance_to(slot.get_global_rect().get_center())
		if distance <= nearest_distance:
			nearest = slot
			nearest_distance = distance
	return nearest


func end_skill_drag() -> void:
	if _ignore_next_drag_end:
		_ignore_next_drag_end = false
		_active_drag_data.clear()
		_hovered_target = null
		return
	_drag_active = false
	_active_drag_data.clear()
	_hovered_target = null
	_clear_interaction_highlights()
	_picker_status = "Select a skill, then choose Q, W, E, or R."
	if _swap_tutorial_active and not _swap_tutorial_dialogue_active:
		_apply_back_roll_glow()


func can_drop_skill(data: Variant, target: SkillSlot) -> bool:
	if not data is Dictionary or target == null or target.locked:
		return false
	var skill_id: StringName = data.get("skill_id", &"")
	if target.skill_id == skill_id:
		return false
	if str(data.get("source_kind", "")) == "player" and int(data.get("source_index", -1)) == target.slot_index:
		return false
	if _swap_tutorial_active:
		return not _swap_tutorial_dialogue_active and skill_id == FoxPlayer.SKILL_ROLL_BACK \
			and target.source_kind == "player" and target.slot_index == _tutorial_target_slot
	return _player != null and _player.unlocked_player_skills.has(skill_id)


func drop_skill(data: Variant, target: SkillSlot) -> void:
	if not can_drop_skill(data, target):
		return
	var skill_id: StringName = data.get("skill_id", &"")
	var skill_data := _player.get_player_skill_data(skill_id)
	var skill_name := str(skill_data.get("name", skill_id))
	var was_cursor_drag := is_instance_valid(_cursor_drag_preview)
	if _drag_active and not was_cursor_drag:
		_ignore_next_drag_end = true
	if _drag_active:
		_drag_active = false
	if is_instance_valid(_cursor_drag_preview):
		_cursor_drag_preview.queue_free()
	_cursor_drag_preview = null
	_cursor_drag_source = null
	if _swap_tutorial_active:
		_swap_tutorial_active = false
		_clear_tutorial_slot_glows()
		_restore_after_swap_tutorial()
		_player.complete_skill_swap_tutorial()
	if str(data.get("source_kind", "")) == "player":
		_player.swap_player_skill_slots(int(data.get("source_index", -1)), target.slot_index)
	else:
		_player.equip_player_skill(target.slot_index, skill_id)
	_active_drag_data.clear()
	_hovered_target = null
	_arranging_skills = true
	_picker.show()
	_refresh_picker()
	_apply_selection_highlights()
	_position_picker()
	var equipped_slot := _get_player_slot(target.slot_index)
	if equipped_slot:
		equipped_slot.play_equip_feedback(PLAYER_SHORTCUT_LABELS[target.slot_index], skill_name)
	_picker_status = "%s · %s equipped" % [PLAYER_SHORTCUT_LABELS[target.slot_index], skill_name]


func is_arranging_skills() -> bool:
	return _arranging_skills


func preview_skill_target(skill_id: StringName, target: SkillSlot, valid: bool) -> void:
	if not _arranging_skills or target == null or target.source_kind != "player":
		return
	_hovered_target = target
	_set_target_highlights(_active_drag_data if not _active_drag_data.is_empty() else {"source_kind": "picker", "source_index": -1, "skill_id": skill_id})
	target.set_interaction_state("hover" if valid else "invalid")
	var incoming := _player.get_player_skill_data(skill_id)
	var outgoing := _player.get_player_skill_data(target.skill_id)
	var incoming_name := str(incoming.get("name", skill_id))
	var outgoing_name := str(outgoing.get("name", "Empty"))
	if valid:
		_picker_status = "%s: %s → %s" % [PLAYER_SHORTCUT_LABELS[target.slot_index], outgoing_name, incoming_name]
	else:
		_picker_status = "%s cannot be placed in %s." % [incoming_name, PLAYER_SHORTCUT_LABELS[target.slot_index]]


func skill_slot_hovered(slot: SkillSlot) -> void:
	if not _arranging_skills or slot.source_kind != "player":
		return
	var skill_id: StringName = _active_drag_data.get("skill_id", &"")
	if skill_id.is_empty():
		return
	preview_skill_target(skill_id, slot, can_drop_skill(_active_drag_data, slot))


func skill_slot_unhovered(slot: SkillSlot) -> void:
	if _hovered_target != slot:
		return
	_hovered_target = null
	_apply_selection_highlights()


func _set_target_highlights(data: Dictionary) -> void:
	for index in range(4):
		var slot := _get_player_slot(index)
		if slot:
			slot.set_interaction_state("valid" if can_drop_skill(data, slot) else "invalid")


func _apply_selection_highlights() -> void:
	_clear_interaction_highlights()


func _clear_interaction_highlights() -> void:
	if is_instance_valid(_player_row):
		for child in _player_row.get_children():
			if child is SkillSlot:
				(child as SkillSlot).set_interaction_state("")
	if is_instance_valid(_picker_list):
		for child in _picker_list.get_children():
			if child is SkillSlot:
				(child as SkillSlot).set_interaction_state("")


func _find_tutorial_target_slot() -> int:
	if _player == null:
		return 0
	for index in range(_player.player_skill_slots_unlocked.size()):
		if bool(_player.player_skill_slots_unlocked[index]) and _player.equipped_player_skills[index] != FoxPlayer.SKILL_ROLL_BACK:
			return index
	return 0


func _get_picker_slot(skill_id: StringName) -> SkillSlot:
	if not is_instance_valid(_picker_list):
		return null
	for child in _picker_list.get_children():
		var slot := child as SkillSlot
		if slot and slot.skill_id == skill_id:
			return slot
	return null


func _clear_tutorial_slot_glows() -> void:
	if is_instance_valid(_player_row):
		for child in _player_row.get_children():
			if child is SkillSlot:
				(child as SkillSlot).set_tutorial_glow(false)
	if is_instance_valid(_picker_list):
		for child in _picker_list.get_children():
			if child is SkillSlot:
				(child as SkillSlot).set_tutorial_glow(false)


func _apply_back_roll_glow() -> void:
	if not _swap_tutorial_active or _swap_tutorial_dialogue_active or _drag_active:
		return
	_clear_tutorial_slot_glows()
	var back_roll := _get_picker_slot(FoxPlayer.SKILL_ROLL_BACK)
	if back_roll:
		back_roll.set_tutorial_glow(true)


func _position_picker() -> void:
	if not is_instance_valid(_picker) or not is_instance_valid(_player_row):
		return
	_picker.reset_size()
	var popup_size := _picker.get_combined_minimum_size()
	_picker.size = popup_size
	var bar_rect := _player_row.get_global_rect()
	var desired_global := Vector2(bar_rect.get_center().x - popup_size.x * 0.5, bar_rect.position.y - popup_size.y - 8.0)
	var viewport_size := get_viewport_rect().size
	desired_global.x = clampf(desired_global.x, 8.0, maxf(8.0, viewport_size.x - popup_size.x - 8.0))
	desired_global.y = maxf(8.0, desired_global.y)
	_picker.global_position = desired_global


func _pause_for_swap_tutorial() -> void:
	if _player == null:
		return
	_tutorial_world = _player._get_navigation_world()
	if is_instance_valid(_tutorial_world):
		_tutorial_world_was_paused = _tutorial_world.gameplay_paused
		_tutorial_world.gameplay_paused = true
	_player.stop()


func _restore_after_swap_tutorial() -> void:
	if is_instance_valid(_tutorial_world):
		_tutorial_world.gameplay_paused = _tutorial_world_was_paused
	_tutorial_world = null


func cast_skill_slot(index: int) -> void:
	_try_cast_player_skill(index)


func _try_cast_player_skill(index: int) -> bool:
	if _player == null:
		return false
	var slot := _get_player_slot(index)
	var cast_succeeded := _player.cast_player_skill_slot(index)
	if slot:
		if cast_succeeded:
			slot.play_cast_feedback()
		else:
			slot.play_failure_feedback(_player.get_last_skill_cast_failure())
	return cast_succeeded


func _get_player_slot(index: int) -> SkillSlot:
	if _player_row == null or index < 0 or index >= mini(4, _player_row.get_child_count()):
		return null
	return _player_row.get_child(index) as SkillSlot


func get_skill_cooldown_ratio(kind: String, index: int, _skill_id: StringName) -> float:
	if kind == "asha":
		return _asha.get_smooch_cooldown_ratio() if is_instance_valid(_asha) and index == 0 else 0.0
	return _player.get_player_skill_cooldown_ratio(index) if _player and kind == "player" else 0.0


func _build_tooltip() -> void:
	_tooltip = _make_panel()
	_tooltip.name = "SkillTooltip"
	_tooltip.z_index = 20
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tooltip)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	_tooltip.add_child(content)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 7)
	content.add_child(heading)
	_tooltip_icon = TextureRect.new()
	_tooltip_icon.custom_minimum_size = Vector2(36, 36)
	_tooltip_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tooltip_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heading.add_child(_tooltip_icon)
	_tooltip_name = Label.new()
	_tooltip_name.add_theme_font_size_override("font_size", 18)
	_tooltip_name.add_theme_color_override("font_color", Color("ffe082"))
	heading.add_child(_tooltip_name)
	_tooltip_description = Label.new()
	_tooltip_description.custom_minimum_size.x = 260
	_tooltip_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_tooltip_description)
	_tooltip_stats = Label.new()
	_tooltip_stats.add_theme_color_override("font_color", Color("67e8f9"))
	content.add_child(_tooltip_stats)
	_tooltip.hide()


func show_skill_tooltip(skill_id: StringName, kind: String) -> void:
	var data := _get_skill_data(skill_id, kind)
	if data.is_empty():
		return
	_tooltip_icon.texture = data.get("icon") as Texture2D
	_tooltip_name.text = str(data.get("name", skill_id))
	_tooltip_description.text = str(data.get("description", ""))
	_tooltip_stats.text = "Cooldown: %ss%s" % [_format_seconds(float(data.get("cooldown", 0.0))), "    Mana: %d" % int(data.get("mana", 0)) if int(data.get("mana", 0)) > 0 else ""]
	_tooltip.show()
	_tooltip.reset_size()
	var tooltip_size := _tooltip.get_combined_minimum_size()
	_tooltip.size = tooltip_size
	var viewport_size := get_viewport_rect().size
	var mouse_position := get_viewport().get_mouse_position()
	var desired := mouse_position + Vector2(16, -tooltip_size.y - 16)
	if desired.y < 8.0:
		desired.y = mouse_position.y + 16.0
	desired.x = clampf(desired.x, 8.0, maxf(8.0, viewport_size.x - tooltip_size.x - 8.0))
	desired.y = clampf(desired.y, 8.0, maxf(8.0, viewport_size.y - tooltip_size.y - 8.0))
	_tooltip.global_position = desired


func hide_skill_tooltip() -> void:
	_tooltip.hide()


func _refresh_tooltip_if_visible() -> void:
	pass


func _get_skill_data(skill_id: StringName, kind: String) -> Dictionary:
	if kind == "asha" and skill_id == ASHA_HEAL:
		return {"name": "Healing Smooch", "description": "Asha automatically heals Mira when her health is low.", "icon": HEAL_ICON, "mana": 0, "cooldown": 8.0}
	return _player.get_player_skill_data(skill_id) if _player else {}


func _format_seconds(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else ("%.1f" % value)


func _exit_tree() -> void:
	_restore_after_swap_tutorial()
