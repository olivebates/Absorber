class_name WhiteTiger
extends Node2D

const ADJACENT_OFFSETS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const PATROL_RADIUS_TILES := 2
const MOVE_SPEED := 120.0

var purchase_counts: Array[int] = [0, 0, 0, 0]
var _waiting_for_player := false
var _player: FoxPlayer
var _world: WorldNavigation
var _shop: TigerShop
var _home_cell := Vector2i.ZERO
var _path := PackedVector2Array()
var _path_index := 0
var _pause_time_left := 0.0
var _highlight: Line2D
var _initialized := false
var _walk_time := 0.0
var _is_walking := false

@onready var tiger_sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("shopkeepers")
	add_to_group("npcs")
	_world = get_parent() as WorldNavigation
	_player = _world.player if _world else get_tree().get_first_node_in_group("player") as FoxPlayer
	_highlight = _create_tile_highlight()
	add_child(_highlight)
	call_deferred("_finish_setup")


func _finish_setup() -> void:
	if _world and _world.floor_layer:
		_home_cell = _world.world_to_cell(global_position)
		_initialized = true


func _process(delta: float) -> void:
	_highlight.visible = Rect2(Vector2(-32, -32), Vector2(64, 64)).has_point(to_local(get_global_mouse_position()))
	_is_walking = false
	if not _initialized:
		_update_walk_animation(delta)
		return
	if _waiting_for_player:
		if is_instance_valid(_player) and is_instance_valid(_world) and _world.are_adjacent(_player, self):
			_waiting_for_player = false
			_player.stop()
			open_shop()
		_update_walk_animation(delta)
		return
	if is_instance_valid(_shop) and _shop.visible:
		_update_walk_animation(delta)
		return
	_patrol(delta)
	_update_walk_animation(delta)


func request_interaction(player: FoxPlayer, world: WorldNavigation) -> bool:
	_player = player
	_world = world
	_stop_patrol()
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
	_pause_time_left = 1.0


func get_save_data() -> Array:
	return [purchase_counts[0], purchase_counts[1], purchase_counts[2], purchase_counts[3], roundi(global_position.x), roundi(global_position.y)]


func load_save_data(data: Array) -> bool:
	purchase_counts = []
	for index in range(4):
		purchase_counts.append(maxi(0, int(data[index])) if index < data.size() else 0)
	if data.size() >= 6 and _world:
		var saved_position := Vector2(float(data[4]), float(data[5]))
		if _world.is_walkable(_world.world_to_cell(saved_position)):
			global_position = saved_position
	_stop_patrol()
	close_shop()
	return true


func _patrol(delta: float) -> void:
	if _world == null:
		return
	if _pause_time_left > 0.0:
		_pause_time_left -= delta
		return
	if _path_index >= _path.size():
		_choose_patrol_path()
		return
	var target := _path[_path_index]
	var offset := target - global_position
	if offset.length() <= 3.0:
		global_position = target
		_path_index += 1
		if _path_index >= _path.size():
			_pause_time_left = randf_range(3.0, 7.0)
		return
	var motion := offset.normalized() * MOVE_SPEED * delta
	if not _world.can_enter_position(self, global_position + motion):
		_stop_patrol()
		_pause_time_left = 0.5
		return
	global_position += motion
	_is_walking = true
	if motion.x < -0.1:
		tiger_sprite.flip_h = false
	elif motion.x > 0.1:
		tiger_sprite.flip_h = true


func _update_walk_animation(delta: float) -> void:
	if not _is_walking:
		tiger_sprite.position.y = 0.0
		tiger_sprite.rotation = 0.0
		return
	_walk_time += delta * 11.0
	tiger_sprite.position.y = -absf(sin(_walk_time)) * 5.0
	tiger_sprite.rotation = sin(_walk_time) * 0.09


func _choose_patrol_path() -> void:
	for _attempt in range(8):
		var destination := _world.get_patrol_destination(_home_cell, PATROL_RADIUS_TILES, self)
		var candidate := _world.get_patrol_path(global_position, destination, _home_cell, PATROL_RADIUS_TILES, self)
		if candidate.size() > 1:
			_path = candidate
			_path_index = 1
			return
	_pause_time_left = randf_range(3.0, 7.0)


func _stop_patrol() -> void:
	_path.clear()
	_path_index = 0


func _create_tile_highlight() -> Line2D:
	var highlight := Line2D.new()
	highlight.width = 2.0
	highlight.default_color = Color.YELLOW
	highlight.antialiased = false
	highlight.z_index = 20
	for point in [Vector2(-31, -31), Vector2(31, -31), Vector2(31, 31), Vector2(-31, 31), Vector2(-31, -31)]:
		highlight.add_point(point)
	highlight.visible = false
	return highlight
