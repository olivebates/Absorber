class_name DungeonDoorLocked
extends Node2D

const PLAYER_PORTRAIT := preload("res://Sprites/Fox.webp")

var unlocked := false
var _pending_player: FoxPlayer
var _level: DungeonLevel


func _ready() -> void:
	add_to_group("dungeon_interactables")
	add_to_group("dungeon_room_objects")
	add_to_group("dungeon_locked_doors")
	add_to_group("solid_walls")
	_refresh_navigation_membership()


func request_interaction(player: FoxPlayer, world: WorldNavigation) -> void:
	if unlocked or player == null or not world is DungeonLevel:
		return
	_pending_player = player
	_level = world as DungeonLevel
	player.clear_attack_target()
	var path := _best_adjacent_path(player, _level)
	if not path.is_empty():
		player.follow_path(path)


func _process(_delta: float) -> void:
	if not is_instance_valid(_pending_player) or not is_instance_valid(_level):
		return
	if _level.are_adjacent(_pending_player, self):
		_pending_player.stop()
		_pending_player = null
		_attempt_unlock()
	elif not _pending_player.is_moving():
		_pending_player = null


func refresh_for_room(_level_value: DungeonLevel) -> void:
	pass


func load_opened(value: bool) -> void:
	if value:
		_unlock(false)


func get_save_data() -> bool:
	return unlocked


func _attempt_unlock() -> void:
	if _level == null or _level.manager == null:
		return
	if _level.manager.has_method("consume_key") and bool(_level.manager.call("consume_key")):
		_unlock(true)
		return
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui") as DialogueBox
	if dialogue:
		dialogue.play([{
			"speaker": "Mira",
			"text": "I need a key to get through here.",
			"portrait": PLAYER_PORTRAIT,
		}])


func _unlock(play_audio: bool) -> void:
	unlocked = true
	remove_from_group("solid_walls")
	remove_from_group("dungeon_interactables")
	_refresh_navigation_membership()
	if play_audio:
		var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
		if audio:
			audio.play_open_gate()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.tween_property(self, "scale", Vector2(1.15, 0.15), 0.22)
	tween.tween_callback(hide)


func _refresh_navigation_membership() -> void:
	var cursor := get_parent()
	while cursor:
		if cursor is WorldNavigation:
			(cursor as WorldNavigation).refresh_navigation_actor_membership(self)
			return
		cursor = cursor.get_parent()


func _best_adjacent_path(player: FoxPlayer, level: DungeonLevel) -> PackedVector2Array:
	var object_cell := level.world_to_cell(global_position)
	var best := PackedVector2Array()
	var best_distance := INF
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var cell := object_cell + offset
		if not level.is_walkable(cell) or level.is_cell_occupied(cell, player):
			continue
		var candidate := level.find_path(player.global_position, level.cell_to_world(cell), player)
		if not candidate.is_empty() and (best.is_empty() or candidate.size() < best.size()):
			best = candidate
	return best
