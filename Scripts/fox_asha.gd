class_name FoxAsha
extends Node2D

const ADJACENT_OFFSETS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const PATROL_RADIUS_TILES := 2
const MOVE_SPEED := 120.0
const INVALID_CELL := Vector2i(-999999, -999999)

@export var reverse_sprite_orientation := false
@export var stationary := false

var purchase_counts: Array[int] = [0, 0, 0, 0]
var _waiting_for_player := false
var _player: FoxPlayer
var _world: WorldNavigation
var _shop: FoxShop
var _home_cell := Vector2i.ZERO
var _path := PackedVector2Array()
var _path_index := 0
var _pause_time_left := 0.0
var _highlight: Line2D
var _initialized := false
var _walk_time := 0.0
var _is_walking := false
var _purchase_reaction_tween: Tween
var _recruited := false
var _last_player_cell := INVALID_CELL
var _follow_target_cell := INVALID_CELL
var _smooch_cooldown_left := 0.0
var _smooch_in_progress := false

@onready var fox_sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("shopkeepers")
	add_to_group("npcs")
	add_to_group("story_characters")
	_world = get_parent() as WorldNavigation
	_player = _world.player if _world else get_tree().get_first_node_in_group("player") as FoxPlayer
	_highlight = _create_tile_highlight()
	add_child(_highlight)
	call_deferred("_finish_setup")


func _finish_setup() -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as FoxPlayer
	if _world and _world.floor_layer:
		_home_cell = _world.world_to_cell(global_position)
		_initialized = true


func _process(delta: float) -> void:
	_highlight.visible = Rect2(Vector2(-32, -32), Vector2(64, 64)).has_point(to_local(get_global_mouse_position()))
	_is_walking = false
	if is_instance_valid(_world) and _world.gameplay_paused:
		_stop_patrol()
		_update_walk_animation(0.0)
		return
	if _dialogue_is_open():
		_stop_patrol()
		_update_walk_animation(delta)
		return
	if not _initialized:
		_update_walk_animation(delta)
		return
	if _waiting_for_player:
		if is_instance_valid(_player) and is_instance_valid(_world) and _world.are_adjacent(_player, self):
			_waiting_for_player = false
			_player.stop()
			interact()
		_update_walk_animation(delta)
		return
	if is_instance_valid(_shop) and _shop.visible:
		_update_walk_animation(delta)
		return
	if _recruited:
		_follow_player(delta)
		_check_asha_healing(delta)
		_update_walk_animation(delta)
		return
	if stationary:
		_update_walk_animation(delta)
		return
	_patrol(delta)
	_update_walk_animation(delta)


func set_recruited(value: bool, celebrate := false) -> void:
	if _recruited == value:
		# Story-state refreshes may reapply the saved recruitment flag. Do not
		# erase an active follow target when the state has not actually changed.
		if value and celebrate:
			_play_recruitment_celebration()
		return
	_recruited = value
	if not value:
		_last_player_cell = INVALID_CELL
		_follow_target_cell = INVALID_CELL
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as FoxPlayer
	stationary = false
	_stop_patrol()
	_last_player_cell = _world.world_to_cell(_player.global_position) if is_instance_valid(_world) and is_instance_valid(_player) else INVALID_CELL
	# There is no vacated tile yet. Asha should hold her position until the
	# player actually crosses into a new cell.
	_follow_target_cell = INVALID_CELL
	if celebrate:
		_play_recruitment_celebration()


func is_recruited() -> bool:
	return _recruited


func can_overlap_navigation_actor(actor: Node2D) -> bool:
	return _recruited and actor is FoxPlayer


func reset_smooch_cooldown() -> void:
	_smooch_cooldown_left = 8.0
	_smooch_in_progress = false


func _follow_player(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as FoxPlayer
	if not is_instance_valid(_world) or not is_instance_valid(_player):
		return
	var player_cell := _world.world_to_cell(_player.global_position)
	_record_player_tile(player_cell)
	if _follow_target_cell == INVALID_CELL:
		return
	var target := _world.cell_to_world(_follow_target_cell)
	var offset := target - global_position
	var distance := offset.length()
	if distance <= 1.0:
		global_position = target
		return
	var lerp_weight := minf(1.0, _player.move_speed * delta / distance)
	var previous_position := global_position
	global_position = global_position.lerp(target, lerp_weight)
	var motion := global_position - previous_position
	_is_walking = true
	if motion.x < -0.1:
		fox_sprite.flip_h = reverse_sprite_orientation
	elif motion.x > 0.1:
		fox_sprite.flip_h = not reverse_sprite_orientation


func _record_player_tile(player_cell: Vector2i) -> bool:
	if player_cell == _last_player_cell:
		return false
	_follow_target_cell = _last_player_cell
	_last_player_cell = player_cell
	return true


func _check_asha_healing(delta: float) -> void:
	_smooch_cooldown_left = maxf(0.0, _smooch_cooldown_left - delta)
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as FoxPlayer
	if _smooch_in_progress or not is_instance_valid(_player) or _player.health <= 0:
		return
	var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
	if story == null:
		return
	if not story.has_seen_event(&"asha_first_smooch"):
		if float(_player.health) < float(_player.max_health) * 0.90:
			_smooch_in_progress = true
			if not story.request_asha_first_smooch():
				_smooch_in_progress = false
		return
	if _smooch_cooldown_left <= 0.0 and float(_player.health) < float(_player.max_health) * 0.95:
		play_smooch_animation()
		var health_before := _player.health
		var smooch_healing := maxi(1, roundi(_player.get_effective_passive_healing_per_second() * 10.0))
		_player.heal(smooch_healing)
		_player.flash_healed()
		_player.show_healing_popup(_player.health - health_before)
		_smooch_cooldown_left = 8.0


func play_smooch_animation() -> void:
	if not is_instance_valid(fox_sprite) or not is_instance_valid(_player):
		return
	var direction := signf(_player.global_position.x - global_position.x)
	if is_zero_approx(direction):
		direction = 1.0
	var tween := fox_sprite.create_tween()
	tween.tween_property(fox_sprite, "position:x", direction * 12.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(fox_sprite, "rotation", -0.18 * direction, 0.10)
	tween.tween_property(fox_sprite, "position", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(fox_sprite, "rotation", 0.0, 0.18)


func _play_recruitment_celebration() -> void:
	var hud := _world.get_node_or_null("HUD") as CanvasLayer if _world else null
	if hud == null:
		return
	var banner := Label.new()
	banner.name = "AshaJoinCelebration"
	banner.text = "Asha joins the team!"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.position = Vector2(-190, 52)
	banner.size = Vector2(380, 54)
	banner.add_theme_font_size_override("font_size", 28)
	banner.add_theme_color_override("font_color", Color("fff176"))
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.add_theme_constant_override("outline_size", 6)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(banner)
	banner.scale = Vector2(0.35, 0.35)
	banner.modulate.a = 0.0
	banner.pivot_offset = banner.size * 0.5
	var tween := banner.create_tween()
	tween.set_parallel(true)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "modulate:a", 1.0, 0.18)
	tween.chain().tween_interval(1.6)
	tween.chain().tween_property(banner, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(banner.queue_free)


func request_interaction(player: FoxPlayer, world: WorldNavigation) -> bool:
	_player = player
	_world = world
	_stop_patrol()
	if _world.are_adjacent(_player, self):
		_player.stop()
		interact()
		return true
	var best_path := PackedVector2Array()
	var fox_cell := _world.world_to_cell(global_position)
	for offset in ADJACENT_OFFSETS:
		var target_cell: Vector2i = fox_cell + Vector2i(offset)
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
	if story and story.interact_with(&"asha"):
		return
	open_shop()


func open_shop() -> void:
	var hud := _world.get_node_or_null("HUD") as CanvasLayer if _world else null
	if hud == null:
		return
	if not is_instance_valid(_shop):
		_shop = FoxShop.new()
		hud.add_child(_shop)
		_shop.setup(self)
	_shop.open()


func close_shop() -> void:
	if is_instance_valid(_shop):
		_shop.close()
	_pause_time_left = 1.0


func play_purchase_reaction() -> void:
	if not is_instance_valid(fox_sprite):
		return
	if _purchase_reaction_tween and _purchase_reaction_tween.is_valid():
		_purchase_reaction_tween.kill()
	fox_sprite.scale = Vector2.ONE
	fox_sprite.modulate = Color.WHITE
	_purchase_reaction_tween = fox_sprite.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_purchase_reaction_tween.tween_property(fox_sprite, "scale", Vector2(1.18, 0.84), 0.08)
	_purchase_reaction_tween.parallel().tween_property(fox_sprite, "modulate", Color(1.28, 1.20, 0.82), 0.08)
	_purchase_reaction_tween.tween_property(fox_sprite, "scale", Vector2(0.94, 1.10), 0.09)
	_purchase_reaction_tween.tween_property(fox_sprite, "scale", Vector2.ONE, 0.13)
	_purchase_reaction_tween.parallel().tween_property(fox_sprite, "modulate", Color.WHITE, 0.13)


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
		fox_sprite.flip_h = reverse_sprite_orientation
	elif motion.x > 0.1:
		fox_sprite.flip_h = not reverse_sprite_orientation


func _update_walk_animation(delta: float) -> void:
	if not _is_walking:
		fox_sprite.position.y = 0.0
		fox_sprite.rotation = 0.0
		return
	_walk_time += delta * 11.0
	fox_sprite.position.y = -absf(sin(_walk_time)) * 5.0
	fox_sprite.rotation = sin(_walk_time) * 0.09


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


func _dialogue_is_open() -> bool:
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui") as DialogueBox
	return dialogue != null and dialogue.is_open()
