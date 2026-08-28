extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var snakemouth := load("res://Scenes/dungeon1_Snakemouth.tscn").instantiate() as DungeonLevel
	root.add_child(snakemouth)
	await process_frame
	await process_frame
	var later_room_spawn := snakemouth.get_node("EntryGuard4") as EnemySpawnPoint
	assert(later_room_spawn.get_active_enemies().is_empty(), "Enemies outside Snakemouth's initial navigation room must wait for their room to activate")
	var later_room := snakemouth.cell_to_room(snakemouth.world_to_cell(later_room_spawn.global_position))
	snakemouth._ensure_room_available(later_room)
	var initial_wave := later_room_spawn.get_active_enemies()
	assert(initial_wave.size() == later_room_spawn.max_enemies, "Activating a Snakemouth room must create its full initial enemy wave")
	assert(initial_wave[0].health == later_room_spawn.enemy_health, "A newly activated room's enemies must start at full health")
	assert(not later_room_spawn._timer_label.visible, "A newly activated room must not show the authored 99,999-second respawn timer")
	later_room_spawn.clear_for_load()
	later_room_spawn.emptied_once = true
	snakemouth._ensure_room_available(later_room)
	assert(later_room_spawn.get_active_enemies().is_empty(), "Reactivating a room must not revive an intentionally cleared one-time spawn")
	print("PASS: Snakemouth rooms spawn their initial enemies when activated")
	snakemouth.queue_free()
	await process_frame
	await process_frame
	quit()
