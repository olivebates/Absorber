extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var audio := GameAudio.new()
	root.add_child(audio)
	await process_frame
	assert(audio._grass_player.volume_db == GameAudio.SILENT_DB, "Grass music must begin silent")
	assert(audio._desert_player.volume_db == GameAudio.SILENT_DB, "Desert music must begin silent")
	assert(audio._grass_player.playing and audio._desert_player.playing, "Both biome playlists must be initialized")
	assert(audio._grass_player.stream_paused and audio._desert_player.stream_paused, "Biome music must begin paused")
	audio.enable_biome_music()
	audio._set_active_biome(GameAudio.Biome.GRASS)
	assert(not audio._grass_player.stream_paused, "Grass music must unpause when grass first becomes active")
	assert(audio._desert_player.stream_paused, "Inactive music must remain paused until its first fade-in")
	audio._on_grass_finished()
	assert(audio._grass_track_index == 1, "Grass1 must advance to Grass2")
	audio._on_grass_finished()
	assert(audio._grass_track_index == 0, "Grass2 must loop back to Grass1")

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
	print("PASS: biome music and death audio sequence work")
	quit()
