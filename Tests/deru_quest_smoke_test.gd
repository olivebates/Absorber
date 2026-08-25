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


func _run() -> void:
	var world := (load("res://Scenes/world.tscn") as PackedScene).instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var box := world.get_node("HUD/DialogueBox") as DialogueBox
	_finish_dialogue(box)
	var story := world.get_node("StoryManager") as StoryManager
	var player := world.player
	var asha := world.get_node("FoxAsha") as FoxAsha
	var deru := world.get_node("FoxDeru") as FoxAsha
	var cart := world.get_node("ObstacleBrokenCart") as ObstacleWall
	assert(deru != null and deru.stationary and cart.footprint_tiles == Vector2i.ONE)
	assert((deru.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/FoxDeruSad.webp")
	assert((cart.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/BrokenCart.webp")
	assert(world.floor_layer.get_cell_source_id(world.world_to_cell(deru.global_position)) != -1, "Deru must stand on authored floor")
	assert(story.interact_with(&"deru"))
	var intro := _finish_dialogue(box)
	assert(intro.contains("my cart gave out on me") and intro.contains("in your debt") and story.is_deru_quest_started())

	assert(story.interact_with(&"deru"))
	var reminder := _finish_dialogue(box)
	assert(reminder.contains("Asha in Tiny Woods") and reminder.contains("expensive brand"), "Deru must repeat his two-line spare-parts reminder")
	assert(story.interact_with(&"asha"))
	var parts_intro := _finish_dialogue(box)
	assert(parts_intro.contains("I need a spare part for Deru's cart") and parts_intro.contains("mark it down to 30 fish") and parts_intro.contains("put it on stock"), "Asha must explain and stock Deru's discounted Spare Part")
	await process_frame
	var shop := asha._shop as FoxShop
	assert(shop != null and shop.visible, "Asha's store must open after the Spare Part conversation")
	var parts_offer_index := -1
	for index in range(shop._get_upgrades().size()):
		if str(shop._get_upgrades()[index].get("item_id", "")) == "spare_cart_parts":
			parts_offer_index = index
	assert(shop._rows.size() == 5 and parts_offer_index >= 0 and shop._rows[parts_offer_index].visible, "Asha must reveal Spare Cart Parts after Deru's introduction")
	var tooltip := get_first_node_in_group("item_tooltip") as ItemTooltip
	shop._show_shop_tooltip(shop._rows[parts_offer_index], "", str(shop._get_upgrades()[parts_offer_index]["description"]))
	assert(tooltip != null and tooltip._rank.text == "Spare Part", "The Spare Parts store hover must identify the object as Spare Part")
	shop._hide_shop_tooltip()
	for index in range(4):
		player.inventory_slots[index] = ItemPickup.make_item("potion_basic")
	var resources := get_first_node_in_group("resource_manager") as ResourceManager
	resources._amounts[&"fish"] = 30.0
	resources._ever_owned[&"fish"] = true
	assert(not shop.buy_upgrade(parts_offer_index) and resources.get_amount(&"fish") == 30, "A full inventory must prevent item purchases without charging")
	player.inventory_slots[0] = {}
	player.inventory_changed.emit()
	assert(shop.buy_upgrade(parts_offer_index) and player.has_inventory_item("spare_cart_parts") and resources.get_amount(&"fish") == 0)
	await create_timer(0.35).timeout
	var recruitment := _finish_dialogue(box)
	await process_frame
	assert(recruitment.contains("do it alone"), "Asha's recruitment invitation must play")
	assert(recruitment.contains("like that"), "Mira must accept Asha's recruitment")
	assert(asha.is_recruited(), "Asha must become a companion when the recruitment dialogue finishes")
	assert(not asha.is_in_group("shopkeepers") and not asha._shop.visible, "A recruited Asha must permanently stop being a shopkeeper")
	asha.open_shop()
	assert(not asha._shop.visible, "Asha's store must not reopen after she joins")
	var celebration := world.get_node_or_null("HUD/AshaJoinCelebration") as Control
	assert(celebration != null and celebration.get_node_or_null("JoinRibbon") != null and celebration.get_node_or_null("AshaJoinPortrait") != null and celebration.get_node_or_null("JoinBurst") != null, "Asha's recruitment must build the banner, portrait, and sun-ray fanfare")
	assert((celebration.get_node("JoinTitle") as Label).text == "Asha joins the party!", "Asha's fanfare must use the requested party text")
	assert(celebration.get_node_or_null("JoinSubtitle") == null and celebration.get_node_or_null("JoinAbilityFollow") == null and celebration.get_node_or_null("JoinAbilityHeal") == null, "The three extra lines beneath Asha's join title must be removed")
	assert(world.gameplay_paused and world.interaction_locked and not (celebration as RecruitmentCelebration).can_continue, "Asha's fanfare must hold gameplay and reject input during its first three seconds")
	assert(not (celebration as RecruitmentCelebration).try_dismiss(), "Asha's fanfare must not dismiss early")
	var join_ribbon := celebration.get_node("JoinRibbon") as ColorRect
	var join_portrait := celebration.get_node("AshaJoinPortrait") as TextureRect
	var join_burst := celebration.get_node("JoinBurst") as Node2D
	var join_title := celebration.get_node("JoinTitle") as Label
	var world_audio := world.get_node("GameAudio") as GameAudio
	assert(join_ribbon.position.x > 0.0 and is_zero_approx(join_portrait.modulate.a) and is_zero_approx(join_burst.modulate.a) and is_zero_approx(join_title.modulate.a), "The black banner must enter before every other fanfare element")
	assert(is_equal_approx(join_ribbon.size.y, 72.0) and join_portrait.position.y + join_portrait.size.y < join_ribbon.position.y, "The black banner must fit only the title while Asha stays above it")
	assert(world_audio._recruitment_music_ducked, "Biome music must begin fading out with Asha's black banner")
	var asha_join_sound_playing := false
	for audio_child in world_audio.get_children():
		if audio_child is AudioStreamPlayer and (audio_child as AudioStreamPlayer).stream == GameAudio.ASHA_JOINS_SFX:
			asha_join_sound_playing = true
	assert(asha_join_sound_playing, "AshaJoins must start with the black banner")
	await create_timer(0.55).timeout
	assert(is_zero_approx(join_ribbon.position.x) and is_zero_approx(join_portrait.modulate.a), "Asha's portrait must wait a quarter-second after the banner")
	assert(world_audio._grass_player.volume_db <= GameAudio.SILENT_DB + 0.1 and world_audio._forest_player.volume_db <= GameAudio.SILENT_DB + 0.1 and world_audio._desert_player.volume_db <= GameAudio.SILENT_DB + 0.1, "Biome music must fade out quickly during Asha's fanfare")
	await create_timer(0.45).timeout
	assert(join_portrait.modulate.a > 0.95 and is_zero_approx(join_burst.modulate.a), "The sun rays must wait a quarter-second after Asha's portrait")
	await create_timer(0.70).timeout
	assert(join_burst.modulate.a > 0.90 and is_zero_approx(join_title.modulate.a), "The title must wait a quarter-second after the sun rays")
	await create_timer(0.50).timeout
	assert(join_title.modulate.a > 0.95, "Asha's party title must pop in last")
	var sun_rotation_before := join_burst.rotation
	await create_timer(0.50).timeout
	assert(not is_equal_approx(join_burst.rotation, sun_rotation_before), "Asha's sun rays must keep rotating until dismissal")
	await create_timer(0.45).timeout
	assert((celebration as RecruitmentCelebration).can_continue and (celebration.get_node("JoinContinuePrompt") as Label).visible, "The continue prompt must appear after three seconds")
	var continue_key := InputEventKey.new()
	continue_key.pressed = true
	continue_key.keycode = KEY_A
	(celebration as RecruitmentCelebration)._input(continue_key)
	await create_timer(0.30).timeout
	assert(not world.gameplay_paused and not world.interaction_locked and not is_instance_valid(celebration), "Any key must dismiss the completed fanfare and resume gameplay")
	assert(not world_audio._recruitment_music_ducked and world_audio._grass_player.volume_db > GameAudio.SILENT_DB + 1.0, "Biome music must return after the player dismisses Asha's fanfare")
	var follow_start := Vector2i.ZERO
	var follow_target := Vector2i.ZERO
	var player_next := Vector2i.ZERO
	for cell in world.floor_layer.get_used_cells():
		if world.is_walkable(cell) and world.is_walkable(cell + Vector2i.LEFT) and world.is_walkable(cell + Vector2i.RIGHT) \
			and not world.is_cell_occupied(cell) and not world.is_cell_occupied(cell + Vector2i.LEFT) and not world.is_cell_occupied(cell + Vector2i.RIGHT):
			follow_start = cell + Vector2i.LEFT
			follow_target = cell
			player_next = cell + Vector2i.RIGHT
			break
	assert(follow_target != Vector2i.ZERO, "The follower test needs three open grid tiles")
	player.stop()
	asha.global_position = world.cell_to_world(follow_start)
	player.global_position = world.cell_to_world(follow_target)
	asha.set_recruited(true)
	assert(asha._follow_target_cell == FoxAsha.INVALID_CELL, "Asha must wait for the player to vacate a tile before following")
	assert(not world.get_occupied_cells(player).has(follow_start), "A recruited Asha must not block player pathfinding")
	assert(not world.get_occupied_cells(asha).has(follow_target), "The player must not block recruited Asha's pathfinding")
	assert(not world.find_path(player.global_position, asha.global_position, player).is_empty(), "The player must be able to pathfind through recruited Asha's tile")
	world._actor_cache_frame = -1
	world._refresh_actor_cache()
	assert(world.can_enter_position(player, asha.global_position) and world.can_enter_position(asha, player.global_position), "The player and recruited Asha must be able to pass through each other")
	asha.set_process(false)
	player.global_position = world.cell_to_world(player_next)
	asha._last_player_cell = follow_target
	asha._follow_target_cell = FoxAsha.INVALID_CELL
	asha._follow_player(0.0)
	assert(asha._follow_target_cell == follow_target, "Asha must target the exact tile the player just vacated")
	world._actor_cache_frame = -1
	world._refresh_actor_cache()
	var asha_before_follow := asha.global_position
	asha._follow_player(0.10)
	assert(asha._follow_target_cell == follow_target and is_equal_approx(asha.global_position.distance_to(asha_before_follow), player.move_speed * 0.10), "Asha must lerp directly toward the last vacated tile at player speed")
	var asha_after_first_step := asha.global_position
	asha.set_recruited(true)
	asha._follow_player(0.10)
	assert(asha._follow_target_cell == follow_target and asha.global_position.distance_to(asha_after_first_step) > 20.0, "Reapplying recruited story state must not reset Asha's active follow target")
	asha._follow_player(0.20)
	assert(asha.global_position == world.cell_to_world(follow_target), "Asha must finish centered on the exact last tile without overshooting")
	asha.set_process(true)

	var parts_index := -1
	for index in range(4):
		if str(player.inventory_slots[index].get("item_id", "")) == "spare_cart_parts":
			parts_index = index
	assert(parts_index >= 0 and not player.move_or_merge("inventory", parts_index, "trash", 0), "Spare Parts must not be removable")
	assert(story.interact_with(&"deru"))
	var dialogue_portrait := box.find_child("Portrait", true, false) as TextureRect
	var deru_recruitment := " " + box.get_current_text()
	assert(box.get_current_speaker() == "Mira" and dialogue_portrait.texture.resource_path == "res://Sprites/Fox.webp", "Mira must offer Deru the Spare Part first")
	box.finish_typing()
	box.advance()
	assert(dialogue_portrait.texture.resource_path == "res://Sprites/FoxDeruHappy.webp", "Deru's dialogue portrait must become happy when his repaired sprite does")
	deru_recruitment += _finish_dialogue(box)
	assert(deru_recruitment.contains("One spare part for deru!") and deru_recruitment.contains("truly indebted") and deru_recruitment.contains("rounding up all the creatures") and deru_recruitment.contains("got yourself a deal") and story.is_deru_quest_completed() and not player.has_inventory_item("spare_cart_parts"))
	assert((deru.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/FoxDeruHappy.webp", "Deru must permanently look happy after receiving the parts")
	assert((cart.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/FixedCart.webp", "The broken cart must permanently use its repaired sprite")
	assert((deru as FoxDeru).is_hunter_recruited(), "Giving Deru the parts must recruit him as a hunter")
	assert((deru as FoxDeru)._get_area_campfire() != null and (deru as FoxDeru)._get_area_campfire().area_id == 2, "Deru must hunt in and return to AreaID 2")
	var area_two_spawn: EnemySpawnPoint
	for spawn_node in get_nodes_in_group("enemy_spawns"):
		var candidate_spawn := spawn_node as EnemySpawnPoint
		if candidate_spawn.area_id == 2 and not FoxLio.EXCLUDED_ENEMY_TYPES.has(candidate_spawn.enemy_type):
			area_two_spawn = candidate_spawn
			break
	assert(area_two_spawn != null, "Deru needs an eligible AreaID 2 enemy spawn")
	var deru_target := (load("res://Scenes/chicken_enemy.tscn") as PackedScene).instantiate() as ChickenEnemy
	deru_target.setup(Vector2i.ZERO, 2, ChickenEnemy.REWARD_DAMAGE, [], &"gold_ore", FoxPlayer.COLOR_RED, 15, 1)
	deru_target.spawn_point = area_two_spawn
	world.add_child(deru_target)
	await process_frame
	deru_target.take_hunter_damage(deru as FoxDeru)
	assert(deru_target.health == 8 and deru_target._hunter_target == deru, "Deru must deal seven damage per hit to AreaID 2 enemies")
	deru_target.take_hunter_damage(deru as FoxDeru)
	assert(deru_target.health == 1, "Deru's second hit must deal another seven damage")
	deru_target.take_hunter_damage(deru as FoxDeru)
	assert((deru as FoxDeru)._get_reward_tooltip_copy().contains("+2 Red Damage") and (deru as FoxDeru)._get_reward_tooltip_copy().ends_with("Price: Free"), "A campfire helper tooltip must list rewards followed by the free price")
	for reward_index in range(13):
		var extra_reward := (load("res://Scenes/chicken_enemy.tscn") as PackedScene).instantiate() as ChickenEnemy
		extra_reward.setup(Vector2i.ZERO, 1, ChickenEnemy.REWARD_DAMAGE)
		(deru as FoxDeru).collect_enemy_reward(extra_reward)
		extra_reward.free()
	assert((deru as FoxDeru)._get_reward_tooltip_copy().ends_with("Price: 3 Gems"), "Deru's paid reward tooltip must show his three-Gem fee")
	resources._amounts[&"jewels"] = 3.0
	assert((deru as FoxDeru).can_pay_reward_fee() and (deru as FoxDeru).pay_reward_fee() and resources.get_amount(&"jewels") == 0, "Deru's paid handoff must cost exactly three Gems")
	(deru as FoxDeru).open_shop()
	assert(deru._shop == null, "Deru must not become a shop after the repair")
	var saved_story := story.get_save_data()
	(deru as FoxDeru).set_repaired(false)
	story.load_save_data(saved_story)
	assert((deru.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/FoxDeruHappy.webp" and (cart.get_node("Sprite2D") as Sprite2D).texture.resource_path == "res://Sprites/FixedCart.webp", "Reloading saved story state must restore both repaired sprites")
	assert((deru as FoxDeru).is_hunter_recruited(), "Reloading completed story state must restore Deru's helper role")
	(deru as FoxDeru).hunt_state = FoxLio.HuntState.WAITING_AT_CAMPFIRE
	var saved_deru := (deru as FoxDeru).get_save_data()
	(deru as FoxDeru).set_hunter_recruited(false)
	(deru as FoxDeru).load_save_data(saved_deru)
	assert((deru as FoxDeru).is_hunter_recruited() and (deru as FoxDeru).is_waiting_at_campfire(), "Deru's hunter and campfire state must persist in saves")

	player.inventory_slots[0] = ItemPickup.make_item("potion_basic")
	player.inventory_changed.emit()
	assert(player.move_or_merge("inventory", 0, "trash", 0) and str(player.trash_slots[0].get("item_id", "")) == "potion_basic")
	player.inventory_slots[0] = ItemPickup.make_item("potion_rope")
	assert(player.move_or_merge("inventory", 0, "trash", 0) and str(player.trash_slots[0].get("item_id", "")) == "potion_rope")
	assert(player.move_or_merge("trash", 0, "inventory", 0) and player.trash_slots[0].is_empty())

	story._seen_events.erase(&"asha_first_smooch")
	if box.is_open():
		_finish_dialogue(box)
	player.max_health = 100
	player.health_bar.max_value = 100
	player.health = 80
	assert(story.request_asha_first_smooch() and box.get_current_text() == "*Smooch*")
	_finish_dialogue(box)
	await create_timer(0.05).timeout
	assert(player.health == player.max_health, "The first smooch must fully heal at the start of the silent pause")
	assert(player.find_child("AshaHealPopup", false, false) is Label, "The first smooch must create its healing popup at the start of the pause")
	assert(player.fox_sprite.modulate != Color.WHITE, "The player's green healing flash must start with the silent pause")
	assert(asha.fox_sprite.position != Vector2.ZERO or not is_zero_approx(asha.fox_sprite.rotation), "Asha's smooch animation must start with the silent pause")
	await create_timer(0.20).timeout
	assert(world.gameplay_paused and world.interaction_locked, "The world must remain paused throughout Asha's silent one-second healing beat")
	await create_timer(0.80).timeout
	assert(player.health == player.max_health and box.is_open(), "The follow-up dialogue must open after the one-second pause")
	assert(_finish_dialogue(box).contains("feel a lot better"))
	player.health = maxi(1, floori(float(player.max_health) * 0.90))
	asha._smooch_cooldown_left = 0.0
	asha._smooch_in_progress = false
	var repeat_health := player.health
	var expected_smooch_healing := maxi(1, roundi(player.get_effective_passive_healing_per_second() * 10.0))
	asha._check_asha_healing(0.01)
	assert(player.health == mini(player.max_health, repeat_health + expected_smooch_healing), "Repeat smooches must heal ten seconds of effective regeneration")

	var enemy := (load("res://Scenes/chicken_enemy.tscn") as PackedScene).instantiate() as ChickenEnemy
	var player_cell := world.world_to_cell(player.global_position)
	enemy.setup(player_cell + Vector2i.RIGHT, 1, ChickenEnemy.REWARD_DAMAGE, [], &"gold_ore", FoxPlayer.COLOR_RED, 10, 5)
	enemy.global_position = world.cell_to_world(player_cell + Vector2i.RIGHT)
	world.add_child(enemy)
	await process_frame
	var paused_enemy_position := enemy.global_position
	var paused_health := player.health
	player._weapon_cooldowns[0] = 0.5
	assert(box.play([{"speaker": "Deru", "text": "Paused", "portrait": null}]))
	enemy._physics_process(1.0)
	player._physics_process(0.25)
	assert(enemy.global_position == paused_enemy_position and player.health == paused_health, "Enemy movement and combat must pause during dialogue")
	assert(is_equal_approx(player._weapon_cooldowns[0], 0.5), "Player combat cooldowns must pause during dialogue")
	box.close()

	print("PASS: dialogue pause, Deru quest, protected parts, recruitment, follower healing, shop, and trash slot work")
	world.queue_free()
	quit()
