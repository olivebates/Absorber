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
	assert(_finish_dialogue(box) == " Oh gosh, what a nice nap! Alright, back to work!", "A new game must begin with Mira's wake-up dialogue")
	story.completed_dialogues = 4

	world.player.global_position = asha.global_position + Vector2(128, 0)
	story._process(0.0)
	assert(not box.is_open(), "Approaching Asha must remain silent")
	asha.interact()
	assert(_finish_dialogue(box) == " Oh, hey! There you are! Still keeping Tiny Woods safe I see :) Yeah. Though lately, it feels like it’s getting easier. Oh? How so? Every time I chase one of those creatures away, I feel a little stronger. Sounds like all that experience is finally paying off ;) Haha, I guess it is! Well, if you need anything, I’ll be right here :)", "Asha's first interaction must play the requested conversation")
	await process_frame
	assert(asha._shop != null and asha._shop.visible, "Asha's shop must open after her greeting")
	var resources := world.get_node("ResourceManager") as ResourceManager
	resources.add_resource(&"gold_ore", 2.0)
	assert(asha._shop.buy_resource(&"fish") and asha._shop.visible, "The first successful purchase must show its feedback before closing the shop")
	await create_timer(0.34).timeout
	assert(not asha._shop.visible, "The first successful purchase must close the shop after its feedback")
	assert(_finish_dialogue(box) == " Thank you! My pleasure.", "The first purchase must play both requested lines")
	await process_frame
	assert(asha._shop.visible, "Asha's shop must reopen after the purchase dialogue")
	asha.close_shop()

	_build_and_expect(world, resources, box, &"fish", "That'll do.")
	var lio_ore := _build_and_expect(world, resources, box, &"gold_ore", "Whoa, that's quite the contraption! I guess that makes my work a lot easier then, haha!")
	_build_and_expect(world, resources, box, &"jewels", "That'll do nicely.")
	_build_and_expect(world, resources, box, &"wood", "A nice lodge to cut my wood from!")
	story.on_structure_built(&"gold_ore", lio_ore)
	assert(not box.is_open(), "A structure's dialogue must not repeat")

	var first_campfire := world.get_node("Campfire") as Campfire
	world.player.global_position = first_campfire.global_position + Vector2(64, 0)
	story._process(0.0)
	assert(_finish_dialogue(box) == " What a nice temperature.", "Direct campfire adjacency must trigger once")
	var second_campfire := world.get_node("Campfire2") as Campfire
	world.player.global_position = second_campfire.global_position
	story._process(0.0)
	assert(_finish_dialogue(box) == " These campfires seem to be connected. I can get around quickly by pressing TAB and selecting a campfire.", "The second campfire must explain fast travel")

	var bull_spawn := story._bull_spawn
	if bull_spawn._spawned_enemies.is_empty():
		bull_spawn._spawn_enemy()
	var bull := bull_spawn._spawned_enemies[0]
	world.player.global_position = bull_spawn.global_position + Vector2(448, 0)
	story._process(0.0)
	assert(not box.is_open(), "The bull warning must not trigger beyond six tiles from its spawn")
	world.player.global_position = bull_spawn.global_position + Vector2(384, 0)
	story._process(0.0)
	assert(_finish_dialogue(box) == " Whoa, I'm feeling some seriously synister energy from that cave.", "Coming within six tiles of the bull spawn must trigger its warning")

	bull.take_damage(bull.health + bull.armor)
	story._process(0.0)
	assert(_finish_dialogue(box) == " Wow, I can't believe I actually did that!", "Opening the bull gate must trigger the victory line")
	world.player.global_position = world.cell_to_world(story._first_gate_cell)
	story._process(0.0)
	assert(_finish_dialogue(box) == " Man, it sure is hot up ahead I can sense a monster over there. He feels powerful.", "Stepping onto the former gate tile must trigger the boss warning")

	world.visited_campfires[world.world_to_cell(first_campfire.global_position)] = true
	var map := world.get_node("HUD/WorldMap") as WorldMap
	world.player.global_position = second_campfire.global_position
	map._canvas._teleport_to_campfire(first_campfire)
	assert(_finish_dialogue(box) == " Convenient.", "The first trip to another campfire must trigger the convenience line")
	var evil_goat_spawn := world.get_node("ChickenSpawn12") as EnemySpawnPoint
	assert(evil_goat_spawn != null, "The world must contain an evil-goat spawn")
	if evil_goat_spawn._spawned_enemies.is_empty():
		evil_goat_spawn._spawn_enemy()
	var evil_goat := evil_goat_spawn._spawned_enemies[0]
	evil_goat.take_damage(evil_goat.health + evil_goat.armor)
	assert(_finish_dialogue(box) == " Oh look, it dropped a shield!", "The first evil-goat kill must mention its shield")

	var saved_events := story.get_save_data()[9] as Dictionary
	assert(saved_events.has("game_intro") and saved_events.has("asha_intro") and saved_events.has("bull_proximity") and saved_events.has("evil_goat_killed"), "One-time story events must be included in saves")
	var story_save := story.get_save_data()
	story._seen_events.clear()
	story.load_save_data(story_save)
	assert(story._has_seen(&"game_intro") and story._has_seen(&"asha_intro") and story._has_seen(&"bull_proximity") and story._has_seen(&"evil_goat_killed"), "One-time story events must restore from saves")
	print("PASS: one-time construction, shop, enemy, gate, campfire, and teleport dialogue events work")
	quit()


func _build_and_expect(world: WorldNavigation, resources: ResourceManager, box: DialogueBox, resource_id: StringName, expected: String) -> GoldOre:
	resources.fill_all_to_maximum()
	var deposit: GoldOre
	for node in get_nodes_in_group("gold_ores"):
		if node is GoldOre and node.mined_resource_id == resource_id and not is_instance_valid(node._mine):
			deposit = node as GoldOre
			break
	assert(deposit != null, "The world must contain an unbuilt deposit for the tested structure")
	deposit._try_build_mine()
	assert(is_instance_valid(deposit._mine), "The structure must build successfully")
	assert(_finish_dialogue(box) == " " + expected, "The first structure of its type must use the requested dialogue")
	return deposit


func _finish_dialogue(box: DialogueBox) -> String:
	var copy := ""
	while box.is_open():
		box.finish_typing()
		copy += " " + box.get_current_text()
		box.advance()
	return copy
