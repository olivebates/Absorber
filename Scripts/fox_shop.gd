class_name FoxShop
extends Control

const DAMAGE_ICON := preload("res://Sprites/DamageIcon.webp")
const REGENERATION_ICON := preload("res://Sprites/RecoveryHeart.webp")
const HEALTH_ICON := preload("res://Sprites/Heart.webp")
const RESOURCE_PURCHASE_PRICE := 2
const RESOURCE_PURCHASES := [&"fish", &"wood"]
const UPGRADES := [
	{"resource_id": &"gold_ore", "base_price": 5, "purchase_slot": 0, "amount": 1, "stat_icon": DAMAGE_ICON, "stat": &"damage", "color": FoxPlayer.COLOR_RED, "name": "Red Damage", "description": "Increase red damage by 1."},
	{"resource_id": &"wood", "base_price": 3, "purchase_slot": 2, "amount": 20, "stat_icon": HEALTH_ICON, "stat": &"health", "name": "Max Health", "description": "Increase maximum health by 20."},
	{"resource_id": &"jewels", "base_price": 5, "purchase_slot": 3, "amount": 1, "stat_icon": REGENERATION_ICON, "stat": &"regeneration", "name": "Regeneration", "description": "Increase passive health regeneration by 0.3."},
	{"resource_id": &"jewels", "base_price": 2, "fixed_price": true, "purchase_slot": 1, "amount": 1, "stat_icon": preload("res://Sprites/PotionBasic.webp"), "stat": &"item", "item_id": "potion_basic", "name": "Basic Potion", "description": "Consume to heal 40 HP."},
]

var _shopkeeper: FoxAsha
var _player: FoxPlayer
var _resource_manager: ResourceManager
var _panel: PanelContainer
var _rows: Array[Button] = []
var _price_icons: Array[TextureRect] = []
var _price_labels: Array[Label] = []
var _resource_purchase_rows: Dictionary = {}
var _hover_tweens: Dictionary = {}
var _remembered_mouse_position := Vector2(-1, -1)
var _remembered_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	gui_input.connect(_on_overlay_gui_input)
	_build_interface()


func setup(shopkeeper: FoxAsha) -> void:
	_shopkeeper = shopkeeper
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
	_animate_rows_open()
	call_deferred("_restore_interaction_state")


func close() -> void:
	_hide_shop_tooltip()
	hide()


func get_panel() -> PanelContainer:
	return _panel


func get_upgrade_price(upgrade_index: int) -> int:
	var upgrades := _get_upgrades()
	if _shopkeeper == null or upgrade_index < 0 or upgrade_index >= upgrades.size():
		return 0
	var upgrade: Dictionary = upgrades[upgrade_index]
	if bool(upgrade.get("fixed_price", false)):
		return int(upgrade["base_price"])
	var purchase_slot := int(upgrade.get("purchase_slot", upgrade_index))
	return int(upgrade["base_price"]) * (_shopkeeper.purchase_counts[purchase_slot] + 1)


func is_upgrade_visible(upgrade_index: int) -> bool:
	return upgrade_index >= 0 and upgrade_index < _rows.size() and _rows[upgrade_index].visible


func buy_upgrade(upgrade_index: int) -> bool:
	var upgrades := _get_upgrades()
	if _shopkeeper == null or _player == null or _resource_manager == null or upgrade_index < 0 or upgrade_index >= upgrades.size():
		return false
	var upgrade: Dictionary = upgrades[upgrade_index]
	var resource_id := StringName(upgrade["resource_id"])
	var price := get_upgrade_price(upgrade_index)
	var before_value: Variant = _get_upgrade_current_value(upgrade_index)
	if StringName(upgrade["stat"]) == &"item" and not _player.can_collect_item(str(upgrade["item_id"])):
		_play_purchase_failure(_rows[upgrade_index], _price_labels[upgrade_index], "Inventory is full")
		return false
	if not _resource_manager.spend_resources({resource_id: price}):
		_refresh()
		_play_purchase_failure(_rows[upgrade_index], _price_labels[upgrade_index], _missing_resource_text(resource_id, price))
		return false
	_apply_upgrade(upgrade)
	var purchase_slot := int(upgrade.get("purchase_slot", upgrade_index))
	_shopkeeper.purchase_counts[purchase_slot] += 1
	_refresh()
	var after_value: Variant = _get_upgrade_current_value(upgrade_index)
	var result_name := str(upgrade["name"])
	var before_text := _format_upgrade_value(upgrade, before_value)
	var after_text := _format_upgrade_value(upgrade, after_value)
	_remember_interaction_state(_rows[upgrade_index])
	_play_purchase_success(
		_rows[upgrade_index],
		upgrade["stat_icon"] as Texture2D,
		_price_icons[upgrade_index].texture,
		&"",
		"Purchased!  %s: %s → %s" % [result_name, before_text, after_text],
		upgrade_index
	)
	return true


func buy_resource(resource_id: StringName) -> bool:
	var offer := _get_resource_offer(resource_id)
	if _resource_manager == null or offer.is_empty():
		return false
	var cost_resource_id := StringName(offer["cost_resource_id"])
	var price := int(offer["price"])
	var button := _resource_purchase_rows.get(resource_id) as Button
	if _resource_manager.get_amount(resource_id) >= _resource_manager.get_maximum_amount(resource_id):
		_refresh()
		_play_purchase_failure(button, button.find_child("PriceAmount", true, false) as Label, "%s is already full" % str(resource_id).capitalize())
		return false
	if not _resource_manager.spend_resources({cost_resource_id: price}):
		_refresh()
		_play_purchase_failure(button, button.find_child("PriceAmount", true, false) as Label, _missing_resource_text(cost_resource_id, price))
		return false
	var before_amount := _resource_manager.get_amount(resource_id)
	_resource_manager.add_resource(resource_id, 1.0)
	_refresh()
	var offer_icon := button.find_child("ResourceIcon", true, false) as TextureRect
	var price_icon := button.find_child("PriceIcon", true, false) as TextureRect
	if price_icon == null:
		price_icon = button.find_child("GoldIcon", true, false) as TextureRect
	_remember_interaction_state(button)
	_play_purchase_success(
		button,
		offer_icon.texture if offer_icon else null,
		price_icon.texture if price_icon else null,
		resource_id,
		"Purchased!  %s: %d → %d" % [str(resource_id).capitalize(), before_amount, _resource_manager.get_amount(resource_id)],
		-1
	)
	return true


func _notify_story_purchase() -> void:
	if is_instance_valid(_shopkeeper):
		_shopkeeper.play_purchase_reaction()
	var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
	if story:
		story.on_asha_purchase()


func _get_upgrades() -> Array:
	return UPGRADES


func _get_resource_offers() -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	for resource_id in RESOURCE_PURCHASES:
		offers.append({"resource_id": resource_id, "cost_resource_id": &"gold_ore", "price": RESOURCE_PURCHASE_PRICE})
	return offers


func _get_resource_offer(resource_id: StringName) -> Dictionary:
	for offer in _get_resource_offers():
		if StringName(offer["resource_id"]) == resource_id:
			return offer
	return {}


func _get_shop_title() -> String:
	return "Asha's Store"


func _apply_upgrade(upgrade: Dictionary) -> void:
	var amount := int(upgrade["amount"])
	match StringName(upgrade["stat"]):
		&"damage":
			_player.add_color_damage(int(upgrade.get("color", FoxPlayer.COLOR_RED)), amount)
		&"defense":
			_player.add_color_defense(int(upgrade.get("color", FoxPlayer.COLOR_RED)), amount)
		&"regeneration":
			_player.add_passive_healing(amount)
		&"health":
			_player.add_max_health(amount)
		&"item":
			_player.collect_item(str(upgrade["item_id"]))


func _get_upgrade_current_value(upgrade_index: int) -> Variant:
	var upgrade: Dictionary = _get_upgrades()[upgrade_index]
	match StringName(upgrade["stat"]):
		&"damage":
			return _player.get_base_damage_for_color(int(upgrade.get("color", FoxPlayer.COLOR_RED)))
		&"defense":
			return _player.get_base_defense_for_color(int(upgrade.get("color", FoxPlayer.COLOR_RED)))
		&"regeneration":
			return _player.get_passive_healing_per_second()
		&"health":
			return _player.max_health
		&"item":
			var count := 0
			var item_id := str(upgrade["item_id"])
			for item in _player.inventory_slots:
				if str(item.get("item_id", "")) == item_id:
					count += 1
			return count
	return 0


func _format_upgrade_value(upgrade: Dictionary, value: Variant) -> String:
	if StringName(upgrade["stat"]) == &"regeneration" and not upgrade.has("display_amount"):
		return FoxPlayer.format_regeneration_value(float(value))
	if StringName(upgrade["stat"]) == &"item":
		return str(int(value))
	return str(int(value))


func _missing_resource_text(resource_id: StringName, price: int) -> String:
	var amount := _resource_manager.get_amount(resource_id)
	var definition := _resource_manager.get_definition(resource_id)
	var display_name: String = definition.display_name if definition else str(resource_id).capitalize()
	return "Need %d more %s" % [maxi(0, price - amount), display_name]


func _remember_interaction_state(button: Button) -> void:
	_remembered_mouse_position = get_viewport().get_mouse_position()
	_remembered_button = button


func _restore_interaction_state() -> void:
	if not visible or not is_instance_valid(_remembered_button):
		return
	_remembered_button.grab_focus()
	if _remembered_mouse_position.x >= 0.0:
		Input.warp_mouse(_remembered_mouse_position)


func _animate_rows_open() -> void:
	var visible_rows: Array[Button] = []
	for offer in _get_resource_offers():
		var resource_row := _resource_purchase_rows.get(StringName(offer["resource_id"])) as Button
		if resource_row and resource_row.visible:
			visible_rows.append(resource_row)
	for row in _rows:
		if row.visible:
			visible_rows.append(row)
	for index in range(visible_rows.size()):
		var row := visible_rows[index]
		row.modulate.a = 0.0
		row.scale = Vector2(0.97, 0.97)
		row.pivot_offset = row.size * 0.5
		var tween := row.create_tween().set_parallel(true)
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(row, "modulate:a", 1.0, 0.16).set_delay(index * 0.035)
		tween.tween_property(row, "scale", Vector2.ONE, 0.16).set_delay(index * 0.035)


func _play_purchase_success(button: Button, benefit_texture: Texture2D, currency_texture: Texture2D, target_resource_id: StringName, _result_text: String, upgrade_index: int) -> void:
	if button == null:
		return
	var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
	if audio:
		audio.play_purchase()
	_flash_button(button, Color(1.0, 0.82, 0.25, 0.42))
	var purchased_amount := int(_get_upgrades()[upgrade_index]["amount"]) if upgrade_index >= 0 else 1
	_show_purchase_feedback(button, purchased_amount, benefit_texture)
	var offer_icon := button.find_child("OfferIcon", true, false) as TextureRect
	if offer_icon == null:
		offer_icon = button.find_child("ResourceIcon", true, false) as TextureRect
	var price_icon := button.find_child("PriceIcon", true, false) as TextureRect
	if price_icon == null:
		price_icon = button.find_child("GoldIcon", true, false) as TextureRect
	if price_icon == null and upgrade_index >= 0:
		price_icon = _price_icons[upgrade_index]
	var start := offer_icon.get_global_rect().get_center() if offer_icon else button.get_global_rect().get_center()
	var price_target := price_icon.get_global_rect().get_center() if price_icon else button.get_global_rect().end - Vector2(18, 20)
	_spawn_flying_icon(currency_texture, start, price_target, 0.22)
	_spawn_flying_icon(benefit_texture, start, _get_benefit_target(target_resource_id, upgrade_index), 0.38)
	get_tree().create_timer(0.30).timeout.connect(_notify_story_purchase)


func _play_purchase_failure(button: Button, price_label: Label, message: String) -> void:
	if button == null:
		return
	var content := button.get_child(0) as Control
	if content:
		var origin := content.position
		var shake := content.create_tween()
		for offset in [5.0, -5.0, 4.0, -4.0, 0.0]:
			shake.tween_property(content, "position:x", origin.x + offset, 0.035)
	if price_label:
		price_label.pivot_offset = price_label.size * 0.5
		price_label.modulate = Color("ff5252")
		var pulse := price_label.create_tween().set_parallel(true)
		pulse.tween_property(price_label, "scale", Vector2(1.22, 1.22), 0.08)
		pulse.chain().tween_property(price_label, "scale", Vector2.ONE, 0.12)
		pulse.tween_property(price_label, "modulate", Color.WHITE, 0.20)
	_show_feedback_label(button, message, Color("ff6262"))


func _flash_button(button: Button, color: Color) -> void:
	var flash := Panel.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	flash.add_theme_stylebox_override("panel", style)
	button.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.32)
	tween.tween_callback(flash.queue_free)


func _show_feedback_label(button: Button, message: String, color: Color) -> void:
	var feedback := Label.new()
	feedback.text = message
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback.z_index = 70
	feedback.add_theme_color_override("font_color", color)
	feedback.add_theme_color_override("font_outline_color", Color.BLACK)
	feedback.add_theme_constant_override("outline_size", 3)
	add_child(feedback)
	feedback.size = feedback.get_combined_minimum_size()
	feedback.global_position = button.get_global_rect().get_center() - Vector2(feedback.size.x * 0.5, 10)
	var tween := feedback.create_tween().set_parallel(true)
	tween.tween_property(feedback, "position:y", feedback.position.y - 24.0, 0.55)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.55).set_delay(0.18)
	tween.chain().tween_callback(feedback.queue_free)


func _show_purchase_feedback(button: Button, amount: int, texture: Texture2D) -> void:
	var feedback := HBoxContainer.new()
	feedback.name = "PurchaseFeedback"
	feedback.alignment = BoxContainer.ALIGNMENT_CENTER
	feedback.add_theme_constant_override("separation", 3)
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback.z_index = 70
	add_child(feedback)
	feedback.add_child(_make_feedback_copy("+%d" % amount))
	var icon := _make_icon(texture, Vector2(22, 22))
	icon.name = "PurchasedIcon"
	feedback.add_child(icon)
	feedback.add_child(_make_feedback_copy("!"))
	feedback.size = feedback.get_combined_minimum_size()
	feedback.global_position = button.get_global_rect().get_center() - Vector2(feedback.size.x * 0.5, 10)
	var tween := feedback.create_tween().set_parallel(true)
	tween.tween_property(feedback, "position:y", feedback.position.y - 24.0, 0.55)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.55).set_delay(0.18)
	tween.chain().tween_callback(feedback.queue_free)


func _make_feedback_copy(copy: String) -> Label:
	var label := Label.new()
	label.text = copy
	label.add_theme_color_override("font_color", Color("ffe082"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _spawn_flying_icon(texture: Texture2D, start: Vector2, target: Vector2, duration: float) -> void:
	if texture == null:
		return
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(24, 24)
	icon.size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.z_index = 65
	add_child(icon)
	icon.global_position = start - icon.size * 0.5
	icon.pivot_offset = icon.size * 0.5
	var tween := icon.create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(icon, "global_position", target - icon.size * 0.5, duration)
	tween.tween_property(icon, "scale", Vector2(0.55, 0.55), duration)
	tween.tween_property(icon, "modulate:a", 0.0, duration).set_delay(duration * 0.65)
	tween.chain().tween_callback(icon.queue_free)


func _get_benefit_target(resource_id: StringName, upgrade_index: int) -> Vector2:
	var hud := get_parent()
	if not resource_id.is_empty():
		var resource_panel := hud.get_node_or_null("ResourcePanel") as ResourcePanel
		if resource_panel:
			return resource_panel.get_resource_target_screen_position(resource_id)
	var upgrade: Dictionary = _get_upgrades()[upgrade_index] if upgrade_index >= 0 else {}
	var stat := StringName(upgrade.get("stat", &""))
	var color_index := int(upgrade.get("color", FoxPlayer.COLOR_RED))
	if stat == &"damage":
		var damage_grid := hud.get_node_or_null("DamageGrid") as DamageGrid
		if damage_grid:
			return damage_grid.get_color_target_screen_position(color_index)
	if stat == &"defense":
		var armor_grid = hud.get_node_or_null("ArmorGrid")
		if armor_grid:
			return armor_grid.get_color_target_screen_position(color_index)
	if stat == &"item":
		var inventory := hud.get_node_or_null("Inventory") as Control
		if inventory:
			return inventory.get_global_rect().get_center()
	var vitals := hud.get_node_or_null("PlayerVitals") as Control
	if vitals:
		var cell_name := "RegenerationCell" if stat == &"regeneration" else "HealthCell"
		var cell := vitals.find_child(cell_name, true, false) as Control
		if cell:
			return cell.get_global_rect().get_center()
	return Vector2(48, 48)


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
	title.text = _get_shop_title()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("ffe082"))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 2)
	title_row.add_child(title)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.tooltip_text = "Close the Store."
	close_button.custom_minimum_size = Vector2(28, 26)
	close_button.pressed.connect(close)
	title_row.add_child(close_button)
	content.add_child(HSeparator.new())
	for offer in _get_resource_offers():
		var resource_id := StringName(offer["resource_id"])
		var purchase_row := _make_resource_purchase_button(resource_id)
		_resource_purchase_rows[resource_id] = purchase_row
		content.add_child(purchase_row)
	content.add_child(HSeparator.new())
	for index in range(_get_upgrades().size()):
		var row := _make_upgrade_button(index)
		_rows.append(row)
		content.add_child(row)


func _make_upgrade_button(upgrade_index: int) -> Button:
	var upgrade: Dictionary = _get_upgrades()[upgrade_index]
	var button := Button.new()
	button.custom_minimum_size = Vector2(310, 40)
	button.set_meta("upgrade_index", upgrade_index)
	var description := str(upgrade["description"])
	if StringName(upgrade["stat"]) == &"regeneration":
		description = "Increase passive health regeneration by %s." % FoxPlayer.format_regeneration_value(
			FoxPlayer.get_healing_increase_per_second(int(upgrade["amount"]))
		)
	button.tooltip_text = ""
	_set_shop_button_style(button)
	_connect_shop_tooltip(button, "", description)
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
	var offer_icon := _make_icon(upgrade["stat_icon"] as Texture2D, Vector2(24, 24))
	offer_icon.name = "OfferIcon"
	row.add_child(offer_icon)
	if StringName(upgrade["stat"]) == &"damage" or StringName(upgrade["stat"]) == &"defense":
		var damage_dot := Panel.new()
		damage_dot.name = "DefenseColorDot" if StringName(upgrade["stat"]) == &"defense" else "DamageColorDot"
		damage_dot.custom_minimum_size = Vector2(10, 10)
		damage_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dot_style := StyleBoxFlat.new()
		var colors := [Color("e53935"), Color("fbc02d"), Color("1976d2")]
		dot_style.bg_color = colors[int(upgrade.get("color", FoxPlayer.COLOR_RED))]
		dot_style.border_color = Color.BLACK
		dot_style.set_border_width_all(1)
		dot_style.set_corner_radius_all(5)
		damage_dot.add_theme_stylebox_override("panel", dot_style)
		row.add_child(damage_dot)
	var amount := Label.new()
	amount.text = str(upgrade["display_amount"]) if upgrade.has("display_amount") else \
		"+%s" % FoxPlayer.format_regeneration_value(FoxPlayer.get_healing_increase_per_second(int(upgrade["amount"]))) \
		if StringName(upgrade["stat"]) == &"regeneration" else "+%d" % int(upgrade["amount"])
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


func _make_resource_purchase_button(resource_id: StringName) -> Button:
	var offer := _get_resource_offer(resource_id)
	var cost_resource_id := StringName(offer["cost_resource_id"])
	var price := int(offer["price"])
	var button := Button.new()
	button.name = "Buy%s" % str(resource_id).capitalize().replace(" ", "")
	button.set_meta("resource_id", resource_id)
	button.custom_minimum_size = Vector2(310, 40)
	button.tooltip_text = ""
	_set_shop_button_style(button)
	var cost_definition := _resource_manager.get_definition(cost_resource_id) if _resource_manager else null
	_connect_shop_tooltip(button, "Buy %s" % str(resource_id).capitalize(), "")
	button.pressed.connect(buy_resource.bind(resource_id))
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
	var definition := _resource_manager.get_definition(resource_id) if _resource_manager else null
	var resource_icon := _make_icon(definition.icon if definition else null, Vector2(24, 24))
	resource_icon.name = "ResourceIcon"
	resource_icon.set_meta("shop_offer_icon", true)
	row.add_child(resource_icon)
	var amount := Label.new()
	amount.text = "+1 %s" % (definition.display_name if definition else str(resource_id).capitalize())
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
	var price_icon := _make_icon(cost_definition.icon if cost_definition else null, Vector2(22, 22))
	price_icon.name = "GoldIcon" if cost_resource_id == &"gold_ore" else "PriceIcon"
	row.add_child(price_icon)
	var price_amount := Label.new()
	price_amount.name = "PriceAmount"
	price_amount.text = str(price)
	price_amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	if _resource_manager == null or _shopkeeper == null:
		return
	for offer in _get_resource_offers():
		var resource_id := StringName(offer["resource_id"])
		var cost_resource_id := StringName(offer["cost_resource_id"])
		var price := int(offer["price"])
		var purchase_button := _resource_purchase_rows.get(resource_id) as Button
		if purchase_button:
			var definition := _resource_manager.get_definition(resource_id)
			var resource_icon := purchase_button.find_child("ResourceIcon", true, false) as TextureRect
			var price_icon := purchase_button.find_child("PriceIcon", true, false) as TextureRect
			if price_icon == null:
				price_icon = purchase_button.find_child("GoldIcon", true, false) as TextureRect
			if resource_icon:
				resource_icon.texture = definition.icon if definition else null
			if price_icon:
				var cost_definition := _resource_manager.get_definition(cost_resource_id)
				price_icon.texture = cost_definition.icon if cost_definition else null
			var at_capacity := _resource_manager.get_amount(resource_id) >= _resource_manager.get_maximum_amount(resource_id)
			var can_afford := _resource_manager.can_afford({cost_resource_id: price}) and not at_capacity
			purchase_button.disabled = false
			var purchase_price := purchase_button.find_child("PriceAmount", true, false) as Label
			if purchase_price:
				purchase_price.add_theme_color_override("font_color", Color.WHITE if can_afford else Color("ef5350"))
	var upgrades := _get_upgrades()
	for index in range(upgrades.size()):
		var resource_id := StringName(upgrades[index]["resource_id"])
		var definition := _resource_manager.get_definition(resource_id)
		_rows[index].visible = bool(upgrades[index].get("visible_by_default", false)) or index == 0 or _resource_manager.has_ever_owned(resource_id)
		_price_icons[index].texture = definition.icon if definition else null
		var price := get_upgrade_price(index)
		_price_labels[index].text = str(price)
		var can_afford := _resource_manager.can_afford({resource_id: price})
		_price_labels[index].add_theme_color_override("font_color", Color.WHITE if can_afford else Color("ef5350"))
		_rows[index].disabled = false


func _connect_shop_tooltip(button: Button, title: String, description: String) -> void:
	button.mouse_entered.connect(_show_shop_tooltip.bind(button, title, description))
	button.mouse_exited.connect(_hide_shop_tooltip)
	button.mouse_entered.connect(_animate_shop_hover.bind(button, true))
	button.mouse_exited.connect(_animate_shop_hover.bind(button, false))


func _show_shop_tooltip(button: Button, title: String, description: String) -> void:
	var tooltip := get_tree().get_first_node_in_group("item_tooltip") as ItemTooltip
	if tooltip == null:
		return
	if button.has_meta("resource_id"):
		description = ""
	elif button.has_meta("upgrade_index"):
		title = ""
	var icon := button.find_child("OfferIcon", true, false) as TextureRect
	if icon == null:
		icon = button.find_child("ResourceIcon", true, false) as TextureRect
	tooltip.show_description(icon.texture if icon else null, title, description)


func _animate_shop_hover(button: Button, hovered: bool) -> void:
	if button == null:
		return
	var key := button.get_instance_id()
	var previous := _hover_tweens.get(key) as Tween
	if previous and previous.is_valid():
		previous.kill()
	var content := button.get_child(0) as Control
	var icon := button.find_child("OfferIcon", true, false) as TextureRect
	if icon == null:
		icon = button.find_child("ResourceIcon", true, false) as TextureRect
	var tween := button.create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_hover_tweens[key] = tween
	if content:
		tween.tween_property(content, "position:x", 3.0 if hovered else 0.0, 0.10)
	if icon:
		icon.pivot_offset = icon.size * 0.5
		tween.tween_property(icon, "scale", Vector2(1.12, 1.12) if hovered else Vector2.ONE, 0.10)


func _hide_shop_tooltip() -> void:
	var tooltip := get_tree().get_first_node_in_group("item_tooltip") as ItemTooltip
	if tooltip:
		tooltip.hide_item()


func _set_shop_button_style(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("202630") if state == "normal" or state == "disabled" else Color("68561e") if state == "hover" else Color("3e3518")
		style.border_color = Color("444e60") if state == "normal" or state == "disabled" else Color("e9c64d")
		style.set_border_width_all(1 if state == "normal" or state == "disabled" else 2)
		style.set_corner_radius_all(4)
		button.add_theme_stylebox_override(state, style)


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
