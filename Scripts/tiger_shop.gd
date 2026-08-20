class_name TigerShop
extends Control

const DAMAGE_ICON := preload("res://Sprites/DamageIcon.webp")
const REGENERATION_ICON := preload("res://Sprites/GreenHeart.png")
const HEALTH_ICON := preload("res://Sprites/Heart.webp")
const UPGRADES := [
	{"resource_id": &"gold_ore", "base_price": 5, "amount": 1, "stat_icon": DAMAGE_ICON},
	{"resource_id": &"jewels", "base_price": 5, "amount": 1, "stat_icon": REGENERATION_ICON},
	{"resource_id": &"fish", "base_price": 5, "amount": 20, "stat_icon": HEALTH_ICON},
	{"resource_id": &"wood", "base_price": 3, "amount": 20, "stat_icon": HEALTH_ICON},
]

var _tiger: WhiteTiger
var _player: FoxPlayer
var _resource_manager: ResourceManager
var _panel: PanelContainer
var _rows: Array[Button] = []
var _price_icons: Array[TextureRect] = []
var _price_labels: Array[Label] = []


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
	title.name = "Title"
	title.text = "Stats Shop"
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
	content.add_child(HSeparator.new())
	for index in range(UPGRADES.size()):
		var row := _make_upgrade_button(index)
		_rows.append(row)
		content.add_child(row)


func _make_upgrade_button(upgrade_index: int) -> Button:
	var upgrade: Dictionary = UPGRADES[upgrade_index]
	var button := Button.new()
	button.custom_minimum_size = Vector2(310, 40)
	button.pressed.connect(buy_upgrade.bind(upgrade_index))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	row.add_child(_make_icon(upgrade["stat_icon"] as Texture2D, Vector2(24, 24)))
	if upgrade_index == 0:
		var damage_dot := Panel.new()
		damage_dot.name = "DamageColorDot"
		damage_dot.custom_minimum_size = Vector2(10, 10)
		damage_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dot_style := StyleBoxFlat.new()
		dot_style.bg_color = Color("e64343")
		dot_style.border_color = Color.BLACK
		dot_style.set_border_width_all(1)
		dot_style.set_corner_radius_all(5)
		damage_dot.add_theme_stylebox_override("panel", dot_style)
		row.add_child(damage_dot)
	var amount := Label.new()
	amount.text = "+%d" % int(upgrade["amount"])
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(amount)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var price_text := Label.new()
	price_text.text = "Price:"
	price_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(price_text)
	var price_icon := _make_icon(null, Vector2(22, 22))
	_price_icons.append(price_icon)
	row.add_child(price_icon)
	var price_amount := Label.new()
	price_amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_price_labels.append(price_amount)
	row.add_child(price_amount)
	return button


func _make_icon(texture: Texture2D, minimum_size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = minimum_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _refresh() -> void:
	if _resource_manager == null or _tiger == null:
		return
	for index in range(UPGRADES.size()):
		var resource_id := StringName(UPGRADES[index]["resource_id"])
		var definition := _resource_manager.get_definition(resource_id)
		_rows[index].visible = index == 0 or _resource_manager.has_ever_owned(resource_id)
		_price_icons[index].texture = definition.icon if definition else null
		var price := get_upgrade_price(index)
		_price_labels[index].text = str(price)
		var can_afford := _resource_manager.can_afford({resource_id: price})
		_price_labels[index].add_theme_color_override("font_color", Color.WHITE if can_afford else Color("ef5350"))
		_rows[index].disabled = not can_afford


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
