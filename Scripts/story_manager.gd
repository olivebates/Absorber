class_name StoryManager
extends Node

const TRIGGER_DISTANCE_TILES := 3
const BULL_TRIGGER_DISTANCE_TILES := 6
const MAD_COYOTE_TRIGGER_DISTANCE_TILES := 7
const SAVE_FORMAT := "story_events_v3"
const PLAYER_PORTRAIT := preload("res://Sprites/Fox.webp")
const ASHA_PORTRAIT := preload("res://Sprites/FoxAsha.webp")
const LIO_PORTRAIT := preload("res://Sprites/FoxLio.webp")
const NIA_PORTRAIT := preload("res://Sprites/FoxNia.webp")
const LUCA_PORTRAIT := preload("res://Sprites/FoxLuca.webp")
const DERU_PORTRAIT := preload("res://Sprites/FoxDeruSad.webp")
const DERU_HAPPY_PORTRAIT := preload("res://Sprites/FoxDeruHappy.webp")

var completed_dialogues := 0
var first_gate_opened := false
var _active_dialogue := 0
var _world: WorldNavigation
var _dialogue_box: DialogueBox
var _asha: FoxAsha
var _luca: FoxLuca
var _lio: FoxLio
var _nia: StoryFox
var _deru: FoxDeru
var _first_gate: Gate
var _bull_spawn: EnemySpawnPoint
var _first_gate_cell := Vector2i.ZERO
var _seen_events: Dictionary = {}
var _queued_events: Array[StringName] = []
var _active_event: StringName = &""
var _reopen_shop_after_dialogue := false
var _shop_to_reopen: FoxAsha
var _initialized := false


func _ready() -> void:
	add_to_group("story_manager")
	_world = get_parent() as WorldNavigation
	_dialogue_box = _world.get_node("HUD/DialogueBox") as DialogueBox
	_dialogue_box.dialogue_finished.connect(_on_dialogue_finished)
	_dialogue_box.line_shown.connect(_on_dialogue_line_shown)
	get_tree().node_added.connect(_on_story_node_added)
	call_deferred("_finish_setup")


func _finish_setup() -> void:
	if _initialized:
		return
	var player := get_tree().get_first_node_in_group("player") as FoxPlayer
	if player == null:
		call_deferred("_finish_setup")
		return
	_world.player = player
	if not player.duplicate_equipment_found.is_connected(_on_duplicate_equipment_found):
		player.duplicate_equipment_found.connect(_on_duplicate_equipment_found)
	_first_gate = _world.get_node_or_null("Gate") as Gate
	if _first_gate:
		first_gate_opened = _first_gate.unlocked
		_first_gate_cell = _world.world_to_cell(_first_gate.global_position)
		_bull_spawn = _first_gate.unlock_enemy_spawn
		_first_gate.gate_opened.connect(_on_first_gate_opened)
	_connect_enemy_story_signals()
	_find_characters()
	_initialized = true
	_trigger_event_once(&"game_intro")


func _process(_delta: float) -> void:
	if not _initialized or _world == null or not is_instance_valid(_world.player):
		return
	var dungeon_manager := get_tree().get_first_node_in_group("dungeon_manager") as DungeonManager
	if dungeon_manager and dungeon_manager.is_dungeon_active():
		return
	if _world.gameplay_paused:
		return
	if not is_instance_valid(_asha) or not is_instance_valid(_luca) or not is_instance_valid(_lio) or not is_instance_valid(_nia):
		_find_characters()
	if _dialogue_box == null or _dialogue_box.is_open() or _active_dialogue != 0 or _active_event != &"":
		return
	if not _queued_events.is_empty():
		_begin_event_dialogue(_queued_events.pop_front())
		return
	if _check_mad_coyote_proximity_event():
		return
	match completed_dialogues:
		0:
			if is_instance_valid(_nia) and _tile_distance_to(_nia) <= TRIGGER_DISTANCE_TILES:
				_start_dialogue(1)
				return
		1:
			pass
		2:
			pass
	if _check_bull_proximity_event():
		return
	if _check_campfire_events():
		return
	if first_gate_opened and not _has_seen(&"bull_gate"):
		_seen_events[&"bull_gate"] = true
		_start_dialogue(4)
		return
	if first_gate_opened and _world.world_to_cell(_world.player.global_position) == _first_gate_cell:
		_trigger_event_once(&"gate_tile")


func interact_with(character_id: StringName) -> bool:
	if _dialogue_box == null or _dialogue_box.is_open():
		return true
	if character_id == &"nia":
		if completed_dialogues == 0:
			return _start_dialogue(1)
		return _play_default_dialogue([
			_line("Nia", "That big angry bull is still blocking the way forward through the cave.", NIA_PORTRAIT),
		])
	if character_id == &"asha":
		if is_asha_recruited():
			if _has_seen(&"asha_post_recruitment"):
				return false
			_seen_events[&"asha_post_recruitment"] = true
			if _play_default_dialogue([
				_line("Asha", "It's fun being with you :)", ASHA_PORTRAIT),
			]):
				return true
			_seen_events.erase(&"asha_post_recruitment")
			return false
		if is_deru_quest_started() and not _has_seen(&"asha_deru_parts_intro") and not are_spare_parts_purchased():
			var had_seen_asha_intro := _has_seen(&"asha_intro")
			_seen_events[&"asha_deru_parts_intro"] = true
			_seen_events[&"asha_intro"] = true
			_reopen_shop_after_dialogue = true
			_shop_to_reopen = _asha
			if _play_default_dialogue([
				_line("Mira", "Hey Asha, I need a spare part for Deru's cart.", PLAYER_PORTRAIT),
				_line("Mira", "His cart is stranded out in the Expanse.", PLAYER_PORTRAIT),
				_line("Asha", "Oh, that sounds expensive, usually I'd sell those for 50 fish.", ASHA_PORTRAIT),
				_line("Asha", "Since it's Deru, I'll mark it down to 30 fish, just to break even.", ASHA_PORTRAIT),
				_line("Asha", "I'll put it on stock for you!", ASHA_PORTRAIT),
				_line("Mira", "Thank you, Asha :)", PLAYER_PORTRAIT),
			]):
				return true
			_seen_events.erase(&"asha_deru_parts_intro")
			if not had_seen_asha_intro:
				_seen_events.erase(&"asha_intro")
			_reopen_shop_after_dialogue = false
			_shop_to_reopen = null
			return false
		if _has_seen(&"asha_intro"):
			return false
		_seen_events[&"asha_intro"] = true
		_reopen_shop_after_dialogue = true
		_shop_to_reopen = _asha
		if _start_dialogue(2):
			return true
		_seen_events.erase(&"asha_intro")
		_reopen_shop_after_dialogue = false
		return false
	if character_id == &"luca":
		if _has_seen(&"luca_intro"):
			return false
		_seen_events[&"luca_intro"] = true
		_reopen_shop_after_dialogue = true
		_shop_to_reopen = _luca
		if _play_default_dialogue([
			_line("Lucie", "Whoa, another traveller?", LUCA_PORTRAIT),
			_line("Lucie", "Let me see what I can find for you.", LUCA_PORTRAIT),
		]):
			return true
		_seen_events.erase(&"luca_intro")
		_reopen_shop_after_dialogue = false
		_shop_to_reopen = null
		return false
	if character_id == &"lio":
		if is_instance_valid(_lio) and _lio.is_hunter_recruited():
			if _lio.is_waiting_at_campfire():
				if _lio.is_reward_handoff_free():
					_active_event = &"lio_reward_intro"
					if _play_default_dialogue([
						_line("Lio", "Hey, this one's on me. Here you go, sir!", LIO_PORTRAIT),
					]):
						_lio.authorize_free_reward_handoff()
						return true
					_active_event = &""
					return false
				if not _lio.has_paid_reward_fee() and not _lio.can_pay_reward_fee():
					return _play_default_dialogue([
						_line("Lio", "Haha, appologies, I don't work for free. We agreed on 3 gold, right?", LIO_PORTRAIT),
						_line("Mira", "I don't have that right now...", PLAYER_PORTRAIT),
						_line("Lio", "Well come back when you got the pay :)", LIO_PORTRAIT),
					])
				_active_event = &"lio_reward_intro"
				if _play_default_dialogue([
					_line("Lio", "Sorry I couldn't carry anything more than this.", LIO_PORTRAIT),
					_line("Lio", "Here you are, sir!", LIO_PORTRAIT),
				]):
					if not _lio.has_paid_reward_fee():
						_lio.pay_reward_fee()
					return true
				_active_event = &""
				return false
			return _play_default_dialogue([
				_line("Lio", "Come see me at the campfire once I'm done roundin' up these here critters.", LIO_PORTRAIT),
			])
		if is_instance_valid(_lio) and _lio.has_required_gold_mines() and not _has_seen(&"lio_recruited"):
			_seen_events[&"lio_recruited"] = true
			_seen_events[&"lio_intro"] = true
			_active_event = &"lio_recruitment"
			if _play_default_dialogue([
				_line("Lio", "Well I be, I never thought I'd see the day. Now about that offer...", LIO_PORTRAIT),
				_line("Lio", "Well I see the good work you are doing for our fellow foxes out there in the world.", LIO_PORTRAIT),
				_line("Lio", "I'd like to contribute!", LIO_PORTRAIT),
				_line("Lio", "I think I'd be strong enough to take care of Tiny Woods for yer.", LIO_PORTRAIT),
				_line("Mira", "Yes, that would be a huge help!", PLAYER_PORTRAIT),
				_line("Lio", "Come see me at the campfire once I'm done roundin' up these here critters.", LIO_PORTRAIT),
				_line("Lio", "I won't touch the moles or bosses though, those things scare me.", LIO_PORTRAIT),
			]):
				return true
			_active_event = &""
			_seen_events.erase(&"lio_recruited")
			return false
		if is_instance_valid(_lio) and _lio.has_first_gold_mine():
			_seen_events[&"lio_intro"] = true
			_reopen_shop_after_dialogue = true
			_shop_to_reopen = _lio
			if _play_default_dialogue([
				_line("Lio", "Say, if you could build those contraptions for the remaining gold veins, I'd be happy to quit and come work for you instead, sir!", LIO_PORTRAIT),
			]):
				return true
			_reopen_shop_after_dialogue = false
			_shop_to_reopen = null
			return false
		if _has_seen(&"lio_intro"):
			return _play_default_dialogue([
				_line("Lio", "If only I had a way to automate this gold digging business.", LIO_PORTRAIT),
			])
		_seen_events[&"lio_intro"] = true
		_reopen_shop_after_dialogue = true
		_shop_to_reopen = _lio
		if _start_dialogue(3):
			return true
		_seen_events.erase(&"lio_intro")
		_reopen_shop_after_dialogue = false
		_shop_to_reopen = null
		return false
	if character_id == &"deru":
		if not _has_seen(&"deru_intro"):
			_seen_events[&"deru_intro"] = true
			return _play_default_dialogue([
				_line("Deru", "Oh! Hey. Sorry, my cart gave out on me.", DERU_PORTRAIT),
				_line("Mira", "That’s rough. Are you hurt?", PLAYER_PORTRAIT),
				_line("Deru", "I’m alright, but my cart isn't.", DERU_PORTRAIT),
				_line("Mira", "Well, what do you need to fix it?", PLAYER_PORTRAIT),
				_line("Deru", "Asha might have some spare parts back in Tiny Woods... but you don’t need to go out of your way.", DERU_PORTRAIT),
				_line("Deru", "It's an expensive brand so she won't give them away for free.", DERU_PORTRAIT),
				_line("Mira", "It’s no trouble, really. I’ll go talk with her and come back.", PLAYER_PORTRAIT),
				_line("Deru", "Really? That means so much to me! I’d be in your debt.", DERU_PORTRAIT),
			])
		if not _has_seen(&"deru_parts_delivered"):
			if _world.player.has_inventory_item("spare_cart_parts"):
				_world.player.remove_quest_item("spare_cart_parts")
				_seen_events[&"deru_parts_delivered"] = true
				_apply_deru_repaired_state()
				_active_event = &"deru_recruitment"
				return _play_default_dialogue([
					_line("Mira", "One spare part for deru! Here you go :)", PLAYER_PORTRAIT),
					_line("Deru", "Oh wow, thank you so much!", DERU_HAPPY_PORTRAIT),
					_line("Deru", "I am truly indebted to you, that had to have been expensive.", DERU_HAPPY_PORTRAIT),
					_line("Deru", "Saddly I have no fish to compensate you with. Perhaps there's something else you want?", DERU_HAPPY_PORTRAIT),
					_line("Mira", "You could help me out by rounding up all the creatures in the desert?", PLAYER_PORTRAIT),
					_line("Mira", "That would save me a ton of time.", PLAYER_PORTRAIT),
					_line("Deru", "Oh, yeah, I'll help you out :)", DERU_HAPPY_PORTRAIT),
				])
			return _play_default_dialogue([
				_line("Deru", "I think Asha in Tiny Woods have some spare parts for my cart.", DERU_PORTRAIT),
				_line("Deru", "It's an expensive brand though, sorry!", DERU_PORTRAIT),
			])
		if is_instance_valid(_deru) and _deru.is_hunter_recruited():
			if _deru.is_waiting_at_campfire():
				if _deru.is_reward_handoff_free():
					_active_event = &"deru_reward_intro"
					if _play_default_dialogue([
						_line("Deru", "This one's for free! Enjoy :)", DERU_HAPPY_PORTRAIT),
					]):
						_deru.authorize_free_reward_handoff()
						return true
					_active_event = &""
					return false
				if not _deru.has_paid_reward_fee() and not _deru.can_pay_reward_fee():
					return _play_default_dialogue([
						_line("Deru", "I need a little bit of comensation, this was quite a lot of work.", DERU_HAPPY_PORTRAIT),
						_line("Mira", "I'll come back when I have some more gems :)", PLAYER_PORTRAIT),
					])
				_active_event = &"deru_reward_intro"
				if _play_default_dialogue([
					_line("Deru", "Here you go, friend :)", DERU_HAPPY_PORTRAIT),
				]):
					if not _deru.has_paid_reward_fee():
						_deru.pay_reward_fee()
					return true
				_active_event = &""
				return false
			return _play_default_dialogue([
				_line("Deru", "I'll be with you in a moment, meet me at the campfire when I'm done <3", DERU_HAPPY_PORTRAIT),
			])
		return false
	return false


func is_deru_quest_started() -> bool:
	return _has_seen(&"deru_intro")


func are_spare_parts_purchased() -> bool:
	return _has_seen(&"spare_parts_purchased")


func is_deru_quest_completed() -> bool:
	return _has_seen(&"deru_parts_delivered")


func is_asha_recruited() -> bool:
	return _has_seen(&"asha_recruited")


func has_seen_event(event_id: StringName) -> bool:
	return _has_seen(event_id)


func get_quest_log_entries() -> Array[Dictionary]:
	var quests: Array[Dictionary] = []
	if _has_seen(&"lio_intro"):
		var first_mine_built := is_instance_valid(_lio) and _lio.has_first_gold_mine()
		var all_mines_built := is_instance_valid(_lio) and _lio.has_required_gold_mines()
		var lio_completed := _has_seen(&"lio_recruited")
		quests.append({
			"id": &"lio_automation",
			"title": "Automating Lio's Gold Mines",
			"location": "Tiny Woods",
			"completed": lio_completed,
			"steps": [
				{"text": "Talk to Lio.", "completed": true},
				{"text": "Build the first Gold Mine beside Lio.", "completed": first_mine_built},
				{"text": "Build the two remaining Gold Mines.", "completed": all_mines_built},
				{"text": "Talk to Lio about joining you.", "completed": lio_completed},
			],
		})
	if _has_seen(&"deru_intro"):
		var deru_completed := _has_seen(&"deru_parts_delivered")
		quests.append({
			"id": &"deru_cart",
			"title": "Deru's Broken Cart",
			"location": "Snakemouth Expanse",
			"completed": deru_completed,
			"steps": [
				{"text": "Talk to Deru about his broken cart.", "completed": true},
				{"text": "Ask Asha about spare cart parts.", "completed": _has_seen(&"asha_deru_parts_intro") or _has_seen(&"spare_parts_purchased")},
				{"text": "Buy the spare cart parts from Asha.", "completed": _has_seen(&"spare_parts_purchased")},
				{"text": "Bring the spare cart parts to Deru.", "completed": deru_completed},
			],
		})
	return quests


func reset_dialogue_flags_before_load() -> void:
	if is_instance_valid(_dialogue_box):
		_dialogue_box.cancel()
	completed_dialogues = 0
	first_gate_opened = false
	_seen_events.clear()
	_queued_events.clear()
	_active_dialogue = 0
	_active_event = &""
	_reopen_shop_after_dialogue = false
	_shop_to_reopen = null
	if is_instance_valid(_world):
		_world.interaction_locked = false
		_world.gameplay_paused = false


func get_save_data() -> Array:
	return [
		completed_dialogues, 0, false, false, false, first_gate_opened,
		_nia.get_save_data() if is_instance_valid(_nia) else [],
		_lio.get_save_data() if is_instance_valid(_lio) else [],
		SAVE_FORMAT, _seen_events.duplicate(true),
	]


func load_save_data(data: Array) -> void:
	if is_instance_valid(_dialogue_box):
		_dialogue_box.cancel()
	if is_instance_valid(_world):
		_world.interaction_locked = false
		_world.gameplay_paused = false
		var camera := _world.player.get_node_or_null("Camera2D") as Camera2D if is_instance_valid(_world.player) else null
		if camera:
			camera.position = Vector2.ZERO
	var saved_progress := maxi(0, int(data[0])) if data.size() > 0 else 0
	first_gate_opened = bool(data[5]) if data.size() > 5 else first_gate_opened
	if data.size() > 8 and str(data[8]) == SAVE_FORMAT:
		completed_dialogues = clampi(saved_progress, 0, 4)
		_seen_events.clear()
		if data.size() > 9 and data[9] is Dictionary:
			for event_id in data[9]:
				if bool(data[9][event_id]):
					_seen_events[StringName(event_id)] = true
		# Players who already saw the former mouse-triggered version should not
		# receive the same dialogue again after its trigger moves to Spider.
		if _seen_events.has(&"first_mouse_killed"):
			_seen_events[&"first_spider_killed"] = true
	else:
		# Map saves from the former seven-beat story onto the four retained beats.
		if saved_progress >= 7:
			completed_dialogues = 4
		elif saved_progress >= 5:
			completed_dialogues = 3
		elif saved_progress >= 2:
			completed_dialogues = 2
		else:
			completed_dialogues = saved_progress
		_seen_events.clear()
		if completed_dialogues >= 2:
			_seen_events[&"asha_intro"] = true
		if completed_dialogues >= 4 or first_gate_opened:
			_seen_events[&"bull_gate"] = true
	_find_characters()
	if data.size() > 6 and data[6] is Array and is_instance_valid(_nia):
		_nia.load_save_data(data[6] as Array)
	if data.size() > 7 and data[7] is Array and is_instance_valid(_lio):
		_lio.load_save_data(data[7] as Array)
	_active_dialogue = 0
	_active_event = &""
	_queued_events.clear()
	_reopen_shop_after_dialogue = false
	_shop_to_reopen = null
	_enable_biome_music()


func _find_characters() -> void:
	_asha = _world.get_node_or_null("FoxAsha") as FoxAsha
	_deru = _world.get_node_or_null("FoxDeru") as FoxDeru
	_luca = _world.get_node_or_null("FoxLuca") as FoxLuca
	_lio = _world.get_node_or_null("FoxLio") as FoxLio
	for node in get_tree().get_nodes_in_group("story_characters"):
		if node is StoryFox:
			var fox := node as StoryFox
			if fox.character_id == &"nia":
				_nia = fox
	if is_instance_valid(_asha):
		_asha.set_recruited(is_asha_recruited(), false)
	if is_instance_valid(_lio) and _has_seen(&"lio_recruited") and not _lio.is_hunter_recruited():
		_lio.set_hunter_recruited(true)
	_apply_deru_repaired_state()


func _apply_deru_repaired_state() -> void:
	if is_instance_valid(_deru):
		_deru.set_repaired(is_deru_quest_completed())


func _start_dialogue(dialogue_number: int) -> bool:
	var lines := _get_dialogue(dialogue_number)
	if lines.is_empty():
		return false
	_world.player.stop()
	_active_dialogue = dialogue_number
	if not _dialogue_box.play(lines):
		_active_dialogue = 0
		return false
	# Record a story conversation when it begins so saving mid-dialogue cannot
	# cause the same one-time conversation to trigger again after loading.
	completed_dialogues = maxi(completed_dialogues, dialogue_number)
	return true


func _play_default_dialogue(lines: Array[Dictionary]) -> bool:
	if lines.is_empty():
		return false
	_world.player.stop()
	return _dialogue_box.play(lines)


func on_structure_built(resource_id: StringName, deposit: GoldOre = null) -> void:
	match resource_id:
		&"fish":
			_trigger_event_once(&"fish_hut")
		&"gold_ore":
			if is_instance_valid(_lio) and _lio.has_required_gold_mines():
				_trigger_event_once(&"lio_all_gold_mines")
			elif _is_nearest_gold_ore_to_lio(deposit):
				_trigger_event_once(&"lio_gold_mine")
			else:
				_trigger_event_once(&"gold_mine")
		&"jewels":
			_trigger_event_once(&"gem_mine")
		&"wood":
			_trigger_event_once(&"wood_lodge")


func on_asha_purchase(item_id := "") -> void:
	if item_id == "spare_cart_parts":
		if _has_seen(&"spare_parts_purchased"):
			return
		_seen_events[&"spare_parts_purchased"] = true
		_seen_events[&"asha_recruited"] = true
		if is_instance_valid(_asha):
			_asha.close_shop()
		_active_event = &"asha_recruitment"
		_dialogue_box.play([
			_line("Asha", "So... that part is for Deru, right?", ASHA_PORTRAIT),
			_line("Mira", "Yeah. He is stranded out in the Expanse with his broken cart.", PLAYER_PORTRAIT),
			_line("Asha", "I thought so. You’re always running off to help someone.", ASHA_PORTRAIT),
			_line("Mira", "Someone has to.", PLAYER_PORTRAIT),
			_line("Asha", "Then hey, umm...", ASHA_PORTRAIT),
			_line("Asha", "Maybe... you shouldn’t have to do it alone?", ASHA_PORTRAIT),
			_line("Mira", "Are you asking to come with me?", PLAYER_PORTRAIT),
			_line("Asha", "If you’ll have me. Of course I completely understand if you-", ASHA_PORTRAIT),
			_line("Mira", "I’d like that.", PLAYER_PORTRAIT),
			_line("Asha", "Yeah? O-Okay then! I promise I'll be of use :)", ASHA_PORTRAIT),
			_line("Mira", "I bet you will :)", PLAYER_PORTRAIT),
		])
		return
	if _has_seen(&"asha_purchase"):
		return
	if is_instance_valid(_asha):
		_asha.close_shop()
	_reopen_shop_after_dialogue = true
	_shop_to_reopen = _asha
	_trigger_event_once(&"asha_purchase")


func request_asha_first_smooch() -> bool:
	if not is_asha_recruited() or _has_seen(&"asha_first_smooch") or _dialogue_box.is_open():
		return false
	_seen_events[&"asha_first_smooch"] = true
	_active_event = &"asha_first_smooch"
	return _dialogue_box.play([_line("Asha", "*Smooch*", ASHA_PORTRAIT)])


func on_luca_purchase() -> void:
	if _has_seen(&"luca_purchase"):
		return
	if is_instance_valid(_luca):
		_luca.close_shop()
	_reopen_shop_after_dialogue = true
	_shop_to_reopen = _luca
	_trigger_event_once(&"luca_purchase")


func on_lio_purchase() -> void:
	if _has_seen(&"lio_purchase"):
		return
	if is_instance_valid(_lio):
		_lio.close_shop()
	_reopen_shop_after_dialogue = true
	_shop_to_reopen = _lio
	_trigger_event_once(&"lio_purchase")


func on_lio_reward_delivery_finished() -> void:
	if not is_instance_valid(_dialogue_box):
		return
	if _dialogue_box.is_open() or _active_event != &"":
		_queued_events.append(&"lio_hunt_departure")
		return
	if not _begin_event_dialogue(&"lio_hunt_departure") and is_instance_valid(_lio):
		_lio.start_hunting_after_handoff()


func on_deru_reward_delivery_finished() -> void:
	if not is_instance_valid(_dialogue_box):
		return
	if _dialogue_box.is_open() or _active_event != &"":
		_queued_events.append(&"deru_hunt_departure")
		return
	if not _begin_event_dialogue(&"deru_hunt_departure") and is_instance_valid(_deru):
		_deru.start_hunting_after_handoff()


func _is_nearest_gold_ore_to_lio(deposit: GoldOre) -> bool:
	if not is_instance_valid(deposit) or not is_instance_valid(_lio):
		return false
	var nearest: GoldOre
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("gold_ores"):
		if not node is GoldOre or (node as GoldOre).mined_resource_id != &"gold_ore":
			continue
		var ore := node as GoldOre
		var distance := ore.global_position.distance_squared_to(_lio.global_position)
		if distance < nearest_distance:
			nearest = ore
			nearest_distance = distance
	return deposit == nearest


func on_campfire_teleported() -> void:
	_trigger_event_once(&"campfire_teleport")


func on_auto_fight_first_toggled() -> void:
	_trigger_event_once(&"auto_fight_tutorial")


func _on_duplicate_equipment_found() -> void:
	_trigger_event_once(&"duplicate_equipment")


func _trigger_event_once(event_id: StringName) -> bool:
	if _has_seen(event_id):
		return false
	_seen_events[event_id] = true
	if _dialogue_box.is_open() or _active_dialogue != 0 or _active_event != &"":
		_queued_events.append(event_id)
		return true
	return _begin_event_dialogue(event_id)


func _begin_event_dialogue(event_id: StringName) -> bool:
	var lines := _get_event_dialogue(event_id)
	if lines.is_empty():
		return false
	_world.player.stop()
	_active_event = event_id
	if not _dialogue_box.play(lines):
		_active_event = &""
		return false
	return true


func _on_dialogue_finished() -> void:
	var finished_event := _active_event
	if _active_dialogue > 0:
		completed_dialogues = maxi(completed_dialogues, _active_dialogue)
		_active_dialogue = 0
	_active_event = &""
	if finished_event == &"game_intro":
		_enable_biome_music()
	if finished_event == &"gate_tile":
		_pan_camera_back()
	if finished_event == &"mad_coyote_dungeon_warning":
		_pan_camera_back()
	if finished_event == &"asha_recruitment":
		if is_instance_valid(_asha):
			_asha.set_recruited(true, true)
		return
	if finished_event == &"deru_recruitment":
		if is_instance_valid(_deru):
			_deru.set_repaired(true)
	if finished_event == &"asha_first_smooch":
		_finish_first_smooch()
		return
	if finished_event == &"lio_recruitment":
		if is_instance_valid(_lio):
			_lio.set_hunter_recruited(true)
	if finished_event == &"lio_reward_intro":
		if is_instance_valid(_lio):
			_lio.begin_reward_delivery()
		return
	if finished_event == &"deru_reward_intro":
		if is_instance_valid(_deru):
			_deru.begin_reward_delivery()
		return
	if finished_event == &"lio_hunt_departure":
		if is_instance_valid(_lio):
			_lio.start_hunting_after_handoff()
	if finished_event == &"deru_hunt_departure":
		if is_instance_valid(_deru):
			_deru.start_hunting_after_handoff()
	if not _queued_events.is_empty():
		_begin_event_dialogue(_queued_events.pop_front())
		return
	if _reopen_shop_after_dialogue:
		_reopen_shop_after_dialogue = false
		var shopkeeper := _shop_to_reopen
		_shop_to_reopen = null
		if is_instance_valid(shopkeeper):
			shopkeeper.call_deferred("open_shop")


func _finish_first_smooch() -> void:
	if not is_instance_valid(_world):
		return
	var interaction_was_locked := _world.interaction_locked
	_world.gameplay_paused = true
	_world.interaction_locked = true
	if not is_instance_valid(_world.player):
		_world.gameplay_paused = false
		_world.interaction_locked = interaction_was_locked
		return
	if is_instance_valid(_asha):
		_asha.play_smooch_animation()
	var health_before := _world.player.health
	_world.player.heal(_world.player.max_health)
	_world.player.flash_healed()
	_world.player.show_healing_popup(_world.player.health - health_before)
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(_world.player):
		_world.gameplay_paused = false
		_world.interaction_locked = interaction_was_locked
		return
	if is_instance_valid(_asha):
		_asha.reset_smooch_cooldown()
	_active_event = &"asha_first_smooch_followup"
	_world.gameplay_paused = false
	_world.interaction_locked = interaction_was_locked
	_dialogue_box.play([
		_line("Mira", "H-hey! What was that for?", PLAYER_PORTRAIT),
		_line("Mira", "Oh, I feel a lot better actually!", PLAYER_PORTRAIT),
		_line("Asha", ";)", ASHA_PORTRAIT),
	])


func _enable_biome_music() -> void:
	var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
	if audio:
		audio.enable_biome_music()


func _on_dialogue_line_shown(index: int) -> void:
	if index != 1:
		return
	var focus_target: Node2D
	if _active_event == &"gate_tile":
		focus_target = _world.get_node_or_null("ChickenSpawn35") as Node2D
	elif _active_event == &"mad_coyote_dungeon_warning":
		focus_target = _find_snakemouth_entrance()
	else:
		return
	var camera := _world.player.get_node_or_null("Camera2D") as Camera2D
	if focus_target == null or camera == null:
		return
	_dialogue_box.set_input_locked(true)
	var target_offset := focus_target.global_position - _world.player.global_position
	var tween := camera.create_tween()
	tween.tween_property(camera, "position", target_offset, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_dialogue_box.set_input_locked.bind(false))


func _pan_camera_back() -> void:
	var camera := _world.player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	_world.interaction_locked = true
	var tween := camera.create_tween()
	tween.tween_property(camera, "position", Vector2.ZERO, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func() -> void: _world.interaction_locked = false)


func _on_first_gate_opened() -> void:
	first_gate_opened = true


func _connect_enemy_story_signals() -> void:
	var armor_goat := _world.get_node_or_null("ChickenSpawn12") as EnemySpawnPoint
	if armor_goat and not armor_goat.enemy_killed.is_connected(_on_evil_goat_killed):
		armor_goat.enemy_killed.connect(_on_evil_goat_killed)
	for node in get_tree().get_nodes_in_group("enemy_spawns"):
		if not node is EnemySpawnPoint:
			continue
		_connect_enemy_story_spawn(node as EnemySpawnPoint)


func _on_story_node_added(node: Node) -> void:
	if node is EnemySpawnPoint:
		call_deferred("_connect_enemy_story_spawn", node as EnemySpawnPoint)


func _connect_enemy_story_spawn(spawn: EnemySpawnPoint) -> void:
	if not is_instance_valid(spawn):
		return
	if spawn.enemy_type == 25 and not spawn.enemy_killed.is_connected(_on_spider_killed):
		spawn.enemy_killed.connect(_on_spider_killed)
	if spawn.enemy_type == 6 and not spawn.enemy_killed.is_connected(_on_evil_goat_killed):
		spawn.enemy_killed.connect(_on_evil_goat_killed)
	if spawn.enemy_type == 13 and spawn.boss and not spawn.enemy_killed.is_connected(_on_mad_coyote_killed):
		spawn.enemy_killed.connect(_on_mad_coyote_killed)


func _on_evil_goat_killed(_enemy: ChickenEnemy) -> void:
	_trigger_event_once(&"evil_goat_killed")


func _on_spider_killed(_enemy: ChickenEnemy) -> void:
	_trigger_event_once(&"first_spider_killed")


func _on_mad_coyote_killed(_enemy: ChickenEnemy) -> void:
	_trigger_event_once(&"mad_coyote_killed")


func _check_bull_proximity_event() -> bool:
	if _has_seen(&"bull_proximity") or not is_instance_valid(_bull_spawn):
		return false
	return _trigger_event_once(&"bull_proximity") if _tile_distance_to(_bull_spawn) <= BULL_TRIGGER_DISTANCE_TILES else false


func _check_mad_coyote_proximity_event() -> bool:
	if _has_seen(&"mad_coyote_dungeon_warning"):
		return false
	var dungeon_manager := get_tree().get_first_node_in_group("dungeon_manager") as DungeonManager
	var entrance := _find_snakemouth_entrance()
	# A completed Snakemouth run permanently suppresses this proximity warning,
	# including immediately after loading a save near the coyote.
	if entrance and dungeon_manager and dungeon_manager.is_cleared(entrance.dungeon_id):
		return false
	for node in get_tree().get_nodes_in_group("enemy_spawns"):
		if node is EnemySpawnPoint and (node as EnemySpawnPoint).enemy_type == 13 \
				and _tile_distance_to(node as Node2D) <= MAD_COYOTE_TRIGGER_DISTANCE_TILES:
			return _trigger_event_once(&"mad_coyote_dungeon_warning")
	return false


func _find_snakemouth_entrance() -> DungeonEntrance:
	for node in get_tree().get_nodes_in_group("dungeon_entrances"):
		if not node is DungeonEntrance:
			continue
		var entrance := node as DungeonEntrance
		if entrance.dungeon_scene and entrance.dungeon_scene.resource_path == "res://Scenes/dungeon1_Snakemouth.tscn":
			return entrance
	return _world.get_node_or_null("DungeonEntrance") as DungeonEntrance


func _check_campfire_events() -> bool:
	for node in get_tree().get_nodes_in_group("campfires"):
		if not node is Campfire or not is_instance_valid(node):
			continue
		var campfire := node as Campfire
		if campfire.name == &"Campfire2" and campfire.is_player_in_range(_world.player) and not _has_seen(&"second_campfire"):
			return _trigger_event_once(&"second_campfire")
		var offset := _world.world_to_cell(_world.player.global_position) - _world.world_to_cell(campfire.global_position)
		if absi(offset.x) + absi(offset.y) == 1 and not _has_seen(&"campfire_adjacent"):
			return _trigger_event_once(&"campfire_adjacent")
	return false


func _has_seen(event_id: StringName) -> bool:
	return bool(_seen_events.get(event_id, false))


func _tile_distance_to(character: Node2D) -> float:
	if character == null or not is_instance_valid(character):
		return 999999
	var offset := _world.world_to_cell(_world.player.global_position) - _world.world_to_cell(character.global_position)
	return Vector2(offset).length()


func _line(speaker: String, text: String, portrait: Texture2D) -> Dictionary:
	return {"speaker": speaker, "text": text, "portrait": portrait}


func _get_dialogue(dialogue_number: int) -> Array[Dictionary]:
	match dialogue_number:
		1:
			return [
				_line("Nia", "Be careful. A big angry bull in the cave is blocking the way forward.", NIA_PORTRAIT),
				_line("Mira", "Then I'll get it out of the way.", PLAYER_PORTRAIT),
				_line("Nia", "Talk to Asha first. She can help you prepare.", NIA_PORTRAIT),
			]
		2:
			return [
				_line("Asha", "Oh, hey! There you are!", ASHA_PORTRAIT),
				_line("Asha", "Still keeping Tiny Woods safe I see :)", ASHA_PORTRAIT),
				_line("Mira", "Yeah. Though lately, it feels like it’s getting easier.", PLAYER_PORTRAIT),
				_line("Asha", "Oh? How so?", ASHA_PORTRAIT),
				_line("Mira", "Every time I chase one of those creatures away, I feel a little stronger.", PLAYER_PORTRAIT),
				_line("Asha", "Sounds like all that experience is finally paying off ;)", ASHA_PORTRAIT),
				_line("Mira", "Haha, I guess it is!", PLAYER_PORTRAIT),
				_line("Asha", "Well if you need anything, I'm here for you Mira :)", ASHA_PORTRAIT),
			]
		3:
			return [
				_line("Lio", "You wouldn’t believe how much work it takes to dig up this gold!", LIO_PORTRAIT),
				_line("Lio", "If only I had some way to automate it, hah!", LIO_PORTRAIT),
				_line("Lio", "What I wouldn’t do for some fish right now, haha!", LIO_PORTRAIT),
			]
		4:
			return [
				_line("Mira", "Wow, I can't believe I actually did that!", PLAYER_PORTRAIT),
			]
	return []


func _get_event_dialogue(event_id: StringName) -> Array[Dictionary]:
	match event_id:
		&"game_intro":
			return [
				_line("Mira", "Oh gosh, what a nice nap!", PLAYER_PORTRAIT),
				_line("Mira", "Alright, back to work!", PLAYER_PORTRAIT),
			]
		&"bull_proximity":
			return [_line("Mira", "Whoa, I'm feeling some seriously synister energy from that cave.", PLAYER_PORTRAIT)]
		&"fish_hut":
			return [_line("Mira", "That'll do.", PLAYER_PORTRAIT)]
		&"gold_mine":
			return [_line("Mira", "I'm going to get so much gold.", PLAYER_PORTRAIT)]
		&"lio_gold_mine":
			return [
				_line("Lio", "Whoa, that's quite the contraption!", LIO_PORTRAIT),
				_line("Lio", "I guess that makes my work a lot easier then, haha!", LIO_PORTRAIT),
				_line("Lio", "Say, if you could build those contraptions for the remaining gold veins, I'd be happy to quit and come work for you instead, sir!", LIO_PORTRAIT),
			]
		&"lio_all_gold_mines":
			return [_line("Mira", "There we go, I should speak to Lio about that job offer.", PLAYER_PORTRAIT)]
		&"gem_mine":
			return [_line("Mira", "That'll do nicely.", PLAYER_PORTRAIT)]
		&"wood_lodge":
			return [_line("Mira", "A nice lodge to cut my wood from!", PLAYER_PORTRAIT)]
		&"campfire_adjacent":
			return [_line("Mira", "What a nice temperature.", PLAYER_PORTRAIT)]
		&"asha_purchase":
			return [
				_line("Mira", "Thank you!", PLAYER_PORTRAIT),
				_line("Asha", "My pleasure.", ASHA_PORTRAIT),
			]
		&"gate_tile":
			return [
				_line("Mira", "Man, it sure is hot up ahead", PLAYER_PORTRAIT),
				_line("Mira", "I can sense a monster over there.", PLAYER_PORTRAIT),
				_line("Mira", "He feels powerful.", PLAYER_PORTRAIT),
			]
		&"second_campfire":
			return [
				_line("Mira", "These campfires seem to be connected.", PLAYER_PORTRAIT),
				_line("Mira", "I can get around quickly by pressing M or TAB and selecting a campfire.", PLAYER_PORTRAIT),
			]
		&"luca_purchase":
			return [_line("Lucie", "Appreicate it.", LUCA_PORTRAIT)]
		&"lio_purchase":
			return [_line("Lio", "Oh man, I'm so hungry, thank you!", LIO_PORTRAIT)]
		&"lio_hunt_departure":
			return [_line("Lio", "Once those critters return, I'll head out again! :)", LIO_PORTRAIT)]
		&"deru_hunt_departure":
			return [_line("Deru", "I'll be heading out once the creatures start comming back.", DERU_HAPPY_PORTRAIT)]
		&"campfire_teleport":
			return [_line("Mira", "Convenient.", PLAYER_PORTRAIT)]
		&"evil_goat_killed":
			return [_line("Mira", "Oh look, it dropped a shield!", PLAYER_PORTRAIT)]
		&"first_spider_killed":
			return [
				_line("Mira", "Phew, that was a close one.", PLAYER_PORTRAIT),
				_line("Mira", "I should keep an eye out on my mana!", PLAYER_PORTRAIT),
			]
		&"duplicate_equipment":
			return [
				_line("Mira", "Oh look, another one!", PLAYER_PORTRAIT),
				_line("Mira", "I can merge this with my current one.", PLAYER_PORTRAIT),
			]
		&"auto_fight_tutorial":
			return [
				_line("Mira", "I'll only be able to auto fight enemies I've fought once before.", PLAYER_PORTRAIT),
				_line("Mira", "The new enemies scare me O///O", PLAYER_PORTRAIT),
			]
		&"mad_coyote_dungeon_warning":
			return [
				_line("Mira", "I’ve got a bad feeling about moving on just yet.", PLAYER_PORTRAIT),
				_line("Mira", "I should probably clear this place out first.", PLAYER_PORTRAIT),
			]
		&"mad_coyote_killed":
			return [_line("Mira", "Alright! That clears the path to the next area :)", PLAYER_PORTRAIT)]
	return []
