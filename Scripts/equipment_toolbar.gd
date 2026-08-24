class_name EquipmentToolbar
extends PanelContainer

var _player: FoxPlayer
var _armor_row: HBoxContainer
var _weapon_row: HBoxContainer
var _dragged_item: Dictionary = {}
var _drag_source_storage := ""
var _drag_source_index := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -214.0
	offset_top = -116.0
	offset_right = -14.0
	offset_bottom = -14.0
	_set_style()
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	add_child(rows)
	_armor_row = HBoxContainer.new()
	_armor_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_armor_row.add_theme_constant_override("separation", 5)
	rows.add_child(_armor_row)
	_weapon_row = HBoxContainer.new()
	_weapon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_weapon_row.add_theme_constant_override("separation", 5)
	rows.add_child(_weapon_row)
	call_deferred("_connect_player")


func _set_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.38, 0.4, 0.44, 0.62)
	style.border_color = Color.BLACK
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)


func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as FoxPlayer
	if _player:
		_player.equipment_changed.connect(_refresh)
		_player.merge_targets_changed.connect(_set_merge_targets)
		_player.merge_completed.connect(_on_merge_completed)
		_refresh()


func _set_merge_targets(item: Dictionary, source_storage: String, source_index: int) -> void:
	_dragged_item = item.duplicate()
	_drag_source_storage = source_storage
	_drag_source_index = source_index
	_update_merge_highlights()


func _update_merge_highlights() -> void:
	for row_and_storage in [[_weapon_row, "weapon"], [_armor_row, "armor"]]:
		var row := row_and_storage[0] as HBoxContainer
		var storage := str(row_and_storage[1])
		for child in row.get_children():
			if child is ItemSlot:
				var slot := child as ItemSlot
				var merge_target := not (storage == _drag_source_storage and slot.slot_index == _drag_source_index) and _player.can_merge(_dragged_item, slot.item)
				var valid_equipment_target := _is_valid_equipment_target(storage, slot.slot_index, _dragged_item)
				slot.configure(self, storage, slot.slot_index, slot.item, merge_target or valid_equipment_target, _is_locked(storage, slot.slot_index), _shows_unarmed_damage(storage, slot.slot_index))


func _refresh() -> void:
	if _player == null:
		return
	_rebuild_row(_weapon_row, "weapon")
	_rebuild_row(_armor_row, "armor")


func _rebuild_row(row: HBoxContainer, storage: String) -> void:
	for child in row.get_children():
		child.queue_free()
	for index in range(4):
		var item := _player.get_slot_item(storage, index)
		var slot := ItemSlot.new()
		var merge_target := not (storage == _drag_source_storage and index == _drag_source_index) and _player.can_merge(_dragged_item, item)
		var valid_equipment_target := _is_valid_equipment_target(storage, index, _dragged_item)
		slot.configure(self, storage, index, item, merge_target or valid_equipment_target, _is_locked(storage, index), _shows_unarmed_damage(storage, index))
		_connect_tooltip(slot)
		row.add_child(slot)


func begin_slot_drag(slot: ItemSlot) -> void:
	_player.set_dragged_item(slot.item, slot.storage, slot.slot_index)


func end_slot_drag() -> void:
	_player.clear_dragged_item()


func can_drop_in_slot(source: ItemSlot, target: ItemSlot) -> bool:
	return _can_move(source, target)


func _can_move(source: ItemSlot, target: ItemSlot) -> bool:
	if source.locked or target.locked:
		return false
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


func click_slot(_slot: ItemSlot) -> void:
	if _slot.locked:
		return
	for index in range(4):
		var candidate := _player.get_slot_item("inventory", index)
		if _player.can_merge(_slot.item, candidate) or candidate.is_empty():
			_player.move_or_merge(_slot.storage, _slot.slot_index, "inventory", index)
			return


func _on_merge_completed(_item: Dictionary, target_storage: String, target_index: int) -> void:
	if target_storage == "weapon" or target_storage == "armor":
		call_deferred("_play_merge_success", target_storage, target_index)


func _play_merge_success(storage: String, target_index: int) -> void:
	var row := _weapon_row if storage == "weapon" else _armor_row
	for child in row.get_children():
		if child is ItemSlot and child.slot_index == target_index:
			child.play_merge_success()
			return


func get_weapon_cooldown_ratio(index: int) -> float:
	return _player.get_weapon_cooldown_ratio(index) if _player else 0.0


func _is_locked(storage: String, index: int) -> bool:
	return index != 0 or (storage != "weapon" and storage != "armor")


func _shows_unarmed_damage(storage: String, index: int) -> bool:
	if storage != "weapon" or index != 0:
		return false
	for weapon_index in range(4):
		if not _player.get_slot_item("weapon", weapon_index).is_empty():
			return false
	return true


func _is_valid_equipment_target(storage: String, index: int, item: Dictionary) -> bool:
	if _is_locked(storage, index):
		return false
	var item_id := str(item.get("item_id", ""))
	return storage == "weapon" and ItemPickup.is_weapon(item_id) \
		or storage == "armor" and ItemPickup.is_armor(item_id)


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
