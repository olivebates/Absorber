extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := (load("res://Scenes/world.tscn") as PackedScene).instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var dialogue := world.get_node("HUD/DialogueBox") as DialogueBox
	if dialogue.is_open():
		dialogue.cancel()
	var player := world.player
	player.set_physics_process(false)
	player.enemy_skill_move_tutorial_seen = true
	player.max_health = 100
	player.health = 100
	player.health_bar.max_value = 100
	player.health_bar.value = 100
	var player_cell := _find_fixture_cell(world, player)
	assert(player_cell != Vector2i(-999999, -999999), "The skill test needs a walkable player tile beside a wall and an enemy tile")
	var enemy_cell := player_cell + Vector2i.LEFT
	player.global_position = world.cell_to_world(player_cell)
	world.sync_navigation_actor(player)

	var enemy := (load("res://Scenes/chicken_enemy.tscn") as PackedScene).instantiate() as ChickenEnemy
	enemy.global_position = world.cell_to_world(enemy_cell)
	enemy.setup(enemy_cell, 1, ChickenEnemy.REWARD_DAMAGE, [], &"gold_ore", FoxPlayer.COLOR_RED, 100, 2, FoxPlayer.COLOR_RED)
	world.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)

	var charged_data: Dictionary = FoxPlayer.SKILL_DATA[FoxPlayer.SKILL_CHARGED_STRIKE]
	assert(int(charged_data.mana) == 10 and is_equal_approx(FoxPlayer.CHARGED_STRIKE_DURATION, 3.0) \
		and FoxPlayer.CHARGED_STRIKE_DAMAGE_MULTIPLIER == 7, "Charged Strike must cost 10 mana, charge for 3 seconds, and use a 7x hit multiplier")
	player.damage_by_color[FoxPlayer.COLOR_RED][0] = 4
	player.max_mana = 10
	player.mana = 10
	assert(player.unlock_player_skill(FoxPlayer.SKILL_CHARGED_STRIKE))
	player.equipped_player_skills[0] = FoxPlayer.SKILL_CHARGED_STRIKE
	assert(player.cast_player_skill_slot(0) and player.mana == 0 and player._skill_casting, "Charged Strike must spend its mana and begin charging")
	await create_timer(2.85).timeout
	assert(enemy.health == 100 and player._skill_casting, "Charged Strike must not deal damage before its three-second charge completes")
	await create_timer(0.25).timeout
	assert(enemy.health == 72 and not player._skill_casting, "Charged Strike must release for seven times the player's normal 4-damage hit")

	var spawn := EnemySpawnPoint.new()
	spawn.enemy_skill_1 = ChickenEnemy.SKILL_SCATTER_STRIKE
	assert(int(spawn._get_enemy_skills()[0].skill_id) == ChickenEnemy.SKILL_SCATTER_STRIKE, "Enemy spawn inspectors must expose Scatter Strike")
	spawn.free()
	enemy.enemy_skills = [{
		"skill_id": ChickenEnemy.SKILL_SCATTER_STRIKE,
		"damage": 10,
		"damage_type": FoxPlayer.COLOR_RED,
		"cooldown": 0.0,
		"initial_offset": 0.0,
	}]
	enemy._skill_cooldowns = [0.0]
	for test_seed in range(1, 21):
		enemy._reset_enemy_skills()
		seed(test_seed)
		enemy._begin_enemy_skill(0)
		_assert_scatter_targets(enemy, world, player_cell)
	enemy._reset_enemy_skills()
	seed(42)
	enemy._begin_enemy_skill(0)
	assert(is_equal_approx(enemy._active_skill_windup, 1.0), "Scatter Strike must wind up for one second")
	var health_before := player.health
	enemy._update_active_enemy_skill(0.99)
	assert(player.health == health_before, "Scatter Strike must not hit before its one-second windup")
	enemy._update_active_enemy_skill(0.02)
	assert(player.health == health_before - 10, "Scatter Strike must always hit the locked player tile when the player does not dodge")

	enemy._reset_enemy_skills()
	await process_frame
	world.queue_free()
	await process_frame
	await process_frame
	print("PASS: charged player strike and random enemy scatter strike")
	quit()


func _find_fixture_cell(world: WorldNavigation, player: FoxPlayer) -> Vector2i:
	for raw_cell in world._walkable_cells.keys():
		var cell := raw_cell as Vector2i
		var enemy_cell := cell + Vector2i.LEFT
		if not world.is_walkable(enemy_cell) or world.is_cell_occupied(cell, player) or world.is_cell_occupied(enemy_cell, player):
			continue
		for y in range(-ChickenEnemy.SCATTER_STRIKE_RADIUS, ChickenEnemy.SCATTER_STRIKE_RADIUS + 1):
			for x in range(-ChickenEnemy.SCATTER_STRIKE_RADIUS, ChickenEnemy.SCATTER_STRIKE_RADIUS + 1):
				if not world.is_walkable(cell + Vector2i(x, y)):
					return cell
	return Vector2i(-999999, -999999)


func _assert_scatter_targets(enemy: ChickenEnemy, world: WorldNavigation, player_cell: Vector2i) -> void:
	assert(enemy._active_skill_targets.size() >= 1 and enemy._active_skill_targets.size() <= 1 + ChickenEnemy.SCATTER_STRIKE_RANDOM_TILE_COUNT)
	assert((enemy._active_skill_targets[0] as Dictionary).cell == player_cell, "Scatter Strike's first target must be the player's locked tile")
	var seen: Dictionary = {}
	for target_data in enemy._active_skill_targets:
		var cell: Vector2i = (target_data as Dictionary).cell
		assert(not seen.has(cell), "Scatter Strike target tiles must be unique")
		seen[cell] = true
		if cell == player_cell:
			continue
		var offset := cell - player_cell
		assert(absi(offset.x) <= ChickenEnemy.SCATTER_STRIKE_RADIUS and absi(offset.y) <= ChickenEnemy.SCATTER_STRIKE_RADIUS, "Every random Scatter Strike tile must be within two tiles of the player")
		assert(world.is_walkable(cell), "Random Scatter Strike rolls on walls must be omitted")
