extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_world: PackedScene = load("res://Scenes/world.tscn")
	assert(packed_world != null, "World scene must load")
	var world := packed_world.instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame

	var first := Node2D.new()
	var second := Node2D.new()
	world.add_child(first)
	world.add_child(second)
	var first_cell := Vector2i(2, 2)
	var second_cell := first_cell + Vector2i.RIGHT
	var first_target := world.cell_to_world(first_cell)
	var second_target := world.cell_to_world(second_cell)
	first.global_position = first_target + Vector2(20.0, -12.0)
	second.global_position = second_target + Vector2(-18.0, 14.0)
	var first_start := first.global_position
	var second_start := second.global_position

	assert(not world.center_stationary_combatants(first, second), "An off-center combat pair must wait for its entry lerp")
	assert(first.global_position == first_start, "The first combatant must not snap when its entry lerp starts")
	assert(second.global_position == second_start, "The second combatant must not snap when its entry lerp starts")
	await create_timer(WorldNavigation.COMBAT_TILE_LERP_DURATION + 0.1).timeout
	assert(world.center_stationary_combatants(first, second), "Combat can begin once both entry lerps finish")
	assert(first.global_position.is_equal_approx(first_target), "The first combatant must finish on its intended tile center")
	assert(second.global_position.is_equal_approx(second_target), "The second combatant must finish on its intended tile center")

	var dialogue := get_first_node_in_group("dialogue_ui") as DialogueBox
	if dialogue:
		dialogue.cancel()
	var combat_enemy: ChickenEnemy
	for node in get_nodes_in_group("enemies"):
		if node is ChickenEnemy:
			if combat_enemy == null:
				combat_enemy = node as ChickenEnemy
			else:
				(node as ChickenEnemy).health = 0
	assert(combat_enemy != null, "The world must provide an enemy for the escape-path regression")
	combat_enemy.health = maxi(1, combat_enemy.health)
	combat_enemy._attack_time_left = 100.0
	var combat_cell := _find_open_horizontal_cells(world)
	assert(combat_cell != Vector2i(-999999, -999999), "The alignment test needs three horizontal floor cells")
	world.player.global_position = world.cell_to_world(combat_cell)
	var moving_entry_enemy_target := world.cell_to_world(combat_cell + Vector2i.RIGHT)
	combat_enemy.global_position = moving_entry_enemy_target + Vector2(-13.0, 7.0)
	world.player._weapon_cooldowns[world.player.current_weapon_index] = 100.0
	var escape_path := PackedVector2Array([
		world.player.global_position,
		world.cell_to_world(combat_cell + Vector2i.LEFT),
	])
	world.player.follow_path(escape_path)
	assert(world.player.is_moving(), "The player must accept a path away from combat")
	world.player._attack_nearby_enemy()
	assert(world.player.is_moving(), "Entering combat must not clear a moving player's path")
	assert(not world.player.has_meta(WorldNavigation.COMBAT_ALIGNMENT_TWEEN_META), "A moving player must not receive a centering tween")
	assert(combat_enemy.has_meta(WorldNavigation.COMBAT_ALIGNMENT_TWEEN_META), "A stationary enemy must center independently while the player moves")
	world.cancel_combatant_tile_lerps(world.player, combat_enemy)
	combat_enemy.global_position = moving_entry_enemy_target
	world.player._combat_entry_aligned = true

	combat_enemy._movement_mode = ChickenEnemy.MovementMode.CHASE
	combat_enemy._pursuit_is_limited = true
	combat_enemy._pursuit_tiles_left = ChickenEnemy.DISENGAGE_FOLLOW_TILES
	combat_enemy._pursuit_distance_left = ChickenEnemy.DISENGAGE_FOLLOW_TILES * WorldNavigation.TILE_SIZE
	world.player.global_position = world.cell_to_world(combat_cell + Vector2i.LEFT)
	combat_enemy.global_position = world.cell_to_world(combat_cell + Vector2i.RIGHT)
	world.player._attack_nearby_enemy()
	assert(combat_enemy.is_player_combat_sequence_active(), "The enemy's three-tile chase must keep the combat sequence active")
	assert(world.player._combat_alignment_enemy == combat_enemy, "Leaving adjacency must retain the pursued enemy as the alignment owner")
	assert(world.player._combat_entry_aligned, "Leaving adjacency during pursuit must retain completed combat alignment")

	combat_enemy.global_position = world.cell_to_world(combat_cell)
	var second_escape_path := PackedVector2Array([
		world.player.global_position,
		world.cell_to_world(combat_cell + Vector2i.LEFT * 2),
	])
	world.player.follow_path(second_escape_path)
	var second_escape_start := world.player.global_position
	world.player._attack_nearby_enemy()
	assert(world.player.is_moving(), "Being caught on the next tile must not clear the player's escape path")
	assert(world.player.global_position == second_escape_start and not world.player.has_meta(WorldNavigation.COMBAT_ALIGNMENT_TWEEN_META), "Being caught during pursuit must not start another centering lerp")

	world.player._path.clear()
	world.player._path_index = 0
	world.player.velocity = Vector2.ZERO
	combat_enemy._clear_movement_path()
	var stopped_player_target := world.cell_to_world(combat_cell + Vector2i.LEFT)
	var stopped_enemy_target := world.cell_to_world(combat_cell)
	world.player.global_position = stopped_player_target + Vector2(14.0, -9.0)
	combat_enemy.global_position = stopped_enemy_target + Vector2(-11.0, 8.0)
	world.player._attack_nearby_enemy()
	assert(world.player.has_meta(WorldNavigation.COMBAT_ALIGNMENT_TWEEN_META), "Stopping off-center during pursuit must start a fresh player alignment")
	assert(combat_enemy.has_meta(WorldNavigation.COMBAT_ALIGNMENT_TWEEN_META), "Stopping off-center during pursuit must start a fresh enemy alignment")
	await create_timer(WorldNavigation.COMBAT_TILE_LERP_DURATION + 0.1).timeout
	world.player._attack_nearby_enemy()
	assert(world.player.global_position.is_equal_approx(stopped_player_target), "The stopped player must finish centered on the current tile")
	assert(combat_enemy.global_position.is_equal_approx(stopped_enemy_target), "The stopped enemy must finish centered on the current tile")

	var player_code := (load("res://Scripts/fox_player.gd") as Script).source_code
	var enemy_code := (load("res://Scripts/chicken_enemy.gd") as Script).source_code
	var hunter_code := (load("res://Scripts/fox_lio.gd") as Script).source_code
	assert(player_code.contains("center_stationary_combatants(self, target)"), "Player combat must request independent tile alignment")
	assert(enemy_code.contains("center_stationary_combatants(combat_target, self)"), "Enemies must request independent tile alignment")
	assert(hunter_code.contains("center_stationary_combatants(self, _hunt_target)"), "Hunter NPC combat must request independent tile alignment")
	assert(hunter_code.contains("_hunt_target.prepare_for_hunter_combat(self)"), "Hunter NPC combat must stop its enemy before both entry lerps begin")

	for child in world.game_audio.get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()
			(child as AudioStreamPlayer).stream = null
	world.free()
	print("PASS: every stationary combatant centers independently while moving combatants remain free")
	quit()


func _find_open_horizontal_cells(world: WorldNavigation) -> Vector2i:
	for cell in world.floor_layer.get_used_cells():
		if world.is_walkable(cell + Vector2i.LEFT) and world.is_walkable(cell) \
			and world.is_walkable(cell + Vector2i.RIGHT):
			return cell
	return Vector2i(-999999, -999999)
