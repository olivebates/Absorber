extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := load("res://Scenes/world.tscn").instantiate() as WorldNavigation
	root.add_child(world)
	await process_frame
	await process_frame
	var story := world.get_node("StoryManager") as StoryManager
	var box := world.get_node("HUD/DialogueBox") as DialogueBox
	var asha := world.get_node("FoxAsha") as FoxAsha
	var nia := world.get_node("FoxNia") as StoryFox
	var lio := world.get_node("FoxLio") as StoryFox
	assert(story != null and box != null and asha != null and nia != null and lio != null, "The world must contain the dialogue system and all three story foxes")
	assert(not box.is_open(), "The opening dialogue must not play when the game starts")
	for dialogue_number in range(1, 5):
		assert(story._get_dialogue(dialogue_number).size() <= 6, "Every story dialogue must contain at most six messages")
	world.player.global_position = nia.global_position + Vector2(256, 0)
	story._process(0.0)
	assert(not box.is_open(), "Nia's opening dialogue must not trigger beyond three tiles")
	world.player.global_position = nia.global_position + Vector2(192, 0)
	story._process(0.0)
	assert(box.is_open() and box.get_current_speaker() == "Nia", "Nia's opening dialogue must begin within a three-tile radius")
	var portrait := box.find_child("Portrait", true, false) as TextureRect
	var identity := portrait.get_parent() as VBoxContainer
	assert(identity.get_index() == 1 and portrait.flip_h, "An NPC portrait and name must appear on the right with the portrait flipped")
	var dialogue_panel := box.get_child(0) as MarginContainer
	var first_line_width := dialogue_panel.size.x
	var opening_copy := box.get_current_text()
	assert(box.is_typing() and not (box.find_child("ContinueHint", true, false) as Label).visible, "Dialogue must type before showing its continue arrow")
	box.finish_typing()
	assert((box.find_child("ContinueHint", true, false) as Label).visible, "Completing a line must reveal the continue arrow")
	box.advance()
	assert(box.get_current_speaker() == "Mira" and identity.get_index() == 0 and not portrait.flip_h, "Mira's unflipped portrait and name must appear on the left")
	assert(is_equal_approx(dialogue_panel.size.x, first_line_width) and absf(dialogue_panel.position.x + dialogue_panel.size.x * 0.5 - box.size.x * 0.5) < 2.0, "The dialogue panel must keep one fitted width throughout a conversation")
	var npc_positions := [asha.global_position, nia.global_position, lio.global_position]
	asha._process(0.5)
	nia._process(0.5)
	lio._process(0.5)
	assert(asha.global_position == npc_positions[0] and nia.global_position == npc_positions[1] and lio.global_position == npc_positions[2], "Story foxes must remain still while dialogue is open")
	opening_copy += _finish_dialogue(box)
	assert(opening_copy.contains("big angry bull") and opening_copy.contains("blocking the way forward") and opening_copy.contains("Asha"), "Nia must explain the cave obstruction and direct the player to Asha")
	assert(story.completed_dialogues == 1, "Finishing the opening must advance story progress")
	assert(story.interact_with(&"nia") and box.is_open(), "Nia must have default interaction dialogue")
	assert(box.get_current_text().contains("big angry bull") and story._active_dialogue == 0, "Nia's default dialogue must be one non-story line about the bull")
	box.finish_typing()
	box.advance()

	world.player.global_position = asha.global_position + Vector2(128, 0)
	story._process(0.0)
	assert(not box.is_open(), "Getting close to Asha must not trigger dialogue")
	assert(story.interact_with(&"asha"), "The first interaction with Asha must start her introduction")
	assert(box.is_open() and box.get_current_speaker() == "Asha", "Asha's introduction must start when she is first interacted with")
	assert(identity.get_index() == 1 and not portrait.flip_h, "Asha must appear on the right without flipping her portrait")
	var asha_copy := _finish_dialogue(box)
	assert(asha_copy.contains("Oh, there you are! Welcome back :)") and asha_copy.contains("Have a look at what I've got"), "Asha must welcome the player before showing her wares")
	await process_frame
	assert(asha._shop != null and asha._shop.visible, "Asha's shop must open after her first dialogue")
	asha.close_shop()
	assert(not story.interact_with(&"asha") and not box.is_open(), "Asha must not repeat her introduction on later interactions")

	world.player.absorb_enemy_health(2)
	story._process(0.0)
	assert(not box.is_open(), "Absorbing enemy Health must not start an extra dialogue")
	world.player.global_position = lio.global_position + Vector2(128, 0)
	story._process(0.0)
	assert(box.is_open() and box.get_current_speaker() == "Lio" and portrait.flip_h, "Lio's introduction must trigger and use a flipped right-side portrait")
	var lio_copy := _finish_dialogue(box)
	assert(lio_copy.contains("giant bull") and lio_copy.contains("cave") and lio_copy.contains("entrance to the desert"), "Lio must explain that the cave's giant bull blocks the desert entrance")
	assert(story.interact_with(&"lio") and box.is_open(), "Lio must have default interaction dialogue")
	assert(box.get_current_text().contains("giant bull") and box.get_current_text().contains("desert"), "Lio's default interaction must be one line about the bull blocking the desert")
	box.finish_typing()
	box.advance()

	var first_gate := world.get_node("Gate") as Gate
	first_gate.set_unlocked(true)
	story._process(0.0)
	assert(box.is_open() and box.get_current_speaker() == "Mira" and identity.get_index() == 0 and not portrait.flip_h, "The first-gate dialogue must use Mira's left-side portrait")
	var gate_copy := _finish_dialogue(box)
	assert(gate_copy.contains("Wow, I can't believe I actually did that!"), "Opening the bull's gate must acknowledge the player's victory")
	assert(story.completed_dialogues == 4, "Only the four retained story dialogues must be tracked")

	var save_system := world.get_node("SaveSystem") as SaveSystem
	var encoded := save_system.create_save_string(1000)
	story.completed_dialogues = 0
	assert(save_system.load_save_string(encoded, 1000), "A save containing story state must load")
	assert(story.completed_dialogues == 4, "Save/load must restore four-dialogue story progress")
	print("PASS: short proximity dialogues, content-fit layout, defaults, and persistence work")
	quit()


func _finish_dialogue(box: DialogueBox) -> String:
	var copy := ""
	while box.is_open():
		box.finish_typing()
		copy += " " + box.get_current_text()
		box.advance()
	return copy
