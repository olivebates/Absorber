class_name TigerShop
extends Control

const UPGRADES := [
	{"resource_id": &"gold_ore", "base_price": 10, "label": "Red Damage +1"},
	{"resource_id": &"jewels", "base_price": 5, "label": "Regeneration +1"},
	{"resource_id": &"fish", "base_price": 5, "label": "Max Health +20"},
	{"resource_id": &"wood", "base_price": 3, "label": "Max Health +20"},
]

var _tiger: WhiteTiger
var _player: FoxPlayer
var _resource_manager: ResourceManager
var _panel: PanelContainer
var _rows: Array[HBoxContainer] = []
var _buy_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	gui_input.connect(_on_overlay_gui_input)
	_build_interface()


func setup(tiger: WhiteTiger) -> void:
	_tiger = tiger
	_player = get_tree().get_first_node_in_group("player") as FoxPlayer
	_resource_manager = get_tree().get_first_node_in_group("resource_manager") as ResourceManager
	if _resource_manager:
		if not _resource_manager.resource_changed.is_connected(_on_resource_changed):
			_resource_manager.resource_changed.connect(_on_resource_changed)
		if not _resource_manager.resource_discovered.is_connected(_on_resource_discovered):
			_resource_manager.resource_discovered.connect(_on_resource_discovered)
	_refresh()


func open() -> void:
	_refresh()
	show()
	move_to_front()


func close() -> void:
	hide()


func get_panel() -> PanelContainer:
	return _panel


func get_upgrade_price(upgrade_index: int) -> int:
	if _tiger == null or upgrade_index < 0 or upgrade_index >= UPGRADES.size():
		return 0
	return int(UPGRADES[upgrade_index]["base_price"]) * (_tiger.purchase_counts[upgrade_index] + 1)


func is_upgrade_visible(upgrade_index: int) -> bool:
	return upgrade_index >= 0 and upgrade_index < _rows.size() and _rows[upgrade_index].visible


func buy_upgrade(upgrade_index: int) -> bool:
	if _tiger == null or _player == null or _resource_manager == null or upgrade_index < 0 or upgrade_index >= UPGRADES.size():
		return false
	var resource_id := StringName(UPGRADES[upgrade_index]["resource_id"])
	var price := get_upgrade_price(upgrade_index)
	if not _resource_manager.spend_resources({resource_id: price}):
		_refresh()
		return false
	match upgrade_index:
		0:
			_player.add_color_damage(FoxPlayer.COLOR_RED, 1)
		1:
			_player.add_passive_healing(1)
		2, 3:
			_player.add_max_health(20)
	_tiger.purchase_counts[upgrade_index] += 1
	_refresh()
	return true


func _build_interface() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_consume_panel_input)
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	_panel.add_child(content)

	var title_row := HBoxContainer.new()
	content.add_child(title_row)
	var title := Label.new()
	title.text = "White Tiger's Shop"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("ffe082"))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 2)
	title_row.add_child(title)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(28, 26)
	close_button.pressed.connect(close)
	title_row.add_child(close_button)

	var separator := HSeparator.new()
	content.add_child(separator)
	for index in range(UPGRADES.size()):
		var row := _make_upgrade_row(index)
		_rows.append(row)
		content.add_child(row)


func _make_upgrade_row(upgrade_index: int) -> HBoxContainer:
	var upgrade: Dictionary = UPGRADES[upgrade_index]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.text = str(upgrade["label"])
	label.custom_minimum_size = Vector2(132, 28)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var button := Button.new()
	button.custom_minimum_size = Vector2(90, 28)
	button.pressed.connect(buy_upgrade.bind(upgrade_index))
	row.add_child(button)
	_buy_buttons.append(button)
	return row


func _refresh() -> void:
	if _resource_manager == null or _tiger == null:
		return
	for index in range(UPGRADES.size()):
		var resource_id := StringName(UPGRADES[index]["resource_id"])
		var definition := _resource_manager.get_definition(resource_id)
		var row_visible := index == 0 or _resource_manager.has_ever_owned(resource_id)
		_rows[index].visible = row_visible
		var icon := _rows[index].get_child(0) as TextureRect
		icon.texture = definition.icon if definition else null
		var price := get_upgrade_price(index)
		_buy_buttons[index].text = "Buy %d" % price
		_buy_buttons[index].disabled = not _resource_manager.can_afford({resource_id: price})


func _on_resource_changed(_resource_id: StringName, _amount: int, _maximum_amount: int) -> void:
	_refresh()


func _on_resource_discovered(_resource_id: StringName) -> void:
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	if key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close()
		accept_event()


func _consume_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.97)
	style.border_color = Color("e9c64d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
