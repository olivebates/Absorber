extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := load("res://Scenes/fox.tscn").instantiate() as FoxPlayer
	root.add_child(player)
	var characters: Array[Node] = [
		load("res://Scenes/fox_asha.tscn").instantiate() as FoxAsha,
		load("res://Scenes/fox_nia.tscn").instantiate() as StoryFox,
		load("res://Scenes/fox_lio.tscn").instantiate() as FoxLio,
		load("res://Scenes/fox_luca.tscn").instantiate() as FoxLuca,
		load("res://Scenes/fox_deru.tscn").instantiate() as FoxDeru,
	]
	for character in characters:
		root.add_child(character)
	var dialogue := DialogueBox.new()
	root.add_child(dialogue)
	await process_frame

	assert(player.get_talk_pitch_range() == Vector2(0.9, 1.1), "Mira must use the requested neutral pitch range")
	var expected_ranges := {
		"Asha": Vector2(1.3, 1.5),
		"Nia": Vector2(1.3, 1.5),
		"Lio": Vector2(0.5, 0.7),
		"Lucie": Vector2(1.3, 1.5),
		"Deru": Vector2(0.5, 0.7),
	}
	for character in characters:
		var speaker := str(character.call("get_dialogue_speaker_name"))
		var pitch_range: Vector2 = character.call("get_talk_pitch_range")
		assert(pitch_range == expected_ranges[speaker], "%s must keep its own authored talk pitch range" % speaker)
		assert(pitch_range == Vector2(1.3, 1.5) if speaker in ["Asha", "Nia", "Lucie"] else pitch_range == Vector2(0.5, 0.7), "%s pitch must reflect the fox's voice" % speaker)

	assert(dialogue.play([{"speaker": "Mira", "text": "Talking", "portrait": null}]), "Dialogue must open")
	for index in range(3):
		dialogue._process(DialogueBox.TYPE_INTERVAL)
	assert(dialogue._talk_player.stream.resource_path == "res://Music/sndTalk.ogg" and dialogue._talk_player.playing, "sndTalk must play as non-whitespace text appears")
	assert(dialogue._talk_sound_play_count == 3, "sndTalk must replay for each newly revealed non-whitespace glyph")
	assert(dialogue._talk_player.pitch_scale >= 0.9 and dialogue._talk_player.pitch_scale <= 1.1, "Mira's talk sound must vary only within 0.9-1.1")
	dialogue.finish_typing()
	assert(not dialogue._talk_player.playing, "Skipping the typewriter must stop the talk sound")
	dialogue.close()

	for speaker in expected_ranges:
		assert(dialogue.play([{"speaker": speaker, "text": "Voice", "portrait": null}]), "%s dialogue must open" % speaker)
		dialogue._process(DialogueBox.TYPE_INTERVAL)
		var pitch_range: Vector2 = expected_ranges[speaker]
		assert(dialogue._talk_player.pitch_scale >= pitch_range.x and dialogue._talk_player.pitch_scale <= pitch_range.y, "%s must use its own pitch range" % speaker)
		dialogue.close()

	print("PASS: typewriter talk audio and per-character pitch ranges work")
	quit()
