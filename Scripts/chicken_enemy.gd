class_name ChickenEnemy
extends CharacterBody2D

const DAMAGE_POPUP_SCENE := preload("res://Scenes/damage_popup.tscn")
const ITEM_PICKUP_SCENE := preload("res://Scenes/item_pickup.tscn")
const REWARD_DAMAGE := 0
const REWARD_HEALTH := 1
const REWARD_RESOURCE := 2
const REWARD_REGENERATE := 3
const REWARD_DEFENSE := 4
const REWARD_MANA := 5
const REWARD_MANA_REGENERATE := 6
const HEALTH_REGEN_DELAY := 3.0
const HEALTH_REGEN_INTERVAL := 1.0
const REWARD_ICON_SIZE := 16.0
const AGGRO_RADIUS_TILES := 3.0
const DISENGAGE_FOLLOW_TILES := 3
const SKILL_NONE := 0
const SKILL_CRUSHING_BLOW := 1
const SKILL_CASCADING_SWEEP := 2
const SKILL_CASCADING_SURROUND := 3
const SKILL_FAN_STRIKE_QUICK := 4
const SKILL_FAN_STRIKE_CHARGED := 5
const SKILL_DRIVING_STRIKE_QUICK := 6
const SKILL_DRIVING_STRIKE_CHARGED := 7
const SKILL_DEFAULT_COOLDOWNS := [0.0, 6.0, 8.0, 10.0, 6.0, 9.0, 6.0, 9.0]
const DAMAGE_COLORS := [Color("e53935"), Color("fbc02d"), Color("1976d2")]
const PLAYER_PORTRAIT := preload("res://Sprites/Fox.webp")
const ENEMY_SKILL_MOVE_TUTORIAL_DELAY := 0.4
const SNARE_WITHOUT_QUICK_ROLL_TUTORIAL_DELAY := 0.2
const CASCADING_SWEEP_TUTORIAL_DELAY := 0.4
const ENEMY_SKILL_MOVE_TUTORIAL_TEXT := "He's about to unleash a powerful attack, I should step out of the way."
const SNARE_WITHOUT_QUICK_ROLL_TUTORIAL_TEXT := "Oh no, I'm snared, I can't move!"
const CASCADING_SWEEP_TUTORIAL_TEXT := "I'm snared, I can't move! I have to use my skill by pressing Q to get out of it."

enum MovementMode {
	PATROL,
	CHASE,
	CENTER_AFTER_PURSUIT,
	RETURN_HOME,
	CENTER_AFTER_RETURN,
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
var rewards_enabled := true
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
var _combat_alignment_target: Node2D
var _combat_entry_aligned := false
var _pursuit_is_limited := false
var _pursuit_tiles_left := 0
var _pursuit_distance_left := 0.0
var _chased_player_cell := Vector2i(-999999, -999999)
var enemy_skills: Array[Dictionary] = []
var _skill_cooldowns: Array[float] = []
var _combat_skills_initialized := false
var _active_skill_slot := -1
var _active_skill_elapsed := 0.0
var _active_skill_windup := 0.0
var _active_skill_damage := 0
var _active_skill_damage_type := FoxPlayer.COLOR_RED
var _active_skill_direction := Vector2i.RIGHT
var _active_skill_targets: Array[Dictionary] = []
var _active_skill_id := SKILL_NONE
var _active_skill_released := false
var _active_skill_impact_count := 0
var _skill_visual_tween: Tween
var _skill_camera_tween: Tween
var _skill_camera: Camera2D
var _skill_camera_origin := Vector2.ZERO
var _skill_name_label: Label
var _last_skill_resolution_feedback: Array[String] = []
var _skill_tutorial_paused := false
var _skip_cascade_tutorial_for_current_cast := false
var _flip_sprite_orientation := false

@onready var chicken_sprite: Sprite2D = $ChickenSprite
@onready var health_bar: ProgressBar = $HealthBar
@onready var reward_label: Label = $RewardLabel
@onready var reward_icon: Sprite2D = $RewardIcon
@onready var health_label: Label = $HealthLabel
@onready var color_dot: Polygon2D = $ColorDot
@onready var damage_label: Label = $DamageLabel
@onready var reward_dot: Polygon2D = $RewardDot
@onready var reward_dot_outline: Polygon2D = $RewardDotOutline


func setup(spawn_cell: Vector2i, reward: int, type := REWARD_DAMAGE, new_drop_table: Array[Dictionary] = [], new_reward_resource_id: StringName = &"gold_ore", new_damage_reward_color := FoxPlayer.COLOR_RED, new_max_health := 3, new_attack_damage := 1, new_damage_color := FoxPlayer.COLOR_RED, new_armor := 0, new_defense_reward_color := FoxPlayer.COLOR_RED, new_aggressive: Variant = null, new_enemy_skills: Array[Dictionary] = [], flip_sprite_orientation := false) -> void:
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
	enemy_skills = new_enemy_skills.slice(0, 3).duplicate(true)
	_flip_sprite_orientation = flip_sprite_orientation
	_skill_cooldowns.resize(enemy_skills.size())
	_skill_cooldowns.fill(0.0)


func _ready() -> void:
	add_to_group("enemies")
	_resolve_gameplay_context()
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
	_set_facing_left(false)


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
		if rewards_enabled:
			_grant_kill_reward()
			_drop_items()
		queue_free()


func take_hunter_damage(hunter: FoxLio) -> void:
	if health <= 0 or hunter == null:
		return
	_hunter_target = hunter
	# Helper attacks deliberately skip the floating damage popup, since only
	# the player's attacks need that feedback.
	health = max(0, health - hunter.get_hunt_damage())
	_health_regen_delay_left = HEALTH_REGEN_DELAY
	_health_regen_tick_left = 0.0
	health_bar.value = health
	_update_health_label()
	_play_hit_animation()
	if health == 0:
		if rewards_enabled:
			hunter.collect_enemy_reward(self)
		died.emit(self)
		queue_free()


func prepare_for_hunter_combat(hunter: FoxLio) -> void:
	if hunter == null or health <= 0:
		return
	_hunter_target = hunter
	_clear_movement_path()


func can_be_auto_fought() -> bool:
	return is_instance_valid(spawn_point) and spawn_point.emptied_once


func get_save_data() -> Array:
	return [
		roundi(global_position.x), roundi(global_position.y), home_cell.x, home_cell.y, health,
		maxi(0, roundi(_health_regen_delay_left * 1000.0)), maxi(0, roundi(_health_regen_tick_left * 1000.0)),
		maxi(0, roundi(_attack_time_left * 1000.0)), maxi(0, roundi(_pause_time_left * 1000.0)),
		rewards_enabled,
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
	rewards_enabled = bool(data[9]) if data.size() > 9 else true
	_update_health_bar()
	_update_reward_visual()
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
		_resolve_gameplay_context()
	if _player == null:
		_resolve_gameplay_context()
	if is_instance_valid(_world) and is_instance_valid(_player) and not _world.belongs_to_world(_player):
		_player = null
	if _world is DungeonLevel and not (_world as DungeonLevel).is_actor_in_active_room(self):
		_reset_enemy_skills()
		velocity = Vector2.ZERO
		_update_walk_animation(0.0)
		_update_combat_ring(false)
		return
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
	if _skill_tutorial_paused:
		_resume_skill_telegraph_tweens()
	_attack_time_left = maxf(0.0, _attack_time_left - delta)
	_attack_visual_time_left = maxf(0.0, _attack_visual_time_left - delta)
	_hit_visual_time_left = maxf(0.0, _hit_visual_time_left - delta)
	var player_in_combat := _is_in_combat()
	var hunter_in_combat := _is_hunter_in_combat()
	var in_combat := player_in_combat or hunter_in_combat
	var combatants_aligned := true
	_update_behavior_state(player_in_combat)
	var player_combat_sequence_active := player_in_combat or _movement_mode == MovementMode.CHASE
	_update_enemy_skill_cooldowns(delta, player_combat_sequence_active)
	if _active_skill_slot >= 0:
		velocity = Vector2.ZERO
		_path.clear()
		_path_index = 0
		_update_active_enemy_skill(delta)
		combatants_aligned = false
	elif in_combat:
		velocity = Vector2.ZERO
		_path.clear()
		_path_index = 0
		var combat_target: Node2D = _hunter_target if hunter_in_combat else _player
		if combat_target != _combat_alignment_target:
			_combat_alignment_target = combat_target
			_combat_entry_aligned = false
		_combat_entry_aligned = _world.center_stationary_combatants(combat_target, self)
		combatants_aligned = _combat_entry_aligned
	elif _movement_mode == MovementMode.CHASE:
		_chase_player(delta)
	elif _movement_mode == MovementMode.CENTER_AFTER_PURSUIT:
		_clear_combat_entry_alignment()
		_center_after_limited_pursuit()
	elif _movement_mode == MovementMode.RETURN_HOME:
		_clear_combat_entry_alignment()
		_return_to_spawn_area(delta)
	elif _movement_mode == MovementMode.CENTER_AFTER_RETURN:
		_clear_combat_entry_alignment()
		_center_after_return()
	elif _pause_time_left > 0.0:
		_clear_combat_entry_alignment()
		_pause_time_left -= delta
		velocity = Vector2.ZERO
	else:
		_clear_combat_entry_alignment()
		_patrol(delta)
	if combatants_aligned:
		if hunter_in_combat:
			_attack_hunter()
		elif not _try_begin_enemy_skill(player_in_combat):
			_attack_player(player_in_combat)
	_update_walk_animation(delta)
	_update_combat_ring(in_combat)
	_face_combat_target(player_in_combat, hunter_in_combat)
	_update_health_regeneration(delta, in_combat)
	_was_in_combat = player_in_combat


func _clear_combat_entry_alignment() -> void:
	_combat_alignment_target = null
	_combat_entry_aligned = false


func _update_enemy_skill_cooldowns(delta: float, combat_sequence_active: bool) -> void:
	if enemy_skills.is_empty():
		return
	if not combat_sequence_active:
		if _active_skill_slot >= 0:
			return
		_reset_enemy_skills()
		return
	if not _combat_skills_initialized:
		_skill_cooldowns.resize(enemy_skills.size())
		for index in range(enemy_skills.size()):
			var skill := enemy_skills[index]
			_skill_cooldowns[index] = maxf(0.0, float(skill.get("initial_offset", 0.0)))
		_combat_skills_initialized = true
		return
	if _active_skill_slot >= 0:
		return
	for index in range(_skill_cooldowns.size()):
		_skill_cooldowns[index] = maxf(0.0, _skill_cooldowns[index] - delta)


func _try_begin_enemy_skill(player_in_combat: bool) -> bool:
	if not player_in_combat or _active_skill_slot >= 0 or not _combat_skills_initialized:
		return false
	for index in range(enemy_skills.size()):
		if index < _skill_cooldowns.size() and _skill_cooldowns[index] <= 0.0:
			_begin_enemy_skill(index)
			return true
	return false


func _begin_enemy_skill(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= enemy_skills.size() or not is_instance_valid(_player) or not is_instance_valid(_world):
		return
	var skill := enemy_skills[slot_index]
	var skill_id := int(skill.get("skill_id", SKILL_NONE))
	if skill_id == SKILL_NONE:
		return
	if _skill_visual_tween and _skill_visual_tween.is_valid():
		_skill_visual_tween.kill()
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	chicken_sprite.position = Vector2.ZERO
	chicken_sprite.scale = Vector2.ONE
	chicken_sprite.rotation = 0.0
	var enemy_cell := _world.world_to_cell(global_position)
	var player_cell := _world.world_to_cell(_player.global_position)
	_active_skill_direction = _cardinal_direction(player_cell - enemy_cell)
	_active_skill_slot = slot_index
	_active_skill_elapsed = 0.0
	_active_skill_windup = _get_enemy_skill_windup(skill_id)
	_active_skill_damage = int(skill.get("damage", 0))
	if _active_skill_damage <= 0:
		_active_skill_damage = attack_damage * 5
	_active_skill_damage_type = clampi(int(skill.get("damage_type", enemy_color)), FoxPlayer.COLOR_RED, FoxPlayer.COLOR_BLUE)
	_active_skill_id = skill_id
	_active_skill_released = false
	_active_skill_impact_count = 0
	_skip_cascade_tutorial_for_current_cast = false
	_last_skill_resolution_feedback.clear()
	_active_skill_targets.clear()
	_show_enemy_skill_name(skill_id)
	chicken_sprite.modulate = Color.WHITE.lerp(DAMAGE_COLORS[_active_skill_damage_type], 0.25)
	_play_enemy_charge_sfx()
	var front := enemy_cell + _active_skill_direction
	_add_enemy_skill_target(front, 0.0)
	if skill_id == SKILL_CASCADING_SWEEP or skill_id == SKILL_CASCADING_SURROUND:
		_player.set_snared_by(self, true)
		var side := Vector2i(-_active_skill_direction.y, _active_skill_direction.x)
		_add_enemy_skill_target(front + _active_skill_direction, 0.08)
		_add_enemy_skill_target(front + side, 0.16)
		_add_enemy_skill_target(front - side, 0.24)
		if skill_id == SKILL_CASCADING_SURROUND:
			_add_enemy_skill_target(enemy_cell + side, 0.4)
			_add_enemy_skill_target(enemy_cell - side, 0.4)
	elif skill_id == SKILL_FAN_STRIKE_QUICK or skill_id == SKILL_FAN_STRIKE_CHARGED:
		var side := Vector2i(-_active_skill_direction.y, _active_skill_direction.x)
		_add_enemy_skill_target(front + side, 0.2)
		_add_enemy_skill_target(front - side, 0.2)
	elif skill_id == SKILL_DRIVING_STRIKE_QUICK or skill_id == SKILL_DRIVING_STRIKE_CHARGED:
		_add_enemy_skill_target(front + _active_skill_direction, 0.2)
	velocity = Vector2.ZERO
	_path.clear()
	_path_index = 0
	_attack_time_left = maxf(_attack_time_left, _active_skill_windup)


func _add_enemy_skill_target(cell: Vector2i, delay: float) -> void:
	var telegraph := Node2D.new()
	telegraph.name = "EnemySkillTelegraph"
	telegraph.global_position = _world.cell_to_world(cell)
	telegraph.z_index = 2
	telegraph.show_behind_parent = true
	_world.add_child(telegraph)
	var tile_points := PackedVector2Array([
		Vector2(-31, -31), Vector2(31, -31), Vector2(31, 31), Vector2(-31, 31),
	])
	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.polygon = tile_points
	fill.color = DAMAGE_COLORS[_active_skill_damage_type]
	fill.modulate.a = 0.65
	fill.scale = Vector2.ZERO
	telegraph.add_child(fill)
	var outline := Line2D.new()
	outline.name = "FlashingOutline"
	outline.points = PackedVector2Array([tile_points[0], tile_points[1], tile_points[2], tile_points[3], tile_points[0]])
	outline.default_color = DAMAGE_COLORS[_active_skill_damage_type]
	outline.modulate.a = 0.75
	outline.width = 3.0
	outline.antialiased = true
	telegraph.add_child(outline)
	var warning_duration := maxf(0.01, _active_skill_windup + delay)
	var growth := fill.create_tween()
	growth.tween_property(fill, "scale", Vector2.ONE, warning_duration).set_trans(Tween.TRANS_LINEAR)
	_active_skill_targets.append({
		"cell": cell, "delay": delay, "resolved": false, "telegraph": telegraph,
		"warning_duration": warning_duration, "growth_tween": growth,
	})


func _get_enemy_skill_windup(skill_id: int) -> float:
	if skill_id == SKILL_CRUSHING_BLOW:
		return 2.0
	if skill_id == SKILL_FAN_STRIKE_QUICK or skill_id == SKILL_DRIVING_STRIKE_QUICK:
		return 0.8
	if skill_id == SKILL_FAN_STRIKE_CHARGED or skill_id == SKILL_DRIVING_STRIKE_CHARGED:
		return 1.5
	return 1.0


func _update_active_enemy_skill(delta: float) -> void:
	if _active_skill_slot < 0:
		return
	_active_skill_elapsed += delta
	if _try_show_enemy_skill_tutorial():
		return
	var pullback_progress := clampf(_active_skill_elapsed / maxf(_active_skill_windup, 0.01), 0.0, 1.0)
	if not _active_skill_released:
		_update_enemy_skill_anticipation(pullback_progress)
	var all_resolved := true
	for target in _active_skill_targets:
		if bool(target.get("resolved", false)):
			continue
		all_resolved = false
		_update_enemy_skill_telegraph_warning(target)
		if _active_skill_elapsed < _active_skill_windup + float(target.get("delay", 0.0)):
			continue
		_resolve_enemy_skill_target(target)
	all_resolved = true
	for target in _active_skill_targets:
		if not bool(target.get("resolved", false)):
			all_resolved = false
			break
	if all_resolved:
		_finish_enemy_skill()


func _try_show_enemy_skill_tutorial() -> bool:
	if not is_instance_valid(_player) or not is_instance_valid(_world):
		return false
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui") as DialogueBox
	if dialogue == null or dialogue.is_open():
		return false
	var is_snaring_skill := _active_skill_id == SKILL_CASCADING_SWEEP or _active_skill_id == SKILL_CASCADING_SURROUND
	if is_snaring_skill and _active_skill_elapsed >= SNARE_WITHOUT_QUICK_ROLL_TUTORIAL_DELAY \
			and not _player.unlocked_player_skills.has(FoxPlayer.SKILL_ROLL_CLOCKWISE) \
			and not _player.snare_without_quick_roll_tutorial_seen:
		if dialogue.play([_tutorial_line(SNARE_WITHOUT_QUICK_ROLL_TUTORIAL_TEXT)]):
			_player.snare_without_quick_roll_tutorial_seen = true
			_pause_skill_telegraph_tweens()
			return true
	if not _player.enemy_skill_move_tutorial_seen and _active_skill_elapsed >= ENEMY_SKILL_MOVE_TUTORIAL_DELAY \
			and not is_snaring_skill:
		var player_cell := _world.world_to_cell(_player.global_position)
		var side := Vector2i(-_active_skill_direction.y, _active_skill_direction.x)
		var side_cells: Array[Vector2i] = [player_cell + side, player_cell - side]
		for cell in side_cells:
			if not _world.is_walkable(cell) or _world.is_cell_occupied(cell, _player):
				return false
		if dialogue.play_tile_choice([_tutorial_line(ENEMY_SKILL_MOVE_TUTORIAL_TEXT)], _world, side_cells, _step_to_tutorial_tile):
			_player.enemy_skill_move_tutorial_seen = true
			_skip_cascade_tutorial_for_current_cast = true
			_pause_skill_telegraph_tweens()
			return true
	if _active_skill_elapsed >= CASCADING_SWEEP_TUTORIAL_DELAY \
			and is_snaring_skill and _player.unlocked_player_skills.has(FoxPlayer.SKILL_ROLL_CLOCKWISE) \
			and not _player.cascading_sweep_skill_tutorial_seen and not _skip_cascade_tutorial_for_current_cast \
			and not _player.is_moving():
		if not _player.prepare_player_skill_slot_for_tutorial(0):
			return false
		if dialogue.play_key_action([_tutorial_line(CASCADING_SWEEP_TUTORIAL_TEXT)], KEY_Q, _cast_tutorial_skill):
			_player.cascading_sweep_skill_tutorial_seen = true
			_pause_skill_telegraph_tweens()
			return true
	return false


func _tutorial_line(text: String) -> Dictionary:
	return {"speaker": "Mira", "text": text, "portrait": PLAYER_PORTRAIT}


func _step_to_tutorial_tile(cell: Vector2i) -> bool:
	if not is_instance_valid(_player) or not is_instance_valid(_world) or not _world.is_walkable(cell) \
			or _world.is_cell_occupied(cell, _player):
		return false
	# Entering combat by clicking the enemy leaves a chase target active. Clear it
	# before starting this forced step so the next physics frame cannot replace
	# the tutorial path with another route toward the enemy.
	_player.clear_attack_target()
	_player.follow_path(PackedVector2Array([_world.cell_to_world(cell)]))
	return _player.is_moving()


func _cast_tutorial_skill() -> bool:
	if not is_instance_valid(_player):
		return false
	var toolbar := get_tree().get_first_node_in_group("skill_toolbar") as SkillToolbar
	if is_instance_valid(toolbar):
		return toolbar._try_cast_player_skill(0)
	return _player.cast_player_skill_slot(0)


func consume_pending_cascading_sweep_tutorial(skill_id: StringName) -> void:
	if skill_id != FoxPlayer.SKILL_ROLL_CLOCKWISE or _active_skill_slot < 0 \
			or (_active_skill_id != SKILL_CASCADING_SWEEP and _active_skill_id != SKILL_CASCADING_SURROUND) \
			or not is_instance_valid(_player) or _player.cascading_sweep_skill_tutorial_seen:
		return
	_player.cascading_sweep_skill_tutorial_seen = true
	_skip_cascade_tutorial_for_current_cast = true


func _pause_skill_telegraph_tweens() -> void:
	_skill_tutorial_paused = true
	for target in _active_skill_targets:
		var growth := target.get("growth_tween") as Tween
		if growth and growth.is_valid():
			growth.pause()


func _resume_skill_telegraph_tweens() -> void:
	_skill_tutorial_paused = false
	for target in _active_skill_targets:
		var growth := target.get("growth_tween") as Tween
		if growth and growth.is_valid():
			growth.play()


func _update_enemy_skill_anticipation(progress: float) -> void:
	var direction := Vector2(_active_skill_direction)
	var turn_sign := signf(direction.x if absf(direction.x) > 0.01 else direction.y)
	if _active_skill_id == SKILL_CRUSHING_BLOW or _active_skill_id >= SKILL_FAN_STRIKE_QUICK:
		chicken_sprite.position = -direction * (10.0 * progress)
		chicken_sprite.scale = Vector2.ONE.lerp(Vector2(1.20, 0.72), progress)
		chicken_sprite.rotation = -0.20 * turn_sign * progress
	elif _active_skill_id == SKILL_CASCADING_SWEEP or _active_skill_id == SKILL_CASCADING_SURROUND:
		chicken_sprite.position = -direction * (5.0 * progress)
		chicken_sprite.scale = Vector2.ONE.lerp(Vector2(0.84, 1.18), progress)
		chicken_sprite.rotation = turn_sign * (0.18 * progress + sin(progress * PI * 3.0) * 0.08)


func _update_enemy_skill_telegraph_warning(target: Dictionary) -> void:
	var telegraph := target.get("telegraph") as Node2D
	if not is_instance_valid(telegraph):
		return
	var outline := telegraph.get_node_or_null("FlashingOutline") as Line2D
	if not is_instance_valid(outline):
		return
	var warning_duration := maxf(0.01, float(target.get("warning_duration", _active_skill_windup)))
	var progress := clampf(_active_skill_elapsed / warning_duration, 0.0, 1.0)
	var urgency := clampf((progress - 0.75) / 0.25, 0.0, 1.0)
	var flashes_per_second := lerpf(2.2, 10.0, urgency)
	var pulse := (sin(_active_skill_elapsed * flashes_per_second * TAU) + 1.0) * 0.5
	outline.modulate.a = lerpf(0.20, 0.75, pulse)


func _resolve_enemy_skill_target(target: Dictionary) -> void:
	target["resolved"] = true
	_play_enemy_skill_impact_sfx()
	var target_cell: Vector2i = target.get("cell", Vector2i.ZERO)
	var hit := false
	if is_instance_valid(_player) and _world.world_to_cell(_player.global_position) == target_cell:
		hit = _player.take_skill_damage(_active_skill_damage, _active_skill_damage_type, Vector2(_active_skill_direction))
	_active_skill_impact_count += 1
	_last_skill_resolution_feedback.append("hit" if hit else "dodged")
	_play_enemy_skill_release(target_cell)
	_resolve_enemy_skill_telegraph(target, hit)


func _resolve_enemy_skill_telegraph(target: Dictionary, hit: bool) -> void:
	var telegraph := target.get("telegraph") as Node2D
	if not is_instance_valid(telegraph):
		return
	var growth := target.get("growth_tween") as Tween
	if growth and growth.is_valid():
		growth.kill()
	var fill := telegraph.get_node_or_null("Fill") as Polygon2D
	var outline := telegraph.get_node_or_null("FlashingOutline") as Line2D
	if is_instance_valid(fill):
		fill.scale = Vector2.ONE
		fill.modulate.a = 0.86 if hit else 0.78
	if is_instance_valid(outline):
		outline.default_color = Color.RED if hit else Color.WHITE
		outline.modulate.a = 1.0
	telegraph.modulate.a = 1.0
	var feedback := telegraph.create_tween()
	if hit:
		telegraph.scale = Vector2(0.86, 0.86)
		feedback.tween_property(telegraph, "scale", Vector2(1.16, 1.16), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		feedback.parallel().tween_property(telegraph, "modulate:a", 0.0, 0.16).set_delay(0.04)
	else:
		if is_instance_valid(fill):
			fill.color = Color.WHITE
		feedback.tween_interval(0.05)
		feedback.tween_property(telegraph, "scale", Vector2(0.06, 0.06), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		feedback.parallel().tween_property(telegraph, "modulate:a", 0.0, 0.13)
	feedback.finished.connect(telegraph.queue_free)


func _play_enemy_skill_release(target_cell: Vector2i) -> void:
	chicken_sprite.modulate = Color.WHITE
	var enemy_cell := _world.world_to_cell(global_position)
	var strike_direction := _cardinal_direction(target_cell - enemy_cell)
	var direction := Vector2(strike_direction)
	var turn_sign := signf(direction.x if absf(direction.x) > 0.01 else direction.y)
	_active_skill_released = true
	if _active_skill_id == SKILL_CRUSHING_BLOW:
		chicken_sprite.position = Vector2(_active_skill_direction) * 18.0
		chicken_sprite.scale = Vector2(1.38, 0.66)
		chicken_sprite.rotation = 0.18 * turn_sign
		_play_enemy_skill_camera_feedback(direction, 5.0)
	else:
		var forward := Vector2(_active_skill_direction)
		var side_amount := forward.cross(direction)
		chicken_sprite.position = direction * 8.0
		chicken_sprite.scale = Vector2(1.16, 0.82)
		chicken_sprite.rotation = side_amount * 0.32 + turn_sign * 0.12
		_play_enemy_skill_camera_feedback(direction, 1.5 + float(_active_skill_impact_count) * 0.7)


func _begin_enemy_skill_recovery(skill_id: int) -> void:
	if _skill_visual_tween and _skill_visual_tween.is_valid():
		_skill_visual_tween.kill()
	_attack_visual_time_left = 0.34
	_attack_time_left = maxf(_attack_time_left, 0.34)
	var direction := Vector2(_active_skill_direction)
	var turn_sign := signf(direction.x if absf(direction.x) > 0.01 else direction.y)
	_skill_visual_tween = create_tween()
	_skill_visual_tween.tween_interval(0.08)
	if skill_id == SKILL_CRUSHING_BLOW:
		_skill_visual_tween.tween_property(chicken_sprite, "position", -direction * 4.0, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_skill_visual_tween.parallel().tween_property(chicken_sprite, "scale", Vector2(0.86, 1.14), 0.09)
		_skill_visual_tween.parallel().tween_property(chicken_sprite, "rotation", -0.12 * turn_sign, 0.09)
	else:
		_skill_visual_tween.tween_property(chicken_sprite, "position", -direction * 2.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_skill_visual_tween.parallel().tween_property(chicken_sprite, "scale", Vector2(0.90, 1.10), 0.08)
		_skill_visual_tween.parallel().tween_property(chicken_sprite, "rotation", -0.18 * turn_sign, 0.08)
	_skill_visual_tween.tween_property(chicken_sprite, "position", Vector2.ZERO, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_skill_visual_tween.parallel().tween_property(chicken_sprite, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_skill_visual_tween.parallel().tween_property(chicken_sprite, "rotation", 0.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_skill_visual_tween.parallel().tween_property(chicken_sprite, "modulate", Color.WHITE, 0.16)


func _play_enemy_charge_sfx() -> void:
	if not _can_emit_combat_feedback():
		return
	var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
	if audio:
		audio.play_enemy_charge()


func _play_enemy_skill_impact_sfx() -> void:
	if not _can_emit_combat_feedback():
		return
	var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
	if audio:
		audio.play_big_attack()


func _show_enemy_skill_name(skill_id: int) -> void:
	_clear_enemy_skill_name()
	if skill_id <= SKILL_NONE:
		return
	_skill_name_label = Label.new()
	_skill_name_label.name = "EnemySkillCastLabel"
	_skill_name_label.text = "Big Attack"
	_skill_name_label.position = Vector2(-90, -88)
	_skill_name_label.size = Vector2(180, 28)
	_skill_name_label.pivot_offset = _skill_name_label.size * 0.5
	_skill_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_name_label.add_theme_font_size_override("font_size", 19)
	_skill_name_label.add_theme_color_override("font_color", Color("ffddd8"))
	_skill_name_label.add_theme_color_override("font_outline_color", Color("4a0909"))
	_skill_name_label.add_theme_constant_override("outline_size", 5)
	_skill_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_name_label.z_index = 40
	_skill_name_label.modulate.a = 0.0
	_skill_name_label.scale = Vector2(0.72, 0.72)
	add_child(_skill_name_label)
	var reveal := _skill_name_label.create_tween().set_parallel(true)
	reveal.tween_property(_skill_name_label, "modulate:a", 1.0, 0.12)
	reveal.tween_property(_skill_name_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fade_enemy_skill_name() -> void:
	if not is_instance_valid(_skill_name_label):
		_skill_name_label = null
		return
	var label := _skill_name_label
	_skill_name_label = null
	var fade := label.create_tween().set_parallel(true)
	fade.tween_property(label, "position:y", label.position.y - 10.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.tween_property(label, "modulate:a", 0.0, 0.16)
	fade.finished.connect(label.queue_free)


func _clear_enemy_skill_name() -> void:
	if is_instance_valid(_skill_name_label):
		_skill_name_label.queue_free()
	_skill_name_label = null


func _play_enemy_skill_camera_feedback(direction: Vector2, strength: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	_cancel_enemy_skill_camera_feedback()
	_skill_camera = camera
	_skill_camera_origin = camera.position
	var strike_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	var perpendicular := Vector2(-strike_direction.y, strike_direction.x)
	_skill_camera_tween = camera.create_tween()
	_skill_camera_tween.tween_property(camera, "position", _skill_camera_origin + strike_direction * strength, 0.035).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_skill_camera_tween.tween_property(camera, "position", _skill_camera_origin - strike_direction * strength * 0.45 + perpendicular * strength * 0.55, 0.04)
	_skill_camera_tween.tween_property(camera, "position", _skill_camera_origin - perpendicular * strength * 0.35, 0.04)
	_skill_camera_tween.tween_property(camera, "position", _skill_camera_origin, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_skill_camera_tween.finished.connect(_finish_enemy_skill_camera_feedback.bind(camera))


func _finish_enemy_skill_camera_feedback(camera: Camera2D) -> void:
	if camera != _skill_camera:
		return
	if is_instance_valid(camera):
		camera.position = _skill_camera_origin
	_skill_camera_tween = null
	_skill_camera = null


func _cancel_enemy_skill_camera_feedback() -> void:
	if _skill_camera_tween and _skill_camera_tween.is_valid():
		_skill_camera_tween.kill()
	if is_instance_valid(_skill_camera):
		_skill_camera.position = _skill_camera_origin
	_skill_camera_tween = null
	_skill_camera = null


func _finish_enemy_skill() -> void:
	var finished_skill_id := _active_skill_id
	_release_player_snare()
	if _active_skill_slot >= 0 and _active_skill_slot < enemy_skills.size():
		_skill_cooldowns[_active_skill_slot] = _get_enemy_skill_cooldown(enemy_skills[_active_skill_slot])
	_active_skill_targets.clear()
	_fade_enemy_skill_name()
	_active_skill_slot = -1
	_active_skill_elapsed = 0.0
	_active_skill_id = SKILL_NONE
	_active_skill_released = false
	_skill_tutorial_paused = false
	_skip_cascade_tutorial_for_current_cast = false
	_begin_enemy_skill_recovery(finished_skill_id)


func _reset_enemy_skills() -> void:
	_release_player_snare()
	_clear_enemy_skill_telegraphs()
	_clear_enemy_skill_name()
	_cancel_enemy_skill_camera_feedback()
	if _skill_visual_tween and _skill_visual_tween.is_valid():
		_skill_visual_tween.kill()
	_combat_skills_initialized = false
	_active_skill_slot = -1
	_active_skill_elapsed = 0.0
	_skill_cooldowns.resize(enemy_skills.size())
	_skill_cooldowns.fill(0.0)
	_active_skill_id = SKILL_NONE
	_active_skill_released = false
	_active_skill_impact_count = 0
	_skill_tutorial_paused = false
	_skip_cascade_tutorial_for_current_cast = false
	if is_instance_valid(chicken_sprite):
		chicken_sprite.position = Vector2.ZERO
		chicken_sprite.scale = Vector2.ONE
		chicken_sprite.rotation = 0.0
		chicken_sprite.modulate = Color.WHITE


func _clear_enemy_skill_telegraphs() -> void:
	for target in _active_skill_targets:
		var telegraph_value: Variant = target.get("telegraph")
		if is_instance_valid(telegraph_value):
			(telegraph_value as Node2D).queue_free()
	_active_skill_targets.clear()


func _release_player_snare() -> void:
	if is_instance_valid(_player):
		_player.set_snared_by(self, false)


func _get_enemy_skill_cooldown(skill: Dictionary) -> float:
	var configured := float(skill.get("cooldown", 0.0))
	if configured > 0.0:
		return configured
	var skill_id := clampi(int(skill.get("skill_id", SKILL_NONE)), 0, SKILL_DEFAULT_COOLDOWNS.size() - 1)
	return SKILL_DEFAULT_COOLDOWNS[skill_id]


func _cardinal_direction(offset: Vector2i) -> Vector2i:
	if absi(offset.x) >= absi(offset.y) and offset.x != 0:
		return Vector2i(signi(offset.x), 0)
	if offset.y != 0:
		return Vector2i(0, signi(offset.y))
	return Vector2i.RIGHT


func is_player_combat_sequence_active() -> bool:
	if health <= 0 or not is_instance_valid(_world) or not is_instance_valid(_player) \
			or not _world.belongs_to_world(_player):
		return false
	if _world is DungeonLevel and not (_world as DungeonLevel).is_actor_in_active_room(self):
		return false
	return _movement_mode == MovementMode.CHASE or _is_in_combat()


func _can_emit_combat_feedback() -> bool:
	if not is_instance_valid(_world) or not is_instance_valid(_player) or not _world.belongs_to_world(_player):
		return false
	return not (_world is DungeonLevel) or (_world as DungeonLevel).is_actor_in_active_room(self)


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
		_begin_pursuit_centering()


func _begin_pursuit_centering() -> void:
	_movement_mode = MovementMode.CENTER_AFTER_PURSUIT
	_pursuit_is_limited = false
	_clear_movement_path()


func _center_after_limited_pursuit() -> void:
	velocity = Vector2.ZERO
	if _world and _world.center_stationary_actor(self):
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
		_begin_return_centering()
		return
	if _path_index >= _path.size():
		_path = _world.find_path(global_position, _world.cell_to_world(home_cell), self)
		_path_index = 1 if _path.size() > 1 else _path.size()
	if _path_index < _path.size():
		_follow_behavior_path(delta)
	else:
		velocity = Vector2.ZERO


func _begin_return_centering() -> void:
	_movement_mode = MovementMode.CENTER_AFTER_RETURN
	_clear_movement_path()


func _center_after_return() -> void:
	velocity = Vector2.ZERO
	if not _world or not _world.center_stationary_actor(self):
		return
	_movement_mode = MovementMode.PATROL
	_pause_time_left = randf_range(1.0, 2.0)
	_clear_movement_path()


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
		_set_facing_left(true)
	elif velocity.x > 0.1:
		_set_facing_left(false)
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
		_set_facing_left(true)
	elif velocity.x > 0.1:
		_set_facing_left(false)
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
	if in_combat and _player and _can_emit_combat_feedback():
		var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
		if audio:
			audio.play_damage()
		_face_toward(_player)
		_play_attack_animation(_player)
		_show_slash(_player)
		_player.take_damage(attack_damage, enemy_color)
		_attack_time_left = attack_cooldown


func _attack_hunter() -> void:
	if _attack_time_left > 0.0 or not _is_hunter_in_combat() or not _can_emit_combat_feedback():
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
		direction = -1.0 if _is_facing_left() else 1.0
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
	if _active_skill_slot >= 0:
		return
	if _attack_visual_time_left > 0.0 or _hit_visual_time_left > 0.0:
		return
	if velocity.length_squared() > 1.0:
		_walk_time += delta * 10.0
		chicken_sprite.position.y = -absf(sin(_walk_time)) * 5.0
		chicken_sprite.rotation = sin(_walk_time) * 0.1
	else:
		chicken_sprite.position = Vector2.ZERO
		chicken_sprite.rotation = 0.0


func _exit_tree() -> void:
	_release_player_snare()
	_clear_enemy_skill_telegraphs()
	_clear_enemy_skill_name()
	_cancel_enemy_skill_camera_feedback()


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
	if not rewards_enabled:
		reward_icon.visible = false
		reward_label.hide()
		reward_dot.hide()
		reward_dot_outline.hide()
		return
	reward_label.show()
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
	elif reward_type == REWARD_MANA:
		reward_color = Color("67e8f9")
		reward_icon.texture = preload("res://Sprites/IconMana.webp")
	elif reward_type == REWARD_MANA_REGENERATE:
		reward_color = Color("67e8f9")
		reward_icon.texture = preload("res://Sprites/iconManaRegen.webp")
		reward_label.text = "+%s" % FoxPlayer.format_health_per_second(float(damage_reward) / 3.0)
		reward_label.offset_right = 112.0
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
		_set_facing_left(false)
	elif horizontal_offset < -0.1:
		_set_facing_left(true)


func _set_facing_left(facing_left: bool) -> void:
	if is_instance_valid(chicken_sprite):
		chicken_sprite.flip_h = facing_left != _flip_sprite_orientation


func _is_facing_left() -> bool:
	return chicken_sprite.flip_h != _flip_sprite_orientation if is_instance_valid(chicken_sprite) else false


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
	var fox := _player
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
		REWARD_MANA:
			var vitals := _get_hud_control("PlayerVitals")
			var mana_target: Vector2 = vitals.call("get_stat_target_screen_position", &"mana") if vitals else Vector2(42, 150)
			_launch_reward_orb(mana_target, Color("67e8f9"), fox.add_max_mana.bind(damage_reward))
		REWARD_MANA_REGENERATE:
			var vitals := _get_hud_control("PlayerVitals")
			var mana_regen_target: Vector2 = vitals.call("get_stat_target_screen_position", &"mana_regeneration") if vitals else Vector2(100, 150)
			_launch_reward_orb(mana_regen_target, Color("67e8f9"), fox.add_passive_mana_regeneration.bind(damage_reward))


func _get_hud_control(node_name: String) -> Control:
	var world := get_tree().current_scene as WorldNavigation
	return world.get_node_or_null("HUD/" + node_name) as Control if world else null


func _resolve_gameplay_context() -> void:
	var cursor := get_parent()
	while cursor:
		if cursor is WorldNavigation:
			_world = cursor as WorldNavigation
			break
		cursor = cursor.get_parent()
	if _world and is_instance_valid(_world.player):
		_player = _world.player
	else:
		_player = get_tree().get_first_node_in_group("player") as FoxPlayer


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
