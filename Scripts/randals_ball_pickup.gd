class_name RandalsBallPickup
extends Node2D

const ADJACENT_OFFSETS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var _player: FoxPlayer
var _world: WorldNavigation
var _waiting_for_player := false

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_world = get_parent() as WorldNavigation
	_player = _world.player if _world else get_tree().get_first_node_in_group("player") as FoxPlayer
	call_deferred("refresh_availability")


func _process(_delta: float) -> void:
	if _waiting_for_player and is_instance_valid(_player) and is_instance_valid(_world) \
			and _world.are_adjacent(_player, self):
		_waiting_for_player = false
		_player.stop()
		interact()
	var hovering := visible and Rect2(Vector2(-24, -24), Vector2(48, 48)).has_point(to_local(get_global_mouse_position()))
	_sprite.modulate = Color(1.35, 1.35, 0.75) if hovering else Color.WHITE


func refresh_availability() -> void:
	var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
	var available := story != null and story.is_randal_quest_started() \
		and not story.is_randals_ball_collected() and not story.is_randal_quest_completed()
	visible = available
	if available:
		if not is_in_group("world_interactables"):
			add_to_group("world_interactables")
	else:
		remove_from_group("world_interactables")
		_waiting_for_player = false


func request_interaction(player: FoxPlayer, world: WorldNavigation) -> bool:
	_player = player
	_world = world
	refresh_availability()
	if not visible:
		return false
	if _world.are_adjacent(_player, self):
		_player.stop()
		interact()
		return true
	var best_path := PackedVector2Array()
	var pickup_cell := _world.world_to_cell(global_position)
	for offset in ADJACENT_OFFSETS:
		var target_cell: Vector2i = pickup_cell + offset
		if not _world.is_walkable(target_cell) or _world.is_cell_occupied(target_cell, _player):
			continue
		var candidate := _world.find_path(_player.global_position, _world.cell_to_world(target_cell), _player)
		if candidate.is_empty():
			continue
		if best_path.is_empty() or candidate.size() < best_path.size():
			best_path = candidate
	if best_path.is_empty():
		return false
	_player.clear_attack_target()
	_player.follow_path(best_path)
	_waiting_for_player = true
	return true


func interact() -> void:
	var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
	if story:
		story.interact_with(&"randals_ball")
	refresh_availability()
