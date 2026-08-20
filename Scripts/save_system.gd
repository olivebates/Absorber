class_name SaveSystem
extends Node

signal game_saved(slot: int)
signal game_loaded(slot: int)

const SAVE_VERSION := 1
const MAX_UNCOMPRESSED_BYTES := 1048576
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


func _ready() -> void:
	_world = get_parent() as WorldNavigation
	add_to_group("save_system")


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
	var save_file := FileAccess.open(get_save_path(slot), FileAccess.WRITE)
	if save_file == null:
		push_error("Could not open save slot %d for writing." % slot)
		return false
	save_file.store_string(create_save_string())
	save_file.close()
	game_saved.emit(slot)
	print("Saved slot %d" % slot)
	return true


func load_game(slot: int) -> bool:
	if slot < 0 or slot > 9 or not FileAccess.file_exists(get_save_path(slot)):
		return false
	var save_file := FileAccess.open(get_save_path(slot), FileAccess.READ)
	if save_file == null:
		push_error("Could not open save slot %d for reading." % slot)
		return false
	var encoded := save_file.get_as_text().strip_edges()
	save_file.close()
	if not load_save_string(encoded):
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
	var spawn_data: Array = []
	for spawn in _get_spawns():
		spawn_data.append(spawn.get_save_data())
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
		if node is ItemPickup and is_instance_valid(node):
			var pickup := node as ItemPickup
			pickup_data.append([roundi(pickup.global_position.x), roundi(pickup.global_position.y), pickup.item_id, pickup.grade])
	var building_data: Array = []
	for node in get_tree().get_nodes_in_group("buildings"):
		if node is GoldShack and is_instance_valid(node):
			building_data.append([roundi(node.global_position.x), roundi(node.global_position.y), node.building_type])
	return [
		SAVE_VERSION, timestamp, _world.player.get_save_data(),
		resource_manager.get_save_data() if resource_manager else [],
		spawn_data, ore_data, gate_mask, pickup_data, building_data,
		_get_shopkeeper().get_save_data() if _get_shopkeeper() else [],
	]


func _apply_state(state: Array, offline_seconds: int) -> bool:
	if _world == null or not is_instance_valid(_world.player):
		return false
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
	var shopkeeper := _get_shopkeeper()
	if shopkeeper:
		shopkeeper.load_save_data(state[9] as Array if state.size() > 9 and state[9] is Array else [])
	var spawn_data := state[4] as Array
	for index in range(spawns.size()):
		var saved_spawn := spawn_data[index] as Array if index < spawn_data.size() and spawn_data[index] is Array else [roundi(spawns[index].respawn_time * 1000.0), []]
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


func _get_shopkeeper() -> WhiteTiger:
	return get_tree().get_first_node_in_group("shopkeepers") as WhiteTiger
