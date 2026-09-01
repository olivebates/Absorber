class_name HelperInventoryTransfer
extends Control

signal confirmed
signal cancelled

var _player: FoxPlayer
var _player_items: Array[Dictionary] = []
var _helper_items: Array[Dictionary] = []
var _player_grid: GridContainer
var _helper_grid: GridContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 900
	_build_ui()


func setup(player: FoxPlayer, helper_items: Array[Dictionary], helper_name: String) -> void:
	_player = player
	_player_items.clear()
	for item in player.inventory_slots:
		_player_items.append(item.duplicate(true))
	_helper_items.clear()
	for item in helper_items:
		_helper_items.append(item.duplicate(true))
	set_meta("helper_name", helper_name)
	var title := get_node_or_null("Center/Panel/Content/Header/Title") as Label
	if title:
		title.text = "%s's Items" % helper_name
	_rebuild()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.0, 0.0, 0.0, 0.64)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(560, 330)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("242938")
	style.border_color = Color("77819a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var header := HBoxContainer.new()
	header.name = "Header"
	content.add_child(header)
	var title := Label.new()
	title.name = "Title"
	title.text = "Helper Items"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(36, 36)
	close_button.pressed.connect(_cancel)
	header.add_child(close_button)
	var hint := Label.new()
	hint.text = "Drag items between inventories. Items left with the helper are discarded when you confirm."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("aeb8cc"))
	content.add_child(hint)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(columns)
	_player_grid = _add_inventory_column(columns, "Your Inventory")
	_helper_grid = _add_inventory_column(columns, "Helper Inventory")
	var confirm := Button.new()
	confirm.name = "ConfirmButton"
	confirm.text = "Confirm"
	confirm.custom_minimum_size = Vector2(0, 42)
	confirm.pressed.connect(_confirm)
	content.add_child(confirm)


func _add_inventory_column(parent: HBoxContainer, title_text: String) -> GridContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	column.add_child(grid)
	return grid


func _rebuild() -> void:
	_rebuild_grid(_player_grid, "transfer_player", _player_items)
	_rebuild_grid(_helper_grid, "transfer_helper", _helper_items)


func _rebuild_grid(grid: GridContainer, storage: String, items: Array[Dictionary]) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for index in range(items.size()):
		var slot := ItemSlot.new()
		slot.configure(self, storage, index, items[index])
		grid.add_child(slot)


func begin_slot_drag(_slot: ItemSlot) -> void:
	pass


func end_slot_drag() -> void:
	pass


func can_drop_in_slot(source: ItemSlot, target: ItemSlot) -> bool:
	if source.storage == target.storage and source.slot_index == target.slot_index:
		return false
	if source.storage == "transfer_player" and target.storage == "transfer_helper" \
			and ItemPickup.is_protected(str(source.item.get("item_id", ""))):
		return false
	return true


func drop_in_slot(source: ItemSlot, target: ItemSlot) -> void:
	var source_items := _player_items if source.storage == "transfer_player" else _helper_items
	var target_items := _player_items if target.storage == "transfer_player" else _helper_items
	var target_item := target_items[target.slot_index]
	target_items[target.slot_index] = source_items[source.slot_index]
	source_items[source.slot_index] = target_item
	_rebuild()


func click_slot(slot: ItemSlot) -> void:
	var target_items := _helper_items if slot.storage == "transfer_player" else _player_items
	for index in range(target_items.size()):
		if target_items[index].is_empty():
			var source_items := _player_items if slot.storage == "transfer_player" else _helper_items
			if slot.storage == "transfer_player" and ItemPickup.is_protected(str(slot.item.get("item_id", ""))):
				return
			target_items[index] = source_items[slot.slot_index]
			source_items[slot.slot_index] = {}
			_rebuild()
			return


func get_weapon_cooldown_ratio(_index: int) -> float:
	return 0.0


func is_equipment_disabled() -> bool:
	return false


func _confirm() -> void:
	if not is_instance_valid(_player):
		_cancel()
		return
	_player.inventory_slots.clear()
	for item in _player_items:
		_player.inventory_slots.append(item.duplicate(true))
	_player.inventory_changed.emit()
	confirmed.emit()
	queue_free()


func _cancel() -> void:
	cancelled.emit()
	queue_free()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_cancel()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel()
		get_viewport().set_input_as_handled()
