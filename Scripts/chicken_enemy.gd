class_name ChickenEnemy
extends CharacterBody2D

const DAMAGE_POPUP_SCENE := preload("res://Scenes/damage_popup.tscn")
const ITEM_PICKUP_SCENE := preload("res://Scenes/item_pickup.tscn")
const REWARD_DAMAGE := 0
const REWARD_HEALTH := 1
const REWARD_RESOURCE := 2
const REWARD_REGENERATE := 3
const REWARD_DEFENSE := 4
const HEALTH_REGEN_DELAY := 3.0
const HEALTH_REGEN_INTERVAL := 1.0
const REWARD_ICON_SIZE := 16.0
const AGGRO_RADIUS_TILES := 3.0
const DISENGAGE_FOLLOW_TILES := 3

enum MovementMode {
	PATROL,
	CHASE,
	RETURN_HOME,
}

signal died(enemy: ChickenEnemy)

@export var move_speed := 170.0
# Spawn points own these gameplay stats so one marker configures every enemy it creates.
var max_health := 3
var attack_damage := 1
var armor := 0
@export var attack_range := 46.0
@export var attack_cooldown := 1.0
@export_enum("Red", "Yellow", "Blue") var enemy_color := FoxPlayer.COLOR_RED
@export var aggressive := false

var damage_reward := 1
var reward_type := REWARD_DAMAGE
var damage_reward_color := FoxPlayer.COLOR_RED
var defense_reward_color := FoxPlayer.COLOR_RED
var reward_resource_id: StringName = &"gold_ore"
var drop_table: Array[Dictionary] = []
var health: int
var home_cell := Vector2i.ZERO
var _path := PackedVector2Array()
var _path_index := 0
var _pause_time_left := 0.0
var _attack_time_left := 0.0
var _attack_tween: Tween
var _hit_tween: Tween
var _walk_time := 0.0
var _attack_visual_time_left := 0.0
var _hit_visual_time_left := 0.0
var _combat_ring: Line2D
var _health_regen_delay_left := HEALTH_REGEN_DELAY
var _health_regen_tick_left := 0.0
var _world: WorldNavigation
var _player: FoxPlayer
var _hunter_target: FoxLio
var spawn_point: EnemySpawnPoint
var _suppress_reward_collection_sound := false
var _movement_mode := MovementMode.PATROL
var _was_in_combat := false
var _pursuit_is_limited := false
var _pursuit_tiles_left := 0
var _pursuit_distance_left := 0.0
var _chased_player_cell := Vector2i(-999999, -999999)

@onready var chicken_sprite: Sprite2D = $ChickenSprite
@onready var health_bar: ProgressBar = $HealthBar
@onready var reward_label: Label = $RewardLabel
@onready var reward_icon: Sprite2D = $RewardIcon
@onready var health_label: Label = $HealthLabel
@onready var color_dot: Polygon2D = $ColorDot
@onready var damage_label: Label = $DamageLabel
@onready var reward_dot: Polygon2D = $RewardDot
@onready var reward_dot_outline: Polygon2D = $RewardDotOutline


func setup(spawn_cell: Vector2i, reward: int, type := REWARD_DAMAGE, new_drop_table: Array[Dictionary] = [], new_reward_resource_id: StringName = &"gold_ore", new_damage_reward_color := FoxPlayer.COLOR_RED, new_max_health := 3, new_attack_damage := 1, new_damage_color := FoxPlayer.COLOR_RED, new_armor := 0, new_defense_reward_color := FoxPlayer.COLOR_RED, new_aggressive: Variant = null) -> void:
	home_cell = spawn_cell
	damage_reward = reward
	reward_type = type
	drop_table = new_drop_table.duplicate(true)
	reward_resource_id = new_reward_resource_id
	damage_reward_color = clampi(new_damage_reward_color, FoxPlayer.COLOR_RED, FoxPlayer.COLOR_BLUE)
	defense_reward_color = clampi(new_defense_reward_color, FoxPlayer.COLOR_RED, FoxPlayer.COLOR_BLUE)
	max_health = maxi(1, new_max_health)
	attack_damage = maxi(1, new_attack_damage)
	armor = maxi(0, new_armor)
	enemy_color = clampi(new_damage_color, FoxPlayer.COLOR_RED, FoxPlayer.COLOR_BLUE)
	if new_aggressive != null:
		aggressive = bool(new_aggressive)


func _ready() -> void:
	add_to_group("enemies")
	_world = get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	_player = get_tree().get_first_node_in_group("player") as FoxPlayer
	_pause_time_left = randf_range(0.0, 1.5)
	health = max_health
	health_bar.max_value = max_health
	health_bar.value = health
	reward_dot.visible = false
	reward_dot_outline.visible = false
	_update_health_label()
	_update_color_dot()
	_update_damage_label()
	_update_reward_visual()
	_combat_ring = _create_combat_ring()
	add_child(_combat_ring)


func take_damage(amount: int, automatic := false) -> void:
	if health <= 0:
		return
	_suppress_reward_collection_sound = _suppress_reward_collection_sound or automatic
	var applied_damage := maxi(1, amount - armor)
	var blocked_damage := maxi(0, amount - applied_damage)
	health = max(0, health - applied_damage)
	_health_regen_delay_left = HEALTH_REGEN_DELAY
	_health_regen_tick_left = 0.0
	_begin_limited_pursuit()
	health_bar.value = health
	_update_health_label()
	_show_damage_popup(amount, enemy_color, blocked_damage)
	if health == 0:
		died.emit(self)
		_grant_kill_reward()
		_drop_items()
		queue_free()


func take_hunter_damage(hunter: FoxLio) -> void:
	if health <= 0 or hunter == null:
		return
	_hunter_target = hunter
	# Lio always lands a flat two-damage hit. His attacks deliberately skip
	# the floating damage popup, since only the player needs that feedback.
	health = max(0, health - FoxLio.HUNT_DAMAGE)
	_health_regen_delay_left = HEALTH_REGEN_DELAY
	_health_regen_tick_left = 0.0
	health_bar.value = health
	_update_health_label()
	_play_hit_animation()
	if health == 0:
		hunter.collect_enemy_reward(self)
		died.emit(self)
		queue_free()


func can_be_auto_fought() -> bool:
	return is_instance_valid(spawn_point) and spawn_point.emptied_once


func get_save_data() -> Array:
	return [
		roundi(global_position.x), roundi(global_position.y), home_cell.x, home_cell.y, health,
		maxi(0, roundi(_health_regen_delay_left * 1000.0)), maxi(0, roundi(_health_regen_tick_left * 1000.0)),
		maxi(0, roundi(_attack_time_left * 1000.0)), maxi(0, roundi(_pause_time_left * 1000.0)),
	]


func load_save_data(data: Array, offline_seconds: int) -> bool:
	if data.size() < 9:
		return false
	health = clampi(int(data[4]), 1, max_health)
	var offline_milliseconds := maxi(0, offline_seconds) * 1000
	var regeneration_delay := maxi(0, int(data[5]))
	var regeneration_tick := maxi(0, int(data[6]))
	if health < max_health and offline_milliseconds >= regeneration_delay:
		var regeneration_elapsed := offline_milliseconds - regeneration_delay
		if regeneration_elapsed >= regeneration_tick:
			var regenerated_ticks := 1 + floori(float(regeneration_elapsed - regeneration_tick) / 1000.0)
			health = mini(max_health, health + regenerated_ticks * _get_health_regen_amount())
			regeneration_tick = 1000 - ((regeneration_elapsed - regeneration_tick) % 1000)
		else:
			regeneration_tick -= regeneration_elapsed
		regeneration_delay = 0
	else:
		regeneration_delay = maxi(0, regeneration_delay - offline_milliseconds)
	_health_regen_delay_left = float(regeneration_delay) / 1000.0
	_health_regen_tick_left = float(regeneration_tick) / 1000.0
	_attack_time_left = maxf(0.0, float(int(data[7]) - offline_milliseconds) / 1000.0)
	_pause_time_left = maxf(0.0, float(int(data[8]) - offline_milliseconds) / 1000.0)
	_update_health_bar()
	return true


func get_drop_table_text() -> String:
	var entries: Array[String] = []
	for entry in drop_table:
		var item_name: String = str(ItemPickup.ITEM_NAMES.get(str(entry.get("item_id", "")), "Unknown item"))
		entries.append("%s — %d%%" % [item_name, roundi(float(entry.get("chance", 0.0)) * 100.0)])
	return "Possible drops\n" + "\n".join(entries)


func _drop_items() -> void:
	for entry in drop_table:
		if randf() > float(entry.get("chance", 0.0)):
			continue
		var item_id := str(entry.get("item_id", "weathered_sword"))
		var grade := int(entry.get("grade", 0))
		var pickup := ITEM_PICKUP_SCENE.instantiate() as ItemPickup
		pickup.setup(item_id, grade)
		pickup.global_position = global_position + Vector2(randf_range(-12.0, 12.0), randf_range(-7.0, 7.0))
		get_parent().add_child(pickup)


func _physics_process(delta: float) -> void:
	if _world == null:
		_world = get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as FoxPlayer
	if is_instance_valid(_world) and _world.gameplay_paused:
		velocity = Vector2.ZERO
		_update_walk_animation(0.0)
		_update_combat_ring(false)
		return
	if _dialogue_is_open():
		velocity = Vector2.ZERO
		_update_walk_animation(0.0)
		_update_combat_ring(false)
		return
	_attack_time_left = maxf(0.0, _attack_time_left - delta)
	_attack_visual_time_left = maxf(0.0, _attack_visual_time_left - delta)
	_hit_visual_time_left = maxf(0.0, _hit_visual_time_left - delta)
	var player_in_combat := _is_in_combat()
	var hunter_in_combat := _is_hunter_in_combat()
	var in_combat := player_in_combat or hunter_in_combat
	_update_behavior_state(player_in_combat)
	if in_combat:
		velocity = Vector2.ZERO
		_path.clear()
		_path_index = 0
	elif _movement_mode == MovementMode.CHASE:
		_chase_player(delta)
	elif _movement_mode == MovementMode.RETURN_HOME:
		_return_to_spawn_area(delta)
	elif _pause_time_left > 0.0:
		_pause_time_left -= delta
		velocity = Vector2.ZERO
	else:
		_patrol(delta)
	if hunter_in_combat:
		_attack_hunter()
	else:
		_attack_player(player_in_combat)
	_update_walk_animation(delta)
	_update_combat_ring(in_combat)
	_face_combat_target(player_in_combat, hunter_in_combat)
	_update_health_regeneration(delta, in_combat)
	_was_in_combat = player_in_combat


func _dialogue_is_open() -> bool:
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui") as DialogueBox
	return dialogue != null and dialogue.is_open()


func _update_behavior_state(in_combat: bool) -> void:
	if _world == null or _player == null or _player.health <= 0:
		if _movement_mode == MovementMode.CHASE:
			_begin_return_home()
		return
	if in_combat:
		_movement_mode = MovementMode.CHASE
		_pursuit_is_limited = false
		_pursuit_tiles_left = DISENGAGE_FOLLOW_TILES
		_pursuit_distance_left = DISENGAGE_FOLLOW_TILES * WorldNavigation.TILE_SIZE
		return
	if _was_in_combat:
		_begin_limited_pursuit()
		return
	if aggressive and _movement_mode == MovementMode.PATROL and _is_player_in_aggro_radius():
		_begin_unlimited_pursuit()


func _is_player_in_aggro_radius() -> bool:
	var radius := AGGRO_RADIUS_TILES * WorldNavigation.TILE_SIZE
	return global_position.distance_squared_to(_player.global_position) <= radius * radius


func _begin_unlimited_pursuit() -> void:
	_movement_mode = MovementMode.CHASE
	_pursuit_is_limited = false
	_pursuit_tiles_left = DISENGAGE_FOLLOW_TILES
	_pursuit_distance_left = DISENGAGE_FOLLOW_TILES * WorldNavigation.TILE_SIZE
	_chased_player_cell = Vector2i(-999999, -999999)
	_clear_movement_path()


func _begin_limited_pursuit() -> void:
	if _world == null:
		return
	_movement_mode = MovementMode.CHASE
	_pursuit_is_limited = true
	_pursuit_tiles_left = DISENGAGE_FOLLOW_TILES
	_pursuit_distance_left = DISENGAGE_FOLLOW_TILES * WorldNavigation.TILE_SIZE
	_chased_player_cell = Vector2i(-999999, -999999)
	_clear_movement_path()


func _begin_return_home() -> void:
	_movement_mode = MovementMode.RETURN_HOME
	_pursuit_is_limited = false
	_chased_player_cell = Vector2i(-999999, -999999)
	_clear_movement_path()


func _clear_movement_path() -> void:
	velocity = Vector2.ZERO
	_path.clear()
	_path_index = 0


func _chase_player(delta: float) -> void:
	if not is_instance_valid(_player) or _player.health <= 0:
		_begin_return_home()
		return
	var player_cell := _world.world_to_cell(_player.global_position)
	if player_cell != _chased_player_cell or _path_index >= _path.size():
		_choose_player_adjacent_path(player_cell)
	if _path_index >= _path.size():
		velocity = Vector2.ZERO
		return
	_record_pursuit_progress(_follow_behavior_path(delta))


func _record_pursuit_progress(distance_traveled: float) -> void:
	if not _pursuit_is_limited:
		return
	_pursuit_distance_left = maxf(0.0, _pursuit_distance_left - distance_traveled)
	_pursuit_tiles_left = ceili(_pursuit_distance_left / WorldNavigation.TILE_SIZE)
	if is_zero_approx(_pursuit_distance_left) and not _is_in_combat():
		_begin_return_home()


func _choose_player_adjacent_path(player_cell: Vector2i) -> void:
	_chased_player_cell = player_cell
	var best_path := PackedVector2Array()
	var best_distance := INF
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var adjacent_cell := player_cell + offset
		if not _world.is_walkable(adjacent_cell) or _world.is_cell_occupied(adjacent_cell, self):
			continue
		var candidate := _world.find_path(global_position, _world.cell_to_world(adjacent_cell), self)
		if candidate.is_empty():
			continue
		var distance := _path_distance(candidate)
		if distance < best_distance:
			best_distance = distance
			best_path = candidate
	_path = best_path
	_path_index = 1 if _path.size() > 1 else _path.size()


func _return_to_spawn_area(delta: float) -> void:
	var current_cell := _world.world_to_cell(global_position)
	if (current_cell - home_cell).length_squared() <= 4:
		_movement_mode = MovementMode.PATROL
		_pause_time_left = randf_range(1.0, 2.0)
		_clear_movement_path()
		return
	if _path_index >= _path.size():
		_path = _world.find_path(global_position, _world.cell_to_world(home_cell), self)
		_path_index = 1 if _path.size() > 1 else _path.size()
	if _path_index < _path.size():
		_follow_behavior_path(delta)
	else:
		velocity = Vector2.ZERO


func _follow_behavior_path(delta: float) -> float:
	var previous_position := global_position
	var target := _path[_path_index]
	if _world.is_enemy_target_conflicted(self, _world.world_to_cell(target)):
		_clear_movement_path()
		return 0.0
	var offset := target - global_position
	if offset.length() <= 3.0:
		global_position = target
		_path_index += 1
		velocity = Vector2.ZERO
		return previous_position.distance_to(global_position)
	velocity = offset.normalized() * move_speed
	if velocity.x < -0.1:
		chicken_sprite.flip_h = true
	elif velocity.x > 0.1:
		chicken_sprite.flip_h = false
	if not _world.can_enter_position(self, global_position + velocity * delta):
		_clear_movement_path()
		return 0.0
	move_and_slide()
	return previous_position.distance_to(global_position)


func _path_distance(points: PackedVector2Array) -> float:
	var distance := 0.0
	for index in range(1, points.size()):
		distance += points[index - 1].distance_to(points[index])
	return distance


func _update_health_regeneration(delta: float, in_combat: bool) -> void:
	if health <= 0 or health >= max_health:
		return
	if in_combat:
		_health_regen_delay_left = HEALTH_REGEN_DELAY
		_health_regen_tick_left = 0.0
		return
	if _health_regen_delay_left > 0.0:
		_health_regen_delay_left = maxf(0.0, _health_regen_delay_left - delta)
		return
	_health_regen_tick_left -= delta
	while _health_regen_tick_left <= 0.0 and health < max_health:
		health = mini(max_health, health + _get_health_regen_amount())
		_health_regen_tick_left += HEALTH_REGEN_INTERVAL
	_update_health_bar()


func _get_health_regen_amount() -> int:
	return maxi(1, ceili(float(max_health) * 0.1))


func _patrol(delta: float) -> void:
	if _path_index >= _path.size():
		_choose_patrol_path()
		return
	var target := _path[_path_index]
	if _world and _world.is_enemy_target_conflicted(self, _world.world_to_cell(target)):
		_set_target_to_own_tile(_world)
		return
	var offset := target - global_position
	if offset.length() <= 3.0:
		global_position = target
		_path_index += 1
		if _path_index >= _path.size():
			_pause_time_left = randf_range(3.0, 7.0)
		return
	velocity = offset.normalized() * move_speed
	if velocity.x < -0.1:
		chicken_sprite.flip_h = true
	elif velocity.x > 0.1:
		chicken_sprite.flip_h = false
	if _world and not _world.can_enter_position(self, global_position + velocity * delta):
		_set_target_to_own_tile(_world)
		return
	move_and_slide()


func get_movement_target_cell(world: WorldNavigation) -> Vector2i:
	if _path_index < _path.size():
		return world.world_to_cell(_path[_path_index])
	return world.world_to_cell(global_position)


func _set_target_to_own_tile(world: WorldNavigation) -> void:
	velocity = Vector2.ZERO
	_path = PackedVector2Array([world.cell_to_world(world.world_to_cell(global_position))])
	_path_index = 0
	_pause_time_left = 0.25


func _choose_patrol_path() -> void:
	if _world == null:
		return
	for attempt in range(8):
		var destination := _world.get_patrol_destination(home_cell, 2, self)
		var candidate_path := _world.get_patrol_path(global_position, destination, home_cell, 2, self)
		if candidate_path.size() > 1:
			_path = candidate_path
			_path_index = 1
			return
	_pause_time_left = randf_range(3.0, 7.0)


func _attack_player(in_combat_override: Variant = null) -> void:
	if _attack_time_left > 0.0:
		return
	var in_combat := _is_in_combat() if in_combat_override == null else bool(in_combat_override)
	if in_combat and _player:
		var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
		if audio:
			audio.play_damage()
		_face_toward(_player)
		_play_attack_animation(_player)
		_show_slash(_player)
		_player.take_damage(attack_damage, enemy_color)
		_attack_time_left = attack_cooldown


func _attack_hunter() -> void:
	if _attack_time_left > 0.0 or not _is_hunter_in_combat():
		return
	var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
	if audio:
		audio.play_lio_fight(_hunter_target.global_position)
	_face_toward(_hunter_target)
	_play_attack_animation(_hunter_target)
	# Lio is invulnerable; this counterattack is intentionally visual only.
	_attack_time_left = attack_cooldown


func _play_attack_animation(target: Node2D) -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	_attack_visual_time_left = 0.30
	var direction := signf(target.global_position.x - global_position.x)
	if is_zero_approx(direction):
		direction = 1.0 if not chicken_sprite.flip_h else -1.0
	chicken_sprite.scale = Vector2(0.80, 1.24)
	chicken_sprite.rotation = -0.24 * direction
	_attack_tween = create_tween()
	_attack_tween.set_parallel(true)
	_attack_tween.tween_property(chicken_sprite, "position:x", direction * 11.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(chicken_sprite, "scale", Vector2(1.36, 0.72), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_attack_tween.chain().set_parallel(true)
	_attack_tween.tween_property(chicken_sprite, "position", Vector2.ZERO, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(chicken_sprite, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(chicken_sprite, "rotation", 0.0, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_walk_animation(delta: float) -> void:
	if _attack_visual_time_left > 0.0 or _hit_visual_time_left > 0.0:
		return
	if velocity.length_squared() > 1.0:
		_walk_time += delta * 10.0
		chicken_sprite.position.y = -absf(sin(_walk_time)) * 5.0
		chicken_sprite.rotation = sin(_walk_time) * 0.1
	else:
		chicken_sprite.position = Vector2.ZERO
		chicken_sprite.rotation = 0.0


func _update_health_label() -> void:
	health_label.text = str(health)


func _update_health_bar() -> void:
	health_bar.value = health
	_update_health_label()


func _update_color_dot() -> void:
	var colors := [Color("e53935"), Color("fbc02d"), Color("1976d2")]
	color_dot.color = colors[enemy_color]


func _update_damage_label() -> void:
	damage_label.text = str(attack_damage)


func _update_reward_visual() -> void:
	var colors := [Color("e53935"), Color("fbc02d"), Color("1976d2")]
	var reward_color: Color = colors[damage_reward_color]
	reward_icon.visible = true
	reward_icon.modulate = Color.WHITE
	reward_label.text = "+%d" % damage_reward
	reward_label.offset_left = -2.0
	reward_label.offset_right = 30.0
	reward_icon.position = Vector2(-15, -57)
	if reward_type == REWARD_HEALTH:
		reward_color = Color("800000")
		reward_icon.texture = preload("res://Sprites/Heart.webp")
		reward_dot.visible = true
		reward_dot_outline.visible = true
		reward_dot.color = reward_color
	elif reward_type == REWARD_REGENERATE:
		reward_color = Color("65d76e")
		reward_icon.texture = preload("res://Sprites/RecoveryHeart.webp")
		reward_label.text = "+%s" % FoxPlayer.format_regeneration_value(FoxPlayer.get_healing_increase_per_second(damage_reward))
		reward_label.offset_right = 112.0
	elif reward_type == REWARD_RESOURCE:
		var resource_manager := get_tree().get_first_node_in_group("resource_manager") as ResourceManager
		var definition := resource_manager.get_definition(reward_resource_id) if resource_manager else null
		if definition:
			reward_icon.texture = definition.icon
			reward_icon.modulate = Color.WHITE
		reward_color = Color("ffe082")
	elif reward_type == REWARD_DEFENSE:
		reward_color = colors[defense_reward_color]
		reward_icon.texture = preload("res://Sprites/ShieldIcon.webp")
	else:
		reward_icon.texture = preload("res://Sprites/DamageIcon.webp")
	_set_reward_icon_size()
	reward_label.add_theme_color_override("font_color", reward_color)


func _set_reward_icon_size() -> void:
	if reward_icon.texture == null:
		return
	var texture_width := maxf(1.0, reward_icon.texture.get_size().x)
	reward_icon.scale = Vector2.ONE * (REWARD_ICON_SIZE / texture_width)


func _update_combat_ring(in_combat: bool) -> void:
	_combat_ring.visible = in_combat


func _is_in_combat() -> bool:
	return _player != null and _world != null and _player.health > 0 and _world.are_adjacent(self, _player)


func _is_hunter_in_combat() -> bool:
	if not is_instance_valid(_hunter_target):
		_hunter_target = null
		return false
	return _world != null and _hunter_target.is_hunter_recruited() \
		and _hunter_target.hunt_state == FoxLio.HuntState.HUNTING and _world.are_adjacent(self, _hunter_target)


func _face_player_in_combat(in_combat: bool) -> void:
	if in_combat and _player:
		_face_toward(_player)


func _face_combat_target(player_in_combat: bool, hunter_in_combat: bool) -> void:
	if hunter_in_combat:
		_face_toward(_hunter_target)
	else:
		_face_player_in_combat(player_in_combat)


func _face_toward(target: Node2D) -> void:
	var horizontal_offset := target.global_position.x - global_position.x
	if horizontal_offset > 0.1:
		chicken_sprite.flip_h = false
	elif horizontal_offset < -0.1:
		chicken_sprite.flip_h = true


func _create_combat_ring() -> Line2D:
	var ring := Line2D.new()
	ring.width = 2.5
	var colors := [Color("e53935"), Color("fbc02d"), Color("1976d2")]
	ring.default_color = colors[enemy_color]
	ring.position = Vector2(0, 19)
	ring.z_index = -1
	for index in range(17):
		var angle := TAU * float(index) / 16.0
		ring.add_point(Vector2(cos(angle) * 22.0, sin(angle) * 8.0))
	ring.visible = false
	return ring


func _show_slash(target: Node2D) -> void:
	var colors := [Color("e53935"), Color("fbc02d"), Color("1976d2")]
	var slash := Node2D.new()
	slash.z_index = 20
	slash.position = Vector2(0, -5)
	slash.modulate = Color(1.0, 1.0, 1.0, 0.62)
	target.add_child(slash)
	for offset in [-3.5, 0.0, 3.5]:
		_add_slash_line(slash, Vector2(-14, -12 + offset), Vector2(14, 10 + offset), Color.BLACK, 6.0)
		_add_slash_line(slash, Vector2(-14, -12 + offset), Vector2(14, 10 + offset), colors[enemy_color], 3.2)
	var tween := slash.create_tween()
	tween.tween_property(slash, "scale", Vector2(1.12, 1.12), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.10)
	tween.tween_callback(slash.queue_free)


func _add_slash_line(parent: Node2D, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.add_point(from)
	line.add_point(to)
	parent.add_child(line)


func _grant_kill_reward() -> void:
	var fox := get_tree().get_first_node_in_group("player") as FoxPlayer
	if fox == null:
		return
	match reward_type:
		REWARD_DAMAGE:
			var damage_grid := _get_hud_control("DamageGrid") as DamageGrid
			var damage_target := damage_grid.get_color_target_screen_position(damage_reward_color) if damage_grid else Vector2(42, 42)
			var colors := [Color("e53935"), Color("fbc02d"), Color("1976d2")]
			_launch_reward_orb(damage_target, colors[damage_reward_color], fox.add_color_damage.bind(damage_reward_color, damage_reward))
		REWARD_HEALTH:
			var vitals := _get_hud_control("PlayerVitals")
			var health_target: Vector2 = vitals.call("get_stat_target_screen_position", &"health") if vitals else Vector2(42, 120)
			_launch_reward_orb(health_target, Color("800000"), fox.absorb_enemy_health.bind(damage_reward))
		REWARD_REGENERATE:
			var vitals := _get_hud_control("PlayerVitals")
			var regeneration_target: Vector2 = vitals.call("get_stat_target_screen_position", &"regeneration") if vitals else Vector2(100, 120)
			_launch_reward_orb(regeneration_target, Color("65d76e"), fox.add_passive_healing.bind(damage_reward))
		REWARD_RESOURCE:
			var resource_manager := get_tree().get_first_node_in_group("resource_manager") as ResourceManager
			if resource_manager == null:
				return
			var definition := resource_manager.get_definition(reward_resource_id)
			if definition == null:
				return
			var resource_panel := _get_hud_control("ResourcePanel") as ResourcePanel
			var resource_target := resource_panel.get_resource_target_screen_position(reward_resource_id) if resource_panel else Vector2(58, get_viewport_rect().size.y - 42.0)
			_launch_reward_orb(resource_target, definition.display_color, resource_manager.add_resource.bind(reward_resource_id, damage_reward))
		REWARD_DEFENSE:
			var armor_grid = _get_hud_control("ArmorGrid")
			var defense_target: Vector2 = armor_grid.get_color_target_screen_position(defense_reward_color) if armor_grid else Vector2(90, 42)
			var colors := [Color("e53935"), Color("fbc02d"), Color("1976d2")]
			_launch_reward_orb(defense_target, colors[defense_reward_color], fox.add_color_defense.bind(defense_reward_color, damage_reward))


func _get_hud_control(node_name: String) -> Control:
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	return world.get_node_or_null("HUD/" + node_name) as Control if world else null


func _launch_reward_orb(target_screen_position: Vector2, color: Color, on_arrive: Callable) -> void:
	var target_world_position := get_viewport().get_canvas_transform().affine_inverse() * target_screen_position
	var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
	var on_collected := Callable()
	if audio and not _suppress_reward_collection_sound:
		on_collected = audio.play_upgrade
	RewardOrb.fly(get_parent(), global_position, target_world_position, color, on_arrive, on_collected)


func _show_damage_popup(amount: int, color_index: int, blocked_damage: int) -> void:
	var popup := DAMAGE_POPUP_SCENE.instantiate() as DamagePopup
	popup.position = global_position + Vector2(0, -38)
	get_parent().add_child(popup)
	popup.show_damage(amount, color_index, blocked_damage)
	_play_hit_animation()


func _play_hit_animation() -> void:
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_visual_time_left = 0.20
	chicken_sprite.modulate = Color("fff3b0")
	chicken_sprite.scale = Vector2(1.22, 0.78)
	_hit_tween = create_tween()
	_hit_tween.set_parallel(true)
	_hit_tween.tween_property(chicken_sprite, "modulate", Color.WHITE, 0.16)
	_hit_tween.tween_property(chicken_sprite, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
