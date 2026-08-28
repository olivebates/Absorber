extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	assert((load("res://Resources/cave_moss.tres") as GameResourceDefinition).maximum_amount == 10)
	assert(ItemPickup.ITEM_DATA["weathered_sword"]["damage"] == 2)
	assert(EnemyDropEntry.ITEM_IDS.has(&"potion_basic") and EnemyDropEntry.ITEM_IDS.has(&"potion_holy"))
	assert(FoxPlayer.SKILL_DATA[FoxPlayer.SKILL_ROLL_CLOCKWISE]["description"] == "* Rolls 90 degrees around your target.\n* Invulnerable while rolling.\n* Increases Yellow damage by 2 for two seconds.")
	var bulwark: Dictionary = FoxPlayer.SKILL_DATA[FoxPlayer.SKILL_BULWARK]
	assert(bulwark["icon"].resource_path == "res://Sprites/skillBulwark.webp")
	assert(int(bulwark["mana"]) == 5 and is_equal_approx(float(bulwark["cooldown"]), 8.0))

	var luca_upgrades := FoxLucaShop.LUCA_UPGRADES
	assert(luca_upgrades[0]["stat"] == &"damage" and luca_upgrades[0]["color"] == FoxPlayer.COLOR_YELLOW and luca_upgrades[0]["amount"] == 2 and luca_upgrades[0]["base_price"] == 10)
	assert(luca_upgrades.any(func(upgrade: Dictionary) -> bool: return upgrade.get("item_id", "") == "potion_basic" and upgrade.get("resource_id") == &"gold_ore" and upgrade.get("base_price") == 2))
	assert(luca_upgrades.any(func(upgrade: Dictionary) -> bool: return upgrade.get("stat") == &"inventory_slot" and upgrade.get("resource_id") == &"wood" and upgrade.get("base_price") == 30))
	assert(luca_upgrades.any(func(upgrade: Dictionary) -> bool: return upgrade.get("stat") == &"auto_fight_range" and upgrade.get("resource_id") == &"wood" and upgrade.get("base_price") == 30))
	var deru_upgrade: Dictionary = FoxDeruShop.DERU_UPGRADES[0]
	assert(deru_upgrade["skill_id"] == FoxPlayer.SKILL_BULWARK and deru_upgrade["resource_id"] == &"cave_moss" and deru_upgrade["base_price"] == 6)

	var player := load("res://Scenes/fox.tscn").instantiate() as FoxPlayer
	root.add_child(player)
	await process_frame
	player.equipped_weapons[0] = ItemPickup.make_item("weathered_sword")
	assert(player.get_damage_for_color(FoxPlayer.COLOR_YELLOW) == player.get_base_damage_for_color(FoxPlayer.COLOR_YELLOW) + 2)
	var slot := ItemSlot.new()
	root.add_child(slot)
	slot.configure(null, "inventory", 0, ItemPickup.make_item("weathered_armor"))
	assert(slot._icon.modulate.is_equal_approx(ItemSlot.EQUIPMENT_YELLOW_TINT))
	assert(player.unlock_player_skill(FoxPlayer.SKILL_BULWARK))
	player.mana = 5
	var defense_before := player.get_defense_for_color(FoxPlayer.COLOR_YELLOW)
	assert(player.cast_player_skill_slot(0))
	assert(player.mana == 0 and player.get_defense_for_color(FoxPlayer.COLOR_YELLOW) == defense_before + 20)
	assert(is_equal_approx(player._bulwark_time_left, 3.0))

	player.unlock_auto_fight()
	player.increase_auto_fight_range()
	assert(player.auto_fight_range_bonus == 1 and is_equal_approx(player._auto_fight_range_fill.polygon[0].x, -224.0))
	var saved_player := player.get_save_data()
	var loaded_player := load("res://Scenes/fox.tscn").instantiate() as FoxPlayer
	root.add_child(loaded_player)
	await process_frame
	assert(loaded_player.load_save_data(saved_player, 0) and loaded_player.auto_fight_range_bonus == 1)
	player.free()
	loaded_player.free()
	slot.free()

	var world := (load("res://Scenes/world.tscn") as PackedScene).instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var manager := world.get_node("DungeonManager") as DungeonManager
	var combat_player := world.player
	combat_player.damage_by_color[FoxPlayer.COLOR_YELLOW][0] = 5
	combat_player.defense_by_color[FoxPlayer.COLOR_YELLOW] = 3
	combat_player.damage_matrix_changed.emit()
	await process_frame
	var damage_grid := world.get_node("HUD/DamageGrid") as DamageGrid
	var armor_grid := world.get_node("HUD/ArmorGrid") as ArmorGrid
	assert(damage_grid.visible and armor_grid.visible)
	manager._overworld_stats = manager._capture_stats(combat_player)
	manager._set_dungeon_stat_visibility_references()
	manager._apply_stats(combat_player, manager._make_reset_stats())
	await process_frame
	assert(damage_grid.visible and armor_grid.visible, "Overworld-visible damage and armor grids must remain visible in dungeons")
	manager._apply_stats(combat_player, manager._overworld_stats)
	manager._clear_dungeon_stat_visibility_references()
	var combat_center := Vector2i(-999999, -999999)
	var player_cell := world.world_to_cell(combat_player.global_position)
	for y_offset in range(-10, 11):
		for x_offset in range(-10, 11):
			var candidate := player_cell + Vector2i(x_offset, y_offset)
			var required := [candidate, candidate + Vector2i.LEFT, candidate + Vector2i.RIGHT, candidate + Vector2i.UP, candidate + Vector2i.DOWN]
			if required.all(func(cell: Vector2i) -> bool: return world.is_walkable(cell) and not world.is_cell_occupied(cell, combat_player)):
				combat_center = candidate
				break
		if combat_center.x > -999999:
			break
	assert(combat_center.x > -999999)
	combat_player.global_position = world.cell_to_world(combat_center + Vector2i.LEFT)
	var combat_enemy := (load("res://Scenes/chicken_enemy.tscn") as PackedScene).instantiate() as ChickenEnemy
	combat_enemy.setup(combat_center, 1, ChickenEnemy.REWARD_DAMAGE, [], &"gold_ore", FoxPlayer.COLOR_RED, 999, 1)
	combat_enemy.global_position = world.cell_to_world(combat_center)
	world.add_child(combat_enemy)
	await process_frame
	world.gameplay_paused = true
	combat_player.unlock_player_skill(FoxPlayer.SKILL_ROLL_CLOCKWISE)
	combat_player.equipped_player_skills[0] = FoxPlayer.SKILL_ROLL_CLOCKWISE
	combat_player.mana = 10
	combat_player._skill_cooldowns[FoxPlayer.SKILL_ROLL_CLOCKWISE] = 0.0
	combat_player.follow_enemy(combat_enemy)
	var yellow_before_roll := combat_player.get_damage_for_color(FoxPlayer.COLOR_YELLOW)
	var quick_roll_cast := combat_player.cast_player_skill_slot(0)
	assert(quick_roll_cast, "Quick Roll failed: %s" % combat_player.get_last_skill_cast_failure())
	assert(combat_player.get_damage_for_color(FoxPlayer.COLOR_YELLOW) == yellow_before_roll + 2)
	assert(is_equal_approx(combat_player._quick_roll_damage_time_left, 2.0) and is_equal_approx(combat_enemy._player_attack_pause_left, 2.0))
	assert(combat_player.is_in_combat() and not combat_player.swap_player_skill_slots(0, 1))
	var toolbar := world.get_node("HUD/SkillToolbar") as SkillToolbar
	toolbar._toggle_picker()
	assert(not toolbar._picker.visible)
	assert(toolbar.get_children().any(func(node: Node) -> bool: return node is Label and (node as Label).text == "In Combat"))

	manager._active_id = &"boss_key_test"
	manager.add_boss_key(2)
	assert(manager.get_boss_key_count() == 2 and manager.consume_boss_key() and manager.get_boss_key_count() == 1)
	assert(manager._boss_key_label.text == "1" and manager._boss_key_label.get_parent().get_child_count() == 4)
	manager.tutorial_seen = true
	manager.reset_for_save_load()
	assert(not manager.tutorial_seen and not manager._tutorial_overlay.visible)
	assert(load("res://Scenes/dungeon_boss_door_locked.tscn") != null)
	var boss_door := (load("res://Scenes/dungeon_boss_door_locked.tscn") as PackedScene).instantiate() as DungeonBossDoorLocked
	assert((boss_door.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/bossDoor.webp")
	boss_door.free()
	var luca := world.get_node("FoxLuca") as FoxLuca
	luca.open_shop()
	var luca_shop := luca._shop as FoxLucaShop
	assert(luca_shop._rows.size() == 8 and not luca_shop.is_upgrade_visible(5))
	combat_player.unlock_auto_fight()
	luca_shop._refresh()
	assert(luca_shop.is_upgrade_visible(5), "Luca's Auto Fight range upgrade must appear after Auto Fight is unlocked")
	luca.purchase_counts[7] = 1
	var luca_save := luca.get_save_data()
	luca.purchase_counts.fill(0)
	assert(luca.load_save_data(luca_save) and luca.purchase_counts[7] == 1)
	var resources := world.get_node("ResourceManager") as ResourceManager
	resources.add_resource(&"cave_moss", 10)
	var deru := world.get_node("FoxDeru") as FoxDeru
	deru.open_shop()
	assert(deru._shop is FoxDeruShop and deru._shop.visible and deru._shop.get_upgrade_price(0) == 6)
	assert(deru._shop.buy_upgrade(0) and combat_player.unlocked_player_skills.has(FoxPlayer.SKILL_BULWARK))
	assert(resources.get_amount(&"cave_moss") == 4)

	world.queue_free()
	await process_frame
	print("PASS: August 28 follow-up shop, skill, dungeon-key, item, and balance changes are configured")
	quit()
