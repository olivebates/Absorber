extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _finish_dialogue(box: DialogueBox) -> String:
	var copy := ""
	while box.is_open():
		copy += " " + box.get_current_text()
		box.finish_typing()
		box.advance()
	return copy


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _run() -> void:
	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var box := world.get_node("HUD/DialogueBox") as DialogueBox
	_finish_dialogue(box)
	var game_audio := world.get_node("GameAudio") as GameAudio
	var player_position := world.player.global_position
	assert(is_equal_approx(game_audio.get_lio_fight_volume_scale(player_position), 1.0))
	assert(is_equal_approx(game_audio.get_lio_fight_volume_scale(player_position + Vector2.RIGHT * WorldNavigation.TILE_SIZE), 1.0))
	assert(is_equal_approx(game_audio.get_lio_fight_volume_scale(player_position + Vector2.RIGHT * WorldNavigation.TILE_SIZE * 4.0), 4.0 / 7.0))
	assert(is_zero_approx(game_audio.get_lio_fight_volume_scale(player_position + Vector2.RIGHT * WorldNavigation.TILE_SIZE * 8.0)))
	assert(is_zero_approx(game_audio.get_lio_fight_volume_scale(player_position + Vector2.RIGHT * WorldNavigation.TILE_SIZE * 12.0)))

	var inventory := world.get_node("HUD/Inventory") as InventoryPanel
	assert(inventory._trash_slot._empty_icon.texture.resource_path == "res://Sprites/IconTrash.webp")
	assert(inventory._trash_slot._empty_icon.z_index < inventory._trash_slot._icon.z_index)
	assert(inventory._trash_slot._icon.size == Vector2(32, 32))
	assert(inventory._trash_slot.get_parent().get_child(1) == inventory._auto_merge_button and inventory._auto_merge_button.text == "Merge All")
	inventory._trash_slot.mouse_entered.emit()
	var item_tooltip := get_first_node_in_group("item_tooltip") as ItemTooltip
	assert(item_tooltip._stat.text == "Throw unwanted in items here. They will remain until you drag the next item in here.")
	inventory._trash_slot.mouse_exited.emit()

	var map := world.get_node("HUD/WorldMap") as WorldMap
	map._unhandled_key_input(_key(KEY_TAB))
	assert(not map.visible, "Tab must not open the map")
	map._unhandled_key_input(_key(KEY_M))
	assert(map.visible, "M must open the map")
	map.close()
	assert(box.play([{"speaker": "Mira", "text": "Space advances this.", "portrait": StoryManager.PLAYER_PORTRAIT}]))
	box._input_delay_left = 0.0
	box._unhandled_key_input(_key(KEY_SPACE))
	assert(not box.is_typing())
	box._unhandled_key_input(_key(KEY_SPACE))
	assert(not box.is_open(), "Space must advance and close dialogue like a click")

	var save_system := world.get_node("SaveSystem") as SaveSystem
	var beginning := world.player._beginning_position
	world.player.global_position = Vector2(864, 480)
	var encoded := save_system.create_save_string(1000)
	world.version_number += 1
	assert(save_system.load_save_string(encoded, 1000))
	assert(world.player.global_position == beginning and world.player._spawn_position == beginning, "World-version mismatch must reset the player to the beginning")
	world.version_number -= 1
	var asha := world.get_node("FoxAsha") as FoxAsha
	var story := world.get_node("StoryManager") as StoryManager
	story._seen_events[&"asha_recruited"] = true
	story._find_characters()
	var respawn := (world.get_node("Campfire") as Campfire).get_respawn_position()
	world.player.set_respawn_position(respawn)
	world.player.global_position = respawn + Vector2.RIGHT * 64.0
	world.player.take_damage(world.player.health + world.player.get_total_block())
	await create_timer(1.0).timeout
	assert(asha.global_position == respawn + Vector2.LEFT * 64.0, "A recruited Asha must respawn to the player's left after blackout")
	story._seen_events.erase(&"asha_recruited")
	asha.set_recruited(false)
	_finish_dialogue(box)

	var lio := world.get_node("FoxLio") as FoxLio
	assert(lio.has_first_gold_mine() == false)
	for ore_name in FoxLio.REQUIRED_GOLD_ORES:
		(world.get_node(str(ore_name)) as GoldOre).load_save_data([1, 0], 0)
	assert(lio.has_required_gold_mines())
	story.on_structure_built(&"gold_ore", world.get_node("GoldOre3") as GoldOre)
	assert(box.get_current_text() == "There we go, I should speak to Lio about that job offer.")
	_finish_dialogue(box)
	assert(story.interact_with(&"lio"))
	var recruitment := _finish_dialogue(box)
	assert(recruitment.contains("I'd like to contribute!") and recruitment.contains("I won't touch the moles or bosses"))
	assert(lio.is_hunter_recruited())

	var reward_enemy := (load("res://Scenes/chicken_enemy.tscn") as PackedScene).instantiate() as ChickenEnemy
	reward_enemy.setup(Vector2i.ZERO, 2, ChickenEnemy.REWARD_DAMAGE, [], &"gold_ore", FoxPlayer.COLOR_RED, 5, 1, FoxPlayer.COLOR_RED, 99)
	reward_enemy.global_position = lio.global_position + Vector2.RIGHT * WorldNavigation.TILE_SIZE
	world.add_child(reward_enemy)
	await process_frame
	reward_enemy.take_hunter_damage(lio)
	assert(reward_enemy.health == 3, "Lio must deal exactly two damage regardless of armor")
	var lio_child_count := lio.get_child_count()
	reward_enemy._attack_time_left = 0.0
	reward_enemy._attack_hunter()
	assert(reward_enemy._attack_visual_time_left > 0.0, "Enemies must visibly counterattack Lio")
	assert(lio.get_child_count() == lio_child_count, "Enemy counterattacks must not draw slash marks on Lio")
	reward_enemy.take_hunter_damage(lio)
	assert(reward_enemy.health == 1)
	reward_enemy.take_hunter_damage(lio)
	assert(reward_enemy.health == 0)
	lio.hunt_state = FoxLio.HuntState.WAITING_AT_CAMPFIRE
	var saved_lio_state := save_system.create_save_string(2000)
	lio.set_hunter_recruited(false)
	lio._collected_rewards.clear()
	assert(save_system.load_save_string(saved_lio_state, 2000))
	assert(lio.is_hunter_recruited() and lio.is_waiting_at_campfire(), "Lio's recruited and campfire states must load from saves")
	assert(int(lio.get_collected_reward_totals().get("damage_0", 0)) == 2, "Lio's carried rewards must load from saves")
	var resources := world.get_node("ResourceManager") as ResourceManager
	var current_gold := resources.get_amount(&"gold_ore")
	if current_gold > 0:
		assert(resources.spend_resources({&"gold_ore": current_gold}))
	var old_damage := world.player.get_base_damage_for_color(FoxPlayer.COLOR_RED)
	var gold_before_free_handoff := resources.get_amount(&"gold_ore")
	assert(story.interact_with(&"lio"))
	assert(box.get_current_text() == "Hey, this one's on me. Here you go, sir!")
	assert(resources.get_amount(&"gold_ore") == gold_before_free_handoff, "Fewer than 15 stat upgrades must be handed over for free")
	var free_lio_state := save_system.create_save_string(2100)
	lio._reward_fee_paid = false
	assert(save_system.load_save_string(free_lio_state, 2100))
	assert(lio.has_paid_reward_fee() and lio.is_waiting_at_campfire(), "A free authorized handoff must survive saving during dialogue")
	assert(story.interact_with(&"lio"))
	assert(_finish_dialogue(box).contains("Hey, this one's on me. Here you go, sir!"))
	assert(world.gameplay_paused, "Reward delivery must pause gameplay")
	await create_timer(1.2).timeout
	assert(world.player.get_base_damage_for_color(FoxPlayer.COLOR_RED) == old_damage + 2)
	assert(box.is_open() and box.get_current_text().contains("headed out again"))
	_finish_dialogue(box)

	var paid_reward_enemy := (load("res://Scenes/chicken_enemy.tscn") as PackedScene).instantiate() as ChickenEnemy
	paid_reward_enemy.setup(Vector2i.ZERO, 15, ChickenEnemy.REWARD_DAMAGE)
	lio.collect_enemy_reward(paid_reward_enemy)
	paid_reward_enemy.free()
	lio.hunt_state = FoxLio.HuntState.WAITING_AT_CAMPFIRE
	lio._reward_fee_paid = false
	assert(lio.get_total_collected_stat_upgrades() == 15 and not lio.is_reward_handoff_free())
	current_gold = resources.get_amount(&"gold_ore")
	if current_gold > 0:
		assert(resources.spend_resources({&"gold_ore": current_gold}))
	assert(story.interact_with(&"lio"))
	var no_payment_dialogue := _finish_dialogue(box)
	assert(no_payment_dialogue.contains("Haha, appologies, I don't work for free. We agreed on 3 gold, right?"))
	assert(no_payment_dialogue.contains("I don't have that right now..."))
	assert(no_payment_dialogue.contains("Well come back when you got the pay :)"))
	assert(lio.is_waiting_at_campfire(), "Lio must keep waiting when the player cannot pay")
	resources.add_resource(&"gold_ore", 3)
	var gold_before_payment := resources.get_amount(&"gold_ore")
	old_damage = world.player.get_base_damage_for_color(FoxPlayer.COLOR_RED)
	assert(story.interact_with(&"lio"))
	assert(resources.get_amount(&"gold_ore") == gold_before_payment - 3, "Collecting Lio's rewards must cost three gold")
	assert(lio.has_paid_reward_fee())
	var paid_lio_state := save_system.create_save_string(2200)
	lio._reward_fee_paid = false
	assert(save_system.load_save_string(paid_lio_state, 2200))
	assert(lio.has_paid_reward_fee() and lio.is_waiting_at_campfire(), "A paid reward handoff must survive saving during dialogue")
	var gold_after_paid_load := resources.get_amount(&"gold_ore")
	assert(story.interact_with(&"lio"))
	assert(resources.get_amount(&"gold_ore") == gold_after_paid_load, "Reloading a paid handoff must not charge Lio's fee twice")
	var campfire_dialogue := _finish_dialogue(box)
	assert(campfire_dialogue.contains("Sorry I couldn't carry anything more than this."))
	assert(campfire_dialogue.contains("Here you are, sir!"))
	assert(world.gameplay_paused, "Reward delivery must pause gameplay")
	await create_timer(1.2).timeout
	assert(world.player.get_base_damage_for_color(FoxPlayer.COLOR_RED) == old_damage + 15)
	assert(box.is_open() and box.get_current_text().contains("headed out again"))
	var wave_spawn: EnemySpawnPoint
	for spawn_node in get_nodes_in_group("enemy_spawns"):
		var spawn := spawn_node as EnemySpawnPoint
		if spawn.area_id == 1 and not FoxLio.EXCLUDED_ENEMY_TYPES.has(spawn.enemy_type):
			spawn.clear_for_load()
			if wave_spawn == null:
				wave_spawn = spawn
	_finish_dialogue(box)
	assert(lio.hunt_state == FoxLio.HuntState.WAITING_FOR_ENEMIES, "Lio must wait at the campfire after an empty handoff")
	var waiting_wave_state := save_system.create_save_string(2300)
	lio.start_hunting_again()
	assert(save_system.load_save_string(waiting_wave_state, 2300))
	assert(lio.hunt_state == FoxLio.HuntState.WAITING_FOR_ENEMIES, "Lio's wave-wait state must survive saving and loading")
	assert(wave_spawn != null)
	for wave_index in range(FoxLio.MINIMUM_RESPAWNED_WAVE_SIZE):
		var wave_position := wave_spawn.global_position + Vector2(wave_index * 2.0, 0.0)
		wave_spawn._create_enemy(world, wave_position, world.world_to_cell(wave_position))
	lio._process(0.0)
	assert(lio.hunt_state == FoxLio.HuntState.HUNTING, "Lio must automatically hunt once six eligible enemies have respawned")

	var luca := world.get_node("FoxLuca") as FoxAsha
	var luca_shop := FoxLucaShop.new()
	luca_shop._shopkeeper = luca
	luca.purchase_counts[0] = 2
	assert(luca_shop.get_upgrade_price(0) == 30, "Every stat shop must add its base price per purchase")
	luca_shop.free()

	for spawn in get_nodes_in_group("enemy_spawns"):
		assert((spawn as EnemySpawnPoint).area_id >= 0, "%s is missing an AreaID" % spawn.name)
	for campfire in get_nodes_in_group("campfires"):
		assert((campfire as Campfire).area_id >= 0, "%s is missing an AreaID" % campfire.name)

	print("PASS: requested inventory, input, versioning, universal pricing, and Lio loop work")
	world.queue_free()
	await process_frame
	quit()
