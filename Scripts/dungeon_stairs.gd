class_name DungeonStairs
extends Node2D

const TRAVERSE_DURATION := 1.2
const EXIT_TRANSITION_DELAY := 0.8
const CORNER_OFFSET := Vector2(22.0, 22.0)
const TRAVERSE_OFFSET := Vector2(0.0, -20.0)

var _pending_player: FoxPlayer
var _level: DungeonLevel
var _leaving := false


func request_interaction(player: FoxPlayer, world: WorldNavigation) -> void:
	if _leaving or player == null or not world is DungeonLevel:
		return
	_pending_player = player
	_level = world as DungeonLevel
	player.clear_attack_target()
	var path := _best_adjacent_path(player, _level)
	if not path.is_empty():
		player.follow_path(path)


func _process(_delta: float) -> void:
	if _leaving or not is_instance_valid(_pending_player) or not is_instance_valid(_level):
		return
	if _level.are_adjacent(_pending_player, self):
		_pending_player.stop()
		var player := _pending_player
		_pending_player = null
		_leaving = true
		_animate_and_leave(player)
	elif not _pending_player.is_moving():
		_pending_player = null


func _animate_and_leave(player: FoxPlayer) -> void:
	if not is_instance_valid(player) or not is_instance_valid(_level):
		return
	_level.interaction_locked = true
	player.begin_scripted_movement()
	var sprite := player.fox_sprite
	var original_sprite_position := sprite.position
	var original_sprite_rotation := sprite.rotation
	player.global_position = global_position + CORNER_OFFSET + TRAVERSE_OFFSET
	var traversal := create_tween()
	traversal.tween_property(player, "global_position", global_position - CORNER_OFFSET + TRAVERSE_OFFSET, TRAVERSE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var walk := create_tween().set_loops(6)
	walk.tween_property(sprite, "rotation", 0.08, 0.10).set_trans(Tween.TRANS_SINE)
	walk.parallel().tween_property(sprite, "position:y", original_sprite_position.y - 4.0, 0.10).set_trans(Tween.TRANS_SINE)
	walk.tween_property(sprite, "rotation", -0.08, 0.10).set_trans(Tween.TRANS_SINE)
	walk.parallel().tween_property(sprite, "position:y", original_sprite_position.y, 0.10).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(EXIT_TRANSITION_DELAY).timeout
	if is_instance_valid(_level) and is_instance_valid(_level.manager) and _level.manager.has_method("leave_dungeon"):
		_level.manager.call_deferred("leave_dungeon", TRAVERSE_DURATION - EXIT_TRANSITION_DELAY)
	await traversal.finished
	if walk and walk.is_valid():
		walk.kill()
	if is_instance_valid(sprite):
		sprite.position = original_sprite_position
		sprite.rotation = original_sprite_rotation


func _best_adjacent_path(player: FoxPlayer, level: DungeonLevel) -> PackedVector2Array:
	var stairs_cell := level.world_to_cell(global_position)
	var best := PackedVector2Array()
	var best_distance := INF
	for offset: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		var cell := stairs_cell + offset
		if not level.is_walkable(cell) or level.is_cell_occupied(cell, player):
			continue
		var candidate := level.find_path(player.global_position, level.cell_to_world(cell), player)
		if candidate.is_empty():
			continue
		var distance := 0.0
		for index in range(1, candidate.size()):
			distance += candidate[index - 1].distance_to(candidate[index])
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best
