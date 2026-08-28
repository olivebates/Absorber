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
	var game_audio := get_first_node_in_group("game_audio") as GameAudio
	assert(game_audio != null and GameAudio.SKILL_UNAVAILABLE_SFX.resource_path.ends_with("sfxSkillUnavailable.ogg") \
		and GameAudio.PLAYER_ROLL_SFX.resource_path.ends_with("sfxPlayerRoll.ogg") and GameAudio.CHEST_VISIBLE_SFX.resource_path.ends_with("sfxChestVisible.ogg"), "Requested skill, roll, and chest reveal sounds must be loaded by GameAudio")
	game_audio._last_enemy_charge_frame = -1
	var charge_players_before := _count_audio_players(game_audio, GameAudio.ENEMY_CHARGE_SFX)
	game_audio.play_enemy_charge()
	game_audio.play_enemy_charge()
	assert(_count_audio_players(game_audio, GameAudio.ENEMY_CHARGE_SFX) == charge_players_before + 1, "Enemy charge feedback must not start multiple copies on the same rendered frame")
	var big_attack_players_before := _count_audio_players(game_audio, GameAudio.BIG_ATTACK_SFX)
	game_audio.play_big_attack()
	game_audio.play_big_attack()
	assert(_count_audio_players(game_audio, GameAudio.BIG_ATTACK_SFX) == big_attack_players_before + 2, "Every resolving enemy-skill tile must play its own sfxBigAttack, even on the same frame")

	var entrance := world.get_node("MossrootGrottoEntrance") as DungeonEntrance
	assert(entrance._tooltip_difficulty.text == entrance.DIFFICULTY_NAMES[entrance.difficulty - 1], "Dungeon hover cards must show only the named difficulty")
	assert(entrance._tooltip_cleared_label.get_index() == 1 and entrance._tooltip_difficulty.get_index() == 2, "The cleared badge must sit directly under the dungeon title and above its difficulty")
	var cleared_style := entrance._tooltip_cleared_label.get_theme_stylebox("normal") as StyleBoxFlat
	assert(cleared_style.border_width_left == 1 and cleared_style.corner_radius_top_left > 0 and cleared_style.border_color == Color.WHITE, "The cleared badge must use a rounded one-pixel white outline")
	var meter := entrance._tooltip_difficulty.get_parent().get_child(3) as Control
	var connector := meter.get_child(0) as ColorRect
	assert(not connector.visible and is_equal_approx((meter.get_child(2) as Label).position.x - (meter.get_child(1) as Label).position.x, 16.0), "Difficulty dots must have no connector and use the tighter spacing")
	assert(not entrance._tooltip_production.get_parent().visible, "The Cave Moss instruction row must be removed from the visible dungeon tooltip")

	var bat := load("res://Scenes/bat_enemy.tscn").instantiate() as ChickenEnemy
	var millipede := load("res://Scenes/millipede_enemy.tscn").instantiate() as ChickenEnemy
	assert((bat.get_node("ChickenSprite") as Sprite2D).texture.resource_path == "res://Sprites/Bat.webp", "The Bat enemy must use the supplied Bat sprite")
	assert((millipede.get_node("ChickenSprite") as Sprite2D).texture.resource_path == "res://Sprites/Millipede.webp", "The Millipede enemy must use the supplied Millipede sprite")
	bat.free()
	millipede.free()
	var spawn := EnemySpawnPoint.new()
	spawn.enemy_skill_1 = ChickenEnemy.SKILL_CRUSHING_BLOW
	spawn.enemy_skill_1_damage_type = FoxPlayer.COLOR_BLUE
	spawn.enemy_skill_1_initial_cooldown_offset = 1.5
	spawn.enemy_skill_2 = ChickenEnemy.SKILL_CASCADING_SWEEP
	var configured_skills := spawn._get_enemy_skills()
	assert(configured_skills.size() == 2 and int(configured_skills[0].damage_type) == FoxPlayer.COLOR_BLUE, "Enemy spawns must expose and compile up to three typed skill slots")
	assert(is_equal_approx(float(configured_skills[0].initial_offset), 1.5), "Enemy skill initial cooldown offsets must remain spawn-configurable")
	spawn.free()
	var snakemouth := load("res://Scenes/dungeon1_Snakemouth.tscn").instantiate() as DungeonLevel
	var skilled_guard := snakemouth.get_node("EntryGuard6") as EnemySpawnPoint
	var first_spider := snakemouth.get_node("EntryGuard11") as EnemySpawnPoint
	var story := world.get_node("StoryManager") as StoryManager
	story._connect_enemy_story_spawn(first_spider)
	var first_spider_lines := story._get_event_dialogue(&"first_spider_killed")
	assert(first_spider.enemy_killed.is_connected(story._on_spider_killed) and first_spider_lines.size() == 2 \
		and first_spider_lines[0].text == "Phew, that was a close one." \
		and first_spider_lines[1].text == "I should keep an eye out on my mana!", "The first Spider kill must trigger Mira's two-line mana warning")
	var guard_eleven_skills := first_spider._get_enemy_skills()
	assert(guard_eleven_skills.size() == 2 and int(guard_eleven_skills[0].skill_id) == ChickenEnemy.SKILL_FAN_STRIKE_QUICK \
		and int(guard_eleven_skills[1].skill_id) == ChickenEnemy.SKILL_DRIVING_STRIKE_QUICK, "EnemyGuard11 must retain both configured abilities")
	var entry_guard_skills := skilled_guard._get_enemy_skills()
	assert(entry_guard_skills.size() == 1 and int(entry_guard_skills[0].skill_id) == ChickenEnemy.SKILL_CRUSHING_BLOW, "Snakemouth's configured skilled guard must compile its Crushing Blow skill")
	assert(is_equal_approx(float(entry_guard_skills[0].initial_offset), 3.0) and is_equal_approx(float(entry_guard_skills[0].cooldown), 7.0), "The skilled guard's authored initial delay and recurring cooldown must be preserved")
	snakemouth.free()

	var player := world.player
	player.max_health = 100
	player.health = 100
	player.health_bar.max_value = 100
	player.health_bar.value = 100
	var enemy := load("res://Scenes/chicken_enemy.tscn").instantiate() as ChickenEnemy
	var enemy_cell := Vector2i.ZERO
	for raw_cell in world._walkable_cells.keys():
		var candidate := raw_cell as Vector2i
		if world.is_walkable(candidate + Vector2i.RIGHT) and world.is_walkable(candidate + Vector2i.DOWN) \
				and world.is_walkable(candidate + Vector2i.RIGHT + Vector2i.UP) and world.is_walkable(candidate + Vector2i.RIGHT + Vector2i.DOWN) \
			and not world.is_cell_occupied(candidate, player) and not world.is_cell_occupied(candidate + Vector2i.RIGHT, player) \
				and not world.is_cell_occupied(candidate + Vector2i.RIGHT + Vector2i.UP, player) and not world.is_cell_occupied(candidate + Vector2i.RIGHT + Vector2i.DOWN, player):
			enemy_cell = candidate
			break
	var player_cell := enemy_cell + Vector2i.RIGHT
	player.global_position = world.cell_to_world(player_cell)
	enemy.global_position = world.cell_to_world(enemy_cell)
	enemy.setup(enemy_cell, 1, ChickenEnemy.REWARD_DAMAGE, [], &"gold_ore", FoxPlayer.COLOR_RED, 20, 2, FoxPlayer.COLOR_RED, 0, FoxPlayer.COLOR_RED, false, [{
		"skill_id": ChickenEnemy.SKILL_CRUSHING_BLOW, "damage": 0, "damage_type": FoxPlayer.COLOR_BLUE, "cooldown": 0.0, "initial_offset": 0.0,
	}])
	world.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)
	enemy.enemy_skills[0]["initial_offset"] = 1.5
	enemy._reset_enemy_skills()
	enemy._update_enemy_skill_cooldowns(0.0, true)
	assert(is_equal_approx(enemy._skill_cooldowns[0], 1.5), "A first engagement must use only the skill's initial delay because its regular cooldown is ready")
	enemy._update_enemy_skill_cooldowns(0.0, false)
	assert(not enemy._combat_skills_initialized and is_zero_approx(enemy._skill_cooldowns[0]), "Leaving combat must reset cooldown and first-engagement offset state")
	enemy.enemy_skills[0]["initial_offset"] = 0.0
	enemy._reset_enemy_skills()
	enemy._update_enemy_skill_cooldowns(0.0, true)
	assert(is_zero_approx(enemy._skill_cooldowns[0]) and enemy._try_begin_enemy_skill(true), "A skill without an initial delay must be ready immediately when combat begins")
	enemy._finish_enemy_skill()
	enemy._begin_enemy_skill(0)
	assert(enemy._active_skill_windup == 2.0 and enemy._active_skill_targets.size() == 1, "Crushing Blow must lock the front tile for a two-second windup")
	assert(enemy.chicken_sprite.modulate.is_equal_approx(Color.WHITE.lerp(FoxPlayer.DAMAGE_COLORS[FoxPlayer.COLOR_BLUE], 0.25)), "An enemy winding up a skill must take on a 25-percent tint of that skill's damage color")
	var crushing_telegraph := enemy._active_skill_targets[0].telegraph as Node2D
	var crushing_fill := crushing_telegraph.get_node("Fill") as Polygon2D
	var crushing_outline := crushing_telegraph.get_node("FlashingOutline") as Line2D
	assert(crushing_fill.scale.length() < 0.01 and is_equal_approx(crushing_fill.modulate.a, 0.65), "Enemy skill fills must begin at the tile center with 0.65 alpha")
	assert(crushing_outline.default_color == ChickenEnemy.DAMAGE_COLORS[FoxPlayer.COLOR_BLUE] and is_equal_approx(crushing_outline.modulate.a, 0.75), "Enemy skill target outlines must flash in the configured damage color at 0.75 alpha")
	assert(enemy._skill_name_label != null and enemy._skill_name_label.text == "Big Attack", "Every charging enemy skill must use the Big Attack label")
	enemy._update_active_enemy_skill(0.39)
	assert(not dialogue.is_open(), "The first enemy-skill tutorial must wait for its full 0.4-second delay")
	enemy._update_active_enemy_skill(0.01)
	assert(dialogue.is_open() and dialogue.get_current_text() == ChickenEnemy.ENEMY_SKILL_MOVE_TUTORIAL_TEXT, "The first enemy skill must pause after 0.4 seconds for Mira's movement warning")
	assert(dialogue._action_mode == DialogueBox.ACTION_TILE_CHOICE and dialogue._tile_choice_buttons.size() == 2 and enemy._skill_tutorial_paused, "Only the two glowing side tiles must resolve the first enemy-skill tutorial")
	var space_attempt := InputEventKey.new()
	space_attempt.keycode = KEY_SPACE
	space_attempt.pressed = true
	dialogue._unhandled_key_input(space_attempt)
	assert(dialogue.is_open() and is_equal_approx(enemy._active_skill_elapsed, 0.4), "Space and ordinary dialogue advancement must not close an action-locked tutorial")
	var tutorial_side_cell := dialogue._tile_choice_cells[0]
	player.follow_enemy(enemy)
	assert(player._attack_target == enemy, "The movement tutorial regression must begin with the click-to-chase target still active")
	dialogue._on_tile_choice_pressed(tutorial_side_cell)
	assert(not dialogue.is_open() and player.is_moving() and player._attack_target == null and player.enemy_skill_move_tutorial_seen, "Clicking either yellow side tile must close the tutorial, clear enemy chase, and make Mira step there")
	await create_timer(0.3).timeout
	assert(world.world_to_cell(player.global_position) == tutorial_side_cell, "An active click-to-chase target must not overwrite the selected tutorial side-step")
	player.stop()
	player.global_position = world.cell_to_world(player_cell)
	enemy._reset_enemy_skills()
	enemy._begin_enemy_skill(0)
	enemy._update_active_enemy_skill(0.5)
	assert(enemy.chicken_sprite.position != Vector2.ZERO and enemy.chicken_sprite.scale != Vector2.ONE, "Crushing Blow must visibly pull back and squash during anticipation")
	var health_before := player.health
	enemy._update_active_enemy_skill(1.51)
	assert(player.health == health_before - 10, "Crushing Blow must deal five times enemy damage on its fixed front tile")
	var skill_popup := world.get_node_or_null("SkillDamagePopup") as DamagePopup
	var skill_damage_label := skill_popup.get_child(0).get_child(1) as Label if skill_popup != null else null
	assert(skill_popup != null and skill_popup.emphasized and skill_damage_label != null and skill_damage_label.get_theme_font_size("font_size") == 30, "Enemy skill hits must use a larger, faster damage popup")
	assert(enemy._last_skill_resolution_feedback == ["hit"] and player.fox_sprite.position != Vector2.ZERO, "A skill hit must trigger its impact result and recoil Mira")
	# Leave scheduling headroom around the exact 0.8-second tween boundary.
	await create_timer(0.70).timeout
	assert(is_instance_valid(skill_popup) and is_equal_approx(skill_popup.modulate.a, 1.0), "A skill damage number must remain fully visible for 0.8 seconds")
	await create_timer(0.36).timeout
	assert(not is_instance_valid(skill_popup), "A skill damage number may fade and clean itself up after its 0.8-second hold")

	enemy.enemy_skills = [{"skill_id": ChickenEnemy.SKILL_CASCADING_SWEEP, "damage": 0, "damage_type": FoxPlayer.COLOR_RED, "cooldown": 0.0, "initial_offset": 0.0}]
	enemy._skill_cooldowns = [0.0]
	enemy._begin_enemy_skill(0)
	assert(enemy._active_skill_windup == 1.0 and enemy._active_skill_targets.size() == 4, "Cascading Sweep must signal the front tile and its three outward neighbors")
	enemy._update_active_enemy_skill(0.19)
	assert(not dialogue.is_open(), "The no-Quick-Roll snare warning must wait for 0.2 seconds")
	enemy._update_active_enemy_skill(0.01)
	assert(dialogue.is_open() and dialogue.get_current_text() == ChickenEnemy.SNARE_WITHOUT_QUICK_ROLL_TUTORIAL_TEXT \
		and enemy._skill_tutorial_paused, "The first snare without Quick Roll must pause the fight and warn Mira")
	dialogue.finish_typing()
	dialogue.advance()
	enemy._resume_skill_telegraph_tweens()
	var first_dodged_telegraph := enemy._active_skill_targets[1].telegraph as Node2D
	enemy._update_active_enemy_skill(0.8)
	var delayed_targets := 0
	for target_data in enemy._active_skill_targets:
		if not bool(target_data.resolved):
			delayed_targets += 1
	assert(delayed_targets == 3, "The latter three sweep tiles must retain their 0.1-second cascade delay")
	enemy._update_active_enemy_skill(0.09)
	assert(enemy._active_skill_impact_count == 2 and (first_dodged_telegraph.get_node("Fill") as Polygon2D).color == Color.WHITE, "A dodged sweep tile must flash white and resolve as the next distinct wave")
	enemy._update_active_enemy_skill(0.08)
	assert(enemy._active_skill_impact_count == 3, "Cascading Sweep must resolve its third tile as a separate wave")
	enemy._update_active_enemy_skill(0.08)
	assert(enemy._active_skill_slot == -1, "Enemy movement lock must end after every delayed tile resolves")

	var toolbar := world.get_node("HUD/SkillToolbar") as SkillToolbar
	assert(not toolbar.visible and not player.mana_bar.visible, "Skill and mana bars must begin hidden")
	assert(player.unlock_player_skill(FoxPlayer.SKILL_ROLL_CLOCKWISE), "The first player skill must be unlockable")
	await process_frame
	assert(toolbar.visible and player.mana_bar.visible, "Unlocking the first skill must reveal both the toolbar and blue mana bar")
	assert(toolbar._player_row.get_child_count() == 5, "The player skill bar must contain four slots and its picker button")
	assert((toolbar._player_row.get_child(0) as SkillSlot).size == Vector2(42, 42) and (toolbar._player_row.get_child(0) as SkillSlot)._feedback_label.get_parent() == toolbar, "Flying cast text must live outside the slot layout so slots remain 42 by 42")
	assert((toolbar._player_row.get_child(0) as SkillSlot)._hotkey_label.text == "Q" and SkillToolbar.PLAYER_SHORTCUT_LABELS == ["Q", "W", "E", "R"], "Player skill shortcuts must be Q, W, E, and R")
	assert(dialogue._get_vertical_offsets().y == DialogueBox.BOTTOM_BOTTOM - DialogueBox.SKILL_TOOLBAR_OFFSET, "Unlocking the skill bar must raise dialogue above it")
	assert(dialogue.play([{"speaker": "Mira", "text": "Skills ready.", "portrait": null}]), "Dialogue must still open after the skill bar unlocks")
	await create_timer(0.2).timeout
	assert(is_equal_approx(dialogue._bottom.offset_bottom, DialogueBox.BOTTOM_BOTTOM - DialogueBox.SKILL_TOOLBAR_OFFSET), "Open dialogue must sit above the unlocked skill bar")
	dialogue.cancel()
	for index in range(1, 4):
		var locked_slot := toolbar._player_row.get_child(index) as SkillSlot
		assert(locked_slot.locked and locked_slot._icon.texture.resource_path == "res://Sprites/IconSkillBook.webp", "The latter three player skill slots must show the skill book beneath their locks")

	player.max_mana = 30
	player.mana = 30
	assert(is_equal_approx(float(FoxPlayer.SKILL_DATA[FoxPlayer.SKILL_ROLL_CLOCKWISE]["cooldown"]), 4.0) \
		and is_equal_approx(float(FoxPlayer.SKILL_DATA[FoxPlayer.SKILL_ROLL_BACK]["cooldown"]), 4.0) \
		and is_equal_approx(float(FoxPlayer.SKILL_DATA[FoxPlayer.SKILL_ROLL_ARC]["cooldown"]), 4.0), "Quick Roll, Back Roll, and Arc Roll must all have four-second cooldowns")
	assert(int(FoxPlayer.SKILL_DATA[FoxPlayer.SKILL_ROLL_CLOCKWISE]["mana"]) == 5 \
		and int(FoxPlayer.SKILL_DATA[FoxPlayer.SKILL_ROLL_BACK]["mana"]) == 5 \
		and int(FoxPlayer.SKILL_DATA[FoxPlayer.SKILL_ROLL_ARC]["mana"]) == 5, "Every player rolling skill must cost five mana")
	assert((FoxPlayer.SKILL_DATA[FoxPlayer.SKILL_ROLL_BACK]["icon"] as Texture2D).resource_path == "res://Sprites/iconBackwardsRoll.webp", "Back Roll must use its supplied backwards-roll icon")
	player._skill_cooldowns[FoxPlayer.SKILL_ROLL_CLOCKWISE] = 0.0
	player.follow_enemy(enemy)
	var relative := world.world_to_cell(player.global_position) - world.world_to_cell(enemy.global_position)
	var expected_roll_cell := world.world_to_cell(enemy.global_position) + Vector2i(-relative.y, relative.x)
	var expected_counter_clockwise_cell := world.world_to_cell(enemy.global_position) + Vector2i(relative.y, -relative.x)
	var clockwise_blocker := Node2D.new()
	clockwise_blocker.add_to_group("solid_walls")
	clockwise_blocker.global_position = world.cell_to_world(expected_roll_cell)
	world.add_child(clockwise_blocker)
	var fallback_plan := player._build_player_skill_cast_plan(FoxPlayer.SKILL_ROLL_CLOCKWISE)
	assert(not fallback_plan.is_empty() and world.world_to_cell(fallback_plan["destination"]) == expected_counter_clockwise_cell and is_equal_approx(float(fallback_plan["arc_angle"]), -PI * 0.5), "Quick Roll must try the counter-clockwise tile when its clockwise destination is blocked")
	var counter_clockwise_blocker := Node2D.new()
	counter_clockwise_blocker.add_to_group("solid_walls")
	counter_clockwise_blocker.global_position = world.cell_to_world(expected_counter_clockwise_cell)
	world.add_child(counter_clockwise_blocker)
	assert(player._build_player_skill_cast_plan(FoxPlayer.SKILL_ROLL_CLOCKWISE).is_empty() and player.get_last_skill_cast_failure() == "Blocked", "Quick Roll must report Blocked when both side tiles are unavailable")
	clockwise_blocker.free()
	counter_clockwise_blocker.free()
	var old_shortcut := InputEventKey.new()
	old_shortcut.keycode = KEY_1
	old_shortcut.pressed = true
	toolbar._unhandled_input(old_shortcut)
	assert(not player._skill_casting and player.mana == 30, "Number keys must no longer cast player skills")
	player.mana = 1
	player._skill_cooldowns[FoxPlayer.SKILL_ROLL_CLOCKWISE] = 7.0
	enemy._begin_enemy_skill(0)
	player.mana = 30
	player._skill_cooldowns[FoxPlayer.SKILL_ROLL_CLOCKWISE] = 0.0
	assert(toolbar._try_cast_player_skill(0), "Q must be able to cast Quick Roll during the tutorial delay")
	assert(player.cascading_sweep_skill_tutorial_seen, "Quick Roll before the delayed Q prompt must consume the tutorial permanently")
	await create_timer(0.31).timeout
	enemy._update_active_enemy_skill(0.4)
	assert(not dialogue.is_open(), "The Q tutorial must not open after Quick Roll was already pressed during its delay")
	player.cascading_sweep_skill_tutorial_seen = false
	enemy._reset_enemy_skills()
	player.global_position = world.cell_to_world(player_cell)
	player.mana = 1
	player._skill_cooldowns[FoxPlayer.SKILL_ROLL_CLOCKWISE] = 7.0
	enemy._begin_enemy_skill(0)
	enemy._update_active_enemy_skill(0.39)
	assert(not dialogue.is_open(), "The Cascading Sweep tutorial must wait for its full 0.4-second delay")
	enemy._update_active_enemy_skill(0.01)
	assert(dialogue.is_open() and dialogue.get_current_text() == ChickenEnemy.CASCADING_SWEEP_TUTORIAL_TEXT and dialogue._action_mode == DialogueBox.ACTION_KEY, "The first Cascading Sweep after a skill unlock must pause for the Q-only dodge tutorial")
	assert(player.mana == 5 and is_zero_approx(float(player._skill_cooldowns[FoxPlayer.SKILL_ROLL_CLOCKWISE])), "Opening the Cascading Sweep tutorial must immediately provide at least five mana and clear the Q skill cooldown")
	dialogue._unhandled_key_input(space_attempt)
	assert(dialogue.is_open() and not player._skill_casting, "Only Q may close the Cascading Sweep tutorial")
	var quick_roll_shortcut := InputEventKey.new()
	quick_roll_shortcut.keycode = KEY_Q
	quick_roll_shortcut.pressed = true
	var roll_players_before := _count_audio_players(game_audio, GameAudio.PLAYER_ROLL_SFX)
	dialogue._unhandled_key_input(quick_roll_shortcut)
	assert(not dialogue.is_open() and player._skill_casting and player.cascading_sweep_skill_tutorial_seen, "Q must close the tutorial and instantly cast Quick Roll")
	assert(_count_audio_players(game_audio, GameAudio.PLAYER_ROLL_SFX) == roll_players_before + 1, "Using any rolling skill must play its roll sound")
	var quick_slot := toolbar._player_row.get_child(0) as SkillSlot
	assert(quick_slot._feedback_tween != null and player._skill_visual_tween != null and player.mana_bar.scale != Vector2.ONE, "A successful shortcut cast must press and flash its slot while Mira and the mana bar anticipate the skill")
	var rolling_health := player.health
	player.take_damage(50, FoxPlayer.COLOR_RED)
	assert(player.health == rolling_health, "Mira must be invulnerable throughout the 0.3-second roll")
	await create_timer(0.15).timeout
	var straight_midpoint := player._roll_start.lerp(player._roll_end, 0.5)
	assert(player.global_position.distance_to(straight_midpoint) > 10.0, "Quick Roll must visibly arc around its enemy instead of travelling straight between tiles")
	assert(is_instance_valid(player._roll_trail) and player._roll_trail.get_point_count() > 2 and get_nodes_in_group("skill_roll_afterimages").size() > 0, "Rolling must draw a motion trail and translucent afterimages")
	await create_timer(0.20).timeout
	assert(world.world_to_cell(player.global_position) == expected_roll_cell and player.mana == 0, "Quick Roll must finish on the next clockwise adjacent tile and spend the five tutorial mana")
	enemy._reset_enemy_skills()
	var unavailable_players_before := _count_audio_players(game_audio, GameAudio.SKILL_UNAVAILABLE_SFX)
	assert(not toolbar._try_cast_player_skill(0) and quick_slot._feedback_label.visible and quick_slot._feedback_label.text == "Cooling Down", "Failed casts must shake the slot and explain why they failed")
	assert(_count_audio_players(game_audio, GameAudio.SKILL_UNAVAILABLE_SFX) == unavailable_players_before + 1, "A failed player-skill attempt must play its unavailable sound")
	assert(quick_slot.size == Vector2(42, 42), "Long flying feedback text must not resize its skill slot")
	player._skill_cooldowns[FoxPlayer.SKILL_ROLL_CLOCKWISE] = 0.0
	quick_slot._process(0.0)
	assert(quick_slot._feedback_label.text == "Ready" and quick_slot._feedback_tween != null, "A completed cooldown must pulse its slot and announce that it is ready")

	assert(player.unlock_player_skill(FoxPlayer.SKILL_YELLOW_GUARD), "Golden Guard must be unlockable")
	player.equip_player_skill(0, FoxPlayer.SKILL_YELLOW_GUARD)
	player._skill_cooldowns[FoxPlayer.SKILL_YELLOW_GUARD] = 0.0
	player.mana = 15
	assert(toolbar._try_cast_player_skill(0), "Golden Guard must cast for fifteen mana")
	assert(player._yellow_guard_ring.scale.x < 0.5 and player.fox_sprite.scale != Vector2.ONE, "Golden Guard must begin with a crouch and an expanding ring")
	var guarded_health := player.health
	player.take_damage(50, FoxPlayer.COLOR_YELLOW)
	assert(player.health == guarded_health and player.mana == 0, "Golden Guard must block all yellow damage for its active second")
	assert(player.has_node("YellowGuardBlockFlash"), "Blocking yellow damage must produce a bright expanding guard flash")

	var chest := load("res://Scenes/dungeon_chest.tscn").instantiate() as DungeonChest
	chest.reward_type = DungeonChest.RewardType.SKILL
	chest.reward_skill = 2
	world.add_child(chest)
	chest._grant_reward(player)
	assert(player.unlocked_player_skills.has(FoxPlayer.SKILL_ROLL_BACK), "Dungeon chests must be able to grant configured player skills")
	chest.queue_free()

	var asha := world.get_node("FoxAsha") as FoxAsha
	asha.set_recruited(true)
	toolbar._process(0.0)
	assert(toolbar._asha_panel.visible and toolbar._asha_row.get_child_count() == 4, "Recruiting Asha must add her four-slot skill bar to the right")
	assert((toolbar._asha_row.get_child(0) as SkillSlot)._icon.texture.resource_path == "res://Sprites/skillHeal.webp", "Healing Smooch must occupy Asha's first skill slot")

	var reset_stats := (world.get_node("DungeonManager") as DungeonManager)._make_reset_stats()
	assert(int(reset_stats.health) == 10 and int(reset_stats.max_health) == 10 and int(reset_stats.mana) == 10 and reset_stats.defense == [0, 0, 0], "Dungeon entry must reset Mira to ten health and mana without granting three unintended defense colors")
	var saved := player.get_save_data()
	player.mana = 1
	player.unlocked_player_skills.clear()
	player.enemy_skill_move_tutorial_seen = false
	player.cascading_sweep_skill_tutorial_seen = false
	assert(player.load_save_data(saved, 0) and player.mana == 0 and player.unlocked_player_skills.has(FoxPlayer.SKILL_ROLL_BACK) \
		and player.snare_without_quick_roll_tutorial_seen, "Mana, skills, cooldowns, and the no-Quick-Roll snare warning must survive save/load")
	assert(player.enemy_skill_move_tutorial_seen and player.cascading_sweep_skill_tutorial_seen, "Both one-time enemy-skill tutorials must survive save/load")

	var manager := world.get_node("DungeonManager") as DungeonManager
	var unfinished_snapshot := {"spawns": {"Boss": [1000, []]}, "chests": {"Chest": true}, "locked_doors": {}, "explored": [[1, 2]], "cleared": false}
	manager.dungeon_states = {
		"unfinished": {"keys": 1, "stats": reset_stats.duplicate(true), "transferred_stats": reset_stats.duplicate(true), "level": unfinished_snapshot, "cleared": false},
		"completed": {"level": unfinished_snapshot, "cleared": true},
		"without_snapshot": {"stats": reset_stats.duplicate(true), "cleared": false},
	}
	var save_system := world.get_node("SaveSystem") as SaveSystem
	var encoded := save_system.create_save_string(1000)
	manager.dungeon_states = {"stale": {"level": {"stale": true}, "cleared": false}}
	var preload_reset_observed := [false]
	manager.dungeons_reset_for_save_load.connect(func() -> void:
		preload_reset_observed[0] = manager.dungeon_states.is_empty()
	, CONNECT_ONE_SHOT)
	assert(save_system.load_save_string(encoded, 1000), "The complete save file must load with dungeon state")
	assert(bool(preload_reset_observed[0]), "Every dungeon must reset before the new save begins applying its world state")
	assert(not manager.dungeon_states.has("stale") and not manager.dungeon_states.has("without_snapshot"), "Loading a save must reset stale dungeons and dungeons without a saved snapshot")
	var loaded_snapshot := (manager.dungeon_states["unfinished"] as Dictionary).get("level", {}) as Dictionary
	assert(bool((loaded_snapshot.get("chests", {}) as Dictionary).get("Chest", false)) and (loaded_snapshot.get("spawns", {}) as Dictionary).has("Boss") and (loaded_snapshot.get("explored", []) as Array).size() == 1, "Loading a save must restore unfinished dungeon snapshots")
	assert((manager.dungeon_states["completed"] as Dictionary) == {"cleared": true}, "Completed dungeons must load using only their completion flag")
	var saved_dungeons := manager.get_save_data()[1] as Dictionary
	assert((saved_dungeons["completed"] as Dictionary) == {"cleared": true}, "Completed dungeon snapshots must be omitted from subsequent saves")

	print("Skill system smoke test passed")
	enemy.queue_free()
	world.queue_free()
	await process_frame
	await process_frame
	quit()


func _count_audio_players(audio: GameAudio, stream: AudioStream) -> int:
	var count := 0
	for child in audio.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).stream == stream:
			count += 1
	return count
