extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var audio := GameAudio.new()
	root.add_child(audio)
	await process_frame
	assert(audio._grass_player.volume_db == GameAudio.SILENT_DB, "Grass music must begin silent")
	assert(audio._forest_player.volume_db == GameAudio.SILENT_DB, "Forest music must begin silent")
	assert(audio._desert_player.volume_db == GameAudio.SILENT_DB, "Desert music must begin silent")
	assert(audio._boss_player.volume_db == GameAudio.SILENT_DB, "Boss music must begin silent")
	assert(audio._grass_player.stream != null and audio._forest_player.stream != null and audio._desert_player.stream != null and audio._boss_player.stream == GameAudio.BOSS_TRACK, "Every biome and boss playlist must be initialized")
	assert(audio._grass_player.stream_paused and audio._forest_player.stream_paused and audio._desert_player.stream_paused and audio._boss_player.stream_paused, "Biome and boss music must begin paused")
	audio.enable_biome_music()
	audio._set_active_biome(GameAudio.Biome.GRASS)
	assert(not audio._grass_player.stream_paused, "Grass music must unpause when grass first becomes active")
	assert(audio._desert_player.stream_paused, "Inactive music must remain paused until its first fade-in")
	audio._on_grass_finished()
	assert(audio._grass_track_index == 1, "Grass1 must advance to Grass2")
	audio._on_grass_finished()
	assert(audio._grass_track_index == 0, "Grass2 must loop back to Grass1")
	audio._set_active_biome(GameAudio.Biome.FOREST)
	assert(not audio._forest_player.stream_paused, "The second floor-atlas row must have its own forest playlist")
	audio._on_forest_finished()
	assert(audio._forest_track_index == 1, "Forrest1 must advance to Forrest2")
	audio._on_forest_finished()
	assert(audio._forest_track_index == 0, "Forrest2 must loop back to Forrest1")

	var fox := load("res://Scenes/fox.tscn").instantiate() as FoxPlayer
	root.add_child(fox)
	await process_frame
	fox.take_damage(fox.max_health)
	assert(fox._is_dying, "Lethal damage must start the death sequence")
	await create_timer(0.45).timeout
	assert(fox._death_overlay.visible, "The screen must turn black after the death rotation")
	assert(fox.health == 0, "The player must remain dead until the blackout ends")
	await create_timer(0.55).timeout
	assert(not fox._is_dying and fox.health == 1, "The player must respawn with one health")
	assert(not fox._death_overlay.visible, "The blackout must clear after respawning")
	assert(is_zero_approx(fox.fox_sprite.rotation), "The player sprite must be upright after respawning")
	audio.queue_free()
	fox.queue_free()
	await process_frame

	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var dialogue := world.get_node("HUD/DialogueBox") as DialogueBox
	dialogue.cancel()
	var world_audio := world.get_node("GameAudio") as GameAudio
	world_audio.enable_biome_music()
	var forest_cell := Vector2i.ZERO
	for cell in world.floor_layer.get_used_cells():
		var atlas := world.floor_layer.get_cell_atlas_coords(cell)
		if atlas.y == 1 and atlas.x >= 0 and atlas.x < 3:
			forest_cell = cell
			break
	assert(forest_cell != Vector2i.ZERO, "The world needs one of the first three tiles on floor-atlas row two")
	world.player.global_position = world.cell_to_world(forest_cell)
	world_audio._update_biome_music()
	assert(world_audio._active_biome == GameAudio.Biome.FOREST and not world_audio._forest_player.stream_paused, "The first three tiles on row two must play the forest themes")
	assert(world_audio._area_label.text == "~ Whippersnapper Woods ~", "The forest playlist must announce Whippersnapper Woods")
	var boss_spawn := world.get_node("ChickenSpawn8") as EnemySpawnPoint
	assert(boss_spawn.boss and not boss_spawn.get_active_enemies().is_empty(), "Boss must be an exposed spawn property used by authored boss spawns")
	var boss_enemy := boss_spawn.get_active_enemies()[0]
	world.player.global_position = boss_enemy.global_position + Vector2.LEFT * WorldNavigation.TILE_SIZE
	world_audio._update_biome_music()
	assert(world_audio._active_biome == GameAudio.Biome.BOSS and not world_audio._boss_player.stream_paused, "Boss.mp3 must start while the player fights a marked boss")
	await create_timer(GameAudio.BOSS_FADE_IN_SECONDS + 0.05).timeout
	assert(world_audio._boss_player.volume_db > GameAudio.MUSIC_DB - 1.0, "Boss music must fade in almost instantly")
	await create_timer(0.42).timeout
	var camera := world.player.get_node("Camera2D") as Camera2D
	assert(camera.zoom.x > 1.10 and camera.zoom.y > 1.10, "Boss combat must zoom the camera in slightly")
	boss_spawn.emptied_once = true
	world_audio._update_biome_music()
	assert(world_audio._active_biome != GameAudio.Biome.BOSS and not world_audio._boss_zoom_active, "A previously killed boss must not trigger boss music or zoom")
	boss_spawn.emptied_once = false
	world.player.global_position += Vector2.RIGHT * WorldNavigation.TILE_SIZE * 10.0
	world_audio._update_biome_music()
	await create_timer(0.42).timeout
	assert(camera.zoom.is_equal_approx(Vector2.ONE), "Leaving boss combat must restore the normal camera zoom")
	print("PASS: biome playlists, forest tiles, boss music/zoom, and death audio sequence work")
	world.queue_free()
	quit()
