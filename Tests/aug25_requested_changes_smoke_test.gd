extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var story := world.get_node("StoryManager") as StoryManager
	var dialogue := world.get_node("HUD/DialogueBox") as DialogueBox
	var asha := world.get_node("FoxAsha") as FoxAsha
	var audio := world.get_node("GameAudio") as GameAudio
	dialogue.cancel()
	var player_position := world.player.global_position
	assert(is_equal_approx(audio.get_lio_fight_volume_scale(player_position + Vector2.RIGHT * WorldNavigation.TILE_SIZE), 1.0), "Helper attacks must remain full volume through one tile")
	assert(is_equal_approx(audio.get_lio_fight_volume_scale(player_position + Vector2.RIGHT * WorldNavigation.TILE_SIZE * 4.0), 4.0 / 7.0), "Helper attacks must fade between one and eight tiles")
	assert(is_zero_approx(audio.get_lio_fight_volume_scale(player_position + Vector2.RIGHT * WorldNavigation.TILE_SIZE * 8.0)), "Helper attacks must be silent at eight tiles")
	story._seen_events[&"asha_recruited"] = true
	story._find_characters()

	assert(asha.is_story_interactable(), "Asha must allow one interaction after joining")
	assert(story.interact_with(&"asha"), "The first post-joining interaction must start dialogue")
	assert(dialogue.get_current_text() == "It's fun being with you :)", "Asha must use her one-time companion line")
	_finish_dialogue(dialogue)
	asha._highlight.visible = true
	asha._process(0.0)
	assert(not asha.is_story_interactable() and not asha._highlight.visible, "Asha must stop highlighting after the companion line")
	assert(world._get_story_character_at_position(asha.global_position) == null, "Asha must no longer intercept movement clicks")
	assert(not world.is_cell_occupied(world.world_to_cell(asha.global_position), world.player), "The player must be able to path onto recruited Asha's tile")

	var encoded := (world.get_node("SaveSystem") as SaveSystem).create_save_string(1000)
	story._seen_events.erase(&"asha_post_recruitment")
	assert((world.get_node("SaveSystem") as SaveSystem).load_save_string(encoded, 1000))
	assert(story.has_seen_event(&"asha_post_recruitment") and not asha.is_story_interactable(), "The one-time Asha interaction must remain consumed after loading")
	print("PASS: Asha's one-time post-joining interaction and click-through behavior work")
	world.queue_free()
	await process_frame
	quit()


func _finish_dialogue(dialogue: DialogueBox) -> void:
	while dialogue.is_open():
		dialogue.finish_typing()
		dialogue.advance()
