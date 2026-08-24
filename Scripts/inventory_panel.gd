class_name InventoryPanel
extends PanelContainer

var _player: FoxPlayer
var _items: HBoxContainer
var _dragged_item: Dictionary = {}
var _drag_source_storage := ""
var _drag_source_index := -1
var _auto_merge_button: Button
var _auto_merge_in_progress := false
var _trash_slot: ItemSlot


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -214.0
	offset_top = -288.0
	offset_right = -14.0
	offset_bottom = -126.0
	_set_style()
	var content := VBoxContainer.new()
	add_child(content)
	var title := Label.new()
	title.text = "Inventory"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.WHITE)
	content.add_child(title)
	_items = HBoxContainer.new()
	_items.alignment = BoxContainer.ALIGNMENT_CENTER
	_items.add_theme_constant_override("separation", 5)
	content.add_child(_items)
	var trash_row := HBoxContainer.new()
	trash_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	content.add_child(trash_row)
	_trash_slot = ItemSlot.new()
	_trash_slot.name = "TrashSlot"
	trash_row.add_child(_trash_slot)
	_trash_slot.mouse_entered.connect(func() -> void:
		var tooltip := get_tree().get_first_node_in_group("item_tooltip") as ItemTooltip
		if tooltip and not _trash_slot.item.is_empty():
			tooltip.show_item(_trash_slot.item)
	)
	_trash_slot.mouse_exited.connect(func() -> void:
		var tooltip := get_tree().get_first_node_in_group("item_tooltip") as ItemTooltip
		if tooltip:
			tooltip.hide_item()
	)
	_auto_merge_button = Button.new()
	_auto_merge_button.text = "Auto Merge"
	_auto_merge_button.tooltip_text = "Merge all matching items in the inventory"
	_auto_merge_button.custom_minimum_size = Vector2(0, 26)
	_set_auto_merge_style(_auto_merge_button)
	_auto_merge_button.pressed.connect(_on_auto_merge_pressed)
	_auto_merge_button.visible = false
	content.add_child(_auto_merge_button)
	call_deferred("_connect_player")


func _set_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.055, 0.93)
	style.border_color = Color.BLACK
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 4
	style.content_margin_bottom = 5
	add_theme_stylebox_override("panel", style)


func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as FoxPlayer
	if _player:
		_player.inventory_changed.connect(_refresh)
		_player.merge_targets_changed.connect(_set_merge_targets)
		_player.merge_completed.connect(_on_merge_completed)
		_refresh()


func _set_merge_targets(item: Dictionary, source_storage: String, source_index: int) -> void:
	_dragged_item = item.duplicate()
	_drag_source_storage = source_storage
	_drag_source_index = source_index
	_update_merge_highlights()


func _update_merge_highlights() -> void:
	for child in _items.get_children():
		if child is ItemSlot:
			var slot := child as ItemSlot
			var merge_target := _player.is_tutorial_merge_slot("inventory", slot.slot_index) or (not ("inventory" == _drag_source_storage and slot.slot_index == _drag_source_index) and _player.can_merge(_dragged_item, slot.item))
			slot.configure(self, "inventory", slot.slot_index, slot.item, merge_target)


func _refresh() -> void:
	if _player == null:
		return
	for child in _items.get_children():
		child.queue_free()
	for index in range(4):
		var item := _player.get_slot_item("inventory", index)
		var slot := ItemSlot.new()
		var merge_target := _player.is_tutorial_merge_slot("inventory", index) or (not ("inventory" == _drag_source_storage and index == _drag_source_index) and _player.can_merge(_dragged_item, item))
		slot.configure(self, "inventory", index, item, merge_target)
		_connect_tooltip(slot)
		_items.add_child(slot)
	var trash_item := _player.get_slot_item("trash", 0)
	_trash_slot.configure(self, "trash", 0, trash_item)
	_trash_slot.tooltip_text = "Trash (drag an item here; the previous item is discarded)"
	_auto_merge_button.visible = _player.has_auto_mergeable_inventory_pair()
	_auto_merge_button.disabled = _auto_merge_in_progress


func begin_slot_drag(slot: ItemSlot) -> void:
	_player.set_dragged_item(slot.item, slot.storage, slot.slot_index)


func end_slot_drag() -> void:
	_player.clear_dragged_item()


func can_drop_in_slot(source: ItemSlot, target: ItemSlot) -> bool:
	return _can_move(source, target)


func _can_move(source: ItemSlot, target: ItemSlot) -> bool:
	var item_id := str(source.item.get("item_id", ""))
	if target.storage == "weapon" and not ItemPickup.is_weapon(item_id):
		return false
	if target.storage == "armor" and not ItemPickup.is_armor(item_id):
		return false
	var target_item := _player.get_slot_item(target.storage, target.slot_index)
	if not target_item.is_empty() and source.storage != "inventory":
		var target_id := str(target_item.get("item_id", ""))
		if source.storage == "weapon" and not ItemPickup.is_weapon(target_id):
			return false
		if source.storage == "armor" and not ItemPickup.is_armor(target_id):
			return false
	return true


func drop_in_slot(source: ItemSlot, target: ItemSlot) -> void:
	_player.move_or_merge(source.storage, source.slot_index, target.storage, target.slot_index)


func click_slot(slot: ItemSlot) -> void:
	if slot.storage == "trash":
		return
	if ItemPickup.is_consumable(str(slot.item.get("item_id", ""))):
		_player.consume_inventory_item(slot.slot_index)
	elif ItemPickup.is_weapon(str(slot.item.get("item_id", ""))):
		_player.move_or_merge(slot.storage, slot.slot_index, "weapon", 0)
	elif ItemPickup.is_armor(str(slot.item.get("item_id", ""))):
		_player.move_or_merge(slot.storage, slot.slot_index, "armor", 0)


func _on_auto_merge_pressed() -> void:
	if _player == null or _auto_merge_in_progress or not _player.has_auto_mergeable_inventory_pair():
		return
	_auto_merge_in_progress = true
	_auto_merge_button.disabled = true
	_run_auto_merge_sequence()


func _run_auto_merge_sequence() -> void:
	while _player and is_instance_valid(_player):
		var pair := _player.get_next_auto_merge_pair()
		if pair.is_empty():
			break
		var source_slot := _get_inventory_slot(int(pair["source_index"]))
		var target_slot := _get_inventory_slot(int(pair["target_index"]))
		if source_slot == null or target_slot == null:
			break
		await _play_auto_merge_animation(source_slot, target_slot)
		if not _player.merge_inventory_pair(int(pair["source_index"]), int(pair["target_index"])):
			break
		await get_tree().process_frame
	_auto_merge_in_progress = false
	_refresh()


func _get_inventory_slot(index: int) -> ItemSlot:
	for child in _items.get_children():
		if child is ItemSlot and child.slot_index == index:
			return child as ItemSlot
	return null


func _play_auto_merge_animation(source_slot: ItemSlot, target_slot: ItemSlot) -> void:
	var moving_icon := TextureRect.new()
	moving_icon.texture = ItemPickup.ITEM_TEXTURES.get(str(source_slot.item.get("item_id", "")))
	moving_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	moving_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	moving_icon.custom_minimum_size = Vector2(32, 32)
	moving_icon.size = Vector2(32, 32)
	moving_icon.position = source_slot.get_global_rect().get_center() - moving_icon.size * 0.5
	moving_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moving_icon.z_index = 30
	get_parent().add_child(moving_icon)
	var destination := target_slot.get_global_rect().get_center() - moving_icon.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(moving_icon, "position", destination, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(moving_icon, "scale", Vector2(0.82, 0.82), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(source_slot, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	if is_instance_valid(moving_icon):
		moving_icon.queue_free()


func _on_merge_completed(_item: Dictionary, target_storage: String, target_index: int) -> void:
	if target_storage == "inventory":
		call_deferred("_play_merge_success", target_index)


func _play_merge_success(target_index: int) -> void:
	for child in _items.get_children():
		if child is ItemSlot and child.slot_index == target_index:
			child.play_merge_success()
			return


func _set_auto_merge_style(button: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("4d3d12") if state == "normal" else Color("715b19") if state == "hover" else Color("2f260a")
		style.border_color = Color("e9c64d")
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("fff2bd"))
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 2)


func _connect_tooltip(slot: ItemSlot) -> void:
	if slot.item.is_empty():
		return
	slot.mouse_entered.connect(func() -> void:
		var tooltip := get_tree().get_first_node_in_group("item_tooltip") as ItemTooltip
		if tooltip:
			tooltip.show_item(slot.item)
	)
	slot.mouse_exited.connect(func() -> void:
		var tooltip := get_tree().get_first_node_in_group("item_tooltip") as ItemTooltip
		if tooltip:
			tooltip.hide_item()
	)
