class_name CommerceHub
extends Control

const BAZAAR_ICON := preload("res://Sprites/iconScale.webp")
const BUILDINGS_ICON := preload("res://Sprites/iconHouse.webp")
const DAMAGE_ICON := preload("res://Sprites/DamageIcon.webp")
const DEFENSE_ICON := preload("res://Sprites/ShieldIcon.webp")
const HEALTH_ICON := preload("res://Sprites/Heart.webp")
const BUTTON_SIZE := Vector2(44, 44)
const BUTTON_GAP := 8.0
const SHOP_HOVER_TILES := 2
const BUILDINGS_PANEL_SIZE := Vector2(960, 560)
const BUILDING_CARD_SIZE := Vector2(210, 170)

var _world: WorldNavigation
var _player: FoxPlayer
var _resources: ResourceManager
var _bazaar_button: Button
var _buildings_button: Button
var _bazaar_overlay: Control
var _bazaar_grid: GridContainer
var _buildings_overlay: Control
var _buildings_grid: GridContainer
var _shop_hover: PanelContainer
var _shop_hover_content: VBoxContainer
var _hovered_shop_id := ""
var _hovered_shop_signature := ""
var _retired_sources: Dictionary = {}
var _discovered_buildings: Dictionary = {}
var _initialized := false
var _previous_interaction_locked := false
var _button_pulse_tweens: Dictionary = {}


func _ready() -> void:
	add_to_group("commerce_hub")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 800
	_world = get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	_player = get_tree().get_first_node_in_group("player") as FoxPlayer
	_resources = get_tree().get_first_node_in_group("resource_manager") as ResourceManager
	_build_buttons()
	_bazaar_overlay = _build_overlay("Bazaar", true)
	_bazaar_grid = _bazaar_overlay.find_child("EntryGrid", true, false) as GridContainer
	_buildings_overlay = _build_overlay("Buildings", false)
	_buildings_grid = _buildings_overlay.find_child("EntryGrid", true, false) as GridContainer
	_build_shop_hover()
	call_deferred("_finish_initialization")


func _finish_initialization() -> void:
	if _world == null:
		_world = get_parent().get_parent() as WorldNavigation
	if _player == null and _world:
		_player = _world.player
	if _resources == null:
		_resources = get_tree().get_first_node_in_group("resource_manager") as ResourceManager
	_initialized = true
	_sync_retired_shops(false)
	_rehydrate_discovered_buildings()


func _process(_delta: float) -> void:
	if _world == null:
		_world = get_parent().get_parent() as WorldNavigation
		if _world:
			_player = _world.player
	_position_buttons()
	_sync_retired_shops(_initialized)
	_discover_visible_buildings()


func _build_buttons() -> void:
	_bazaar_button = _make_header_button("BazaarButton", "Bazaar", BAZAAR_ICON)
	_bazaar_button.pressed.connect(_open_bazaar)
	_bazaar_button.hide()
	add_child(_bazaar_button)
	_buildings_button = _make_header_button("BuildingsButton", "Buildings", BUILDINGS_ICON)
	_buildings_button.pressed.connect(_open_buildings)
	_buildings_button.hide()
	add_child(_buildings_button)


func _make_header_button(button_name: String, hint: String, texture: Texture2D) -> Button:
	var button := Button.new()
	button.name = button_name
	button.tooltip_text = hint
	button.size = BUTTON_SIZE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("242938")
	normal.border_color = Color("aeb8cc")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("343b50")
	hover.border_color = Color.WHITE
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("171b26")
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.position = Vector2(6, 6)
	icon.size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	return button


func _position_buttons() -> void:
	var quest_log := get_parent().get_node_or_null("QuestLog") as QuestLog
	if quest_log == null or not is_instance_valid(quest_log._button):
		return
	var cursor_x := quest_log._button.global_position.x - BUTTON_GAP
	if _bazaar_button.visible:
		cursor_x -= BUTTON_SIZE.x
		_bazaar_button.global_position = Vector2(cursor_x, quest_log._button.global_position.y)
		cursor_x -= BUTTON_GAP
	if _buildings_button.visible:
		cursor_x -= BUTTON_SIZE.x
		_buildings_button.global_position = Vector2(cursor_x, quest_log._button.global_position.y)


func _build_overlay(title_text: String, is_bazaar: bool) -> Control:
	var overlay := Control.new()
	overlay.name = "%sOverlay" % title_text
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.hide()
	add_child(overlay)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.62)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_overlay_backdrop_input.bind(overlay))
	overlay.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "%sPanel" % title_text
	panel.custom_minimum_size = Vector2(500, 330) if is_bazaar else BUILDINGS_PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			panel.accept_event()
	)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("242938")
	style.border_color = Color("77819a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	header.add_child(title)
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(38, 38)
	close.pressed.connect(_close_overlay.bind(overlay))
	header.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "EntryGrid"
	grid.columns = 7 if is_bazaar else 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	return overlay


func _build_shop_hover() -> void:
	_shop_hover = PanelContainer.new()
	_shop_hover.name = "ShopAreaPopup"
	_shop_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_hover.z_index = 760
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.96)
	style.border_color = Color("e9c64d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	_shop_hover.add_theme_stylebox_override("panel", style)
	_shop_hover_content = VBoxContainer.new()
	_shop_hover_content.add_theme_constant_override("separation", 3)
	_shop_hover.add_child(_shop_hover_content)
	_shop_hover.hide()
	add_child(_shop_hover)


func is_active_shop(npc: FoxAsha) -> bool:
	return is_instance_valid(npc) and _is_active_shop(npc)


func show_map_shop_popup(hovered: FoxAsha, screen_position: Vector2) -> void:
	if not is_instance_valid(hovered) or not _is_active_shop(hovered) or _bazaar_overlay.visible or _buildings_overlay.visible:
		hide_map_shop_popup()
		return
	var entries := _catalog_for(hovered)
	var signature := str(hovered.get_instance_id()) + JSON.stringify(_catalog_signature(entries))
	if _hovered_shop_signature != signature:
		_hovered_shop_signature = signature
		_hovered_shop_id = str(hovered.name)
		_rebuild_shop_hover(_shop_title(hovered), entries)
	_shop_hover.show()
	_shop_hover.reset_size()
	var desired := screen_position + Vector2(18, 18)
	_shop_hover.position = Vector2(
		clampf(desired.x, 0.0, maxf(0.0, get_viewport_rect().size.x - _shop_hover.size.x)),
		clampf(desired.y, 0.0, maxf(0.0, get_viewport_rect().size.y - _shop_hover.size.y))
	)


func hide_map_shop_popup() -> void:
	_hovered_shop_id = ""
	_hovered_shop_signature = ""
	if is_instance_valid(_shop_hover):
		_shop_hover.hide()


func _catalog_signature(entries: Array[Dictionary]) -> Array:
	var signature: Array = []
	for entry in entries:
		signature.append([entry.get("name", ""), entry.get("price", 0), entry.get("cost_id", "")])
	return signature


func _rebuild_shop_hover(title_text: String, entries: Array[Dictionary]) -> void:
	_clear_children(_shop_hover_content)
	var title := Label.new()
	title.text = title_text
	title.add_theme_color_override("font_color", Color("ffe082"))
	_shop_hover_content.add_child(title)
	for entry in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		_shop_hover_content.add_child(row)
		var item_icon := _make_small_icon(entry.get("icon") as Texture2D, 20)
		var item_id := str(entry.get("item_id", ""))
		if not item_id.is_empty():
			item_icon.modulate = ItemPickup.get_icon_modulate(item_id)
		row.add_child(item_icon)
		var label := Label.new()
		label.text = str(entry.get("name", ""))
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(label)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		var cost_id := StringName(entry.get("cost_id", &""))
		var definition := _resources.get_definition(cost_id) if _resources else null
		row.add_child(_make_small_icon(definition.icon if definition else null, 16))
		var price := Label.new()
		price.text = str(int(entry.get("price", 0)))
		price.add_theme_color_override("font_color", Color("ffe082"))
		row.add_child(price)


func _sync_retired_shops(animate: bool) -> void:
	for source_name in ["FoxAsha", "FoxLio", "FoxDeru"]:
		var npc := _world.get_node_or_null(source_name) as FoxAsha if _world else null
		if npc == null or not _has_shop_retired(npc) or bool(_retired_sources.get(source_name, false)):
			continue
		_retired_sources[source_name] = true
		_bazaar_button.show()
		_rebuild_bazaar()
		if animate:
			_fly_dot(_world.get_canvas_transform() * npc.global_position, _bazaar_button, Color("45d66b"), "BazaarArrivalDot")
	_bazaar_button.visible = not _retired_sources.is_empty()


func _has_shop_retired(npc: FoxAsha) -> bool:
	if npc is FoxDeru:
		return _player != null and _player.unlocked_player_skills.has(FoxPlayer.SKILL_BULWARK)
	if npc is FoxLio:
		return (npc as FoxLio).is_hunter_recruited()
	if npc is FoxLuca:
		return false
	return npc.is_recruited()


func _is_active_shop(npc: FoxAsha) -> bool:
	if _has_shop_retired(npc):
		return false
	if npc is FoxDeru:
		return _player != null and _player.has_unlocked_player_skill()
	if npc is FoxLio:
		return not (npc as FoxLio).is_hunter_recruited()
	if npc is FoxLuca:
		return true
	return not npc.is_recruited()


func _catalog_for(npc: FoxAsha) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var upgrades := _shop_upgrades(npc)
	for index in range(upgrades.size()):
		var upgrade := upgrades[index] as Dictionary
		if not _upgrade_available(npc, index, upgrade):
			continue
		var cost_id := StringName(upgrade.get("cost_resource_id", upgrade.get("resource_id", &"")))
		var purchase_slot := int(upgrade.get("purchase_slot", index))
		var purchases := npc.purchase_counts[purchase_slot] if purchase_slot < npc.purchase_counts.size() else 0
		var price := int(upgrade.get("base_price", 0)) if StringName(upgrade.get("stat", &"")) == &"item" else int(upgrade.get("base_price", 0)) * (purchases + 1)
		entries.append({
			"kind": "upgrade", "index": index, "source": str(npc.name),
			"name": str(upgrade.get("name", "Item")), "icon": upgrade.get("stat_icon"),
			"item_id": str(upgrade.get("item_id", "")), "price": price, "cost_id": cost_id,
			"stat": upgrade.get("stat", &""), "amount": upgrade.get("amount", 0),
			"color": upgrade.get("color", FoxPlayer.COLOR_RED), "description": upgrade.get("description", ""),
		})
	for offer in _shop_resource_offers(npc):
		var resource_id := StringName(offer.get("resource_id", &""))
		var definition := _resources.get_definition(resource_id) if _resources else null
		entries.append({
			"kind": "resource", "resource_id": resource_id, "source": str(npc.name),
			"name": definition.display_name if definition else str(resource_id).capitalize(),
			"icon": definition.icon if definition else null, "price": int(offer.get("price", 0)),
			"cost_id": StringName(offer.get("cost_resource_id", &"gold_ore")),
		})
	return entries


func _upgrade_available(npc: FoxAsha, index: int, upgrade: Dictionary) -> bool:
	var stat := StringName(upgrade.get("stat", &""))
	if stat == &"auto_fight":
		return _player == null or not _player.auto_fight_unlocked
	if stat == &"auto_fight_range":
		return _player != null and _player.auto_fight_unlocked and _player.auto_fight_range_bonus < int(upgrade.get("amount", 1))
	if stat == &"skill":
		return _player != null and _player.has_unlocked_player_skill() and not _player.unlocked_player_skills.has(StringName(upgrade.get("skill_id", &"")))
	if bool(upgrade.get("one_time", false)):
		var purchase_slot := int(upgrade.get("purchase_slot", index))
		return purchase_slot >= npc.purchase_counts.size() or npc.purchase_counts[purchase_slot] == 0
	var item_id := str(upgrade.get("item_id", ""))
	if item_id == "spare_cart_parts":
		var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
		return story != null and story.is_deru_quest_started() and not story.are_spare_parts_purchased()
	return true


func _shop_upgrades(npc: FoxAsha) -> Array:
	if npc is FoxDeru:
		return FoxDeruShop.DERU_UPGRADES
	if npc is FoxLuca:
		return FoxLucaShop.LUCA_UPGRADES
	if npc is FoxLio:
		return FoxLioShop.LIO_UPGRADES
	return FoxShop.UPGRADES


func _shop_resource_offers(npc: FoxAsha) -> Array:
	if npc is FoxDeru:
		return []
	if npc is FoxLuca:
		return [{"resource_id": &"fish", "cost_resource_id": &"jewels", "price": 2}, {"resource_id": &"jewels", "cost_resource_id": &"gold_ore", "price": 5}]
	if npc is FoxLio:
		return [{"resource_id": &"gold_ore", "cost_resource_id": &"fish", "price": 2}]
	return [{"resource_id": &"fish", "cost_resource_id": &"gold_ore", "price": FoxShop.RESOURCE_PURCHASE_PRICE}, {"resource_id": &"wood", "cost_resource_id": &"gold_ore", "price": FoxShop.RESOURCE_PURCHASE_PRICE}]


func _shop_title(npc: FoxAsha) -> String:
	if npc is FoxDeru:
		return "Deru's Store"
	if npc is FoxLuca:
		return "Lucie's Store"
	if npc is FoxLio:
		return "Lios Shop"
	return "Asha's Store"


func _open_bazaar() -> void:
	_rebuild_bazaar()
	_open_overlay(_bazaar_overlay)


func _rebuild_bazaar() -> void:
	if not is_instance_valid(_bazaar_grid):
		return
	_clear_children(_bazaar_grid)
	var entries: Array[Dictionary] = []
	for source_name in _retired_sources:
		var npc := _world.get_node_or_null(str(source_name)) as FoxAsha if _world else null
		if npc == null:
			continue
		for entry in _catalog_for(npc):
			entries.append(entry)
	entries.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_resource := StringName(first.get("cost_id", &""))
		var second_resource := StringName(second.get("cost_id", &""))
		var first_order := _resource_sort_index(first_resource)
		var second_order := _resource_sort_index(second_resource)
		if first_order != second_order:
			return first_order < second_order
		var first_price := int(first.get("price", 0))
		var second_price := int(second.get("price", 0))
		if first_price != second_price:
			return first_price < second_price
		return str(first.get("name", "")) < str(second.get("name", ""))
	)
	for entry in entries:
		_add_catalog_icon(_bazaar_grid, entry, true)


func _resource_sort_index(resource_id: StringName) -> int:
	if _resources:
		var definitions := _resources.get_definitions()
		for index in range(definitions.size()):
			if definitions[index].resource_id == resource_id:
				return index
	return 1000


func _add_catalog_icon(grid: GridContainer, entry: Dictionary, purchasable: bool) -> void:
	var card: VBoxContainer
	if not purchasable:
		card = VBoxContainer.new()
		card.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_theme_constant_override("separation", 3)
		grid.add_child(card)
	var button := Button.new()
	button.set_meta("catalog_entry", entry)
	button.custom_minimum_size = Vector2(54, 54)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if purchasable else Control.CURSOR_ARROW
	var style := StyleBoxFlat.new()
	style.bg_color = Color("192236")
	style.border_color = Color.BLACK
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.border_color = Color("e9c64d")
	button.add_theme_stylebox_override("hover", hover)
	var icon := TextureRect.new()
	icon.texture = entry.get("icon") as Texture2D
	icon.position = Vector2(7, 7)
	icon.size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var item_id := str(entry.get("item_id", ""))
	if not item_id.is_empty():
		icon.modulate = ItemPickup.get_icon_modulate(item_id)
	button.add_child(icon)
	if purchasable:
		var cost_id := StringName(entry.get("cost_id", &""))
		var cost_definition := _resources.get_definition(cost_id) if _resources else null
		var cost_badge := HBoxContainer.new()
		cost_badge.name = "CostBadge"
		cost_badge.position = Vector2(2, 34)
		cost_badge.size = Vector2(50, 18)
		cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_badge.add_theme_constant_override("separation", 1)
		button.add_child(cost_badge)
		var cost_icon := _make_small_icon(cost_definition.icon if cost_definition else null, 16)
		cost_icon.name = "CostIcon"
		cost_badge.add_child(cost_icon)
		var cost_label := Label.new()
		cost_label.name = "CostAmount"
		cost_label.text = str(int(entry.get("price", 0)))
		cost_label.add_theme_font_size_override("font_size", 14)
		cost_label.add_theme_color_override("font_color", Color.WHITE)
		cost_label.add_theme_color_override("font_outline_color", Color.BLACK)
		cost_label.add_theme_constant_override("outline_size", 2)
		cost_badge.add_child(cost_label)
	if purchasable:
		button.mouse_entered.connect(_show_catalog_tooltip.bind(entry))
	button.mouse_exited.connect(_hide_item_tooltip)
	if purchasable:
		button.pressed.connect(_buy_bazaar_entry.bind(entry))
	if purchasable:
		grid.add_child(button)
	else:
		card.add_child(button)
		var price := Label.new()
		price.text = str(entry.get("price_text", ""))
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.add_theme_font_size_override("font_size", 12)
		price.add_theme_color_override("font_color", Color.WHITE)
		card.add_child(price)


func _show_catalog_tooltip(entry: Dictionary) -> void:
	var tooltip := get_tree().get_first_node_in_group("item_tooltip") as ItemTooltip
	if tooltip:
		var item_id := str(entry.get("item_id", ""))
		var rows: Array[Dictionary] = []
		var stat := StringName(entry.get("stat", &""))
		var amount := int(entry.get("amount", 0))
		var color_index := int(entry.get("color", FoxPlayer.COLOR_RED))
		if str(entry.get("kind", "")) == "resource":
			var resource_id := StringName(entry.get("resource_id", &""))
			var resource_definition := _resources.get_definition(resource_id) if _resources else null
			rows.append({"icon": resource_definition.icon if resource_definition else null, "text": "+1 %s" % _resource_name(resource_id), "color": Color("63d471")})
		elif not item_id.is_empty() and ItemPickup.is_equipment(item_id):
			var preview := {"item_id": item_id, "grade": 0}
			var is_weapon := ItemPickup.is_weapon(item_id)
			rows.append({"icon": DAMAGE_ICON if is_weapon else DEFENSE_ICON, "text": "+%d %s %s" % [ItemPickup.get_damage_bonus(preview) if is_weapon else ItemPickup.get_block_amount(preview), _color_name(ItemPickup.get_stat_color(preview) if is_weapon else FoxPlayer.COLOR_RED), "Damage" if is_weapon else "Defence"], "color": _stat_color(ItemPickup.get_stat_color(preview) if is_weapon else FoxPlayer.COLOR_RED)})
			if not is_weapon:
				rows.append({"icon": DEFENSE_ICON, "text": "+%d Yellow Defence" % ItemPickup.get_block_amount(preview), "color": _stat_color(FoxPlayer.COLOR_YELLOW)})
		elif stat == &"damage":
			rows.append({"icon": DAMAGE_ICON, "text": "+%d %s Damage" % [amount, _color_name(color_index)], "color": _stat_color(color_index)})
		elif stat == &"health":
			rows.append({"icon": HEALTH_ICON, "text": "+%d Max Health" % amount, "color": Color("63d471")})
		elif stat == &"regeneration":
			rows.append({"icon": entry.get("icon") as Texture2D, "text": "+%s Regeneration" % str(entry.get("amount", 0)), "color": Color("63d471")})
		elif not str(entry.get("description", "")).is_empty():
			rows.append({"icon": entry.get("icon") as Texture2D, "text": str(entry.get("description", "")), "color": Color.WHITE})
		var cost_id := StringName(entry.get("cost_id", &""))
		var cost_definition := _resources.get_definition(cost_id) if _resources else null
		rows.append({"icon": cost_definition.icon if cost_definition else null, "text": "Price: %d %s" % [int(entry.get("price", 0)), _resource_name(cost_id)], "color": Color("ffe082")})
		tooltip.show_catalog(entry.get("icon") as Texture2D, str(entry.get("name", "")), rows, ItemPickup.get_icon_modulate(item_id) if not item_id.is_empty() else Color.WHITE)


func _stat_color(color_index: int) -> Color:
	return [Color("e53935"), Color("fbc02d"), Color("1976d2")][clampi(color_index, 0, 2)]


func _color_name(color_index: int) -> String:
	return ["Red", "Yellow", "Blue"][clampi(color_index, 0, 2)]


func _hide_item_tooltip() -> void:
	var tooltip := get_tree().get_first_node_in_group("item_tooltip") as ItemTooltip
	if tooltip:
		tooltip.hide_item()


func _buy_bazaar_entry(entry: Dictionary) -> void:
	var npc := _world.get_node_or_null(str(entry.get("source", ""))) as FoxAsha if _world else null
	if npc == null:
		return
	var shop := _ensure_shop(npc)
	if shop == null:
		return
	if str(entry.get("kind", "")) == "resource":
		shop.buy_resource(StringName(entry.get("resource_id", &"")))
	else:
		shop.buy_upgrade(int(entry.get("index", -1)))
	_rebuild_bazaar()


func _ensure_shop(npc: FoxAsha) -> FoxShop:
	if is_instance_valid(npc._shop):
		return npc._shop
	var shop: FoxShop
	if npc is FoxDeru:
		shop = FoxDeruShop.new()
	elif npc is FoxLuca:
		shop = FoxLucaShop.new()
	elif npc is FoxLio:
		shop = FoxLioShop.new()
	else:
		shop = FoxShop.new()
	npc._shop = shop
	get_parent().add_child(shop)
	shop.setup(npc)
	return shop


func _discover_visible_buildings() -> void:
	for raw_ore in get_tree().get_nodes_in_group("gold_ores"):
		if not raw_ore is GoldOre:
			continue
		var ore := raw_ore as GoldOre
		if ore.build_button.visible and not is_instance_valid(ore._mine):
			_discover_building(_building_key(ore, false), ore, false, true)
		if not ore._shack_buttons.is_empty():
			_discover_building(_building_key(ore, true), ore, true, true)


func _building_key(ore: GoldOre, capacity: bool) -> String:
	return "%s:%s" % [str(ore.mined_resource_id), "capacity" if capacity else "producer"]


func _discover_building(key: String, ore: GoldOre, capacity: bool, animate: bool) -> void:
	if bool(_discovered_buildings.get(key, false)):
		return
	_discovered_buildings[key] = true
	_buildings_button.show()
	_rebuild_buildings()
	if animate:
		var start := _world.get_canvas_transform() * ore.global_position
		if capacity and not ore._shack_buttons.is_empty() and is_instance_valid(ore._shack_buttons[0]):
			start = (ore._shack_buttons[0] as Button).get_global_rect().get_center()
		elif not capacity and is_instance_valid(ore.build_button):
			start = ore.build_button.get_global_rect().get_center()
		_fly_dot(start, _buildings_button, Color("ef4444"), "BuildingDiscoveryDot")


func _rehydrate_discovered_buildings() -> void:
	_buildings_button.visible = not _discovered_buildings.is_empty()
	_rebuild_buildings()


func _open_buildings() -> void:
	_rebuild_buildings()
	_open_overlay(_buildings_overlay)


func _rebuild_buildings() -> void:
	if not is_instance_valid(_buildings_grid):
		return
	_clear_children(_buildings_grid)
	for key in _discovered_buildings:
		var entry := _building_entry(str(key))
		if not entry.is_empty():
			_add_building_card(_buildings_grid, entry)


func _building_entry(key: String) -> Dictionary:
	var parts := key.split(":")
	if parts.size() != 2:
		return {}
	var capacity := parts[1] == "capacity"
	for raw_ore in get_tree().get_nodes_in_group("gold_ores"):
		if raw_ore is GoldOre and str((raw_ore as GoldOre).mined_resource_id) == parts[0]:
			var ore := raw_ore as GoldOre
			var cost := ore.get_current_shack_cost() if capacity else ore.get_current_build_cost()
			var built_count := _count_built_buildings(ore.mined_resource_id, capacity)
			var resource_name := _resource_name(ore.mined_resource_id)
			var minutes_per_resource := 1.0 / maxf(ore.mine_production_speed * 60.0, 0.00001)
			var minute_text := str(roundi(minutes_per_resource)) if is_equal_approx(minutes_per_resource, roundf(minutes_per_resource)) else "%.1f" % minutes_per_resource
			var effect_text := ""
			if built_count > 0:
				effect_text = "Capacity: +%d %s" % [10 if ore.mined_resource_id == &"jewels" else GoldShack.GOLD_CAPACITY_BONUS, resource_name] if capacity else "Production: +1 %s every %s min" % [resource_name, minute_text]
			var authored_name := ore.capacity_build_label if capacity else ore.mine_build_label
			var deposit_icon: Texture2D
			if not capacity and ore.mined_resource_id in [&"gold_ore", &"jewels"]:
				var deposit_sprite := ore.get_node_or_null("Sprite2D") as Sprite2D
				deposit_icon = deposit_sprite.texture if deposit_sprite else null
			return {
				"name": authored_name.trim_prefix("Build "),
				"icon": ore.shack_icon if capacity else ore.mine_icon,
				"deposit_icon": deposit_icon,
				"price": _cost_total(cost),
				"cost_id": &"mixed",
				"price_text": _format_cost(cost),
				"cost": cost,
				"effect_text": effect_text,
				"built_count": built_count,
				"resource_id": ore.mined_resource_id,
			}
	return {}


func _count_built_buildings(resource_id: StringName, capacity: bool) -> int:
	var count := 0
	if capacity:
		for node in get_tree().get_nodes_in_group("buildings"):
			if node is GoldShack and is_instance_valid(node) and (node as GoldShack).resource_id == resource_id:
				count += 1
	else:
		for node in get_tree().get_nodes_in_group("gold_ores"):
			if node is GoldOre and is_instance_valid(node) and (node as GoldOre).mined_resource_id == resource_id and is_instance_valid((node as GoldOre)._mine):
				count += 1
	return count


func _add_building_card(grid: GridContainer, entry: Dictionary) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = BUILDING_CARD_SIZE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var style := StyleBoxFlat.new()
	style.bg_color = Color("192236")
	style.border_color = Color.BLACK
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	card.add_theme_stylebox_override("panel", style)
	grid.add_child(card)
	var content := VBoxContainer.new()
	content.clip_contents = true
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 4)
	card.add_child(content)
	var icon_row := HBoxContainer.new()
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_row.custom_minimum_size.y = 58
	icon_row.add_theme_constant_override("separation", 3)
	content.add_child(icon_row)
	var icon := TextureRect.new()
	icon.name = "BuildingIcon"
	icon.texture = entry.get("icon") as Texture2D
	icon.custom_minimum_size = Vector2(58, 58)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var deposit_texture := entry.get("deposit_icon") as Texture2D
	if deposit_texture:
		var icon_stack := Control.new()
		icon_stack.name = "BuildingIconStack"
		icon_stack.custom_minimum_size = Vector2(58, 58)
		icon_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_row.add_child(icon_stack)
		var deposit_icon := TextureRect.new()
		deposit_icon.name = "DepositIcon"
		deposit_icon.texture = deposit_texture
		deposit_icon.position = Vector2(0, 5)
		deposit_icon.size = Vector2(58, 58)
		deposit_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		deposit_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		deposit_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		deposit_icon.z_index = 0
		icon_stack.add_child(deposit_icon)
		icon.position = Vector2(0, -5)
		icon.size = Vector2(58, 58)
		icon.z_index = 1
		icon_stack.add_child(icon)
	else:
		icon_row.add_child(icon)
	var built_amount := int(entry.get("built_count", 0))
	if built_amount > 0:
		var built_count := Label.new()
		built_count.name = "BuiltCount"
		built_count.text = "x%d" % built_amount
		built_count.custom_minimum_size = Vector2(28, 58)
		built_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		built_count.add_theme_font_size_override("font_size", 14)
		built_count.add_theme_color_override("font_color", Color.WHITE)
		built_count.add_theme_color_override("font_outline_color", Color.BLACK)
		built_count.add_theme_constant_override("outline_size", 2)
		icon_row.add_child(built_count)
	var name_label := Label.new()
	name_label.name = "BuildingName"
	name_label.text = str(entry.get("name", ""))
	name_label.clip_text = true
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color.WHITE)
	content.add_child(name_label)
	for row_data in _cost_rows(entry.get("cost", {}) as Dictionary):
		content.add_child(_make_detail_row(row_data))
	var effect_text := str(entry.get("effect_text", ""))
	if not effect_text.is_empty():
		var effect := Label.new()
		effect.name = "BuildingEffect"
		effect.text = effect_text
		effect.clip_text = true
		effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect.add_theme_font_size_override("font_size", 12)
		effect.add_theme_color_override("font_color", Color("63d471"))
		content.add_child(effect)


func _cost_rows(cost: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for raw_resource_id in cost:
		var resource_id := StringName(raw_resource_id)
		var definition := _resources.get_definition(resource_id) if _resources else null
		rows.append({"icon": definition.icon if definition else null, "text": str(int(cost[raw_resource_id])), "color": Color.WHITE})
	return rows


func _make_detail_row(row_data: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.add_child(_make_small_icon(row_data.get("icon") as Texture2D, 16))
	var label := Label.new()
	label.text = str(row_data.get("text", ""))
	label.custom_minimum_size.x = 24
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", row_data.get("color", Color.WHITE) as Color)
	row.add_child(label)
	return row


func _make_small_icon(texture: Texture2D, icon_size: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.size = Vector2(icon_size, icon_size)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _cost_total(cost: Dictionary) -> int:
	var result := 0
	for value in cost.values():
		result += int(value)
	return result


func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in cost:
		parts.append("%d %s" % [int(cost[resource_id]), _resource_name(StringName(resource_id))])
	return ", ".join(parts)


func _resource_name(resource_id: StringName) -> String:
	if resource_id == &"mixed":
		return "resources"
	var definition := _resources.get_definition(resource_id) if _resources else null
	return definition.display_name if definition else str(resource_id).capitalize()


func _fly_dot(start: Vector2, target: Control, color: Color, dot_name: String) -> void:
	if not is_instance_valid(target):
		return
	_position_buttons()
	var dot := Panel.new()
	dot.name = dot_name
	dot.size = Vector2(14, 14)
	dot.pivot_offset = dot.size * 0.5
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.z_index = 900
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.darkened(0.65)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	dot.add_theme_stylebox_override("panel", style)
	add_child(dot)
	dot.global_position = start - dot.size * 0.5
	var destination := target.get_global_rect().get_center() - dot.size * 0.5
	var tween := dot.create_tween().set_parallel(true)
	tween.tween_property(dot, "global_position", destination, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(dot, "scale", Vector2(0.3, 0.3), 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		dot.queue_free()
		_pulse_header_button(target)
	)


func _pulse_header_button(button: Control) -> void:
	if not is_instance_valid(button):
		return
	var old_tween := _button_pulse_tweens.get(button) as Tween
	if old_tween and old_tween.is_valid():
		old_tween.kill()
	button.scale = Vector2.ONE
	button.pivot_offset = button.size * 0.5
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_button_pulse_tweens[button] = tween
	tween.tween_property(button, "scale", Vector2(1.18, 1.18), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func() -> void:
		if is_instance_valid(button):
			button.scale = Vector2.ONE
		if _button_pulse_tweens.get(button) == tween:
			_button_pulse_tweens.erase(button)
	)


func _open_overlay(overlay: Control) -> void:
	var other := _buildings_overlay if overlay == _bazaar_overlay else _bazaar_overlay
	if not _bazaar_overlay.visible and not _buildings_overlay.visible and _world:
		_previous_interaction_locked = _world.interaction_locked
	other.hide()
	overlay.show()
	overlay.move_to_front()
	_hide_item_tooltip()
	if _world:
		_world.interaction_locked = true


func _close_overlay(overlay: Control) -> void:
	overlay.hide()
	_hide_item_tooltip()
	if _world and not _bazaar_overlay.visible and not _buildings_overlay.visible:
		_world.interaction_locked = _previous_interaction_locked


func _on_overlay_backdrop_input(event: InputEvent, overlay: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_close_overlay(overlay)
		overlay.accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _bazaar_overlay.visible:
			_close_overlay(_bazaar_overlay)
			get_viewport().set_input_as_handled()
		elif _buildings_overlay.visible:
			_close_overlay(_buildings_overlay)
			get_viewport().set_input_as_handled()


func get_save_data() -> Array:
	return [_retired_sources.keys(), _discovered_buildings.keys()]


func load_save_data(data: Array) -> void:
	_retired_sources.clear()
	_discovered_buildings.clear()
	if data.size() > 0 and data[0] is Array:
		for source in data[0] as Array:
			_retired_sources[str(source)] = true
	if data.size() > 1 and data[1] is Array:
		for key in data[1] as Array:
			_discovered_buildings[str(key)] = true
	_bazaar_button.visible = not _retired_sources.is_empty()
	_rehydrate_discovered_buildings()
	_rebuild_bazaar()


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
