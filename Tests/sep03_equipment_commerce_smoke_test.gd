extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := (load("res://Scenes/world.tscn") as PackedScene).instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var player := world.player
	assert(player.inventory_slots.size() == 4, "New players must start with four inventory slots")

	var sword := ItemPickup.make_item("weathered_sword")
	var two_swords := ItemPickup.make_item("weathered_sword", 1)
	assert(ItemPickup.get_damage_bonus(sword) == 5 and ItemPickup.get_damage_bonus(two_swords) == 10)
	player.inventory_slots = [sword, two_swords, {}, {}]
	assert(player.merge_inventory_pair(0, 1))
	assert(ItemPickup.get_merge_amount(player.inventory_slots[1]) == 3)
	assert(ItemPickup.get_damage_bonus(player.inventory_slots[1]) == 15, "Every merged base item must add its base stat")

	var red_stone := ItemPickup.make_item("red_damage_stone")
	var two_red_stones := ItemPickup.make_item("red_damage_stone", 1)
	player.inventory_slots = [red_stone, two_red_stones, ItemPickup.make_item("blue_sword"), {}]
	assert(player.merge_inventory_pair(0, 1))
	assert(ItemPickup.get_stone_bonus(player.inventory_slots[1]) == 6 and player.can_merge(red_stone, two_red_stones))
	player.equipped_weapons[0] = player.inventory_slots[2]
	player.inventory_slots[2] = {}
	assert(player.equip_stone("inventory", 1, "weapon", 0))
	assert(ItemPickup.get_equipped_stone(player.equipped_weapons[0]).get("item_id") == "red_damage_stone")
	assert(player.get_damage_for_color(FoxPlayer.COLOR_BLUE) == player.get_base_damage_for_color(FoxPlayer.COLOR_BLUE) + 20)
	assert(player.get_damage_for_color(FoxPlayer.COLOR_RED) == player.get_base_damage_for_color(FoxPlayer.COLOR_RED) + 6)
	player.inventory_slots[0] = ItemPickup.make_item("red_damage_stone")
	assert(player.is_stone_replacement_weaker("inventory", 0, "weapon", 0))
	var equipment_toolbar := world.get_node("HUD/EquipmentToolbar") as EquipmentToolbar
	equipment_toolbar.request_stone_equip("inventory", 0, "weapon", 0)
	await process_frame
	assert(is_instance_valid(equipment_toolbar._stone_confirmation), "A weaker replacement must ask for confirmation near the cursor")
	equipment_toolbar._close_stone_confirmation()

	var saved := player.get_save_data()
	player.equipped_weapons[0] = {}
	assert(player.load_save_data(saved, 0))
	assert(ItemPickup.get_stone_bonus(ItemPickup.get_equipped_stone(player.equipped_weapons[0])) == 6, "Equipped stones must survive save/load")

	var tooltip := world.get_node("HUD/ItemTooltip") as ItemTooltip
	tooltip.show_item(player.equipped_weapons[0])
	assert(tooltip._stone_slot.visible and tooltip._stone_icon.texture == ItemPickup.ITEM_TEXTURES["red_damage_stone"])
	var slot := ItemSlot.new()
	root.add_child(slot)
	slot.configure(null, "inventory", 0, player.equipped_weapons[0])
	assert(slot._stone_icon.visible and slot._stone_icon.size == Vector2(8, 8))
	slot.queue_free()

	var shop := FoxLucaShop.new()
	root.add_child(shop)
	await process_frame
	assert(shop._rows[7].find_child("PurchasableSlotFrame", true, false) != null, "Slot upgrades sold by shops need a rounded slot frame")
	shop.queue_free()
	for upgrades in [FoxShop.UPGRADES, FoxLucaShop.LUCA_UPGRADES, FoxLioShop.LIO_UPGRADES]:
		assert(not upgrades.any(func(upgrade: Dictionary) -> bool: return ItemPickup.is_stone(str(upgrade.get("item_id", "")))), "Stat stones must not be sold by any store")

	var hub := world.get_node("HUD/CommerceHub") as CommerceHub
	var asha := world.get_node("FoxAsha") as FoxAsha
	asha._recruited = true
	await process_frame
	assert(hub._bazaar_button.visible and hub._retired_sources.has("FoxAsha"))
	assert(hub._bazaar_grid.get_child_count() > 0, "A retired shop inventory must populate the Bazaar")
	var bazaar_button := hub._bazaar_grid.get_child(0) as Button
	var cost_badge := bazaar_button.get_node("CostBadge") as HBoxContainer
	assert((cost_badge.get_node("CostIcon") as TextureRect).custom_minimum_size == Vector2(16, 16) and (cost_badge.get_node("CostAmount") as Label).get_theme_font_size("font_size") == 14 and (cost_badge.get_node("CostAmount") as Label).get_theme_color("font_color") == Color.WHITE, "Bazaar items must show a 16x16 resource icon and readable white cost in their bottom-left corner")
	var previous_resource_order := -1
	var previous_price := -1
	for raw_button in hub._bazaar_grid.get_children():
		var sorted_entry := (raw_button as Button).get_meta("catalog_entry") as Dictionary
		var resource_order := hub._resource_sort_index(StringName(sorted_entry.get("cost_id", &"")))
		var price := int(sorted_entry.get("price", 0))
		assert(resource_order > previous_resource_order or resource_order == previous_resource_order and price >= previous_price, "Bazaar items must sort by cost resource and then price")
		if resource_order != previous_resource_order:
			previous_price = -1
		previous_resource_order = resource_order
		previous_price = price
	var bazaar_entry := hub._catalog_for(asha)[0] as Dictionary
	hub._show_catalog_tooltip(bazaar_entry)
	assert(tooltip._extra_rows.get_child_count() >= 2 and (tooltip._extra_rows.get_child(0).get_child(0) as TextureRect).texture != null, "Bazaar hover must show icon-led stat and price rows")
	hub._hide_item_tooltip()
	var luca := world.get_node("FoxLuca") as FoxLuca
	var map_canvas := (world.get_node("HUD/WorldMap") as WorldMap)._canvas
	world.load_exploration_save_data([])
	assert(not map_canvas._is_shop_spawn_explored(luca), "A shop spawn behind fog must not be hoverable on the map")
	var luca_home := luca._home_cell
	world.load_exploration_save_data([[[luca_home.x, luca_home.y]], [], false, true, true])
	assert(map_canvas._is_shop_spawn_explored(luca), "An explored shop spawn must become hoverable on the map")
	hub.show_map_shop_popup(luca, Vector2(200, 200))
	assert(hub._shop_hover.visible and hub._shop_hover_content.get_child_count() > 1, "Map shop hover must show the active shop catalog")
	var map_offer_row := hub._shop_hover_content.get_child(1) as HBoxContainer
	assert(map_offer_row.get_child(0) is TextureRect and map_offer_row.get_child(3) is TextureRect, "Map shop rows must use item and price-resource icons")
	hub.hide_map_shop_popup()
	var ore := world.get_node("GoldOre") as GoldOre
	ore.show_build_button()
	await process_frame
	assert(hub._buildings_button.visible and not hub._discovered_buildings.is_empty())
	for raw_ore in get_nodes_in_group("gold_ores"):
		if raw_ore is GoldOre:
			hub._discovered_buildings[hub._building_key(raw_ore as GoldOre, false)] = true
			hub._discovered_buildings[hub._building_key(raw_ore as GoldOre, true)] = true
	hub._rebuild_buildings()
	assert(hub._buildings_grid.columns == 4 and (hub._buildings_overlay.find_child("BuildingsPanel", true, false) as PanelContainer).custom_minimum_size == CommerceHub.BUILDINGS_PANEL_SIZE, "The Buildings popup must be wide enough for four cards and tall enough for two and a half rows")
	hub._open_buildings()
	await process_frame
	var building_card := hub._buildings_grid.get_child(0) as PanelContainer
	assert(building_card != null and building_card.custom_minimum_size == CommerceHub.BUILDING_CARD_SIZE, "Discovered building cards must share one equalized size")
	for raw_card in hub._buildings_grid.get_children():
		assert((raw_card as PanelContainer).custom_minimum_size == building_card.custom_minimum_size and (raw_card as PanelContainer).size == building_card.size)
	assert(hub._buildings_grid.get_child(3).position.y == building_card.position.y and hub._buildings_grid.get_child(4).position.y > building_card.position.y, "The Buildings popup must lay out four equal cards per row")
	hub._close_overlay(hub._buildings_overlay)
	var building_content := building_card.get_child(0) as VBoxContainer
	var composite_mine_icons := 0
	for raw_card in hub._buildings_grid.get_children():
		var card := raw_card as PanelContainer
		var building_name := card.find_child("BuildingName", true, false) as Label
		assert(building_name != null and not building_name.text.begins_with("Build "), "Building gallery names must omit the action prefix")
		var deposit_icon := card.find_child("DepositIcon", true, false) as TextureRect
		if deposit_icon:
			var mine_icon := card.find_child("BuildingIcon", true, false) as TextureRect
			assert(mine_icon != null and deposit_icon.z_index < mine_icon.z_index and deposit_icon.position.y > mine_icon.position.y, "Gold and Gem gallery art must layer the deposit behind the mine")
			composite_mine_icons += 1
	assert(composite_mine_icons == 2, "Only the Gold and Gem mine cards must include their underlying deposits")
	assert(building_content.get_child(2) is HBoxContainer and building_content.get_child(3) is HBoxContainer and building_content.get_child(2).get_child(0) is TextureRect and building_content.get_child(3).get_child(0) is TextureRect, "Building resource requirements must stack vertically with icons")
	assert((building_content.get_child(2).get_child(1) as Label).text.is_valid_int() and (building_content.get_child(2).get_child(1) as Label).get_theme_font_size("font_size") == 14 and (building_content.get_child(2).get_child(1) as Label).custom_minimum_size.x >= 24, "Building resource rows must visibly show the required amount without an x prefix")
	assert(building_content.find_child("BuiltCount", true, false) == null, "Unbuilt building icons must not show an x0 count")
	assert(hub._buildings_grid.find_child("BuildingEffect", true, false) == null, "Discovered blueprints must hide their effects until one is built")
	assert(building_card.get_signal_connection_list("mouse_entered").is_empty(), "Building cards must not open mouseover popups")
	ore._create_mine()
	hub._rebuild_buildings()
	var effect_label := hub._buildings_grid.find_child("BuildingEffect", true, false) as Label
	assert(effect_label != null and effect_label.text.begins_with("Production:") and effect_label.text.ends_with("min") and effect_label.get_theme_color("font_color") == Color("63d471"), "A constructed building must reveal its green effect in minutes")
	assert((hub._buildings_grid.find_child("BuiltCount", true, false) as Label).text == "x1", "Constructing a building must update its icon count")
	assert((ore.get_node("Sprite2D") as Sprite2D).position.y > (ore._mine.get_node("Sprite2D") as Sprite2D).position.y, "Gold and gem deposits must remain drawn beneath their mine")
	var inventory_panel := world.get_node("HUD/Inventory") as InventoryPanel
	var inventory_title: Label
	for child in inventory_panel._content.get_children():
		if child is Label and (child as Label).text == "Inventory":
			inventory_title = child as Label
	var quest_button := world.get_node("HUD/QuestLog")._button as Button
	assert(inventory_title != null and hub._bazaar_button.global_position.y < inventory_title.global_position.y and hub._buildings_button.global_position.y < inventory_title.global_position.y, "Quest, Bazaar, and Buildings buttons must sit above the Inventory title")
	assert(hub._buildings_button.global_position.x < hub._bazaar_button.global_position.x and hub._bazaar_button.global_position.x < quest_button.global_position.x, "Buildings, Bazaar, and Quest controls must form a right-aligned row")
	hub._fly_dot(hub._bazaar_button.get_global_rect().get_center(), hub._bazaar_button, Color.WHITE, "BazaarPulseTestDot")
	hub._fly_dot(hub._buildings_button.get_global_rect().get_center(), hub._buildings_button, Color.WHITE, "BuildingsPulseTestDot")
	await create_timer(0.72).timeout
	assert(hub._bazaar_button.scale.x > 1.0 and hub._buildings_button.scale.x > 1.0, "Bazaar and Buildings buttons must grow when they receive a dot")
	await create_timer(0.25).timeout
	assert(hub._bazaar_button.scale.is_equal_approx(Vector2.ONE) and hub._buildings_button.scale.is_equal_approx(Vector2.ONE), "Bazaar and Buildings buttons must shrink back after receiving a dot")
	assert(DamageGrid.WEAPON_TYPE_TOOLTIP == "Weapon Type", "The top-left damage icon must describe weapon type")
	var lio := world.get_node("FoxLio") as FoxLio
	lio.set_hunter_recruited(true, false)
	assert(lio.has_unrestricted_helper_movement() and world.get_occupied_cells(lio).is_empty(), "Recruited helpers must ignore dynamic movement restrictions")
	var horizontal_target := Vector2.ZERO
	for direction in [Vector2i.LEFT, Vector2i.RIGHT]:
		var candidate: Vector2i = world.world_to_cell(lio.global_position) + direction
		if world.is_walkable(candidate):
			horizontal_target = world.cell_to_world(candidate)
			break
	assert(horizontal_target != Vector2.ZERO, "The test needs a horizontal floor tile beside Lio")
	lio._path = PackedVector2Array([lio.global_position, horizontal_target])
	lio._path_index = 1
	var lio_before := lio.global_position
	lio._follow_hunt_path(0.1)
	assert(not is_equal_approx(lio.global_position.x, lio_before.x) and is_equal_approx(lio.global_position.y, lio_before.y), "Lio must move horizontally along a horizontal helper path")
	var lio_save := lio.get_save_data()
	lio._hunt_path_refresh_left = 99.0
	assert(lio.load_save_data(lio_save) and is_zero_approx(lio._hunt_path_refresh_left), "Loading an active helper must immediately clear stale movement delays")
	var hub_save := hub.get_save_data()
	hub.load_save_data([])
	assert(not hub._bazaar_button.visible and not hub._buildings_button.visible)
	hub.load_save_data(hub_save)
	assert(hub._bazaar_button.visible and hub._buildings_button.visible, "Bazaar retirements and building discoveries must survive saves")
	var save_system := world.get_node("SaveSystem") as SaveSystem
	var decoded_state := save_system._decode_state(save_system.create_save_string(1000))
	assert(decoded_state.size() > 16 and decoded_state[16] == hub.get_save_data(), "Commerce discoveries must be appended compatibly to the world save")

	var banner_item := ItemPickup.make_item("weathered_sword", 1)
	banner_item["_previous_stat"] = 5
	var banner := (world.get_node("HUD/MergeUpgradeBanners") as MergeUpgradeBanners)._create_banner(banner_item)
	var banner_text := banner.find_child("BannerText", true, false) as Label
	assert(banner_text.text == "Damage 5 -> 10" and banner_text.get_theme_color("font_color") == Color.WHITE)
	banner.free()

	print("PASS: exact merge stats, stones, blue sword, shop slot frames, Bazaar, and building discovery work")
	world.queue_free()
	await process_frame
	quit()
