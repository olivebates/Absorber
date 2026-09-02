class_name DungeonDoor
extends Node2D

var _opened := false
var _armed := false


func _ready() -> void:
	add_to_group("dungeon_room_objects")
	add_to_group("solid_walls")
	_refresh_navigation_membership()
	_arm_after_spawns()


func _arm_after_spawns() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_armed = true


func refresh_for_room(level: DungeonLevel) -> void:
	if _opened or not _armed or level == null:
		return
	var room := level.cell_to_room(level.world_to_cell(global_position))
	if room != level.current_room:
		return
	if not level.has_current_room_enemies():
		_open()


func _open() -> void:
	_opened = true
	remove_from_group("solid_walls")
	_refresh_navigation_membership()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.tween_property(self, "scale", Vector2(1.2, 0.2), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(hide)


func _refresh_navigation_membership() -> void:
	var cursor := get_parent()
	while cursor:
		if cursor is WorldNavigation:
			(cursor as WorldNavigation).refresh_navigation_actor_membership(self)
			return
		cursor = cursor.get_parent()
