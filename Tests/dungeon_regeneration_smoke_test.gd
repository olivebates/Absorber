extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var dialogue := world.get_node("HUD/DialogueBox") as DialogueBox
	if dialogue.is_open():
		dialogue.cancel()
	var manager := world.get_node("DungeonManager") as DungeonManager
	manager.tutorial_seen = true
	var entrance := world.get_node("MossrootGrottoEntrance") as DungeonEntrance
	await manager._begin_entry(entrance)
	var level := manager.get_active_level()
	assert(level != null and not level.is_current_room_clear(), "The test dungeon must begin with enemies in Mira's room")
	var player := world.player
	player.damage_by_color[FoxPlayer.COLOR_RED][0] = 4
	player.defense_by_color[FoxPlayer.COLOR_RED] = 2
	player.equipped_weapons[0] = ItemPickup.make_item("weathered_sword")
	player.equipped_armor[0] = ItemPickup.make_item("weathered_armor")
	player.equipment_changed.emit()
	await process_frame
	assert(player.get_damage_for_color(FoxPlayer.COLOR_RED) == 4 and player.get_defense_for_color(FoxPlayer.COLOR_RED) == 2, "Weapon and armor bonuses must not apply inside a dungeon")
	var equipment_toolbar := world.get_node("HUD/EquipmentToolbar") as EquipmentToolbar
	for row in [equipment_toolbar._weapon_row, equipment_toolbar._armor_row]:
		for slot in row.get_children():
			assert((slot as ItemSlot)._disabled_line.visible == not (slot as ItemSlot).item.is_empty(), "Only occupied dungeon equipment slots may show their red disabled line")
	player.unlock_player_skill(FoxPlayer.SKILL_ROLL_CLOCKWISE)
	player.health = player.max_health - 2
	player.mana = player.max_mana - 2
	player._heal_time_left = 0.01
	player._mana_regen_time_left = 0.01
	player._physics_process(0.02)
	assert(player.health == player.max_health - 2, "Health must not regenerate while dungeon enemies are present")
	assert(player.mana == player.max_mana - 2, "Mana must not regenerate while dungeon enemies are present")
	assert(is_equal_approx(player._heal_time_left, 0.01) and is_equal_approx(player._mana_regen_time_left, 0.01), "Blocked dungeon regeneration must preserve both timers")
	var vitals := world.get_node("HUD/PlayerVitals") as PlayerVitals
	vitals._refresh_regeneration()
	vitals._refresh_mana()
	assert(vitals._regen_block_line.visible and is_equal_approx(vitals._regen_block_line.width, 3.0), "The blocked-regeneration cross-out must be a visible three-pixel line")
	assert(vitals._regen_block_line.points == PackedVector2Array([Vector2(0, 29), Vector2(74, 0)]), "The regeneration cross-out must run from the cell's bottom-left to its top-right corner")
	assert(vitals._mana_regen_block_line.visible and vitals._mana_regen_block_line.points == vitals._regen_block_line.points, "Occupied dungeon rooms must cross out mana regeneration in the same way")
	var hidden_chest := level.get_node("KeyChest") as DungeonChest
	assert(hidden_chest.visible and not hidden_chest._sprite.visible and hidden_chest.HIDDEN_OUTLINE_COLOR == Color.WHITE and not hidden_chest.is_in_group("solid_walls"), "An unrevealed chest must draw its white dotted tile outline while its sprite and collision remain hidden")
	var entry_spawn := level.get_node("EntryGuard") as EnemySpawnPoint
	entry_spawn.max_enemies = 2
	entry_spawn.ensure_initial_wave_spawned()
	var original_wave := entry_spawn.get_active_enemies()
	assert(original_wave.size() == 2, "The abandonment regression requires a two-enemy wave")
	var killed_enemy := original_wave[0]
	var surviving_enemy := original_wave[1]
	var surviving_enemy_id := surviving_enemy.get_instance_id()
	killed_enemy.take_damage(killed_enemy.health)
	await process_frame
	assert(level._transition_to_room(Vector2i.RIGHT), "The regression fixture must be able to leave its occupied entry room")
	var respawned_enemies := entry_spawn.get_active_enemies()
	assert(respawned_enemies.size() == entry_spawn.max_enemies and respawned_enemies[0].get_instance_id() != surviving_enemy_id and respawned_enemies[0].health == entry_spawn.enemy_health, "Leaving an occupied room must replace every spawn there with a full-health wave")
	var rewarding_respawns: Array[ChickenEnemy] = []
	var rewardless_respawns: Array[ChickenEnemy] = []
	for respawned_enemy in respawned_enemies:
		if respawned_enemy.rewards_enabled:
			rewarding_respawns.append(respawned_enemy)
		else:
			rewardless_respawns.append(respawned_enemy)
	assert(rewarding_respawns.size() == 1 and rewardless_respawns.size() == 1, "A surviving enemy's replacement must keep its reward, while a previously killed enemy's replacement must be rewardless")
	for respawned_enemy in respawned_enemies:
		assert(respawned_enemy.reward_label.visible == respawned_enemy.rewards_enabled, "Each replacement's reward display must match its preserved reward eligibility")
	var saved_respawned_enemy: Array = rewardless_respawns[0].get_save_data()
	assert(saved_respawned_enemy.size() > 9 and not bool(saved_respawned_enemy[9]), "No-reward abandoned enemies must retain that state in dungeon saves")
	for node in get_nodes_in_group("dungeon_chests"):
		if node is DungeonChest and level.belongs_to_world(node):
			(node as DungeonChest).load_opened(true)
	var lift_start_y := player.global_position.y
	level.notify_chest_opened()
	await process_frame
	assert(manager._completion_exit_running and level.has_node("DungeonCompletionLight"), "Looting the final dungeon chest must begin the light-beam completion animation")
	var completion_light := level.get_node("DungeonCompletionLight") as Node2D
	var outer_light := completion_light.get_child(0) as Polygon2D
	assert(not level.is_processing() and manager.is_cleared(level.dungeon_id), "Final-chest completion must freeze room camera tracking and permanently clear the dungeon immediately")
	await create_timer(1.1).timeout
	assert(is_equal_approx(outer_light.color.a, 0.5), "The completion light must fade to fifty percent opacity over one second")
	assert(player.global_position.y < lift_start_y, "The completion light must lift Mira upward and out of the dungeon viewport")
	assert(absf(player.fox_sprite.rotation) > 0.0, "Mira must rotate slightly while floating")
	await create_timer(4.2).timeout
	assert(not manager.is_dungeon_active() and player.get_parent() == world, "The lift animation must transition into the existing overworld dungeon exit")
	print("PASS: dungeon regeneration cross-out and survivor-aware abandoned-wave rewards")
	world.queue_free()
	await process_frame
	await process_frame
	quit()
