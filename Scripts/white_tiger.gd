class_name WhiteTiger
extends Node2D

const ADJACENT_OFFSETS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var purchase_counts: Array[int] = [0, 0, 0, 0]
var _waiting_for_player := false
var _player: FoxPlayer
var _world: WorldNavigation
var _shop: TigerShop


func _ready() -> void:
	add_to_group("shopkeepers")
	add_to_group("npcs")
	_world = get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	_player = get_tree().get_first_node_in_group("player") as FoxPlayer


func _process(_delta: float) -> void:
	if _waiting_for_player and is_instance_valid(_player) and is_instance_valid(_world) and _world.are_adjacent(_player, self):
		_waiting_for_player = false
		_player.stop()
		open_shop()


func request_interaction(player: FoxPlayer, world: WorldNavigation) -> bool:
	_player = player
	_world = world
	if _world.are_adjacent(_player, self):
		_player.stop()
		open_shop()
		return true
	var best_path := PackedVector2Array()
	var tiger_cell := _world.world_to_cell(global_position)
	for offset in ADJACENT_OFFSETS:
		var target_cell: Vector2i = tiger_cell + Vector2i(offset)
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


func open_shop() -> void:
	var hud := _world.get_node_or_null("HUD") as CanvasLayer if _world else null
	if hud == null:
		return
	if not is_instance_valid(_shop):
		_shop = TigerShop.new()
		hud.add_child(_shop)
		_shop.setup(self)
	_shop.open()


func close_shop() -> void:
	if is_instance_valid(_shop):
		_shop.close()


func get_save_data() -> Array:
	return purchase_counts.duplicate()


func load_save_data(data: Array) -> bool:
	purchase_counts = []
	for index in range(4):
		purchase_counts.append(maxi(0, int(data[index])) if index < data.size() else 0)
	close_shop()
	return true
