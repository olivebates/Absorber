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
	await manager._begin_entry(entrance)
	audio._update_biome_music()
	assert(audio._active_biome == GameAudio.Biome.DUNGEON, "Dungeon entry must select dungeon background music")
	assert(not audio._dungeon_player.stream_paused and audio._dungeon_player.stream == GameAudio.DUNGEON_TRACKS[0], "Dungeon1 must begin the dungeon playlist")
	await manager.leave_dungeon()
	audio._update_biome_music()
	assert(audio._active_biome != GameAudio.Biome.DUNGEON, "Dungeon exit must restore location-appropriate overworld music")
	print("PASS: dungeon entry and exit switch background playlists")
	world.queue_free()
	await process_frame
	quit()
