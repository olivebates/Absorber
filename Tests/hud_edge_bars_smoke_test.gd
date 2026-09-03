extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := (load("res://Scenes/world.tscn") as PackedScene).instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	var edge_bars := world.get_node("HUD/EdgeBars") as Control
	var viewport_size := edge_bars.get_viewport_rect().size
	var left := edge_bars.get_node("Left") as ColorRect
	var right := edge_bars.get_node("Right") as ColorRect
	var top := edge_bars.get_node("Top") as ColorRect
	var bottom := edge_bars.get_node("Bottom") as ColorRect

	assert(left.size == Vector2(320.0, viewport_size.y), "The left HUD bar must be five tiles wide")
	assert(right.size == Vector2(320.0, viewport_size.y), "The right HUD bar must be five tiles wide")
	assert(top.size == Vector2(viewport_size.x, 192.0), "The top HUD bar must be three tiles tall")
	assert(bottom.size == Vector2(viewport_size.x, 192.0), "The bottom HUD bar must be three tiles tall")
	assert(left.position == Vector2.ZERO and top.position == Vector2.ZERO, "The left and top bars must touch their screen edges")
	assert(is_equal_approx(right.position.x + right.size.x, viewport_size.x), "The right bar must touch the right screen edge")
	assert(is_equal_approx(bottom.position.y + bottom.size.y, viewport_size.y), "The bottom bar must touch the bottom screen edge")
	for bar in [left, right, top, bottom]:
		assert(bar.color == Color.BLACK, "Every HUD edge bar must be opaque black")
		assert(bar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUD edge bars must not consume input")
	assert(edge_bars.get_index() < world.get_node("HUD/DamageGrid").get_index(), "HUD edge bars must render beneath the GUI")

	var damage_grid := world.get_node("HUD/DamageGrid") as DamageGrid
	var armor_grid := world.get_node("HUD/ArmorGrid") as ArmorGrid
	var vitals := world.get_node("HUD/PlayerVitals") as PlayerVitals
	var resource_panel := world.get_node("HUD/ResourcePanel") as ResourcePanel
	var auto_fight := world.get_node("HUD/AutoFight") as AutoFightControl
	var debug_menu := world.get_node("HUD/DebugMenu") as DebugStatMenu
	var minimap := world.get_node("HUD/Minimap") as Minimap
	var inventory := world.get_node("HUD/Inventory") as InventoryPanel
	var equipment := world.get_node("HUD/EquipmentToolbar") as EquipmentToolbar
	world.player.add_color_damage(FoxPlayer.COLOR_RED, 1)
	world.player.collect_item("weathered_armor")
	world.player.unlock_auto_fight()
	var resource_manager := world.get_node("ResourceManager") as ResourceManager
	resource_manager.add_resource(&"gold_ore", 1.0)
	var resource_test_producer := Node.new()
	world.add_child(resource_test_producer)
	resource_manager.register_producer(resource_test_producer, &"gold_ore", 1.0 / 300.0)
	await process_frame
	await process_frame

	assert(vitals.position.x == 12.0 and is_equal_approx(vitals.size.x, vitals.get_combined_minimum_size().x) and vitals.size.x < 296.0, "Player vitals must fit their content in the top-left bar")
	var resource_style := resource_panel.get_theme_stylebox("panel")
	assert(resource_panel.position.x == 12.0 and resource_panel.size == Vector2(296.0, resource_panel._rows.get_combined_minimum_size().y + resource_style.get_minimum_size().y), "Resources must fill the inner sidebar width and fit their vertical rows")
	assert(auto_fight.position.x == 12.0 and auto_fight.size.x == 296.0, "Auto Fight must fill the left sidebar's inner width")
	debug_menu.show()
	debug_menu._fit_below_damage_grid()
	assert(debug_menu.position.x == 12.0 and is_equal_approx(debug_menu.size.x, debug_menu.get_combined_minimum_size().x) and debug_menu.size.x < 296.0, "The debug menu must fit its content in the top-left bar")
	assert(auto_fight.get_global_rect().end.y <= resource_panel.get_global_rect().position.y - 7.0, "Full-width bottom-left panels must stack without overlap")
	assert(damage_grid.position.x == 12.0 and is_equal_approx(damage_grid.size.x, damage_grid.get_combined_minimum_size().x), "The damage grid must fit its content")
	assert(is_equal_approx(armor_grid.size.x, armor_grid.get_combined_minimum_size().x) and armor_grid.get_global_rect().end.x < 308.0, "The armor grid must fit beside damage without filling the top-left bar")
	assert(is_equal_approx(armor_grid.position.x - damage_grid.get_global_rect().end.x, 8.0), "Damage and defense containers must retain an eight-pixel margin")
	assert(is_equal_approx(vitals.position.y - maxf(damage_grid.get_global_rect().end.y, armor_grid.get_global_rect().end.y), 8.0), "Vitals must retain an eight-pixel margin below the stat grids")
	var damage_icon := damage_grid._grid.get_child(1).find_children("*", "TextureRect", true, false)[0] as TextureRect
	var shield_icon := armor_grid.find_child("ShieldIcon", true, false) as TextureRect
	var health_icon := vitals.find_child("HealthIcon", true, false) as TextureRect
	var health_value := vitals.find_child("HealthValue", true, false) as Label
	var damage_value := damage_grid._grid.get_child(3).get_child(0) as Label
	var defense_value := armor_grid._grid.get_child(3).get_child(0) as Label
	var resource_row := resource_panel._rows.get_child(0) as HBoxContainer
	var resource_icon := resource_row.get_child(0) as TextureRect
	var resource_values := resource_row.get_node("Values") as HBoxContainer
	var resource_value := resource_values.get_node("ResourceAmount") as Label
	var resource_production := resource_values.get_node("ResourceProduction") as Label
	assert(damage_icon.custom_minimum_size == Vector2(32, 32), "The left damage icon must use its full 32x32 size")
	assert(shield_icon.custom_minimum_size == Vector2(32, 32), "The left defense icon must use its full 32x32 size")
	assert(health_icon.custom_minimum_size == Vector2(32, 32), "Left vital icons must use their full 32x32 size")
	assert(resource_icon.custom_minimum_size == Vector2(32, 32), "Left resource icons must use their full 32x32 size")
	assert(health_value.get_theme_font_size("font_size") == 22 and damage_value.get_theme_font_size("font_size") == 22 and defense_value.get_theme_font_size("font_size") == 22, "Top-left stat values must use the slightly smaller 22px text size")
	assert(resource_value.get_theme_font_size("font_size") == 24, "Bottom-left resource values must retain 24px text")
	assert(resource_value.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT and resource_production.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "Resource amounts and production speeds must both be left-aligned")
	assert(is_equal_approx(resource_production.position.x - resource_value.get_rect().end.x, 32.0), "Resource amounts and production speeds must have an exact 32px gap")
	for definition in resource_manager.get_definitions():
		resource_manager.add_resource(definition.resource_id, 1.0)
	await process_frame
	await process_frame
	assert(resource_panel._rows is VBoxContainer and resource_panel._rows.get_child_count() == resource_manager.get_definitions().size(), "Discovered resources must populate one vertical row each")
	assert(resource_panel.size.x == 296.0, "The complete resource list must remain inside the left sidebar")
	for cell in damage_grid._grid.get_children():
		assert((cell as Control).size == Vector2(40, 40), "Every damage-grid cell must use the standardized 40x40 dimensions")
	for cell in armor_grid._grid.get_children():
		assert((cell as Control).size == Vector2(40, 40), "Every defense-grid cell must use the standardized 40x40 dimensions")
	for stat_container in [damage_grid, armor_grid, vitals.find_child("HealthCell", true, false)]:
		var stat_style := (stat_container as Control).get_theme_stylebox("panel")
		assert(stat_style.content_margin_left == 8.0 and stat_style.content_margin_right == 8.0 and stat_style.content_margin_top == 8.0 and stat_style.content_margin_bottom == 8.0, "Top-left stat containers must use eight-pixel margins")
	assert(minimap.position.x == viewport_size.x - 308.0 and minimap.size.x == 296.0, "The minimap must retain the right sidebar width")
	assert(is_equal_approx(minimap.size.y, 207.2), "The minimap must be 30% shorter while retaining its width")
	var minimap_header := minimap.get_node("MinimapHeader") as PanelContainer
	var settings_button := world.get_node("HUD/SettingsMenu/SettingsButton") as Button
	var settings_anchor := minimap_header.get_node("Content/SettingsAnchor") as Control
	assert(minimap_header.size == Vector2(296, 44) and is_equal_approx(minimap_header.get_global_rect().end.y + 8.0, minimap.get_global_rect().position.y), "The minimap header must align above the fixed-width map with an eight-pixel gap")
	assert(settings_button.get_global_rect().position == settings_anchor.get_global_rect().position, "Settings must live inside the minimap header")
	for control in [inventory, equipment]:
		assert(is_equal_approx(control.get_global_rect().end.x, viewport_size.x - 12.0), "Bottom-right panels must retain their right inset")
		assert(is_equal_approx(control.size.x, control.get_combined_minimum_size().x) and control.size.x <= 296.0, "Bottom-right panels must fit their content inside the sidebar")
	assert(world.player.inventory_slots.size() == 4 and inventory._items.get_child_count() == 4, "The player must start with four inventory slots")
	assert(inventory._items.columns == 6 and equipment._armor_row.columns == 6 and equipment._weapon_row.columns == 6, "Inventory and equipment must use six columns because they fit")
	assert((inventory._items.get_child(0) as ItemSlot).size == Vector2(42, 42), "Inventory slots must return to their compact size")
	assert((equipment._weapon_row.get_child(0) as ItemSlot).size == Vector2(42, 42), "Equipment slots must return to their compact size")
	assert(equipment._weapon_row.get_child_count() == 6 and equipment._armor_row.get_child_count() == 6, "Equipment must expose six weapon and six armor positions")
	equipment._refresh()
	equipment._refresh()
	equipment._fit_to_content()
	assert(equipment._weapon_row.get_child_count() == 6 and equipment._armor_row.get_child_count() == 6 and is_equal_approx(equipment.size.x, equipment.get_combined_minimum_size().x), "Consecutive equipment refreshes must retain exactly six fitted slots per row")
	for index in range(1, 6):
		assert((equipment._weapon_row.get_child(index) as ItemSlot).locked and (equipment._armor_row.get_child(index) as ItemSlot).locked, "Every added equipment position must begin locked")
	var bottom_right_cluster := world.get_node("HUD/BottomRightCluster") as Panel
	assert(is_equal_approx(inventory.get_global_rect().end.y, equipment.get_global_rect().position.y), "Inventory and equipment sections must meet inside one unified card")
	assert(bottom_right_cluster.get_global_rect().position == inventory.get_global_rect().position and bottom_right_cluster.get_global_rect().end == equipment.get_global_rect().end, "The shared bottom-right background must frame both sections")
	assert(equipment.find_child("EquipmentTitle", true, false) != null, "The unified card must label its equipment section")
	var equipment_background := equipment.find_child("SecondaryEquipmentBackground", true, false) as Panel
	assert((equipment_background.get_theme_stylebox("panel") as StyleBoxFlat).bg_color != (bottom_right_cluster.get_theme_stylebox("panel") as StyleBoxFlat).bg_color, "Equipment must use a subtler secondary background inside the unified card")
	var quest_button := world.get_node("HUD/QuestLog/QuestLogButton") as Button
	assert(quest_button.get_global_rect().position == inventory.get_quest_anchor_rect().position, "The Quest Log button must sit inside the Inventory header")
	var health_style := (vitals.find_child("HealthCell", true, false) as Control).get_theme_stylebox("panel") as StyleBoxFlat
	var regeneration_style := (vitals.find_child("RegenerationCell", true, false) as Control).get_theme_stylebox("panel") as StyleBoxFlat
	assert(health_style.bg_color != regeneration_style.bg_color and health_style.bg_color.v > regeneration_style.bg_color.v, "Primary vitals must be visually stronger than secondary regeneration")

	var legacy_save := world.player.get_save_data()
	legacy_save[6] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
	legacy_save[7] = [[], [], [], []]
	legacy_save[8] = [[], [], [], []]
	legacy_save[9] = [[], [], [], []]
	legacy_save[11] = [0, 0, 0, 0]
	legacy_save[34] = 4
	legacy_save[35] = 4
	assert(world.player.load_save_data(legacy_save, 0), "Legacy four-slot player data must still load")
	assert(world.player.inventory_slots.size() == 4 and world.player.equipped_weapons.size() == 6 and world.player.equipped_armor.size() == 6, "Legacy saves must retain four inventory slots and six equipment slots")
	assert(world.player.damage_by_color[1][0] == 5 and world.player.damage_by_color[2][3] == 12 and world.player.damage_by_color[0][4] == 1, "Legacy four-column damage data must retain its color grouping and pad new columns")
	assert(world.player.unlock_equipment_slots(3) == 2 and world.player.equipment_slots_unlocked == 6, "Equipment rewards must unlock both new positions without exceeding six")
	world.queue_free()
	await process_frame
	await process_frame
	print("PASS: HUD edge bars and sidebar GUI use tile-exact screen-edge dimensions")
	quit()
