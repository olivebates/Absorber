extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := (load("res://Scenes/world.tscn") as PackedScene).instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame

	var tooltip := world.get_node("HUD/ItemTooltip") as ItemTooltip
	var blue_sword := ItemPickup.make_item("blue_sword")
	var blue_stone := ItemPickup.make_item("blue_damage_stone")
	assert(ItemPickup.get_damage_bonus(blue_sword) == 20, "Blue Sword must deal 20 blue damage")
	assert(ItemPickup.get_stone_bonus(blue_stone) == 5, "Blue Damage Stone must grant 5 blue damage")
	tooltip.show_item(blue_stone)
	assert(tooltip._instruction.visible and tooltip._instruction.text == "Drag onto equipment to activate." and tooltip._instruction.get_theme_color("font_color") == Color.WHITE, "Stone popups must show their white drag instruction below the name")

	blue_sword["stone"] = blue_stone
	tooltip.show_item(blue_sword)
	assert(tooltip._stat_bonus.visible and tooltip._stat_bonus.text == "+5" and tooltip._stat_bonus.get_theme_color("font_color") == Color("63d471"), "A matching stone stat must appear as a green bonus on its equipment row")
	assert(tooltip._stat_dot.visible and tooltip._stat_dot.get_index() < tooltip._stat_icon.get_index(), "Equipment color dots must appear before their stat icons")
	blue_sword["stone"] = ItemPickup.make_item("red_damage_stone")
	tooltip.show_item(blue_sword)
	var added_row := tooltip._extra_rows.get_child(0) as HBoxContainer
	assert(not tooltip._stat_bonus.visible and (added_row.get_child(2) as Label).text == "+2 Red Damage" and (added_row.get_child(2) as Label).get_theme_color("font_color") == Color("63d471"), "A non-matching stone stat must get its own green equipment row")

	assert(ResourceManager.format_production_rate(1.0 / 300.0) == "+1/5 min")
	assert(ResourceManager.format_production_rate(2.0 / 300.0) == "+2/5 min")
	assert(ResourceManager.format_production_rate(1.0 / 600.0) == "+1/10 min")
	var save_system := world.get_node("SaveSystem") as SaveSystem
	var fill_key := InputEventKey.new()
	fill_key.pressed = true
	fill_key.physical_keycode = KEY_P
	fill_key.shift_pressed = true
	save_system._unhandled_key_input(fill_key)
	var hub := world.get_node("HUD/CommerceHub") as CommerceHub
	assert(hub._discovered_buildings.has(CommerceHub.DUNGEON_MINE_KEY), "Shift+P must unlock the dungeon mine and every other Buildings-tab entry")

	var manager := world.get_node("DungeonManager") as DungeonManager
	var entrance := world.get_node("DungeonEntrance") as DungeonEntrance
	manager.dungeon_states[str(entrance.dungeon_id)] = {"cleared": true}
	manager.dungeon_state_changed.emit(entrance.dungeon_id)
	assert(is_zero_approx((world.get_node("ResourceManager") as ResourceManager).get_production_speed(&"cave_moss")), "A completed dungeon must not produce Cave Moss before its mine is built")
	entrance.show_build_button()
	assert(entrance._build_button.visible and DungeonEntrance.MINE_BUILD_COST == {"cave_moss": 5, "wood": 2})
	entrance._try_build_mine()
	var resources := world.get_node("ResourceManager") as ResourceManager
	assert(resources.get_amount(&"cave_moss") == 5 and resources.get_amount(&"wood") == 8, "A dungeon mine must cost 5 Cave Moss and 2 Wood")
	assert(manager.has_cave_moss_mine(entrance.dungeon_id) and is_instance_valid(entrance._mine), "Building on a completed dungeon must create its persisted Cave Moss mine")
	assert((entrance._mine.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/MinerStructure.webp")
	assert(is_equal_approx(resources.get_production_speed(&"cave_moss"), 1.0 / 600.0))

	hub._rebuild_buildings()
	var dungeon_card: PanelContainer
	for raw_card in hub._buildings_grid.get_children():
		var card := raw_card as PanelContainer
		var title := card.find_child("BuildingName", true, false) as Label
		if title and title.text == "Cave Moss Mine":
			dungeon_card = card
			break
	assert(dungeon_card != null, "The Buildings tab must contain the Cave Moss Mine")
	var dungeon_icon := dungeon_card.find_child("DepositIcon", true, false) as TextureRect
	var mine_icon := dungeon_card.find_child("BuildingIcon", true, false) as TextureRect
	assert(dungeon_icon != null and dungeon_icon.texture == entrance.get_sprite_texture() and dungeon_icon.z_index < mine_icon.z_index, "The Buildings tab must draw the dungeon behind the mine")
	assert((dungeon_card.find_child("BuildingEffect", true, false) as Label).text == "Production: +1/10 min")
	var saved_dungeons := manager.get_save_data()[1] as Dictionary
	assert(bool((saved_dungeons[str(entrance.dungeon_id)] as Dictionary).get("mine", false)), "Dungeon mine construction must survive saving")

	world.queue_free()
	await process_frame
	await process_frame
	print("PASS: September 4 stone, equipment, production, and dungeon-mine changes")
	quit()
