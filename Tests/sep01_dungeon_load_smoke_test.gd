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
	var entrance := world.get_node("DungeonEntrance") as DungeonEntrance
	manager.tutorial_seen = true
	await manager._begin_entry(entrance)
	var level := manager.get_active_level()
	var spawn := level.get_node("EntryGuard2") as EnemySpawnPoint
	var enemies := spawn.get_active_enemies()
	assert(enemies.size() == 1, "The entry-room enemy must exist before saving")
	var enemy := enemies[0]
	enemy.health = 1
	enemy.global_position += Vector2(7.0, 3.0)
	enemy._pause_time_left = 10.0
	var saved_enemy_position := Vector2(roundi(enemy.global_position.x), roundi(enemy.global_position.y))
	spawn._respawn_time_left = 54321.0
	var save_system := world.get_node("SaveSystem") as SaveSystem
	var encoded := save_system.create_save_string(1000)
	assert(save_system.load_save_string(encoded, 1000))
	await create_timer(0.9).timeout
	assert(manager.is_dungeon_active(), "Loading a dungeon save must reopen the active dungeon")
	level = manager.get_active_level()
	spawn = level.get_node("EntryGuard2") as EnemySpawnPoint
	enemies = spawn.get_active_enemies()
	assert(enemies.size() == 1, "The saved dungeon enemy must be restored")
	assert(enemies[0].health == 1 and enemies[0].global_position == saved_enemy_position, "Dungeon enemies must restore health and position")
	assert(spawn._respawn_time_left <= spawn.respawn_time, "A restored dungeon cooldown must remain bounded")
	print("PASS: active dungeon enemies and cooldowns save/load correctly")
	world.queue_free()
	await process_frame
	await process_frame
	quit()
