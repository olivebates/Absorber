class_name FoxPlayer
extends CharacterBody2D

const DAMAGE_POPUP_SCENE := preload("res://Scenes/damage_popup.tscn")
const COLOR_RED := 0
const COLOR_YELLOW := 1
const COLOR_BLUE := 2

signal damage_matrix_changed
signal inventory_changed
signal equipment_changed
signal merge_targets_changed(dragged_item: Dictionary, source_storage: String, source_index: int)
signal merge_completed(merged_item: Dictionary, target_storage: String, target_index: int)

@export var move_speed := 280.0
@export var max_health := 10
@export var attack_damage := 1 # Compatibility value mirrors the equipped red damage.
@export var attack_range := 52.0
@export var attack_cooldown := 0.8

var health: int
var passive_healing_amount := 1
var current_weapon_index := 0
var damage_by_color := [[1, 1, 1, 1], [1, 1, 1, 1], [1, 1, 1, 1]]
var equipped_armor: Array[Dictionary] = [{}, {}, {}, {}]
var equipped_weapons: Array[Dictionary] = [{}, {}, {}, {}]
var inventory_slots: Array[Dictionary] = [{}, {}, {}, {}]
var weapon_ever_equipped := [false, false, false, false]
var _weapon_cooldowns := [0.0, 0.0, 0.0, 0.0]
var _heal_time_left := 3.0
var _path := PackedVector2Array()
var _path_index := 0
var _destination := Vector2.ZERO
var _attack_target: ChickenEnemy
var _target_cell := Vector2i(-999999, -999999)
var _attack_tween: Tween
var _hit_tween: Tween
var _walk_time := 0.0
var _attack_visual_time_left := 0.0
var _hit_visual_time_left := 0.0
var _spawn_position := Vector2.ZERO
var _pending_item_collections := 0
var _combat_ring: Line2D
var _healing_particles: HealingParticles

@onready var fox_sprite: Sprite2D = $FoxSprite
@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthLabel


func _ready() -> void:
	_spawn_position = global_position
	health = max_health
	health_bar.max_value = max_health
	health_bar.value = health
	_update_health_label()
	attack_damage = get_damage_for_color(COLOR_RED)
	_combat_ring = _create_combat_ring(Color.WHITE)
	add_child(_combat_ring)
	_healing_particles = HealingParticles.new()
	_healing_particles.position = Vector2(0, 10)
	_healing_particles.z_index = 2
	add_child(_healing_particles)


func follow_path(points: PackedVector2Array) -> void:
	_path = points
	_path_index = 0
	if not points.is_empty():
		_destination = points[-1]
	_advance_past_reached_points()


func stop() -> void:
	_path.clear()
	_path_index = 0
	velocity = Vector2.ZERO
	_snap_to_tile_center()


func follow_enemy(enemy: ChickenEnemy) -> void:
	_attack_target = enemy
	_target_cell = Vector2i(-999999, -999999)
	_update_enemy_chase()


func clear_attack_target() -> void:
	_attack_target = null


func is_moving() -> bool:
	return _path_index < _path.size()


func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = max(0, health - max(0, amount - get_total_block()))
	health_bar.value = health
	_update_health_label()
	_show_damage_popup(amount)
	if health == 0:
		_respawn()


func heal(amount: int) -> void:
	if health <= 0 or amount <= 0:
		return
	health = min(max_health, health + amount)
	health_bar.value = health
	_update_health_label()


func add_max_health(amount: int) -> void:
	if amount == 0:
		return
	var old_max_health := max_health
	max_health = maxi(1, max_health + amount)
	health_bar.max_value = max_health
	if max_health > old_max_health:
		heal(max_health - old_max_health)
	else:
		health = mini(health, max_health)
		health_bar.value = health
		_update_health_label()


func add_passive_healing(amount: int) -> void:
	if amount == 0:
		return
	var old_interval := _get_passive_heal_interval()
	passive_healing_amount = maxi(1, passive_healing_amount + amount)
	var progress_left := clampf(_heal_time_left / old_interval, 0.0, 1.0)
	_heal_time_left = _get_passive_heal_interval() * progress_left


func add_attack_damage(amount: int) -> void:
	add_color_damage(COLOR_RED, amount)


func add_color_damage(color_index: int, amount: int) -> void:
	if color_index < 0 or color_index >= damage_by_color.size():
		return
	damage_by_color[color_index][current_weapon_index] = maxi(1, damage_by_color[color_index][current_weapon_index] + amount)
	attack_damage = get_damage_for_color(COLOR_RED)
	damage_matrix_changed.emit()


func collect_item(item_id: String, grade := 0) -> bool:
	if not ItemPickup.ITEM_DATA.has(item_id):
		return false
	for index in range(inventory_slots.size()):
		if inventory_slots[index].is_empty():
			inventory_slots[index] = ItemPickup.make_item(item_id, grade)
			inventory_changed.emit()
			return true
	return false


func reserve_item_collection() -> bool:
	var empty_slots := 0
	for item in inventory_slots:
		if item.is_empty():
			empty_slots += 1
	if empty_slots <= _pending_item_collections:
		return false
	_pending_item_collections += 1
	return true


func complete_item_collection(item_id: String, grade: int) -> void:
	_pending_item_collections = max(0, _pending_item_collections - 1)
	collect_item(item_id, grade)


func get_weapon_cooldown_ratio(weapon_index: int) -> float:
	if weapon_index < 0 or weapon_index >= _weapon_cooldowns.size() or attack_cooldown <= 0.0:
		return 0.0
	return clampf(_weapon_cooldowns[weapon_index] / attack_cooldown, 0.0, 1.0)


func get_slot_item(storage: String, index: int) -> Dictionary:
	var slots := _get_slots(storage)
	if index < 0 or index >= slots.size():
		return {}
	return slots[index].duplicate()


func move_or_merge(source_storage: String, source_index: int, target_storage: String, target_index: int) -> bool:
	if source_storage == target_storage and source_index == target_index:
		return false
	var source_slots := _get_slots(source_storage)
	var target_slots := _get_slots(target_storage)
	if source_index < 0 or source_index >= source_slots.size() or target_index < 0 or target_index >= target_slots.size():
		return false
	var source_item := source_slots[source_index]
	if source_item.is_empty() or not _storage_accepts(target_storage, source_item):
		return false
	var target_item := target_slots[target_index]
	var merged_item: Dictionary = {}
	if can_merge(source_item, target_item):
		target_item["grade"] = ItemPickup.get_item_grade(target_item) + 1
		target_slots[target_index] = target_item
		source_slots[source_index] = {}
		merged_item = target_item.duplicate()
	else:
		if not target_item.is_empty() and not _storage_accepts(source_storage, target_item):
			return false
		source_slots[source_index] = target_item
		target_slots[target_index] = source_item
	if target_storage == "weapon" and not target_slots[target_index].is_empty():
		weapon_ever_equipped[target_index] = true
	if source_storage == "weapon" and not source_slots[source_index].is_empty():
		weapon_ever_equipped[source_index] = true
	attack_damage = get_damage_for_color(COLOR_RED)
	inventory_changed.emit()
	equipment_changed.emit()
	damage_matrix_changed.emit()
	if not merged_item.is_empty():
		merge_completed.emit(merged_item, target_storage, target_index)
	return true


func auto_merge_inventory() -> int:
	var merge_count := 0
	while true:
		var pair := get_next_auto_merge_pair()
		if pair.is_empty() or not merge_inventory_pair(int(pair["source_index"]), int(pair["target_index"])):
			break
		merge_count += 1
	return merge_count


func has_auto_mergeable_inventory_pair() -> bool:
	return not get_next_auto_merge_pair().is_empty()


func get_next_auto_merge_pair() -> Dictionary:
	for target_index in range(inventory_slots.size()):
		if inventory_slots[target_index].is_empty():
			continue
		for source_index in range(target_index + 1, inventory_slots.size()):
			if can_merge(inventory_slots[source_index], inventory_slots[target_index]):
				return {"source_index": source_index, "target_index": target_index}
	return {}


func merge_inventory_pair(source_index: int, target_index: int) -> bool:
	return move_or_merge("inventory", source_index, "inventory", target_index)


func can_merge(first: Dictionary, second: Dictionary) -> bool:
	return not first.is_empty() and not second.is_empty() \
		and str(first.get("item_id", "")) == str(second.get("item_id", "")) \
		and ItemPickup.get_item_grade(first) == ItemPickup.get_item_grade(second) \
		and ItemPickup.get_item_grade(first) < ItemPickup.GRADES.size() - 1


func set_dragged_item(item: Dictionary, source_storage: String, source_index: int) -> void:
	merge_targets_changed.emit(item, source_storage, source_index)


func clear_dragged_item() -> void:
	merge_targets_changed.emit({}, "", -1)


func has_equipped_armor() -> bool:
	for item in equipped_armor:
		if not item.is_empty():
			return true
	return false


func get_damage_for_color(color_index: int) -> int:
	return get_damage_for_weapon_color(color_index, current_weapon_index)


func get_base_damage_for_color(color_index: int) -> int:
	if color_index < 0 or color_index >= damage_by_color.size():
		return 0
	return damage_by_color[color_index][current_weapon_index]


func has_weapon_been_equipped(weapon_index: int) -> bool:
	return weapon_index >= 0 and weapon_index < weapon_ever_equipped.size() and weapon_ever_equipped[weapon_index]


func get_damage_for_weapon_color(color_index: int, weapon_index: int) -> int:
	if color_index < 0 or color_index >= damage_by_color.size() or weapon_index < 0 or weapon_index >= equipped_weapons.size():
		return 0
	return damage_by_color[color_index][weapon_index] + ItemPickup.get_damage_bonus(equipped_weapons[weapon_index])


func get_total_block() -> int:
	var total := 0
	for item in equipped_armor:
		total += ItemPickup.get_block_amount(item)
	return total


func get_save_data() -> Array:
	var flattened_damage: Array[int] = []
	for color_values in damage_by_color:
		for value in color_values:
			flattened_damage.append(int(value))
	var ever_equipped_mask := 0
	for index in range(weapon_ever_equipped.size()):
		if bool(weapon_ever_equipped[index]):
			ever_equipped_mask |= 1 << index
	var cooldown_milliseconds: Array[int] = []
	for cooldown in _weapon_cooldowns:
		cooldown_milliseconds.append(maxi(0, roundi(float(cooldown) * 1000.0)))
	return [
		roundi(global_position.x), roundi(global_position.y), health, max_health,
		passive_healing_amount, current_weapon_index, flattened_damage,
		_pack_items(inventory_slots), _pack_items(equipped_weapons), _pack_items(equipped_armor),
		ever_equipped_mask, cooldown_milliseconds, maxi(0, roundi(_heal_time_left * 1000.0)),
		maxi(1, roundi(_get_healing_speed_multiplier())),
	]


func load_save_data(data: Array, offline_seconds: int) -> bool:
	if data.size() < 14:
		return false
	stop()
	clear_attack_target()
	global_position = Vector2(float(data[0]), float(data[1]))
	max_health = maxi(1, int(data[3]))
	passive_healing_amount = maxi(1, int(data[4]))
	current_weapon_index = clampi(int(data[5]), 0, equipped_weapons.size() - 1)

	var flattened_damage := data[6] as Array
	var damage_index := 0
	damage_by_color = []
	for _color_index in range(3):
		var color_values: Array[int] = []
		for _weapon_index in range(4):
			color_values.append(maxi(1, int(flattened_damage[damage_index])) if damage_index < flattened_damage.size() else 1)
			damage_index += 1
		damage_by_color.append(color_values)

	inventory_slots = _unpack_items(data[7] as Array, 4)
	equipped_weapons = _unpack_items(data[8] as Array, 4)
	equipped_armor = _unpack_items(data[9] as Array, 4)
	var ever_equipped_mask := int(data[10])
	weapon_ever_equipped = []
	for index in range(4):
		weapon_ever_equipped.append((ever_equipped_mask & (1 << index)) != 0)

	var saved_cooldowns := data[11] as Array
	_weapon_cooldowns = []
	for index in range(4):
		var saved_milliseconds := int(saved_cooldowns[index]) if index < saved_cooldowns.size() else 0
		_weapon_cooldowns.append(maxf(0.0, float(saved_milliseconds - offline_seconds * 1000) / 1000.0))

	var healing_speed_multiplier := maxi(1, int(data[13]))
	var healing_milliseconds := int(data[12]) - offline_seconds * 1000 * healing_speed_multiplier
	var healing_interval_milliseconds := maxf(1.0, 3000.0 / float(maxi(1, passive_healing_amount)))
	var saved_health := clampi(int(data[2]), 0, max_health)
	if healing_milliseconds <= 0:
		var heal_ticks := 1 + floori(float(-healing_milliseconds) / healing_interval_milliseconds)
		saved_health = mini(max_health, saved_health + heal_ticks)
		healing_milliseconds += roundi(float(heal_ticks) * healing_interval_milliseconds)
	health = saved_health
	_heal_time_left = maxf(0.001, float(healing_milliseconds) / 1000.0)
	_pending_item_collections = 0
	attack_damage = get_damage_for_color(COLOR_RED)
	health_bar.max_value = max_health
	health_bar.value = health
	_update_health_label()
	inventory_changed.emit()
	equipment_changed.emit()
	damage_matrix_changed.emit()
	return true


func _pack_items(items: Array[Dictionary]) -> Array:
	var packed: Array = []
	for item in items:
		packed.append([] if item.is_empty() else [str(item.get("item_id", "")), ItemPickup.get_item_grade(item)])
	return packed


func _unpack_items(packed: Array, expected_size: int) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for index in range(expected_size):
		var packed_item := packed[index] as Array if index < packed.size() and packed[index] is Array else []
		var item_id := str(packed_item[0]) if not packed_item.is_empty() else ""
		items.append(ItemPickup.make_item(item_id, int(packed_item[1]) if packed_item.size() > 1 else 0) if ItemPickup.ITEM_DATA.has(item_id) else {})
	return items


func _get_slots(storage: String) -> Array[Dictionary]:
	match storage:
		"inventory":
			return inventory_slots
		"weapon":
			return equipped_weapons
		"armor":
			return equipped_armor
	return []


func _storage_accepts(storage: String, item: Dictionary) -> bool:
	var item_id := str(item.get("item_id", ""))
	return storage == "inventory" \
		or storage == "weapon" and ItemPickup.is_weapon(item_id) \
		or storage == "armor" and ItemPickup.is_armor(item_id)


func _physics_process(delta: float) -> void:
	for index in range(_weapon_cooldowns.size()):
		_weapon_cooldowns[index] = maxf(0.0, _weapon_cooldowns[index] - delta)
	_attack_visual_time_left = maxf(0.0, _attack_visual_time_left - delta)
	_hit_visual_time_left = maxf(0.0, _hit_visual_time_left - delta)
	_heal_time_left -= delta * _get_healing_speed_multiplier()
	while _heal_time_left <= 0.0:
		heal(1)
		_heal_time_left += _get_passive_heal_interval()
	_update_campfire_healing_visual()
	_update_enemy_chase()
	_move_along_path(delta)
	_collect_pickups_on_current_tile()
	_attack_nearby_enemy()
	_update_walk_animation(delta)
	_update_combat_ring()
	_face_combat_enemy()


func _move_along_path(delta: float) -> void:
	_advance_past_reached_points()
	if not is_moving():
		velocity = Vector2.ZERO
		_snap_to_tile_center()
		return
	var target := _path[_path_index]
	var offset := target - global_position
	if offset.length() <= 3.0:
		global_position = target
		_path_index += 1
		return
	velocity = offset.normalized() * move_speed
	if velocity.x > 0.1:
		fox_sprite.flip_h = true
	elif velocity.x < -0.1:
		fox_sprite.flip_h = false
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	if world and not world.can_enter_position(self, global_position + velocity * delta):
		velocity = Vector2.ZERO
		var detour := world.find_path(global_position, _destination, self)
		if detour.size() > 1:
			_path = detour
			_path_index = 1
		return
	move_and_slide()


func _attack_nearby_enemy() -> void:
	if _weapon_cooldowns[current_weapon_index] > 0.0:
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
		if enemy is ChickenEnemy and world and world.are_adjacent(self, enemy):
			_face_toward(enemy)
			_play_attack_animation(enemy)
			_show_slash(enemy, ItemPickup.get_grade_color(ItemPickup.get_item_grade(equipped_weapons[current_weapon_index])))
			enemy.take_damage(get_damage_for_color(enemy.enemy_color))
			_weapon_cooldowns[current_weapon_index] = attack_cooldown
			return


func _collect_pickups_on_current_tile() -> void:
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	if world == null:
		return
	var player_cell := world.world_to_cell(global_position)
	for pickup in get_tree().get_nodes_in_group("item_pickups"):
		if pickup is ItemPickup and is_instance_valid(pickup) and world.world_to_cell(pickup.global_position) == player_cell:
			pickup.begin_collect(self)


func _update_combat_ring() -> void:
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	_combat_ring.visible = false
	if world == null:
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is ChickenEnemy and is_instance_valid(enemy) and enemy.health > 0 and world.are_adjacent(self, enemy):
			_combat_ring.visible = true
			return


func _face_combat_enemy() -> void:
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	if world == null:
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is ChickenEnemy and is_instance_valid(enemy) and enemy.health > 0 and world.are_adjacent(self, enemy):
			_face_toward(enemy)
			return


func _face_toward(target: Node2D) -> void:
	var horizontal_offset := target.global_position.x - global_position.x
	if horizontal_offset > 0.1:
		fox_sprite.flip_h = true
	elif horizontal_offset < -0.1:
		fox_sprite.flip_h = false


func _get_healing_speed_multiplier() -> float:
	return 5.0 if _is_near_campfire() else 1.0


func _get_passive_heal_interval() -> float:
	return 3.0 / float(maxi(1, passive_healing_amount))


func _is_near_campfire() -> bool:
	for campfire in get_tree().get_nodes_in_group("campfires"):
		if campfire is Campfire and is_instance_valid(campfire) and campfire.is_player_in_range(self):
			return true
	return false


func _update_campfire_healing_visual() -> void:
	if _healing_particles:
		_healing_particles.emitting = _is_near_campfire()


func _create_combat_ring(color: Color) -> Line2D:
	var ring := Line2D.new()
	ring.width = 2.5
	ring.default_color = color
	ring.position = Vector2(0, 19)
	ring.z_index = -1
	for index in range(17):
		var angle := TAU * float(index) / 16.0
		ring.add_point(Vector2(cos(angle) * 22.0, sin(angle) * 8.0))
	ring.visible = false
	return ring


func _show_slash(target: Node2D, color: Color) -> void:
	var slash := Node2D.new()
	slash.z_index = 20
	slash.position = Vector2(0, -5)
	slash.modulate = Color(1.0, 1.0, 1.0, 0.62)
	target.add_child(slash)
	for offset in [-3.5, 0.0, 3.5]:
		_add_slash_line(slash, Vector2(-14, 10 + offset), Vector2(14, -12 + offset), Color.BLACK, 6.0)
		_add_slash_line(slash, Vector2(-14, 10 + offset), Vector2(14, -12 + offset), color, 3.2)
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


func _update_enemy_chase() -> void:
	if not is_instance_valid(_attack_target) or _attack_target.health <= 0:
		_attack_target = null
		return
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	if world == null:
		return
	if world.are_adjacent(self, _attack_target):
		stop()
		return
	var enemy_cell := world.world_to_cell(_attack_target.global_position)
	if enemy_cell == _target_cell:
		return
	_target_cell = enemy_cell
	var best_path := PackedVector2Array()
	var best_distance := INF
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var adjacent_cell: Vector2i = enemy_cell + offset
		if not world.is_walkable(adjacent_cell) or world.is_cell_occupied(adjacent_cell, self):
			continue
		var candidate := world.find_path(global_position, world.cell_to_world(adjacent_cell), self)
		if candidate.is_empty():
			continue
		var distance := _path_distance(candidate)
		if distance < best_distance:
			best_distance = distance
			best_path = candidate
	if not best_path.is_empty():
		follow_path(best_path)
	else:
		# Retry next frame; another actor may vacate a valid adjacent tile.
		_target_cell = Vector2i(-999999, -999999)


func _path_distance(points: PackedVector2Array) -> float:
	var distance := 0.0
	for index in range(1, points.size()):
		distance += points[index - 1].distance_to(points[index])
	return distance


func _advance_past_reached_points() -> void:
	while _path_index < _path.size() and global_position.distance_squared_to(_path[_path_index]) <= 9.0:
		_path_index += 1


func _snap_to_tile_center() -> void:
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	if world and world.is_walkable(world.world_to_cell(global_position)):
		global_position = world.cell_to_world(world.world_to_cell(global_position))


func _respawn() -> void:
	stop()
	clear_attack_target()
	global_position = _spawn_position
	health = max_health
	health_bar.value = health
	_update_health_label()
	_heal_time_left = 3.0


func _play_attack_animation(target: Node2D) -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	_attack_visual_time_left = 0.30
	var direction := signf(target.global_position.x - global_position.x)
	if is_zero_approx(direction):
		direction = 1.0 if fox_sprite.flip_h else -1.0
	fox_sprite.scale = Vector2(0.82, 1.22)
	fox_sprite.rotation = -0.22 * direction
	_attack_tween = create_tween()
	_attack_tween.set_parallel(true)
	_attack_tween.tween_property(fox_sprite, "position:x", direction * 12.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(fox_sprite, "scale", Vector2(1.34, 0.74), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_attack_tween.chain().set_parallel(true)
	_attack_tween.tween_property(fox_sprite, "position", Vector2.ZERO, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(fox_sprite, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(fox_sprite, "rotation", 0.0, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_walk_animation(delta: float) -> void:
	if _attack_visual_time_left > 0.0 or _hit_visual_time_left > 0.0:
		return
	if velocity.length_squared() > 1.0:
		_walk_time += delta * 11.0
		fox_sprite.position.y = -absf(sin(_walk_time)) * 5.0
		fox_sprite.rotation = sin(_walk_time) * 0.09
	else:
		fox_sprite.position = Vector2.ZERO
		fox_sprite.rotation = 0.0


func _update_health_label() -> void:
	health_label.text = str(health)


func _show_damage_popup(amount: int) -> void:
	var popup := DAMAGE_POPUP_SCENE.instantiate() as DamagePopup
	popup.position = global_position + Vector2(0, -38)
	get_parent().add_child(popup)
	popup.show_damage(amount)
	_play_hit_animation()


func _play_hit_animation() -> void:
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_visual_time_left = 0.20
	fox_sprite.modulate = Color("fff3b0")
	fox_sprite.scale = Vector2(1.22, 0.78)
	_hit_tween = create_tween()
	_hit_tween.set_parallel(true)
	_hit_tween.tween_property(fox_sprite, "modulate", Color.WHITE, 0.16)
	_hit_tween.tween_property(fox_sprite, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
