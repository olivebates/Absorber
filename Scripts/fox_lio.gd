class_name FoxLio
extends FoxAsha

const LIO_SAVE_FORMAT := "lio_hunter_v1"
const REQUIRED_GOLD_ORES := [&"GoldOre", &"GoldOre2", &"GoldOre3"]
const EXCLUDED_ENEMY_TYPES := [3, 4, 2, 6, 13, 18, 19]
const HUNT_PATH_REFRESH := 0.35
const HUNT_ATTACK_INTERVAL := 0.8
const HUNT_DAMAGE := 2
const REWARD_RELEASE_FRAME_INTERVAL := 10
const REWARD_FEE := {&"gold_ore": 3}
const FREE_HANDOFF_THRESHOLD := 15
const MINIMUM_RESPAWNED_WAVE_SIZE := 6
const DAMAGE_ICON := preload("res://Sprites/DamageIcon.webp")
const HEALTH_ICON := preload("res://Sprites/Heart.webp")
const REGENERATION_ICON := preload("res://Sprites/RecoveryHeart.webp")
const DEFENSE_ICON := preload("res://Sprites/ShieldIcon.webp")

enum HuntState { INACTIVE, HUNTING, RETURNING, WAITING_AT_CAMPFIRE, DELIVERING, WAITING_FOR_ENEMIES }

var hunt_state := HuntState.INACTIVE
var _hunter_recruited := false
var _hunt_target: ChickenEnemy
var _hunt_path_refresh_left := 0.0
var _hunt_attack_left := 0.0
var _collected_rewards: Array[Dictionary] = []
var _collected_row: HBoxContainer
var _delivery_running := false
var _reward_fee_paid := false
var _hunt_attack_tween: Tween
var _hunt_attack_visual_time_left := 0.0
var _helper_tooltip_visible := false
var _helper_tooltip_copy := ""
var _original_position := Vector2.ZERO


func _ready() -> void:
	_original_position = global_position
	super._ready()
	stationary = _is_stationary_before_recruitment()
	_build_collected_stats_display()


func _process(delta: float) -> void:
	_hunt_attack_visual_time_left = maxf(0.0, _hunt_attack_visual_time_left - delta)
	stationary = _hunter_recruited or _is_stationary_before_recruitment()
	super._process(delta)
	_update_helper_tooltip()
	if not _hunter_recruited or not _initialized or not is_instance_valid(_world):
		return
	if _world.gameplay_paused or _dialogue_is_open() or _waiting_for_player or (is_instance_valid(_shop) and _shop.visible):
		return
	_is_walking = false
	match hunt_state:
		HuntState.HUNTING:
			_process_hunting(delta)
		HuntState.RETURNING:
			_process_returning(delta)
		HuntState.WAITING_FOR_ENEMIES:
			if _count_eligible_enemies() >= MINIMUM_RESPAWNED_WAVE_SIZE:
				start_hunting_again()
	_update_walk_animation(delta)


func interact() -> void:
	var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
	if story and story.interact_with(&"lio"):
		return
	if not _hunter_recruited:
		open_shop()


func open_shop() -> void:
	var hud := _world.get_node_or_null("HUD") as CanvasLayer if _world else null
	if hud == null:
		return
	if not is_instance_valid(_shop):
		_shop = FoxLioShop.new()
		hud.add_child(_shop)
		_shop.setup(self)
	_shop.open()


func has_required_gold_mines() -> bool:
	if not is_instance_valid(_world):
		return false
	for ore_name in REQUIRED_GOLD_ORES:
		var ore := _world.get_node_or_null(NodePath(str(ore_name))) as GoldOre
		if ore == null or not is_instance_valid(ore._mine):
			return false
	return true


func has_first_gold_mine() -> bool:
	if not is_instance_valid(_world):
		return false
	var ore := _world.get_node_or_null("GoldOre") as GoldOre
	return ore != null and is_instance_valid(ore._mine)


func set_hunter_recruited(value: bool, begin_hunting := true) -> void:
	_hunter_recruited = value
	stationary = value
	if not value:
		hunt_state = HuntState.INACTIVE
		_hunt_target = null
		_reward_fee_paid = false
		stationary = _is_stationary_before_recruitment()
		_stop_patrol()
		return
	if hunt_state == HuntState.INACTIVE and begin_hunting:
		start_hunting_again()


func is_hunter_recruited() -> bool:
	return _hunter_recruited


func is_waiting_at_campfire() -> bool:
	return _hunter_recruited and hunt_state == HuntState.WAITING_AT_CAMPFIRE


func can_pay_reward_fee() -> bool:
	if _reward_fee_paid:
		return true
	var resources := get_tree().get_first_node_in_group("resource_manager") as ResourceManager
	return resources != null and resources.can_afford(get_reward_fee())


func pay_reward_fee() -> bool:
	if _reward_fee_paid:
		return true
	var resources := get_tree().get_first_node_in_group("resource_manager") as ResourceManager
	if resources == null or not resources.spend_resources(get_reward_fee()):
		return false
	_reward_fee_paid = true
	return true


func has_paid_reward_fee() -> bool:
	return _reward_fee_paid


func get_reward_fee() -> Dictionary:
	return REWARD_FEE


func authorize_free_reward_handoff() -> void:
	_reward_fee_paid = true


func get_total_collected_stat_upgrades() -> int:
	var total := 0
	for reward in _collected_rewards:
		if int(reward.get("type", ChickenEnemy.REWARD_DAMAGE)) != ChickenEnemy.REWARD_RESOURCE:
			total += maxi(0, int(reward.get("amount", 0)))
	return total


func is_reward_handoff_free() -> bool:
	return get_total_collected_stat_upgrades() < FREE_HANDOFF_THRESHOLD


func start_hunting_again() -> void:
	if not _hunter_recruited:
		return
	_reward_fee_paid = false
	hunt_state = HuntState.HUNTING
	_hunt_target = null
	_hunt_path_refresh_left = 0.0
	_hunt_attack_left = 0.0
	_stop_patrol()


func start_hunting_after_handoff() -> void:
	if not _hunter_recruited:
		return
	_reward_fee_paid = false
	_hunt_target = null
	_hunt_path_refresh_left = 0.0
	_hunt_attack_left = 0.0
	_stop_patrol()
	if _count_eligible_enemies() == 0:
		hunt_state = HuntState.WAITING_FOR_ENEMIES
	else:
		hunt_state = HuntState.HUNTING


func collect_enemy_reward(enemy: ChickenEnemy) -> void:
	if enemy == null or not _hunter_recruited:
		return
	_collected_rewards.append({
		"type": enemy.reward_type,
		"amount": maxi(0, enemy.damage_reward),
		"damage_color": enemy.damage_reward_color,
		"defense_color": enemy.defense_reward_color,
		"resource_id": str(enemy.reward_resource_id),
	})
	_refresh_collected_stats_display()


func begin_reward_delivery() -> void:
	if _delivery_running or hunt_state != HuntState.WAITING_AT_CAMPFIRE or not _reward_fee_paid:
		return
	_delivery_running = true
	hunt_state = HuntState.DELIVERING
	_run_reward_delivery()


func get_collected_reward_totals() -> Dictionary:
	var totals := {}
	for reward in _collected_rewards:
		var key := _reward_key(reward)
		totals[key] = int(totals.get(key, 0)) + int(reward.get("amount", 0))
	return totals


func get_save_data() -> Array:
	var data := super.get_save_data()
	data.append(LIO_SAVE_FORMAT)
	data.append(_hunter_recruited)
	data.append(hunt_state)
	data.append(_collected_rewards.duplicate(true))
	data.append(_reward_fee_paid)
	return data


func load_save_data(data: Array) -> bool:
	var loaded := super.load_save_data(data)
	_hunter_recruited = false
	hunt_state = HuntState.INACTIVE
	_collected_rewards.clear()
	_reward_fee_paid = false
	if data.size() >= 10 and str(data[6]) == LIO_SAVE_FORMAT:
		_hunter_recruited = bool(data[7])
		var saved_hunt_state := int(data[8])
		hunt_state = HuntState.WAITING_AT_CAMPFIRE if saved_hunt_state == HuntState.DELIVERING \
			else clampi(saved_hunt_state, HuntState.INACTIVE, HuntState.WAITING_FOR_ENEMIES)
		if data[9] is Array:
			for raw_reward in data[9]:
				if raw_reward is Dictionary:
					_collected_rewards.append((raw_reward as Dictionary).duplicate(true))
		_reward_fee_paid = bool(data[10]) if data.size() > 10 else false
	if hunt_state != HuntState.WAITING_AT_CAMPFIRE:
		_reward_fee_paid = false
	stationary = _hunter_recruited or _is_stationary_before_recruitment()
	_hunt_target = null
	_delivery_running = false
	if not _hunter_recruited:
		# A non-helper save represents the character before recruitment. Return to
		# the location authored in the current scene instead of leaving them at a
		# campfire or hunting position from the running session.
		global_position = _original_position
		_last_player_cell = INVALID_CELL
		_follow_target_cell = INVALID_CELL
		_stop_patrol()
	call_deferred("_refresh_collected_stats_display")
	return loaded


func _process_hunting(delta: float) -> void:
	_hunt_attack_left = maxf(0.0, _hunt_attack_left - delta)
	if not is_instance_valid(_hunt_target) or not _is_eligible_enemy(_hunt_target):
		_hunt_target = _find_nearest_eligible_enemy()
		_hunt_path_refresh_left = 0.0
	if not is_instance_valid(_hunt_target):
		hunt_state = HuntState.RETURNING
		_stop_patrol()
		return
	if _world.are_adjacent(self, _hunt_target):
		_stop_patrol()
		_hunt_target.prepare_for_hunter_combat(self)
		if not _world.center_stationary_combatants(self, _hunt_target):
			return
		if _hunt_attack_left <= 0.0:
			var attacked_enemy := _hunt_target
			_face_hunt_target(attacked_enemy)
			_hunt_attack_left = HUNT_ATTACK_INTERVAL
			_play_hunt_attack_animation(attacked_enemy)
			_show_hunt_slash(attacked_enemy)
			var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
			if audio:
				audio.play_lio_fight(global_position)
			attacked_enemy.take_hunter_damage(self)
			if not is_instance_valid(attacked_enemy) or attacked_enemy.health <= 0:
				_hunt_target = null
		return
	_hunt_path_refresh_left -= delta
	if _hunt_path_refresh_left <= 0.0 or _path_index >= _path.size():
		_hunt_path_refresh_left = HUNT_PATH_REFRESH
		_path = _best_adjacent_path(_hunt_target)
		_path_index = 1 if _path.size() > 1 else _path.size()
	_follow_hunt_path(delta)


func _process_returning(delta: float) -> void:
	var campfire := _get_area_campfire()
	if campfire == null:
		return
	var destination := campfire.get_respawn_position()
	if global_position.distance_to(destination) <= 4.0:
		global_position = destination
		_stop_patrol()
		hunt_state = HuntState.WAITING_AT_CAMPFIRE
		return
	_hunt_path_refresh_left -= delta
	if _hunt_path_refresh_left <= 0.0 or _path_index >= _path.size():
		_hunt_path_refresh_left = HUNT_PATH_REFRESH
		_path = _world.find_path(global_position, destination, self)
		_path_index = 1 if _path.size() > 1 else _path.size()
	_follow_hunt_path(delta)


func _find_nearest_eligible_enemy() -> ChickenEnemy:
	var nearest: ChickenEnemy
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("enemy_spawns"):
		if not node is EnemySpawnPoint:
			continue
		var spawn := node as EnemySpawnPoint
		if spawn.area_id != _get_hunt_area_id() or EXCLUDED_ENEMY_TYPES.has(spawn.enemy_type):
			continue
		for enemy in spawn.get_active_enemies():
			var distance := global_position.distance_squared_to(enemy.global_position)
			if distance < nearest_distance:
				nearest = enemy
				nearest_distance = distance
	return nearest


func _count_eligible_enemies() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("enemy_spawns"):
		if not node is EnemySpawnPoint:
			continue
		var spawn := node as EnemySpawnPoint
		if spawn.area_id != _get_hunt_area_id() or EXCLUDED_ENEMY_TYPES.has(spawn.enemy_type):
			continue
		count += spawn.get_active_enemies().size()
	return count


func _is_eligible_enemy(enemy: ChickenEnemy) -> bool:
	return is_instance_valid(enemy) and enemy.health > 0 and is_instance_valid(enemy.spawn_point) \
		and enemy.spawn_point.area_id == _get_hunt_area_id() and not EXCLUDED_ENEMY_TYPES.has(enemy.spawn_point.enemy_type)


func _best_adjacent_path(enemy: ChickenEnemy) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_length := INF
	var enemy_cell := _world.world_to_cell(enemy.global_position)
	for offset: Vector2i in ADJACENT_OFFSETS:
		var cell := enemy_cell + offset
		if not _world.is_walkable(cell) or _world.is_cell_occupied(cell, self):
			continue
		var candidate := _world.find_path(global_position, _world.cell_to_world(cell), self)
		if candidate.is_empty():
			continue
		var length := _path_distance(candidate)
		if length < best_length:
			best = candidate
			best_length = length
	return best


func _path_distance(points: PackedVector2Array) -> float:
	var result := 0.0
	for index in range(1, points.size()):
		result += points[index - 1].distance_to(points[index])
	return result


func _follow_hunt_path(delta: float) -> void:
	if _path_index >= _path.size():
		return
	var target := _path[_path_index]
	var offset := target - global_position
	if offset.length() <= 3.0:
		global_position = target
		_path_index += 1
		return
	var motion := offset.normalized() * MOVE_SPEED * delta
	if not _world.can_enter_position(self, global_position + motion):
		_stop_patrol()
		_hunt_path_refresh_left = 0.0
		return
	global_position += motion
	_is_walking = true
	if motion.x < -0.1:
		fox_sprite.flip_h = reverse_sprite_orientation
	elif motion.x > 0.1:
		fox_sprite.flip_h = not reverse_sprite_orientation


func _face_hunt_target(enemy: ChickenEnemy) -> void:
	if enemy.global_position.x < global_position.x:
		fox_sprite.flip_h = reverse_sprite_orientation
	elif enemy.global_position.x > global_position.x:
		fox_sprite.flip_h = not reverse_sprite_orientation


func _play_hunt_attack_animation(target: Node2D) -> void:
	if _hunt_attack_tween and _hunt_attack_tween.is_valid():
		_hunt_attack_tween.kill()
	_hunt_attack_visual_time_left = 0.30
	var direction := signf(target.global_position.x - global_position.x)
	if is_zero_approx(direction):
		direction = 1.0 if fox_sprite.flip_h else -1.0
	fox_sprite.scale = Vector2(0.82, 1.22)
	fox_sprite.rotation = -0.22 * direction
	_hunt_attack_tween = create_tween()
	_hunt_attack_tween.set_parallel(true)
	_hunt_attack_tween.tween_property(fox_sprite, "position:x", direction * 12.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hunt_attack_tween.tween_property(fox_sprite, "scale", Vector2(1.34, 0.74), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hunt_attack_tween.chain().set_parallel(true)
	_hunt_attack_tween.tween_property(fox_sprite, "position", Vector2.ZERO, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hunt_attack_tween.tween_property(fox_sprite, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hunt_attack_tween.tween_property(fox_sprite, "rotation", 0.0, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_hunt_slash(target: Node2D) -> void:
	var slash := Node2D.new()
	slash.z_index = 20
	slash.position = Vector2(0, -5)
	slash.modulate = Color(1.0, 1.0, 1.0, 0.62)
	target.add_child(slash)
	for offset in [-3.5, 0.0, 3.5]:
		_add_hunt_slash_line(slash, Vector2(-14, 10 + offset), Vector2(14, -12 + offset), Color.BLACK, 6.0)
		_add_hunt_slash_line(slash, Vector2(-14, 10 + offset), Vector2(14, -12 + offset), Color("ffe082"), 3.2)
	var tween := slash.create_tween()
	tween.tween_property(slash, "scale", Vector2(1.12, 1.12), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.10)
	tween.tween_callback(slash.queue_free)


func _add_hunt_slash_line(parent: Node2D, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.add_point(from)
	line.add_point(to)
	parent.add_child(line)


func _update_walk_animation(delta: float) -> void:
	if _hunt_attack_visual_time_left > 0.0:
		return
	super._update_walk_animation(delta)


func _get_area_campfire() -> Campfire:
	for node in get_tree().get_nodes_in_group("campfires"):
		if node is Campfire and (node as Campfire).area_id == _get_hunt_area_id():
			return node as Campfire
	return null


func _get_hunt_area_id() -> int:
	return 1


func get_hunt_damage() -> int:
	return HUNT_DAMAGE


func _is_stationary_before_recruitment() -> bool:
	return false


func _get_helper_name() -> String:
	return "Lio"


func _get_reward_price_text() -> String:
	if is_reward_handoff_free():
		return "Free"
	var fee := get_reward_fee()
	var resources := get_tree().get_first_node_in_group("resource_manager") as ResourceManager
	var entries: Array[String] = []
	for raw_resource_id in fee:
		var resource_id := StringName(raw_resource_id)
		var definition := resources.get_definition(resource_id) if resources else null
		var display_name: String = definition.display_name if definition else str(resource_id).capitalize()
		entries.append("%d %s" % [int(fee[raw_resource_id]), display_name])
	return " + ".join(entries)


func _update_helper_tooltip() -> void:
	var hovering := Rect2(Vector2(-32, -32), Vector2(64, 64)).has_point(to_local(get_global_mouse_position()))
	var should_show := hovering and is_waiting_at_campfire() and not _collected_rewards.is_empty() and not _dialogue_is_open()
	var tooltip := get_tree().get_first_node_in_group("item_tooltip") as ItemTooltip
	if not should_show:
		if _helper_tooltip_visible and tooltip:
			tooltip.hide_item()
		_helper_tooltip_visible = false
		_helper_tooltip_copy = ""
		return
	if tooltip == null:
		return
	var copy := _get_reward_tooltip_copy()
	if _helper_tooltip_visible and copy == _helper_tooltip_copy:
		return
	_helper_tooltip_visible = true
	_helper_tooltip_copy = copy
	tooltip.show_description(fox_sprite.texture, "%s's Rewards" % _get_helper_name(), copy)


func _get_reward_tooltip_copy() -> String:
	var totals := get_collected_reward_totals()
	var keys := totals.keys()
	keys.sort()
	var lines: Array[String] = []
	for key_variant in keys:
		var key := str(key_variant)
		lines.append("+%d %s" % [int(totals[key_variant]), _reward_name_for_key(key)])
	lines.append("Price: %s" % _get_reward_price_text())
	return "\n".join(lines)


func _reward_name_for_key(key: String) -> String:
	var colors := ["Red", "Yellow", "Blue"]
	if key.begins_with("damage_"):
		return "%s Damage" % colors[clampi(int(key.trim_prefix("damage_")), 0, 2)]
	if key.begins_with("defense_"):
		return "%s Defense" % colors[clampi(int(key.trim_prefix("defense_")), 0, 2)]
	if key == "health":
		return "Health"
	if key == "regeneration":
		return "Regeneration"
	if key.begins_with("resource_"):
		var resource_id := StringName(key.trim_prefix("resource_"))
		var resources := get_tree().get_first_node_in_group("resource_manager") as ResourceManager
		var definition := resources.get_definition(resource_id) if resources else null
		return definition.display_name if definition else str(resource_id).capitalize()
	return "Reward"


func _run_reward_delivery() -> void:
	if not is_instance_valid(_world):
		_delivery_running = false
		return
	_world.gameplay_paused = true
	_world.interaction_locked = true
	var rewards := _collected_rewards.duplicate(true)
	for reward_index in range(rewards.size()):
		_launch_collected_reward(rewards[reward_index])
		if reward_index >= rewards.size() - 1:
			continue
		for _frame in range(REWARD_RELEASE_FRAME_INTERVAL):
			await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	_world.gameplay_paused = false
	_world.interaction_locked = false
	_delivery_running = false
	var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
	if story:
		_notify_reward_delivery_finished(story)


func _notify_reward_delivery_finished(story: StoryManager) -> void:
	story.on_lio_reward_delivery_finished()


func _launch_collected_reward(reward: Dictionary) -> void:
	var target_screen := _reward_target_screen(reward)
	var target_world := get_viewport().get_canvas_transform().affine_inverse() * target_screen
	var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
	RewardOrb.fly(_world, global_position + Vector2(0, -24), target_world, _reward_color(reward), _apply_collected_reward.bind(reward), audio.play_upgrade if audio else Callable())


func _apply_collected_reward(reward: Dictionary) -> void:
	if not is_instance_valid(_player):
		return
	var amount := int(reward.get("amount", 0))
	match int(reward.get("type", ChickenEnemy.REWARD_DAMAGE)):
		ChickenEnemy.REWARD_DAMAGE:
			_player.add_color_damage(int(reward.get("damage_color", FoxPlayer.COLOR_RED)), amount)
		ChickenEnemy.REWARD_HEALTH:
			_player.absorb_enemy_health(amount)
		ChickenEnemy.REWARD_REGENERATE:
			_player.add_passive_healing(amount)
		ChickenEnemy.REWARD_DEFENSE:
			_player.add_color_defense(int(reward.get("defense_color", FoxPlayer.COLOR_RED)), amount)
		ChickenEnemy.REWARD_RESOURCE:
			var resources := get_tree().get_first_node_in_group("resource_manager") as ResourceManager
			if resources:
				resources.add_resource(StringName(reward.get("resource_id", "gold_ore")), amount)
	_collected_rewards.erase(reward)
	_refresh_collected_stats_display()


func _reward_target_screen(reward: Dictionary) -> Vector2:
	var hud := _world.get_node_or_null("HUD") if _world else null
	match int(reward.get("type", ChickenEnemy.REWARD_DAMAGE)):
		ChickenEnemy.REWARD_DAMAGE:
			var damage_grid := hud.get_node_or_null("DamageGrid") as DamageGrid if hud else null
			if damage_grid:
				return damage_grid.get_color_target_screen_position(int(reward.get("damage_color", 0)))
		ChickenEnemy.REWARD_DEFENSE:
			var armor_grid = hud.get_node_or_null("ArmorGrid") if hud else null
			if armor_grid:
				return armor_grid.get_color_target_screen_position(int(reward.get("defense_color", 0)))
		ChickenEnemy.REWARD_RESOURCE:
			var resource_panel := hud.get_node_or_null("ResourcePanel") as ResourcePanel if hud else null
			if resource_panel:
				return resource_panel.get_resource_target_screen_position(StringName(reward.get("resource_id", "gold_ore")))
		ChickenEnemy.REWARD_HEALTH, ChickenEnemy.REWARD_REGENERATE:
			var vitals := hud.get_node_or_null("PlayerVitals") if hud else null
			if vitals:
				return vitals.call("get_stat_target_screen_position", &"health" if int(reward.get("type", 0)) == ChickenEnemy.REWARD_HEALTH else &"regeneration")
	return Vector2(48, 48)


func _reward_color(reward: Dictionary) -> Color:
	var colors := [Color("e53935"), Color("fbc02d"), Color("1976d2")]
	match int(reward.get("type", ChickenEnemy.REWARD_DAMAGE)):
		ChickenEnemy.REWARD_DAMAGE:
			return colors[clampi(int(reward.get("damage_color", 0)), 0, 2)]
		ChickenEnemy.REWARD_DEFENSE:
			return colors[clampi(int(reward.get("defense_color", 0)), 0, 2)]
		ChickenEnemy.REWARD_HEALTH:
			return Color("800000")
		ChickenEnemy.REWARD_REGENERATE:
			return Color("65d76e")
		ChickenEnemy.REWARD_RESOURCE:
			var resources := get_tree().get_first_node_in_group("resource_manager") as ResourceManager
			var definition := resources.get_definition(StringName(reward.get("resource_id", "gold_ore"))) if resources else null
			return definition.display_color if definition else Color.WHITE
	return Color.WHITE


func _build_collected_stats_display() -> void:
	_collected_row = HBoxContainer.new()
	_collected_row.name = "CollectedStats"
	_collected_row.position.y = -46.0
	_collected_row.add_theme_constant_override("separation", 6)
	_collected_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collected_row.z_index = 25
	add_child(_collected_row)
	_refresh_collected_stats_display()


func _refresh_collected_stats_display() -> void:
	if not is_instance_valid(_collected_row):
		return
	for child in _collected_row.get_children():
		_collected_row.remove_child(child)
		child.queue_free()
	var totals := get_collected_reward_totals()
	var keys := totals.keys()
	keys.sort()
	for key in keys:
		var entry := HBoxContainer.new()
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.texture = _reward_icon_for_key(str(key))
		icon.custom_minimum_size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(icon)
		var amount := Label.new()
		amount.text = str(int(totals[key]))
		amount.add_theme_color_override("font_color", Color.WHITE)
		amount.add_theme_color_override("font_outline_color", Color.BLACK)
		amount.add_theme_constant_override("outline_size", 3)
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(amount)
		_collected_row.add_child(entry)
	_collected_row.visible = not totals.is_empty()
	_collected_row.reset_size()
	_center_collected_stats_display()
	call_deferred("_center_collected_stats_display")


func _center_collected_stats_display() -> void:
	if is_instance_valid(_collected_row):
		_collected_row.position = Vector2(-_collected_row.size.x * 0.5, -46.0)


func _reward_key(reward: Dictionary) -> String:
	match int(reward.get("type", ChickenEnemy.REWARD_DAMAGE)):
		ChickenEnemy.REWARD_DAMAGE:
			return "damage_%d" % int(reward.get("damage_color", 0))
		ChickenEnemy.REWARD_DEFENSE:
			return "defense_%d" % int(reward.get("defense_color", 0))
		ChickenEnemy.REWARD_HEALTH:
			return "health"
		ChickenEnemy.REWARD_REGENERATE:
			return "regeneration"
		ChickenEnemy.REWARD_RESOURCE:
			return "resource_%s" % str(reward.get("resource_id", "gold_ore"))
	return "unknown"


func _reward_icon_for_key(key: String) -> Texture2D:
	if key.begins_with("damage_"):
		return DAMAGE_ICON
	if key.begins_with("defense_"):
		return DEFENSE_ICON
	if key == "health":
		return HEALTH_ICON
	if key == "regeneration":
		return REGENERATION_ICON
	if key.begins_with("resource_"):
		var resources := get_tree().get_first_node_in_group("resource_manager") as ResourceManager
		var definition := resources.get_definition(StringName(key.trim_prefix("resource_"))) if resources else null
		return definition.icon if definition else null
	return null
