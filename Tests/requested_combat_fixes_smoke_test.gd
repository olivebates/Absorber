extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var dialogue := world.get_node("HUD/DialogueBox") as DialogueBox
	dialogue.cancel()
	var player := world.player
	var enemy_cell := _find_combat_cell(world, player)
	assert(enemy_cell != Vector2i(-999999, -999999), "The snare regression needs two adjacent free cells")
	var player_cell := enemy_cell + Vector2i.RIGHT
	player.global_position = world.cell_to_world(player_cell)
	var enemy := load("res://Scenes/chicken_enemy.tscn").instantiate() as ChickenEnemy
	enemy.global_position = world.cell_to_world(enemy_cell)
	enemy.setup(enemy_cell, 1, ChickenEnemy.REWARD_DAMAGE, [], &"gold_ore", FoxPlayer.COLOR_RED, 20, 2, FoxPlayer.COLOR_RED, 0, FoxPlayer.COLOR_RED, false, [{
		"skill_id": ChickenEnemy.SKILL_CASCADING_SWEEP,
		"damage": 10,
		"damage_type": FoxPlayer.COLOR_RED,
		"cooldown": 0.0,
		"initial_offset": 0.0,
	}])
	world.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)
	assert(not player.unlocked_player_skills.has(FoxPlayer.SKILL_ROLL_CLOCKWISE), "The first-snare regression must begin without Quick Roll")
	enemy._begin_enemy_skill(0)
	enemy._update_active_enemy_skill(0.19)
	assert(not dialogue.is_open(), "The no-Quick-Roll snare warning must wait for 0.2 seconds")
	enemy._update_active_enemy_skill(0.01)
	assert(dialogue.is_open() and dialogue.get_current_text() == "Oh no, I'm snared, I can't move!", "The first snare without Quick Roll must show the requested dialogue")
	assert(enemy._skill_tutorial_paused and player.snare_without_quick_roll_tutorial_seen, "The warning must pause the fight and be marked as seen")
	var saved_player := player.get_save_data()
	player.snare_without_quick_roll_tutorial_seen = false
	assert(player.load_save_data(saved_player, 0) and player.snare_without_quick_roll_tutorial_seen, "The one-time no-Quick-Roll warning must survive save/load")
	dialogue.cancel()
	enemy._reset_enemy_skills()
	assert(player.unlock_player_skill(FoxPlayer.SKILL_ROLL_CLOCKWISE), "The Q-race regression must unlock Quick Roll")
	player.mana = 10
	player.cascading_sweep_skill_tutorial_seen = false
	enemy._begin_enemy_skill(0)
	enemy._update_active_enemy_skill(0.2)
	assert(not dialogue.is_open() and player.cast_player_skill_slot(0), "Quick Roll must cast before the delayed Q tutorial appears")
	assert(player.cascading_sweep_skill_tutorial_seen, "Casting Quick Roll during the delay must permanently consume the Q tutorial")
	await create_timer(0.31).timeout
	enemy._update_active_enemy_skill(0.2)
	assert(not dialogue.is_open(), "The delayed Q tutorial must not appear after Quick Roll was already pressed")
	enemy._reset_enemy_skills()
	enemy.enemy_skills = [{
		"skill_id": ChickenEnemy.SKILL_FAN_STRIKE_QUICK,
		"damage": 15,
		"damage_type": FoxPlayer.COLOR_YELLOW,
		"cooldown": 14.0,
		"initial_offset": 3.0,
	}, {
		"skill_id": ChickenEnemy.SKILL_DRIVING_STRIKE_QUICK,
		"damage": 10,
		"damage_type": FoxPlayer.COLOR_YELLOW,
		"cooldown": 14.0,
		"initial_offset": 10.0,
	}]
	enemy._reset_enemy_skills()
	enemy._update_enemy_skill_cooldowns(0.0, true)
	enemy._update_enemy_skill_cooldowns(3.0, true)
	assert(is_zero_approx(enemy._skill_cooldowns[0]) and is_equal_approx(enemy._skill_cooldowns[1], 7.0), "EnemyGuard11's two initial skill timers must advance together")
	enemy._skill_cooldowns[0] = 14.0
	enemy._movement_mode = ChickenEnemy.MovementMode.CHASE
	var combat_sequence_active := false or enemy._movement_mode == ChickenEnemy.MovementMode.CHASE
	enemy._update_enemy_skill_cooldowns(7.0, combat_sequence_active)
	assert(is_equal_approx(enemy._skill_cooldowns[0], 7.0) and is_zero_approx(enemy._skill_cooldowns[1]), "Dodging out of adjacency during pursuit must not reset EnemyGuard11's second ability")
	assert(enemy._try_begin_enemy_skill(true) and enemy._active_skill_slot == 1, "EnemyGuard11 must use the second ready ability instead of restarting the first ability's timer")
	print("PASS: first snare without Quick Roll pauses after 0.2 seconds and persists")
	print("PASS: Quick Roll before the delayed Q prompt consumes that tutorial")
	print("PASS: EnemyGuard11 preserves both skill timers through dodge and pursuit")
	world.queue_free()
	await process_frame
	quit()


func _find_combat_cell(world: WorldNavigation, player: FoxPlayer) -> Vector2i:
	for raw_cell in world._walkable_cells.keys():
		var cell := raw_cell as Vector2i
		if world.is_walkable(cell + Vector2i.RIGHT) and world.is_walkable(cell + Vector2i.DOWN) \
				and not world.is_cell_occupied(cell + Vector2i.DOWN, player) \
				and not world.is_cell_occupied(cell, player) \
				and not world.is_cell_occupied(cell + Vector2i.RIGHT, player):
			return cell
	return Vector2i(-999999, -999999)
