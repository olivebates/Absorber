class_name SaveSystem
extends Node

signal game_saved(slot: int)
signal game_loaded(slot: int)
signal auto_saved
signal backups_changed

const SAVE_VERSION := 1
const MAX_UNCOMPRESSED_BYTES := 1048576
const AUTO_SAVE_PATH := "user://auto_save"
const BACKUP_STATE_PATH := "user://backup_state.json"
const AUTO_SAVE_INTERVAL := 5.0
const STARTUP_BACKUP_COOLDOWN_SECONDS := 10 * 60
const SESSION_BACKUP_INTERVAL := 2.0 * 60.0 * 60.0
const MAX_SESSION_BACKUPS := 5
const MAX_BACKUPS := 20
const ITEM_PICKUP_SCENE := preload("res://Scenes/item_pickup.tscn")
const GOLD_SHACK_SCENE := preload("res://Scenes/gold_shack.tscn")
const GEM_SHACK_SCENE := preload("res://Scenes/gem_shack.tscn")
const FISH_CRATE_SCENE := preload("res://Scenes/fish_crate.tscn")
const WOOD_CRATE_SCENE := preload("res://Scenes/wood_crate.tscn")
const COMPRESSION_MODES := [
	FileAccess.COMPRESSION_FASTLZ,
	FileAccess.COMPRESSION_DEFLATE,
	FileAccess.COMPRESSION_ZSTD,
	FileAccess.COMPRESSION_GZIP,
]

var _world: WorldNavigation
var _auto_save_time_left := AUTO_SAVE_INTERVAL
var _session_backup_time_left := SESSION_BACKUP_INTERVAL
var _session_backup_count := 0
var _automatic_saves_enabled := false


func _ready() -> void:
	_world = get_parent() as WorldNavigation
	add_to_group("save_system")
	call_deferred("_start_automatic_saves")


func _process(delta: float) -> void:
	if not _automatic_saves_enabled:
		return
	_auto_save_time_left -= delta
	if _auto_save_time_left <= 0.0:
		_auto_save_time_left = AUTO_SAVE_INTERVAL
		save_auto()
	if _session_backup_count >= MAX_SESSION_BACKUPS:
		return
	_session_backup_time_left -= delta
	if _session_backup_time_left <= 0.0:
		_session_backup_time_left += SESSION_BACKUP_INTERVAL
		if create_backup():
			_session_backup_count += 1


func _start_automatic_saves() -> void:
	# Script-driven smoke tests instantiate the world without making it the active
	# scene. Keeping persistence off there avoids tests touching a player's saves.
	if get_tree().current_scene != _world:
		return
	_create_startup_backup_if_due()
	if FileAccess.file_exists(AUTO_SAVE_PATH):
		load_file(AUTO_SAVE_PATH)
	_automatic_saves_enabled = true


func save_auto() -> bool:
	var saved := save_string_to_file(AUTO_SAVE_PATH, create_save_string())
	if saved:
		auto_saved.emit()
	return saved


func load_auto() -> bool:
	return load_file(AUTO_SAVE_PATH)


func save_string_to_file(path: String, encoded: String) -> bool:
	var save_file := FileAccess.open(path, FileAccess.WRITE)
	if save_file == null:
		push_error("Could not open %s for writing." % path)
		return false
	save_file.store_string(encoded.strip_edges())
	save_file.close()
	return true


func load_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var save_file := FileAccess.open(path, FileAccess.READ)
	if save_file == null:
		return false
	var encoded := save_file.get_as_text().strip_edges()
	save_file.close()
	return load_save_string(encoded)


func import_save_string(encoded: String) -> bool:
	if not load_save_string(encoded.strip_edges()):
		return false
	return save_auto()


func delete_auto_save() -> bool:
	if not FileAccess.file_exists(AUTO_SAVE_PATH):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(AUTO_SAVE_PATH)) == OK


func create_backup() -> bool:
	if not FileAccess.file_exists(AUTO_SAVE_PATH):
		return false
	var source := FileAccess.open(AUTO_SAVE_PATH, FileAccess.READ)
	if source == null:
		return false
	var encoded := source.get_as_text()
	source.close()
	var path := _unique_backup_path()
	if not save_string_to_file(path, encoded):
		return false
	_trim_backups()
	backups_changed.emit()
	return true


func get_backup_paths(show_all := false) -> PackedStringArray:
	var paths := _all_backup_paths()
	paths.reverse()
	if not show_all and paths.size() > 5:
		paths.resize(5)
	return paths


func load_backup(path: String) -> bool:
	if not path.begins_with("user://backup_"):
		return false
	if not load_file(path):
		return false
	return save_auto()


func get_backup_display_name(path: String) -> String:
	return path.get_file().trim_prefix("backup_").replace("_", "  ")


func _create_startup_backup_if_due() -> void:
	if not FileAccess.file_exists(AUTO_SAVE_PATH):
		return
	var now := int(Time.get_unix_time_from_system())
	var state := _read_backup_state()
	var last_startup := int(state.get("last_startup_backup_unix", 0))
	if now - last_startup < STARTUP_BACKUP_COOLDOWN_SECONDS:
		return
	if create_backup():
		state["last_startup_backup_unix"] = now
		_write_backup_state(state)


func _unique_backup_path() -> String:
	var time := Time.get_datetime_dict_from_system()
	var stem := "backup_%04d-%02d-%02d_%02d-%02d-%02d" % [time.year, time.month, time.day, time.hour, time.minute, time.second]
	var path := "user://%s" % stem
	var suffix := 2
	while FileAccess.file_exists(path):
		path = "user://%s_%d" % [stem, suffix]
		suffix += 1
	return path


func _all_backup_paths() -> PackedStringArray:
	var result := PackedStringArray()
	var directory := DirAccess.open("user://")
	if directory == null:
		return result
	for file_name in directory.get_files():
		if file_name.begins_with("backup_") and file_name != BACKUP_STATE_PATH.get_file():
			result.append("user://%s" % file_name)
	result.sort()
	return result


func _trim_backups() -> void:
	var paths := _all_backup_paths()
	while paths.size() > MAX_BACKUPS:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(paths[0]))
		paths.remove_at(0)


func _read_backup_state() -> Dictionary:
	if not FileAccess.file_exists(BACKUP_STATE_PATH):
		return {}
	var file := FileAccess.open(BACKUP_STATE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}


func _write_backup_state(state: Dictionary) -> void:
	save_string_to_file(BACKUP_STATE_PATH, JSON.stringify(state))


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	var key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	if key == KEY_P and key_event.shift_pressed and not key_event.ctrl_pressed and not key_event.alt_pressed and not key_event.meta_pressed:
		var resource_manager := get_tree().get_first_node_in_group("resource_manager") as ResourceManager
		if resource_manager:
			resource_manager.fill_all_to_maximum()
		get_viewport().set_input_as_handled()
		return
	if key < KEY_0 or key > KEY_9 or key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed:
		return
	var slot := int(key - KEY_0)
	if key_event.shift_pressed:
		save_game(slot)
	else:
		load_game(slot)
	get_viewport().set_input_as_handled()


func get_save_path(slot: int) -> String:
	return "user://s%d" % slot


func save_game(slot: int) -> bool:
	if slot < 0 or slot > 9:
		return false
	if not save_string_to_file(get_save_path(slot), create_save_string()):
		return false
	game_saved.emit(slot)
	print("Saved slot %d" % slot)
	return true


func load_game(slot: int) -> bool:
	if slot < 0 or slot > 9 or not FileAccess.file_exists(get_save_path(slot)):
		return false
	if not load_file(get_save_path(slot)):
		push_error("Save slot %d is invalid or incompatible." % slot)
		return false
	game_loaded.emit(slot)
	print("Loaded slot %d" % slot)
	return true


func create_save_string(saved_at_unix := -1) -> String:
	var timestamp := int(Time.get_unix_time_from_system()) if saved_at_unix < 0 else int(saved_at_unix)
	return _encode_state(_capture_state(timestamp))


func load_save_string(encoded: String, loaded_at_unix := -1) -> bool:
	var state := _decode_state(encoded)
	if state.size() < 8 or int(state[0]) != SAVE_VERSION:
		return false
	var now := int(Time.get_unix_time_from_system()) if loaded_at_unix < 0 else int(loaded_at_unix)
	var offline_seconds := maxi(0, now - int(state[1]))
	return _apply_state(state, offline_seconds)


func _capture_state(timestamp: int) -> Array:
	var resource_manager := get_tree().get_first_node_in_group("resource_manager") as ResourceManager
	var dungeon_manager := _get_dungeon_manager()
	var spawn_data: Array = []
	for spawn in _get_spawns():
		spawn_data.append([str(spawn.name), spawn.get_save_data()])
	var ore_data: Array = []
	for ore in _get_ores():
		ore_data.append(ore.get_save_data())
	var gate_mask := 0
	var gates := _get_gates()
	for index in range(gates.size()):
		if gates[index].unlocked:
			gate_mask |= 1 << index
	var pickup_data: Array = []
	for node in get_tree().get_nodes_in_group("item_pickups"):
		if node is ItemPickup and is_instance_valid(node) and _world.belongs_to_world(node):
			var pickup := node as ItemPickup
			pickup_data.append([roundi(pickup.global_position.x), roundi(pickup.global_position.y), pickup.item_id, pickup.grade])
	var building_data: Array = []
	for node in get_tree().get_nodes_in_group("buildings"):
		if node is GoldShack and is_instance_valid(node):
			building_data.append([roundi(node.global_position.x), roundi(node.global_position.y), node.building_type])
	return [
		SAVE_VERSION, timestamp, dungeon_manager.get_player_save_data_for_save() if dungeon_manager else _world.player.get_save_data(),
		resource_manager.get_save_data() if resource_manager else [],
		spawn_data, ore_data, gate_mask, pickup_data, building_data,
		_get_shopkeeper().get_save_data() if _get_shopkeeper() else [],
		_world.get_exploration_save_data(),
		_get_story_manager().get_save_data() if _get_story_manager() else [],
		_get_luca().get_save_data() if _get_luca() else [],
		_get_deru().get_save_data() if _get_deru() else [],
		_world.version_number,
		dungeon_manager.get_save_data() if dungeon_manager else [],
	]


func _apply_state(state: Array, offline_seconds: int) -> bool:
	if _world == null or not is_instance_valid(_world.player):
		return false
	var story := _get_story_manager()
	if story:
		story.reset_dialogue_flags_before_load()
	var dungeon_manager := _get_dungeon_manager()
	if dungeon_manager:
		dungeon_manager.prepare_for_save_load()
		dungeon_manager.reset_for_save_load()
	var spawns := _get_spawns()
	for spawn in spawns:
		spawn.clear_for_load()
	for node in get_tree().get_nodes_in_group("reward_orbs"):
		if is_instance_valid(node):
			node.free()
	for node in get_tree().get_nodes_in_group("item_pickups"):
		if is_instance_valid(node):
			node.free()
	for node in get_tree().get_nodes_in_group("buildings"):
		if node is GoldShack and is_instance_valid(node):
			node.free()
	var saved_buildings := state[8] as Array if state.size() > 8 and state[8] is Array else []
	for raw_building in saved_buildings:
		if not raw_building is Array or (raw_building as Array).size() < 2:
			continue
		var building_position := raw_building as Array
		var building_type := int(building_position[2]) if building_position.size() > 2 else 0
		var shack_scene := WOOD_CRATE_SCENE if building_type == 3 else FISH_CRATE_SCENE if building_type == 2 else GEM_SHACK_SCENE if building_type == 1 else GOLD_SHACK_SCENE
		var shack := shack_scene.instantiate() as GoldShack
		shack.global_position = Vector2(float(building_position[0]), float(building_position[1]))
		_world.add_child(shack)

	var resource_manager := get_tree().get_first_node_in_group("resource_manager") as ResourceManager
	if resource_manager:
		resource_manager.load_save_data(state[3] as Array)

	var gates := _get_gates()
	var gate_mask := int(state[6])
	for index in range(gates.size()):
		gates[index].set_unlocked((gate_mask & (1 << index)) != 0)

	var ore_data := state[5] as Array
	var ores := _get_ores()
	for index in range(ores.size()):
		ores[index].load_save_data(ore_data[index] as Array if index < ore_data.size() and ore_data[index] is Array else [0], offline_seconds)

	if not _world.player.load_save_data(state[2] as Array, offline_seconds):
		return false
	var saved_world_version := int(state[14]) if state.size() > 14 else -1
	if saved_world_version != _world.version_number:
		_world.player.reset_to_beginning()
	_world.load_exploration_save_data(state[10] as Array if state.size() > 10 and state[10] is Array else [])
	if story:
		story.load_save_data(state[11] as Array if state.size() > 11 and state[11] is Array else [])
	var shopkeeper := _get_shopkeeper()
	if shopkeeper:
		shopkeeper.load_save_data(state[9] as Array if state.size() > 9 and state[9] is Array else [])
	var luca: FoxAsha = _get_luca()
	if luca:
		luca.load_save_data(state[12] as Array if state.size() > 12 and state[12] is Array else [])
	var deru: FoxAsha = _get_deru()
	if deru:
		deru.load_save_data(state[13] as Array if state.size() > 13 and state[13] is Array else [])
	if dungeon_manager:
		dungeon_manager.load_save_data(state[15] as Array if state.size() > 15 and state[15] is Array else [], offline_seconds)
	var spawn_data := state[4] as Array
	var saved_spawns_by_name: Dictionary = {}
	var uses_named_spawns := false
	for raw_spawn in spawn_data:
		if raw_spawn is Array and raw_spawn.size() >= 2 and raw_spawn[0] is String and raw_spawn[1] is Array:
			uses_named_spawns = true
			saved_spawns_by_name[str(raw_spawn[0])] = raw_spawn[1]
	for index in range(spawns.size()):
		var default_spawn := [roundi(spawns[index].respawn_time * 1000.0), []]
		var saved_spawn: Array
		if uses_named_spawns:
			saved_spawn = saved_spawns_by_name.get(str(spawns[index].name), default_spawn) as Array
		else:
			saved_spawn = spawn_data[index] as Array if index < spawn_data.size() and spawn_data[index] is Array else default_spawn
		spawns[index].load_save_data(saved_spawn, offline_seconds)

	for raw_pickup in state[7] as Array:
		if not raw_pickup is Array:
			continue
		var pickup_data := raw_pickup as Array
		if pickup_data.size() < 4 or not ItemPickup.ITEM_DATA.has(str(pickup_data[2])):
			continue
		var pickup := ITEM_PICKUP_SCENE.instantiate() as ItemPickup
		pickup.setup(str(pickup_data[2]), int(pickup_data[3]))
		pickup.global_position = Vector2(float(pickup_data[0]), float(pickup_data[1]))
		_world.add_child(pickup)
	return true


func _encode_state(state: Array) -> String:
	var raw := JSON.stringify(state).to_utf8_buffer()
	var best_mode: int = COMPRESSION_MODES[0]
	var best_compressed := raw.compress(best_mode)
	for mode in COMPRESSION_MODES:
		var candidate := raw.compress(int(mode))
		if not candidate.is_empty() and (best_compressed.is_empty() or candidate.size() < best_compressed.size()):
			best_mode = int(mode)
			best_compressed = candidate
	var envelope := PackedByteArray()
	envelope.resize(5)
	envelope[0] = best_mode
	envelope.encode_u32(1, raw.size())
	envelope.append_array(best_compressed)
	return Marshalls.raw_to_base64(envelope)


func _decode_state(encoded: String) -> Array:
	var envelope := Marshalls.base64_to_raw(encoded)
	if envelope.size() <= 5:
		return []
	var compression_mode := int(envelope[0])
	if not COMPRESSION_MODES.has(compression_mode):
		return []
	var raw_size := int(envelope.decode_u32(1))
	if raw_size <= 0 or raw_size > MAX_UNCOMPRESSED_BYTES:
		return []
	var raw := envelope.slice(5).decompress(raw_size, compression_mode)
	if raw.size() != raw_size:
		return []
	var decoded: Variant = JSON.parse_string(raw.get_string_from_utf8())
	return decoded as Array if decoded is Array else []


func _get_spawns() -> Array[EnemySpawnPoint]:
	var result: Array[EnemySpawnPoint] = []
	for child in _world.get_children():
		if child is EnemySpawnPoint:
			result.append(child)
	return result


func _get_ores() -> Array[GoldOre]:
	var result: Array[GoldOre] = []
	for child in _world.get_children():
		if child is GoldOre:
			result.append(child)
	return result


func _get_gates() -> Array[Gate]:
	var result: Array[Gate] = []
	for child in _world.get_children():
		if child is Gate:
			result.append(child)
	return result


func _get_shopkeeper() -> FoxAsha:
	return _world.get_node_or_null("FoxAsha") as FoxAsha


func _get_luca() -> FoxAsha:
	return _world.get_node_or_null("FoxLuca") as FoxAsha


func _get_deru() -> FoxAsha:
	return _world.get_node_or_null("FoxDeru") as FoxAsha


func _get_story_manager() -> StoryManager:
	return get_tree().get_first_node_in_group("story_manager") as StoryManager


func _get_dungeon_manager() -> DungeonManager:
	return get_tree().get_first_node_in_group("dungeon_manager") as DungeonManager
