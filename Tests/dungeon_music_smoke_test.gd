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
	var audio := world.get_node("GameAudio") as GameAudio
	var manager := world.get_node("DungeonManager") as DungeonManager
	var entrance := world.get_node("MossrootGrottoEntrance") as DungeonEntrance
	audio.enable_biome_music()
	manager.tutorial_seen = true
	var item_tooltip := world.get_node("HUD/ItemTooltip") as ItemTooltip
	var build_tooltip := world.get_node("HUD/BuildMineTooltip") as BuildMineTooltip
	item_tooltip.show_description(null, "Overworld popup", "Must close on dungeon entry")
	build_tooltip.show_stat(null, "Production", "+1/s", entrance)
	assert(item_tooltip.visible and build_tooltip.visible, "The popup suppression fixture must begin with visible overworld popups")
	await manager._begin_entry(entrance)
	assert(not item_tooltip.visible and not build_tooltip.visible, "Entering a dungeon must suppress overworld popups")
	audio._update_biome_music()
	assert(audio._active_biome == GameAudio.Biome.DUNGEON, "Dungeon entry must select dungeon background music")
	assert(not audio._dungeon_player.stream_paused and audio._dungeon_player.stream == GameAudio.DUNGEON_TRACKS[0], "Dungeon1 must begin the dungeon playlist")
	var active := manager.get_active_level()
	var boss_spawn := EnemySpawnPoint.new()
	boss_spawn.max_enemies = 0
	boss_spawn.boss = true
	boss_spawn.global_position = world.player.global_position + Vector2.RIGHT * WorldNavigation.TILE_SIZE
	active.add_child(boss_spawn)
	boss_spawn.max_enemies = 1
	boss_spawn.ensure_initial_wave_spawned()
	var boss_enemy := boss_spawn.get_active_enemies()[0]
	world.player.global_position = boss_enemy.global_position + Vector2.LEFT * WorldNavigation.TILE_SIZE
	audio._update_biome_music()
	assert(audio._active_biome == GameAudio.Biome.BOSS and not audio._boss_player.stream_paused, "Fighting a marked dungeon boss must switch to boss music")
	await create_timer(0.42).timeout
	assert(active._camera.zoom.x > 1.10 and active._camera.zoom.y > 1.10, "Fighting a marked dungeon boss must zoom the dungeon camera")
	boss_enemy._physics_process(0.0)
	world.player.global_position += Vector2.LEFT * WorldNavigation.TILE_SIZE * 5.0
	audio._update_biome_music()
	assert(audio._active_biome == GameAudio.Biome.BOSS, "Boss music and zoom must persist while the boss is still pursuing Mira")
	active.gameplay_paused = true
	audio._update_biome_music()
	assert(audio._active_biome == GameAudio.Biome.BOSS, "Pausing an active boss fight must not drop its music or zoom")
	active.gameplay_paused = false
	world.player.clear_attack_target()
	world.player.stop()
	boss_enemy._begin_return_home()
	world.player.set_physics_process(false)
	boss_enemy.set_physics_process(false)
	audio._update_biome_music()
	await create_timer(0.42).timeout
	assert(audio._active_biome == GameAudio.Biome.DUNGEON, "Boss music must end only when the boss disengages")
	assert(active._camera.zoom.is_equal_approx(Vector2.ONE), "Boss camera zoom must end only when the boss disengages")
	var charge_players_before := _count_audio_players(audio, GameAudio.ENEMY_CHARGE_SFX)
	boss_enemy.global_position += Vector2.RIGHT * active.room_size_tiles.x * WorldNavigation.TILE_SIZE
	boss_enemy._play_enemy_charge_sfx()
	assert(_count_audio_players(audio, GameAudio.ENEMY_CHARGE_SFX) == charge_players_before, "An enemy outside the active dungeon room must not emit combat sounds")
	await manager.leave_dungeon()
	audio._update_biome_music()
	assert(audio._active_biome != GameAudio.Biome.DUNGEON, "Dungeon exit must restore location-appropriate overworld music")
	print("PASS: dungeon entry and exit switch background playlists")
	world.queue_free()
	await process_frame
	quit()


func _count_audio_players(audio: GameAudio, stream: AudioStream) -> int:
	var count := 0
	for child in audio.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).stream == stream:
			count += 1
	return count
