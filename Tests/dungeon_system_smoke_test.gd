extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var standalone_entrance_scene := load("res://Scenes/dungeon_entrance.tscn") as PackedScene
	assert(standalone_entrance_scene != null, "A dungeon entrance must load without requiring DungeonManager's type to be registered first")
	var standalone_entrance := standalone_entrance_scene.instantiate() as DungeonEntrance
	assert(standalone_entrance != null, "A dungeon entrance must instantiate on its own in the editor")
	root.add_child(standalone_entrance)
	await process_frame
	standalone_entrance.queue_free()
	await process_frame
	var transition_level := DungeonLevel.new()
	assert(transition_level._get_transition_neighbor(Vector2i(16, 3)) == Vector2i.RIGHT, "Right transitions must work three tiles from the edge without a declared neighbor")
	assert(transition_level._get_transition_neighbor(Vector2i(2, 6)) == Vector2i.LEFT, "Left transitions must work two tiles from the edge without a declared neighbor")
	assert(transition_level._get_transition_neighbor(Vector2i(7, 1)) == Vector2i.UP, "Upper transitions must work one tile from the edge without a declared neighbor")
	assert(transition_level._get_transition_neighbor(Vector2i(12, 9)) == Vector2i.DOWN, "Lower transitions must work one tile from the edge without a declared neighbor")
	assert(transition_level._get_transition_neighbor(Vector2i(2, 1), Vector2i.UP) == Vector2i.UP, "Movement direction must select the correct side where transition thresholds overlap")
	assert(transition_level._get_transition_neighbor(Vector2i(2, 1), Vector2i.LEFT) == Vector2i.LEFT, "Corner thresholds must remain open in both applicable directions")
	assert(transition_level._get_transition_destination(Vector2i(15, 5), Vector2i.RIGHT, Vector2i.RIGHT) == Vector2i(23, 5), "Entering from the left must land three tiles into the room")
	assert(transition_level._get_transition_destination(Vector2i(3, 5), Vector2i.LEFT, Vector2i.LEFT) == Vector2i(-5, 5), "Entering from the right must land four tiles into the room")
	assert(transition_level._get_transition_destination(Vector2i(10, 8), Vector2i.DOWN, Vector2i.DOWN) == Vector2i(10, 13), "Entering from above must land two tiles into the room")
	assert(transition_level._get_transition_destination(Vector2i(10, 2), Vector2i.UP, Vector2i.UP) == Vector2i(10, -3), "Entering from below must land two tiles into the room")
	transition_level.current_room = Vector2i(1000, -1000)
	var distant_right_threshold := transition_level.current_room * transition_level.room_size_tiles + Vector2i(16, 4)
	assert(transition_level._get_transition_neighbor(distant_right_threshold) == transition_level.current_room + Vector2i.RIGHT, "Room transitions must remain unrestricted at arbitrary grid coordinates")
	transition_level.free()

	var packed_world := load("res://Scenes/world.tscn") as PackedScene
	assert(packed_world != null, "World with dungeon framework must load")
	var world := packed_world.instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var manager := world.get_node("DungeonManager") as DungeonManager
	assert(manager != null, "World must own the dungeon manager")
	assert(manager._tutorial_overlay != null and not manager._tutorial_overlay.visible, "The first-entry dungeon warning must use its own centered popup")
	var entrance_one := world.get_node("MossrootGrottoEntrance") as DungeonEntrance
	var entrance_two := world.get_node("SunkenBurrowEntrance") as DungeonEntrance
	assert(entrance_one != null and entrance_two != null, "Two configured test entrances must exist")
	assert(entrance_one.dungeon_scene.resource_path == "res://Scenes/dungeon_template.tscn", "First entrance must target its configured dungeon scene")
	assert(entrance_two.dungeon_scene.resource_path == "res://Scenes/test_dungeon_two.tscn", "Second entrance must target its own dungeon scene")
	var tutorial_dialogue := world.get_node("HUD/DialogueBox") as DialogueBox
	if tutorial_dialogue.is_open():
		tutorial_dialogue.cancel()
	manager.request_enter(entrance_one)
	assert(manager._tutorial_overlay.visible, "A first dungeon entry must open the dedicated warning popup")
	assert(not tutorial_dialogue.is_open(), "The first-entry warning must not use the standard dialogue box")
	manager._tutorial_overlay.hide()
	manager._tutorial_pending_entrance = null
	manager._active_entrance = null
	world.interaction_locked = false
	assert(world.is_walkable(world.world_to_cell(entrance_one.global_position)), "First dungeon entrance must sit on painted floor")
	assert(world.is_walkable(world.world_to_cell(entrance_two.global_position)), "Second dungeon entrance must sit on painted floor")

	for dungeon_scene in [entrance_one.dungeon_scene, entrance_two.dungeon_scene]:
		var packed := dungeon_scene as PackedScene
		assert(packed != null, "Every test dungeon scene must load")
		var level := packed.instantiate() as DungeonLevel
		assert(level != null, "Every test dungeon must instantiate without requiring a predeclared room layout")
		level.free()

	var original_parent := world.player.get_parent()
	var original_health := world.player.max_health
	manager.tutorial_seen = true
	await manager._begin_entry(entrance_one)
	assert(manager.is_dungeon_active(), "Entering must activate the selected dungeon")
	var active := manager.get_active_level()
	assert(manager._camera.get_parent() == world and manager._camera.global_position != Vector2.ZERO, "The overworld camera must remain frozen over the overworld instead of falling back to zero while a dungeon is active")
	assert(active._camera != manager._camera and active._camera.get_parent() == active, "The dungeon viewport must use a separate fixed camera")
	assert(active != null and active.dungeon_id == &"mossroot_grotto", "The entrance must load its attached dungeon")
	var game_audio := world.get_node("GameAudio") as GameAudio
	assert(game_audio._area_label.text == entrance_one.dungeon_name, "Dungeon entry must show the area name exported by its entrance")
	game_audio.enable_biome_music()
	game_audio._update_biome_music()
	assert(game_audio._active_biome == GameAudio.Biome.DUNGEON and not game_audio._dungeon_player.stream_paused, "Entering a dungeon must crossfade to the Dungeon1/Dungeon2 playlist")
	assert(world.player.get_parent() == active, "The shared player must move into the isolated dungeon viewport")
	assert(world.player.max_health == 1 and world.player.passive_healing_amount == 1, "A first dungeon visit must reset temporary stats to one")
	world.player.add_max_health(2)
	assert(active.current_room == Vector2i.ZERO and active.explored_cells.has(active.entry_cell), "Dungeon fog must begin with the entry room explored")
	assert(active.get_map_region() == Rect2i(Vector2i.ZERO, active.room_size_tiles), "Dungeon maps must initially fit only the visited entry room")
	assert(active.get_map_cells().size() == active.room_size_tiles.x * active.room_size_tiles.y, "Dungeon maps must expose the complete visited room and no predefined unvisited rooms")
	assert(active.get_node("EntryGuard") is EnemySpawnPoint, "Dungeon must instantiate room enemies")
	assert(active.get_node("RoomDoor") is DungeonDoor, "Dungeon must contain a room-clear door")
	assert(active.get_node("LockedDoor") is DungeonDoorLocked, "Dungeon must contain a keyed door")
	assert(active.get_node("KeyChest") is DungeonChest, "Dungeon must contain a reward chest")
	var authored_wall_cells := active.wall_layer.get_used_cells()
	assert(not authored_wall_cells.is_empty(), "The test dungeon must contain authored wall tiles")
	var authored_wall_cell := authored_wall_cells[0]
	assert(not active.is_walkable(authored_wall_cell), "Every authored dungeon wall tile must be excluded from navigation")
	assert(active.find_path(world.player.global_position, active.cell_to_world(authored_wall_cell), world.player).is_empty(), "The player must not be able to path onto a dungeon wall")
	assert(active.is_walkable(active.world_to_cell(world.player.global_position)), "A wall-authored entry cell must move the player to the nearest safe floor without changing the exported entry value")
	assert(not active._navigation_rooms.has(Vector2i.UP), "The upper room should not need to be predeclared")
	world.player.stop()
	world.player.global_position = active.cell_to_world(Vector2i(10, 1))
	assert(not active.is_walkable(Vector2i(10, 1)), "A manually painted wall must remain solid even when it occupies a transition threshold")
	assert(not active._try_transition_toward(Vector2i(10, 0)), "A wall tile at a transition threshold must block the room transfer")
	active.wall_layer.erase_cell(Vector2i(16, 5))
	active._build_dungeon_navigation()
	assert(active.is_walkable(Vector2i(16, 5)), "The runtime test doorway must be open before testing right-room transitions")
	active._ensure_room_available(Vector2i.UP)
	assert(active._navigation_rooms.has(Vector2i.UP), "Entering an undeclared direction must expand dungeon navigation dynamically")
	var dynamic_room_has_open_cell := false
	for y in range(-active.room_size_tiles.y, 0):
		for x in range(active.room_size_tiles.x):
			var dynamic_cell := Vector2i(x, y)
			if active.wall_layer.get_cell_source_id(dynamic_cell) == -1:
				dynamic_room_has_open_cell = active.is_walkable(dynamic_cell)
				break
		if dynamic_room_has_open_cell:
			break
	assert(dynamic_room_has_open_cell, "Dynamically created rooms must leave every non-authored-wall cell walkable")
	assert(active.get_map_region() == Rect2i(Vector2i.ZERO, active.room_size_tiles), "Generating an adjacent room must not reveal it on either dungeon map")
	world.player.global_position = active.cell_to_world(Vector2i(10, 3))
	active._process(0.0)
	var middle_spawn := active.get_node("MiddleGuard") as EnemySpawnPoint
	var frozen_enemy := middle_spawn.get_active_enemies()[0]
	var frozen_position := frozen_enemy.global_position
	frozen_enemy._physics_process(1.0)
	assert(frozen_enemy.global_position == frozen_position, "Enemies outside the fixed camera room must remain frozen")
	var first_camera_center := active.get_room_center(Vector2i.ZERO)
	world.player.stop()
	world.player.global_position = active.cell_to_world(Vector2i(16, 5))
	active._process(0.0)
	assert(active.current_room == Vector2i.ZERO, "Standing at a room threshold without moving outward must not change rooms")
	world.player.follow_path(PackedVector2Array([active.cell_to_world(Vector2i(18, 5))]))
	active._process(0.0)
	await create_timer(0.35).timeout
	assert(active.current_room == Vector2i(1, 0), "Moving right at three tiles from the right edge must enter the neighboring room")
	assert(active.world_to_cell(world.player.global_position) == Vector2i(23, 5), "Entering from the left must move the player three tiles into the neighboring room")
	assert(active.get_map_region() == Rect2i(Vector2i.ZERO, Vector2i(active.room_size_tiles.x * 2, active.room_size_tiles.y)), "Visiting a room must expand the dungeon maps to include it")
	assert(active._camera.global_position.distance_to(first_camera_center + Vector2(active.room_size_tiles.x * WorldNavigation.TILE_SIZE, 0)) < 1.0, "The fixed camera must move exactly one room width")
	assert(active.explored_cells.has(Vector2i(20, 5)), "Entering a room must reveal that room in dungeon fog")
	world.player.global_position = active.cell_to_world(Vector2i(23, 5))
	active._process(0.0)
	world.player.global_position = active.cell_to_world(Vector2i(22, 5))
	world.player.follow_path(PackedVector2Array([active.cell_to_world(Vector2i(20, 5))]))
	active._process(0.0)
	await create_timer(0.35).timeout
	assert(active.current_room == Vector2i.ZERO and active.world_to_cell(world.player.global_position) == Vector2i(15, 5), "Entering from the right must move the player four tiles into the previous room")
	world.player.global_position = active.cell_to_world(Vector2i(15, 5))
	active._process(0.0)
	world.player.global_position = active.cell_to_world(Vector2i(16, 5))
	world.player.stop()
	assert(active._try_transition_toward(Vector2i(18, 5)), "Requesting movement outward from a threshold must transfer rooms even when the clicked tile is part of the wall")
	await create_timer(0.35).timeout
	assert(active.current_room == Vector2i(1, 0), "The doorway must re-arm after the player leaves its destination edge tile")

	var key_chest := active.get_node("KeyChest") as DungeonChest
	key_chest._level = active
	key_chest._open(world.player)
	assert(manager.get_key_count() == 1 and key_chest.opened, "A key chest must update this dungeon's separate key counter")
	key_chest._show_reward_over_player(world.player, key_chest._get_reward_icon())
	var chest_reward_icon := key_chest._reward_display.get_child(1) as Sprite2D
	var chest_reward_rotation := chest_reward_icon.rotation
	await create_timer(0.12).timeout
	assert(is_equal_approx(chest_reward_icon.rotation, chest_reward_rotation), "The chest reward icon must remain upright while only its light rays rotate")
	key_chest._clear_reward_display()
	var locked_door := active.get_node("LockedDoor") as DungeonDoorLocked
	locked_door._level = active
	locked_door._attempt_unlock()
	assert(locked_door.unlocked and manager.get_key_count() == 0, "A locked door must consume one dungeon key")
	var boss_chest := active.get_node("BossChest") as DungeonChest
	boss_chest._level = active
	boss_chest._open(world.player)
	for child in active.get_children():
		if is_instance_valid(child) and child is EnemySpawnPoint:
			(child as EnemySpawnPoint).clear_for_load()
			(child as EnemySpawnPoint).emptied_once = true
	var snapshot := active.capture_snapshot()
	assert(snapshot.has("spawns") and snapshot.has("chests") and snapshot.has("locked_doors"), "Dungeon snapshots must include enemies, chests, and keyed doors")
	assert(bool(snapshot.get("cleared", false)), "Killing the boss and opening every chest must clear the dungeon")

	await manager.leave_dungeon()
	assert(not manager.is_dungeon_active(), "Leaving from the map action must close the dungeon")
	game_audio._update_biome_music()
	assert(game_audio._active_biome != GameAudio.Biome.DUNGEON, "Leaving a dungeon must restore overworld background music")
	assert(world.player.get_parent() == original_parent, "Leaving must return the shared player to the overworld")
	assert(manager._camera.position == Vector2.ZERO, "Leaving a dungeon must snap the camera directly onto the player")
	assert(world.player.max_health == original_health, "Leaving must restore overworld stats before transferring dungeon gains")
	var dialogue := world.get_node("HUD/DialogueBox") as DialogueBox
	assert(dialogue.is_open() and dialogue.get_current_text() == DungeonManager.FIRST_EXIT_TEXT, "The first dungeon exit must play Mira's one-time reaction")
	dialogue.close()
	await create_timer(0.65).timeout
	assert(world.player.max_health == original_health + 2, "New dungeon stat gains must fly into and permanently increase restored overworld stats")
	assert((manager.dungeon_states["mossroot_grotto"] as Dictionary).has("level"), "Leaving must retain a dungeon snapshot for re-entry")
	assert((manager.get_save_data()[1] as Dictionary).has("mossroot_grotto"), "Dungeon state must be included in save data")
	assert(manager.is_cleared(&"mossroot_grotto"), "Cleared state must persist on the entrance")
	assert(bool(manager.get_save_data()[3]), "The first-exit reaction state must persist in dungeon save data")
	await manager._begin_entry(entrance_one)
	assert(manager.is_dungeon_active(), "A saved dungeon must support re-entry")
	var restored_level := manager.get_active_level()
	assert((restored_level.get_node("KeyChest") as DungeonChest).opened, "Re-entry must restore opened chests without touching freed nodes from the prior instance")
	assert((restored_level.get_node("LockedDoor") as DungeonDoorLocked).unlocked, "Re-entry must restore unlocked doors")
	await manager.leave_dungeon()
	assert(not dialogue.is_open(), "The first-exit reaction must not repeat on later exits")
	var resources := world.get_node("ResourceManager") as ResourceManager
	assert(is_equal_approx(resources.get_definition(&"cave_moss").production_speed, 1.0 / 600.0), "Each cleared dungeon must produce one Cave Moss per ten minutes")
	print("Dungeon system smoke test passed")
	world.queue_free()
	await process_frame
	await process_frame
	quit()
