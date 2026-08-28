extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(DungeonManager.COMPLETION_LIGHT_FADE_TIME == 1.0)
	assert(DungeonManager.COMPLETION_RISE_TIME == 3.0)
	assert(DungeonManager.COMPLETION_TRANSITION_DELAY == 2.5)
	assert(DungeonManager.WARNING_TEXT.contains("stats are temporarily reset") and DungeonManager.WARNING_TEXT.contains("rewards"), "The first-entry popup must explain dungeon rules")

	var player := load("res://Scenes/fox.tscn").instantiate() as FoxPlayer
	root.add_child(player)
	await process_frame
	player.equipped_weapons[0] = ItemPickup.make_item("weathered_sword")
	player.equipped_armor[0] = ItemPickup.make_item("weathered_armor")
	assert(player.get_damage_for_color(FoxPlayer.COLOR_YELLOW) == player.get_base_damage_for_color(FoxPlayer.COLOR_YELLOW) + 3)
	assert(player.get_damage_for_color(FoxPlayer.COLOR_RED) == player.get_base_damage_for_color(FoxPlayer.COLOR_RED))
	assert(player.get_defense_for_color(FoxPlayer.COLOR_YELLOW) == player.get_base_defense_for_color(FoxPlayer.COLOR_YELLOW) + 2)
	assert(player.get_defense_for_color(FoxPlayer.COLOR_BLUE) == player.get_base_defense_for_color(FoxPlayer.COLOR_BLUE))

	var slot := ItemSlot.new()
	root.add_child(slot)
	slot.configure(null, "inventory", 0, ItemPickup.make_item("weathered_sword"))
	var expected_tint := Color.WHITE.lerp(Color("fbc02d"), 0.30)
	assert(slot._icon.modulate.is_equal_approx(expected_tint), "Equipment icons must carry a thirty-percent yellow tint")

	var drop := EnemyDropEntry.new()
	drop.item_type = EnemyDropEntry.ItemType.WEATHERED_SWORD
	drop.chance = 0.37
	var spawn := EnemySpawnPoint.new()
	spawn.item_drops = [drop]
	spawn.flip_enemy_sprites_horizontally = true
	assert(is_equal_approx(float(spawn._get_drop_table()[0]["chance"]), 0.37), "Spawner drop entries must preserve their typed chance")
	assert(spawn.get_property_list().any(func(property: Dictionary) -> bool: return property.name == &"flip_enemy_sprites_horizontally"), "Spawner sprite flipping must be exported")
	var flipped_enemy := load("res://Scenes/chicken_enemy.tscn").instantiate() as ChickenEnemy
	flipped_enemy.process_mode = Node.PROCESS_MODE_DISABLED
	flipped_enemy.setup(Vector2i.ZERO, 1, ChickenEnemy.REWARD_DAMAGE, [], &"gold_ore", FoxPlayer.COLOR_RED, 3, 1, FoxPlayer.COLOR_RED, 0, FoxPlayer.COLOR_RED, false, [], true)
	root.add_child(flipped_enemy)
	await process_frame
	assert(flipped_enemy.chicken_sprite.flip_h, "A flipped spawn must mirror its enemy's normal right-facing sprite")
	flipped_enemy._set_facing_left(true)
	assert(not flipped_enemy.chicken_sprite.flip_h, "Mirrored enemies must retain inverted facing while turning")
	flipped_enemy.free()

	var auto_upgrade: Dictionary = FoxLucaShop.LUCA_UPGRADES[-1]
	assert(auto_upgrade["stat"] == &"auto_fight" and auto_upgrade["resource_id"] == &"jewels" and auto_upgrade["base_price"] == 20)
	var auto_control := AutoFightControl.new()
	assert(not auto_control.has_method("_on_first_boss_killed"), "Boss kills must no longer unlock auto-combat")
	auto_control.free()

	var story := StoryManager.new()
	var warning_lines := story._get_event_dialogue(&"mad_coyote_dungeon_warning")
	assert(warning_lines.size() == 2)
	assert(warning_lines[0]["text"] == "I’ve got a bad feeling about moving on just yet.")
	assert(warning_lines[1]["text"] == "I should probably clear this place out first.")
	assert(StoryManager.MAD_COYOTE_TRIGGER_DISTANCE_TILES == 7)

	spawn.free()
	slot.free()
	player.free()
	story.free()

	var packed_world := load("res://Scenes/world.tscn") as PackedScene
	var world := packed_world.instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var dialogue := world.get_node("HUD/DialogueBox") as DialogueBox
	if dialogue.is_open():
		dialogue.close()
	var snakemouth := world.get_node("DungeonEntrance") as DungeonEntrance
	assert(snakemouth.dungeon_id == &"mossroot_grotto" and snakemouth.dungeon_name == "Snakemouth Dungeon")
	var dungeon_manager := world.get_node("DungeonManager") as DungeonManager
	var live_story := world.get_node("StoryManager") as StoryManager
	var mad_coyote_spawn := world.get_node("ChickenSpawn35") as EnemySpawnPoint
	world.player.global_position = mad_coyote_spawn.global_position
	assert(live_story._check_mad_coyote_proximity_event())
	assert(dialogue.get_current_text() == "I’ve got a bad feeling about moving on just yet.")
	live_story._on_dialogue_line_shown(1)
	await create_timer(0.8).timeout
	var camera := world.player.get_node("Camera2D") as Camera2D
	assert(camera.position.distance_to(snakemouth.global_position - world.player.global_position) < 1.0, "The warning must pan to Snakemouth Dungeon")
	dialogue.close()
	await create_timer(0.8).timeout
	assert(camera.position.distance_to(Vector2.ZERO) < 1.0)

	dungeon_manager.dungeon_states["mossroot_grotto"] = {"cleared": true}
	dungeon_manager.dungeon_state_changed.emit(&"mossroot_grotto")
	assert(snakemouth._cleared_badge.visible and snakemouth._tooltip_production_row.visible)
	assert(not snakemouth._tooltip_meter.visible and not snakemouth._tooltip_difficulty.visible)
	var audio := world.get_node("GameAudio") as GameAudio
	var audio_children_before := audio.get_child_count()
	snakemouth.request_interaction(world.player, world)
	assert(audio.get_child_count() == audio_children_before + 1, "A cleared entrance must play the unavailable-skill sound")
	var unavailable_player := audio.get_child(audio.get_child_count() - 1) as AudioStreamPlayer
	assert(unavailable_player.stream == GameAudio.SKILL_UNAVAILABLE_SFX)

	var first_uncleared_entrance := world.get_node("SunkenBurrowEntrance") as DungeonEntrance
	dungeon_manager.tutorial_seen = false
	dungeon_manager.request_enter(first_uncleared_entrance)
	assert(dungeon_manager._tutorial_overlay.visible, "The rules popup must appear before a player's first dungeon entry")
	var popup_copy_found := false
	for node in dungeon_manager._tutorial_overlay.find_children("*", "Label", true, false):
		if (node as Label).text == DungeonManager.WARNING_TEXT:
			popup_copy_found = true
	assert(popup_copy_found, "The first-entry popup must render its explanatory copy")
	dungeon_manager._tutorial_overlay.hide()
	dungeon_manager._tutorial_pending_entrance = null
	world.interaction_locked = false

	world.queue_free()
	await process_frame
	await process_frame
	print("PASS: August 28 requested dungeon, minimap, equipment, shop, spawn, and story changes are configured")
	quit()
