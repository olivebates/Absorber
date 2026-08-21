extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var dialogue := world.get_node("HUD/DialogueBox") as DialogueBox
	while dialogue.is_open():
		dialogue.finish_typing()
		dialogue.advance()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var enemies: Array[ChickenEnemy] = []
	for node in get_nodes_in_group("enemies"):
		if node is ChickenEnemy:
			enemies.append(node)
	assert(enemies.size() >= 2, "The performance world must contain at least two enemies")
	var occupied := world.get_occupied_cells()
	var reserved := {}
	for enemy in enemies:
		reserved[enemy.get_movement_target_cell(world)] = true
	var target_cell := Vector2i(-999999, -999999)
	for cell in world.floor_layer.get_used_cells():
		if world.is_walkable(cell) and not occupied.has(cell) and not reserved.has(cell):
			target_cell = cell
			break
	assert(target_cell.x > -999999, "The performance test needs one unreserved floor tile")
	var first := enemies[0]
	var second := enemies[1]
	var lower := first if first.get_instance_id() < second.get_instance_id() else second
	var higher := second if lower == first else first
	lower._path = PackedVector2Array([world.cell_to_world(target_cell)])
	lower._path_index = 0
	higher._path = PackedVector2Array([world.cell_to_world(target_cell)])
	higher._path_index = 0
	world._actor_cache_frame = -1
	world._refresh_actor_cache()
	assert(not world.is_enemy_target_conflicted(lower, target_cell), "The lowest-id enemy must retain a shared reserved target")
	assert(world.is_enemy_target_conflicted(higher, target_cell), "The higher-id enemy must yield a shared reserved target")
	assert(not world.can_enter_position(first, second.global_position), "Cached occupancy must still prevent enemies from entering one another's cells")
	var started := Time.get_ticks_usec()
	for _index in range(20000):
		world.is_enemy_target_conflicted(higher, target_cell)
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	assert(elapsed_ms < 250.0, "Cached conflict lookups must remain constant-time under a large enemy population")
	assert(Minimap.REDRAW_INTERVAL >= 0.1, "The minimap must not redraw every rendered frame")
	print("PASS: cached enemy conflicts and occupancy work; 20k lookups took %.2f ms across %d enemies" % [elapsed_ms, enemies.size()])
	quit()
