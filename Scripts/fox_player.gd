class_name FoxPlayer
extends CharacterBody2D

const DAMAGE_POPUP_SCENE := preload("res://Scenes/damage_popup.tscn")
const COLOR_RED := 0
const COLOR_YELLOW := 1
const COLOR_BLUE := 2
const SKILL_ROLL_CLOCKWISE := &"roll_clockwise"
const SKILL_YELLOW_GUARD := &"yellow_guard"
const SKILL_ROLL_BACK := &"roll_back"
const SKILL_ROLL_ARC := &"roll_arc"
const SKILL_BULWARK := &"bulwark"
const PLAYER_SKILL_IDS: Array[StringName] = [SKILL_ROLL_CLOCKWISE, SKILL_YELLOW_GUARD, SKILL_ROLL_BACK, SKILL_ROLL_ARC, SKILL_BULWARK]
const DAMAGE_COLORS := [Color("e53935"), Color("fbc02d"), Color("1976d2")]
const SKILL_DATA := {
	SKILL_ROLL_CLOCKWISE: {
		"name": "Quick Roll", "description": "* Rolls 90 degrees around your target.\n* Invulnerable while rolling.\n* Increases Yellow damage by 2 for two seconds.",
		"icon": preload("res://Sprites/skillRoll.webp"), "mana": 5, "cooldown": 4.0,
	},
	SKILL_YELLOW_GUARD: {
		"name": "Golden Guard", "description": "Create a golden circle for 1 second that blocks all yellow damage.",
		"icon": preload("res://Sprites/IconSkillBook.webp"), "mana": 15, "cooldown": 12.0,
	},
	SKILL_ROLL_BACK: {
		"name": "Back Roll", "description": "Roll two tiles away from your current enemy target. You cannot take damage during the roll.",
		"icon": preload("res://Sprites/iconBackwardsRoll.webp"), "mana": 5, "cooldown": 4.0,
	},
	SKILL_ROLL_ARC: {
		"name": "Arc Roll", "description": "Roll clockwise around your target to the opposite tile. You cannot take damage during the roll.",
		"icon": preload("res://Sprites/skillRoll.webp"), "mana": 5, "cooldown": 4.0,
	},
	SKILL_BULWARK: {
		"name": "Bulwark", "description": "Gain 20 Yellow armor for 3 seconds.",
		"icon": preload("res://Sprites/skillBulwark.webp"), "mana": 5, "cooldown": 8.0,
	},
}

signal damage_matrix_changed
signal vitals_changed
signal inventory_changed
signal equipment_changed
signal enemy_health_absorbed(amount: int)
signal merge_targets_changed(dragged_item: Dictionary, source_storage: String, source_index: int)
signal merge_completed(merged_item: Dictionary, target_storage: String, target_index: int)
signal duplicate_equipment_found
signal auto_fight_changed
signal skills_changed
signal mana_changed

@export var move_speed := 280.0
@export var max_health := 10
@export var attack_damage := 1 # Compatibility value mirrors the equipped red damage.
@export var attack_range := 52.0
@export var attack_cooldown := 0.8

var health: int
var passive_healing_amount := 1
var max_mana := 10
var mana := 10
var passive_mana_regeneration_amount := 1
var unlocked_player_skills: Array[StringName] = []
var equipped_player_skills: Array[StringName] = [&"", &"", &"", &""]
var player_skill_slots_unlocked := [true, false, false, false]
var equipment_slots_unlocked := 1
var skill_swap_tutorial_seen := false
var current_weapon_index := 0
var damage_by_color := [[1, 1, 1, 1], [1, 1, 1, 1], [1, 1, 1, 1]]
var defense_by_color: Array[int] = [0, 0, 0]
var defense: int:
	set(value):
		defense_by_color[COLOR_RED] = maxi(0, value)
		damage_matrix_changed.emit()
	get:
		return defense_by_color[COLOR_RED]
var equipped_armor: Array[Dictionary] = [{}, {}, {}, {}]
var equipped_weapons: Array[Dictionary] = [{}, {}, {}, {}]
var inventory_slots: Array[Dictionary] = [{}, {}, {}, {}]
var trash_slots: Array[Dictionary] = [{}]
var weapon_ever_equipped := [false, false, false, false]
var armor_ever_equipped := false
var merge_count := 0
var duplicate_equipment_tutorial_seen := false
var enemy_skill_move_tutorial_seen := false
var cascading_sweep_skill_tutorial_seen := false
var snare_without_quick_roll_tutorial_seen := false
var auto_fight_unlocked := false
var auto_fight_enabled := false
var auto_fight_range_bonus := 0
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
var _beginning_position := Vector2.ZERO
var _pending_item_collections := 0
var _combat_ring: Line2D
var _combat_alignment_enemy: ChickenEnemy
var _combat_entry_aligned := false
var _healing_particles: HealingParticles
var _is_dying := false
var _scripted_movement := false
var _death_overlay: ColorRect
var _auto_fight_range_fill: Polygon2D
var _auto_fight_range_border: Line2D
var _skill_cooldowns: Dictionary = {}
var _mana_regen_time_left := 3.0
var _skill_casting := false
var _skill_invulnerable := false
var _yellow_guard_time_left := 0.0
var _yellow_guard_ring: Line2D
var _bulwark_time_left := 0.0
var _bulwark_ring: Line2D
var _quick_roll_damage_time_left := 0.0
var _skill_visual_tween: Tween
var _last_skill_cast_failure := ""
var _roll_start := Vector2.ZERO
var _roll_end := Vector2.ZERO
var _roll_center := Vector2.ZERO
var _roll_start_angle := 0.0
var _roll_arc_angle := 0.0
var _roll_is_arc := false
var _roll_sprite_start_rotation := 0.0
var _roll_rotation_turns := 1.0
var _roll_skill_id: StringName = &""
var _roll_trail: Line2D
var _roll_afterimage_progress := -1.0
var _snare_sources: Dictionary = {}
var _snare_ring: Line2D
var _snare_label: Label
var _snare_shake_tween: Tween

@onready var fox_sprite: Sprite2D = $FoxSprite
@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthLabel
@onready var mana_bar: ProgressBar = $ManaBar
@onready var mana_label: Label = $ManaLabel


func _ready() -> void:
	_spawn_position = global_position
	_beginning_position = global_position
	health = max_health
	health_bar.max_value = max_health
	health_bar.value = health
	_update_health_label()
	mana = max_mana
	mana_bar.max_value = max_mana
	mana_bar.value = mana
	_update_mana_display()
	attack_damage = get_damage_for_color(COLOR_RED)
	_combat_ring = _create_combat_ring(Color.WHITE)
	add_child(_combat_ring)
	_healing_particles = HealingParticles.new()
	_healing_particles.position = Vector2(0, 10)
	_healing_particles.z_index = 2
	add_child(_healing_particles)
	_create_auto_fight_range()


func follow_path(points: PackedVector2Array) -> void:
	if is_snared() and not points.is_empty():
		_play_snare_blocked_feedback()
		return
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


func begin_scripted_movement() -> void:
	_path.clear()
	_path_index = 0
	velocity = Vector2.ZERO
	clear_attack_target()
	_scripted_movement = true


func end_scripted_movement() -> void:
	_scripted_movement = false
	velocity = Vector2.ZERO


func follow_enemy(enemy: ChickenEnemy) -> void:
	if is_snared():
		_play_snare_blocked_feedback()
		return
	_attack_target = enemy
	_target_cell = Vector2i(-999999, -999999)
	_update_enemy_chase()


func clear_attack_target() -> void:
	_attack_target = null


func is_moving() -> bool:
	return _path_index < _path.size()


func get_remaining_path_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	if not is_moving():
		return points
	points.append(global_position)
	for index in range(_path_index, _path.size()):
		points.append(_path[index])
	return points


func take_damage(amount: int, color_index := COLOR_RED) -> void:
	_apply_damage(amount, color_index, false, Vector2.ZERO)


func take_skill_damage(amount: int, color_index: int, impact_direction: Vector2) -> bool:
	return _apply_damage(amount, color_index, true, impact_direction)


func _apply_damage(amount: int, color_index: int, skill_hit: bool, impact_direction: Vector2) -> bool:
	if health <= 0 or _is_dying or _skill_invulnerable:
		return false
	if color_index == COLOR_YELLOW and _yellow_guard_time_left > 0.0:
		_play_guard_block_feedback()
		return false
	var applied_damage := maxi(1, amount - get_defense_for_color(color_index))
	var blocked_damage := maxi(0, amount - applied_damage)
	health = max(0, health - applied_damage)
	health_bar.value = health
	_update_health_label()
	vitals_changed.emit()
	_show_damage_popup(amount, color_index, blocked_damage, skill_hit, impact_direction)
	if health == 0:
		_begin_death_sequence()
	return true


func heal(amount: int) -> void:
	if health <= 0 or amount <= 0:
		return
	health = min(max_health, health + amount)
	health_bar.value = health
	_update_health_label()
	vitals_changed.emit()


func flash_healed() -> void:
	if not is_instance_valid(fox_sprite):
		return
	fox_sprite.modulate = Color("75ff8a")
	var tween := fox_sprite.create_tween()
	for _pulse in range(3):
		tween.tween_property(fox_sprite, "modulate", Color.WHITE, 0.10)
		tween.tween_property(fox_sprite, "modulate", Color("75ff8a"), 0.10)
	tween.tween_property(fox_sprite, "modulate", Color.WHITE, 0.12)


func show_healing_popup(amount: int) -> void:
	if amount <= 0:
		return
	var popup := Label.new()
	popup.name = "AshaHealPopup"
	popup.text = "+%d" % amount
	popup.position = Vector2(-28, -60)
	popup.size = Vector2(56, 28)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 20)
	popup.add_theme_color_override("font_color", Color("54e36b"))
	popup.add_theme_color_override("font_outline_color", Color("123519"))
	popup.add_theme_constant_override("outline_size", 4)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = 50
	add_child(popup)
	var tween := popup.create_tween().set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 38.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.85).set_delay(0.35)
	tween.chain().tween_callback(popup.queue_free)


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
	vitals_changed.emit()


func absorb_enemy_health(amount: int) -> void:
	add_max_health(amount)
	enemy_health_absorbed.emit(amount)


func add_passive_healing(amount: int) -> void:
	if amount == 0:
		return
	var old_interval := _get_passive_heal_interval()
	passive_healing_amount = maxi(1, passive_healing_amount + amount)
	var progress_left := clampf(_heal_time_left / old_interval, 0.0, 1.0)
	_heal_time_left = _get_passive_heal_interval() * progress_left
	vitals_changed.emit()


func add_max_mana(amount: int) -> void:
	if amount == 0:
		return
	var old_maximum := max_mana
	max_mana = maxi(1, max_mana + amount)
	if max_mana > old_maximum:
		mana = mini(max_mana, mana + max_mana - old_maximum)
	else:
		mana = mini(mana, max_mana)
	_update_mana_display()
	mana_changed.emit()
	vitals_changed.emit()


func add_passive_mana_regeneration(amount: int) -> void:
	if amount == 0:
		return
	var old_interval := _get_passive_mana_regeneration_interval()
	passive_mana_regeneration_amount = maxi(1, passive_mana_regeneration_amount + amount)
	var progress_left := clampf(_mana_regen_time_left / old_interval, 0.0, 1.0)
	_mana_regen_time_left = _get_passive_mana_regeneration_interval() * progress_left
	mana_changed.emit()
	vitals_changed.emit()


func restore_mana(amount: int) -> void:
	if amount <= 0 or mana >= max_mana:
		return
	mana = mini(max_mana, mana + amount)
	_update_mana_display()
	mana_changed.emit()
	vitals_changed.emit()


func unlock_player_skill(skill_id: StringName) -> bool:
	if not SKILL_DATA.has(skill_id) or unlocked_player_skills.has(skill_id):
		return false
	unlocked_player_skills.append(skill_id)
	for index in range(equipped_player_skills.size()):
		if bool(player_skill_slots_unlocked[index]) and equipped_player_skills[index].is_empty():
			equipped_player_skills[index] = skill_id
			break
	_update_mana_display()
	skills_changed.emit()
	mana_changed.emit()
	return true


func unlock_player_skill_slot(index: int) -> bool:
	if index < 0 or index >= player_skill_slots_unlocked.size() or bool(player_skill_slots_unlocked[index]):
		return false
	player_skill_slots_unlocked[index] = true
	skills_changed.emit()
	return true


func unlock_next_player_skill_slots(amount := 1) -> int:
	var unlocked := 0
	for index in range(player_skill_slots_unlocked.size()):
		if unlocked >= maxi(0, amount):
			break
		if unlock_player_skill_slot(index):
			unlocked += 1
	return unlocked


func unlock_inventory_slots(amount := 1) -> int:
	var unlocked := maxi(0, amount)
	for _index in range(unlocked):
		inventory_slots.append({})
	if unlocked > 0:
		inventory_changed.emit()
	return unlocked


func unlock_equipment_slots(amount := 1) -> int:
	var previous := equipment_slots_unlocked
	equipment_slots_unlocked = mini(4, equipment_slots_unlocked + maxi(0, amount))
	var unlocked := equipment_slots_unlocked - previous
	if unlocked > 0:
		equipment_changed.emit()
	return unlocked


func is_equipment_slot_unlocked(index: int) -> bool:
	return index >= 0 and index < equipment_slots_unlocked


func complete_skill_swap_tutorial() -> void:
	if skill_swap_tutorial_seen:
		return
	skill_swap_tutorial_seen = true
	skills_changed.emit()


func equip_player_skill(slot_index: int, skill_id: StringName) -> bool:
	if slot_index < 0 or slot_index >= equipped_player_skills.size() or not bool(player_skill_slots_unlocked[slot_index]) \
		or not unlocked_player_skills.has(skill_id) or is_in_combat():
		return false
	var existing_slot := equipped_player_skills.find(skill_id)
	if existing_slot >= 0 and existing_slot != slot_index:
		var replaced := equipped_player_skills[slot_index]
		equipped_player_skills[existing_slot] = replaced
	equipped_player_skills[slot_index] = skill_id
	skills_changed.emit()
	return true


func swap_player_skill_slots(first: int, second: int) -> bool:
	if first < 0 or second < 0 or first >= 4 or second >= 4 \
		or not bool(player_skill_slots_unlocked[first]) or not bool(player_skill_slots_unlocked[second]) or is_in_combat():
		return false
	var first_skill := equipped_player_skills[first]
	equipped_player_skills[first] = equipped_player_skills[second]
	equipped_player_skills[second] = first_skill
	skills_changed.emit()
	return true


func has_unlocked_player_skill() -> bool:
	return not unlocked_player_skills.is_empty()


func get_player_skill_data(skill_id: StringName) -> Dictionary:
	return SKILL_DATA.get(skill_id, {}) as Dictionary


func get_player_skill_cooldown_ratio(slot_index: int) -> float:
	if slot_index < 0 or slot_index >= equipped_player_skills.size():
		return 0.0
	var skill_id := equipped_player_skills[slot_index]
	var data := get_player_skill_data(skill_id)
	if data.is_empty():
		return 0.0
	return clampf(float(_skill_cooldowns.get(skill_id, 0.0)) / maxf(float(data.get("cooldown", 1.0)), 0.01), 0.0, 1.0)


func cast_player_skill_slot(slot_index: int) -> bool:
	_last_skill_cast_failure = ""
	if slot_index < 0 or slot_index >= equipped_player_skills.size() or not bool(player_skill_slots_unlocked[slot_index]):
		return _fail_player_skill_cast("Locked")
	if _skill_casting:
		return _fail_player_skill_cast("Busy")
	var skill_id := equipped_player_skills[slot_index]
	var data := get_player_skill_data(skill_id)
	if data.is_empty():
		return _fail_player_skill_cast("Empty")
	if float(_skill_cooldowns.get(skill_id, 0.0)) > 0.0:
		return _fail_player_skill_cast("Cooling Down")
	var mana_cost := int(data.get("mana", 0))
	if mana < mana_cost:
		return _fail_player_skill_cast("No Mana")
	var cast_plan := _build_player_skill_cast_plan(skill_id)
	if cast_plan.is_empty():
		if _last_skill_cast_failure.is_empty():
			_last_skill_cast_failure = "No Target"
		return _fail_player_skill_cast(_last_skill_cast_failure)
	if skill_id != SKILL_YELLOW_GUARD and skill_id != SKILL_BULWARK:
		break_snare()
		var skill_target := cast_plan.get("target") as ChickenEnemy
		if is_instance_valid(skill_target):
			skill_target.consume_pending_cascading_sweep_tutorial(skill_id)
	mana -= mana_cost
	_skill_cooldowns[skill_id] = float(data.get("cooldown", 0.0))
	_update_mana_display()
	_play_mana_spend_feedback()
	mana_changed.emit()
	if skill_id == SKILL_YELLOW_GUARD:
		_begin_yellow_guard()
	elif skill_id == SKILL_BULWARK:
		_begin_bulwark()
	else:
		_begin_player_roll(cast_plan)
	return true


func _fail_player_skill_cast(reason: String) -> bool:
	_last_skill_cast_failure = reason
	var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
	if audio:
		audio.play_skill_unavailable()
	return false


func prepare_player_skill_slot_for_tutorial(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= equipped_player_skills.size() or not bool(player_skill_slots_unlocked[slot_index]):
		return false
	var skill_id := equipped_player_skills[slot_index]
	var data := get_player_skill_data(skill_id)
	if data.is_empty():
		return false
	_skill_cooldowns[skill_id] = 0.0
	if mana < 5:
		mana = mini(max_mana, 5)
		_update_mana_display()
		mana_changed.emit()
	var mana_cost := int(data.get("mana", 0))
	return mana >= mana_cost and not _build_player_skill_cast_plan(skill_id).is_empty()


func get_last_skill_cast_failure() -> String:
	return _last_skill_cast_failure


func _build_player_skill_cast_plan(skill_id: StringName) -> Dictionary:
	if skill_id == SKILL_YELLOW_GUARD or skill_id == SKILL_BULWARK:
		return {"guard": true}
	var world := _get_navigation_world()
	var target := _get_player_skill_target(world)
	if world == null or target == null:
		_last_skill_cast_failure = "No Target"
		return {}
	var player_cell := world.world_to_cell(global_position)
	var enemy_cell := world.world_to_cell(target.global_position)
	var relative := player_cell - enemy_cell
	if absi(relative.x) + absi(relative.y) != 1:
		_last_skill_cast_failure = "Move Closer"
		return {}
	var destination_cell := player_cell
	var arc_angle := 0.0
	if skill_id == SKILL_ROLL_CLOCKWISE:
		destination_cell = enemy_cell + Vector2i(-relative.y, relative.x)
		arc_angle = PI * 0.5
		if not world.is_walkable(destination_cell) or world.is_cell_occupied(destination_cell, self):
			destination_cell = enemy_cell + Vector2i(relative.y, -relative.x)
			arc_angle = -PI * 0.5
	elif skill_id == SKILL_ROLL_BACK:
		destination_cell = player_cell + relative * 2
	elif skill_id == SKILL_ROLL_ARC:
		destination_cell = enemy_cell - relative
		arc_angle = PI
	else:
		return {}
	if not world.is_walkable(destination_cell) or world.is_cell_occupied(destination_cell, self):
		_last_skill_cast_failure = "Blocked"
		return {}
	if skill_id == SKILL_ROLL_BACK:
		var middle_cell := player_cell + relative
		if not world.is_walkable(middle_cell) or world.is_cell_occupied(middle_cell, self):
			_last_skill_cast_failure = "Blocked"
			return {}
	return {
		"skill_id": skill_id,
		"target": target,
		"destination": world.cell_to_world(destination_cell),
		"center": world.cell_to_world(enemy_cell),
		"arc_angle": arc_angle,
		"is_arc": not is_zero_approx(arc_angle),
	}


func _get_player_skill_target(world: WorldNavigation) -> ChickenEnemy:
	if world == null:
		return null
	if is_instance_valid(_attack_target) and _attack_target.health > 0 and world.belongs_to_world(_attack_target):
		return _attack_target
	return _get_adjacent_enemy(world)


func _begin_player_roll(plan: Dictionary) -> void:
	var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
	if audio:
		audio.play_player_roll()
	_skill_casting = true
	_skill_invulnerable = true
	if StringName(plan.get("skill_id", &"")) == SKILL_ROLL_CLOCKWISE:
		_quick_roll_damage_time_left = 2.0
		damage_matrix_changed.emit()
		var quick_roll_target := plan.get("target") as ChickenEnemy
		if is_instance_valid(quick_roll_target) and not is_in_dungeon():
			quick_roll_target.delay_player_attacks(2.0)
	_cancel_combat_visual_tweens()
	if _skill_visual_tween and _skill_visual_tween.is_valid():
		_skill_visual_tween.kill()
	stop()
	clear_attack_target()
	_roll_skill_id = plan.get("skill_id", SKILL_ROLL_CLOCKWISE)
	_roll_start = global_position
	_roll_end = plan.get("destination", global_position)
	_roll_center = plan.get("center", global_position)
	_roll_arc_angle = float(plan.get("arc_angle", 0.0))
	_roll_is_arc = bool(plan.get("is_arc", false))
	_roll_start_angle = (_roll_start - _roll_center).angle()
	_roll_rotation_turns = -1.0 if _roll_skill_id == SKILL_ROLL_BACK else 1.5 if _roll_skill_id == SKILL_ROLL_ARC else 1.0
	_roll_afterimage_progress = -1.0
	fox_sprite.modulate = Color.WHITE
	var movement_direction := _roll_start.direction_to(_roll_end)
	var anticipation_scale := Vector2(1.16, 0.80) if _roll_skill_id == SKILL_ROLL_BACK else Vector2(0.86, 1.16) if _roll_skill_id == SKILL_ROLL_ARC else Vector2(1.12, 0.84)
	var anticipation_rotation := clampf(movement_direction.x, -1.0, 1.0) * (-0.12 if _roll_skill_id == SKILL_ROLL_BACK else 0.09)
	_skill_visual_tween = create_tween().set_parallel(true)
	_skill_visual_tween.tween_property(fox_sprite, "position", -movement_direction * 6.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_skill_visual_tween.tween_property(fox_sprite, "scale", anticipation_scale, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_skill_visual_tween.tween_property(fox_sprite, "rotation", anticipation_rotation, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_skill_visual_tween.finished.connect(_start_player_roll)


func _start_player_roll() -> void:
	if not _skill_casting:
		return
	_roll_sprite_start_rotation = fox_sprite.rotation
	fox_sprite.position = Vector2.ZERO
	fox_sprite.scale = Vector2.ONE
	_create_roll_trail()
	_add_roll_afterimage()
	var duration := 0.34 if _roll_skill_id == SKILL_ROLL_ARC else 0.28 if _roll_skill_id == SKILL_ROLL_BACK else 0.24
	_skill_visual_tween = create_tween()
	_skill_visual_tween.tween_method(_update_player_roll, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_skill_visual_tween.tween_callback(_finish_player_roll)
	_trigger_asha_roll()


func _update_player_roll(progress: float) -> void:
	if _roll_is_arc:
		# Interpolating the radius keeps the path curved around the enemy even if
		# combat left either actor a few pixels away from its tile center, while
		# still meeting the destination tile without a visible final snap.
		var radius := lerpf(_roll_start.distance_to(_roll_center), _roll_end.distance_to(_roll_center), progress)
		global_position = _roll_center + Vector2.RIGHT.rotated(_roll_start_angle + _roll_arc_angle * progress) * radius
	else:
		global_position = _roll_start.lerp(_roll_end, progress)
	fox_sprite.rotation = _roll_sprite_start_rotation + TAU * _roll_rotation_turns * progress
	if is_instance_valid(_roll_trail):
		_roll_trail.add_point(_roll_trail.get_parent().to_local(global_position))
		while _roll_trail.get_point_count() > 24:
			_roll_trail.remove_point(0)
	if progress - _roll_afterimage_progress >= 0.16:
		_roll_afterimage_progress = progress
		_add_roll_afterimage()


func _finish_player_roll() -> void:
	global_position = _roll_end
	fox_sprite.rotation = 0.0
	fox_sprite.position = Vector2.ZERO
	fox_sprite.scale = Vector2(1.26, 0.74)
	fox_sprite.modulate = _get_roll_color().lightened(0.28)
	_skill_casting = false
	_skill_invulnerable = false
	velocity = Vector2.ZERO
	_skill_visual_tween = create_tween().set_parallel(true)
	_skill_visual_tween.tween_property(fox_sprite, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_skill_visual_tween.tween_property(fox_sprite, "modulate", Color.WHITE, 0.12)
	_fade_roll_trail()
	_play_skill_camera_nudge(_roll_start.direction_to(_roll_end), 3.0)


func _create_roll_trail() -> void:
	if is_instance_valid(_roll_trail):
		_roll_trail.queue_free()
	_roll_trail = Line2D.new()
	_roll_trail.name = "SkillRollTrail"
	_roll_trail.width = 7.0 if _roll_skill_id == SKILL_ROLL_ARC else 5.0 if _roll_skill_id == SKILL_ROLL_BACK else 4.0
	_roll_trail.default_color = _get_roll_color()
	_roll_trail.default_color.a = 0.62
	_roll_trail.antialiased = true
	_roll_trail.z_index = z_index - 2
	get_parent().add_child(_roll_trail)
	_roll_trail.add_point(_roll_trail.get_parent().to_local(global_position))


func _fade_roll_trail() -> void:
	if not is_instance_valid(_roll_trail):
		return
	var trail := _roll_trail
	_roll_trail = null
	var tween := trail.create_tween().set_parallel(true)
	tween.tween_property(trail, "modulate:a", 0.0, 0.18)
	tween.tween_property(trail, "width", 0.5, 0.18)
	tween.chain().tween_callback(trail.queue_free)


func _add_roll_afterimage() -> void:
	if not is_instance_valid(fox_sprite) or get_parent() == null:
		return
	var afterimage := Sprite2D.new()
	afterimage.name = "SkillRollAfterimage"
	afterimage.texture = fox_sprite.texture
	afterimage.texture_filter = fox_sprite.texture_filter
	afterimage.flip_h = fox_sprite.flip_h
	afterimage.add_to_group("skill_roll_afterimages")
	get_parent().add_child(afterimage)
	afterimage.global_position = global_position + fox_sprite.position
	afterimage.global_rotation = fox_sprite.global_rotation
	afterimage.scale = fox_sprite.scale
	afterimage.modulate = _get_roll_color()
	afterimage.modulate.a = 0.38
	afterimage.z_index = z_index - 1
	var tween := afterimage.create_tween().set_parallel(true)
	tween.tween_property(afterimage, "modulate:a", 0.0, 0.20)
	tween.tween_property(afterimage, "scale", afterimage.scale * 0.78, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(afterimage.queue_free)


func _get_roll_color() -> Color:
	if _roll_skill_id == SKILL_ROLL_BACK:
		return Color("b58cff")
	if _roll_skill_id == SKILL_ROLL_ARC:
		return Color("ffd65a")
	return Color("65e6ff")


func _trigger_asha_roll() -> void:
	for node in get_tree().get_nodes_in_group("story_characters"):
		if node is FoxAsha and (node as FoxAsha).is_recruited():
			(node as FoxAsha).play_roll_animation(0.2)
			return


func _begin_yellow_guard() -> void:
	_yellow_guard_time_left = 1.0
	_skill_casting = true
	_cancel_combat_visual_tweens()
	if _skill_visual_tween and _skill_visual_tween.is_valid():
		_skill_visual_tween.kill()
	if is_instance_valid(_yellow_guard_ring):
		_yellow_guard_ring.queue_free()
	_yellow_guard_ring = _create_combat_ring(Color("fbc02d"))
	_yellow_guard_ring.name = "YellowSkillGuard"
	_yellow_guard_ring.width = 4.0
	_yellow_guard_ring.position = Vector2(0, 10)
	_yellow_guard_ring.visible = true
	_yellow_guard_ring.scale = Vector2(0.28, 0.28)
	add_child(_yellow_guard_ring)
	_yellow_guard_ring.modulate.a = 0.0
	fox_sprite.scale = Vector2(1.14, 0.82)
	fox_sprite.modulate = Color("ffe780")
	_skill_visual_tween = create_tween().set_parallel(true)
	_skill_visual_tween.tween_property(_yellow_guard_ring, "scale", Vector2(1.16, 1.16), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_skill_visual_tween.tween_property(_yellow_guard_ring, "modulate:a", 1.0, 0.08)
	_skill_visual_tween.tween_property(fox_sprite, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_skill_visual_tween.tween_property(fox_sprite, "modulate", Color.WHITE, 0.14)
	_skill_visual_tween.finished.connect(_finish_guard_cast)
	var fade := _yellow_guard_ring.create_tween()
	fade.tween_interval(0.78)
	fade.tween_property(_yellow_guard_ring, "modulate:a", 0.0, 0.20)


func _begin_bulwark() -> void:
	_bulwark_time_left = 3.0
	_skill_casting = true
	_cancel_combat_visual_tweens()
	if _skill_visual_tween and _skill_visual_tween.is_valid():
		_skill_visual_tween.kill()
	if is_instance_valid(_bulwark_ring):
		_bulwark_ring.queue_free()
	_bulwark_ring = _create_combat_ring(Color("fbc02d"))
	_bulwark_ring.name = "BulwarkArmor"
	_bulwark_ring.width = 6.0
	_bulwark_ring.position = Vector2(0, 10)
	_bulwark_ring.visible = true
	_bulwark_ring.scale = Vector2(0.35, 0.35)
	add_child(_bulwark_ring)
	fox_sprite.modulate = Color("ffe780")
	_skill_visual_tween = create_tween().set_parallel(true)
	_skill_visual_tween.tween_property(_bulwark_ring, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_skill_visual_tween.tween_property(fox_sprite, "modulate", Color.WHITE, 0.16)
	_skill_visual_tween.finished.connect(_finish_guard_cast)
	damage_matrix_changed.emit()


func _finish_guard_cast() -> void:
	if is_instance_valid(_yellow_guard_ring):
		var settle := _yellow_guard_ring.create_tween()
		settle.tween_property(_yellow_guard_ring, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_skill_casting = false


func _play_guard_block_feedback() -> void:
	var flash := _create_combat_ring(Color.WHITE)
	flash.name = "YellowGuardBlockFlash"
	flash.width = 6.0
	flash.position = Vector2(0, 10)
	flash.scale = Vector2(0.92, 0.92)
	flash.modulate = Color("fff4a8")
	flash.visible = true
	flash.z_index = 3
	add_child(flash)
	var tween := flash.create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(1.45, 1.45), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate:a", 0.0, 0.16)
	tween.chain().tween_callback(flash.queue_free)
	fox_sprite.modulate = Color("fff1a6")
	var sprite_flash := fox_sprite.create_tween()
	sprite_flash.tween_property(fox_sprite, "modulate", Color.WHITE, 0.14)
	_play_skill_camera_nudge(Vector2.UP, 1.8)


func _play_mana_spend_feedback() -> void:
	if not is_instance_valid(mana_bar):
		return
	mana_bar.pivot_offset = mana_bar.size * 0.5
	mana_bar.modulate = Color("7eeeff")
	mana_bar.scale = Vector2(1.08, 0.82)
	var tween := mana_bar.create_tween().set_parallel(true)
	tween.tween_property(mana_bar, "modulate", Color.WHITE, 0.16)
	tween.tween_property(mana_bar, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_skill_camera_nudge(direction: Vector2, strength: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var origin := camera.position
	var nudge_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.UP
	var tween := camera.create_tween()
	tween.tween_property(camera, "position", origin + nudge_direction * strength, 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "position", origin - nudge_direction * strength * 0.35, 0.05)
	tween.tween_property(camera, "position", origin, 0.065).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _cancel_combat_visual_tweens() -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	_attack_visual_time_left = 0.0
	_hit_visual_time_left = 0.0


func add_attack_damage(amount: int) -> void:
	add_color_damage(COLOR_RED, amount)


func add_color_damage(color_index: int, amount: int) -> void:
	if color_index < 0 or color_index >= damage_by_color.size():
		return
	damage_by_color[color_index][current_weapon_index] = maxi(1, damage_by_color[color_index][current_weapon_index] + amount)
	attack_damage = get_damage_for_color(COLOR_RED)
	damage_matrix_changed.emit()


func add_color_defense(color_index: int, amount: int) -> void:
	if color_index < 0 or color_index >= defense_by_color.size():
		return
	defense_by_color[color_index] = maxi(0, defense_by_color[color_index] + amount)
	damage_matrix_changed.emit()


func collect_item(item_id: String, grade := 0) -> bool:
	if not ItemPickup.ITEM_DATA.has(item_id):
		return false
	var equipment_storage := "weapon" if ItemPickup.is_weapon(item_id) else "armor" if ItemPickup.is_armor(item_id) else ""
	if not equipment_storage.is_empty():
		var equipment_slots := _get_slots(equipment_storage)
		if equipment_slots[0].is_empty():
			equipment_slots[0] = ItemPickup.make_item(item_id, grade)
			if equipment_storage == "weapon":
				weapon_ever_equipped[0] = true
			else:
				armor_ever_equipped = true
			attack_damage = get_damage_for_color(COLOR_RED)
			equipment_changed.emit()
			damage_matrix_changed.emit()
			_check_duplicate_equipment_tutorial()
			return true
	for index in range(inventory_slots.size()):
		if inventory_slots[index].is_empty():
			inventory_slots[index] = ItemPickup.make_item(item_id, grade)
			inventory_changed.emit()
			_check_duplicate_equipment_tutorial()
			return true
	return false


func can_collect_item(item_id: String) -> bool:
	if not ItemPickup.ITEM_DATA.has(item_id):
		return false
	if ItemPickup.is_weapon(item_id) and equipped_weapons[0].is_empty():
		return true
	if ItemPickup.is_armor(item_id) and equipped_armor[0].is_empty():
		return true
	for item in inventory_slots:
		if item.is_empty():
			return true
	return false


func reserve_item_collection(item_id := "") -> bool:
	var empty_slots := 0
	for item in inventory_slots:
		if item.is_empty():
			empty_slots += 1
	if ItemPickup.is_weapon(item_id) and equipped_weapons[0].is_empty():
		empty_slots += 1
	elif ItemPickup.is_armor(item_id) and equipped_armor[0].is_empty():
		empty_slots += 1
	if empty_slots <= _pending_item_collections:
		return false
	_pending_item_collections += 1
	return true


func complete_item_collection(item_id: String, grade: int) -> void:
	_pending_item_collections = max(0, _pending_item_collections - 1)
	collect_item(item_id, grade)


func get_item_collection_target_screen_position(item_id: String) -> Vector2:
	var preferred_storage := "weapon" if ItemPickup.is_weapon(item_id) else "armor" if ItemPickup.is_armor(item_id) else "inventory"
	var preferred_index := 0
	if preferred_storage != "inventory" and not _get_slots(preferred_storage)[0].is_empty():
		preferred_storage = "inventory"
		for index in range(inventory_slots.size()):
			if inventory_slots[index].is_empty():
				preferred_index = index
				break
	for node in get_tree().get_nodes_in_group("item_slots"):
		if node is ItemSlot and node.storage == preferred_storage and node.slot_index == preferred_index:
			return (node as ItemSlot).get_global_rect().get_center()
	return get_viewport_rect().size - Vector2(42, 42)


func set_respawn_position(new_position: Vector2) -> void:
	_spawn_position = new_position


func reset_to_beginning() -> void:
	stop()
	clear_attack_target()
	global_position = _beginning_position
	_spawn_position = _beginning_position


func get_weapon_cooldown_ratio(weapon_index: int) -> float:
	if weapon_index < 0 or weapon_index >= _weapon_cooldowns.size() or attack_cooldown <= 0.0:
		return 0.0
	return clampf(_weapon_cooldowns[weapon_index] / attack_cooldown, 0.0, 1.0)


func get_slot_item(storage: String, index: int) -> Dictionary:
	var slots := _get_slots(storage)
	if index < 0 or index >= slots.size():
		return {}
	return slots[index].duplicate()


func has_inventory_item(item_id: String) -> bool:
	for item in inventory_slots:
		if str(item.get("item_id", "")) == item_id:
			return true
	return false


func remove_quest_item(item_id: String) -> bool:
	for index in range(inventory_slots.size()):
		if str(inventory_slots[index].get("item_id", "")) == item_id:
			inventory_slots[index] = {}
			inventory_changed.emit()
			return true
	return false


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
	if ItemPickup.is_protected(str(source_item.get("item_id", ""))) and target_storage != "inventory":
		return false
	if not target_item.is_empty() and ItemPickup.is_protected(str(target_item.get("item_id", ""))) and source_storage != "inventory":
		return false
	if target_storage == "trash":
		target_slots[target_index] = source_item
		source_slots[source_index] = {}
		inventory_changed.emit()
		equipment_changed.emit()
		damage_matrix_changed.emit()
		return true
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
	if target_storage == "armor" and not target_slots[target_index].is_empty():
		armor_ever_equipped = true
	if source_storage == "weapon" and not source_slots[source_index].is_empty():
		weapon_ever_equipped[source_index] = true
	if source_storage == "armor" and not source_slots[source_index].is_empty():
		armor_ever_equipped = true
	attack_damage = get_damage_for_color(COLOR_RED)
	inventory_changed.emit()
	equipment_changed.emit()
	damage_matrix_changed.emit()
	if not merged_item.is_empty():
		merge_count += 1
		merge_completed.emit(merged_item, target_storage, target_index)
	return true


func auto_merge_inventory() -> int:
	var merge_count := 0
	while true:
		var pair := get_next_auto_merge_pair()
		if pair.is_empty() or not merge_auto_pair(pair):
			break
		merge_count += 1
	return merge_count


func has_auto_mergeable_inventory_pair() -> bool:
	return not get_next_auto_merge_pair().is_empty()


func get_next_auto_merge_pair() -> Dictionary:
	# Equipped locations come first so merging an equipped item with a matching
	# inventory item keeps the upgraded result equipped.
	var locations: Array[Dictionary] = []
	for storage in ["weapon", "armor", "inventory"]:
		var slots := _get_slots(storage)
		for index in range(slots.size()):
			if not slots[index].is_empty():
				locations.append({"storage": storage, "index": index, "item": slots[index]})
	for target_location_index in range(locations.size()):
		var target := locations[target_location_index]
		for source_location_index in range(target_location_index + 1, locations.size()):
			var source := locations[source_location_index]
			if can_merge(source["item"], target["item"]):
				return {
					"source_storage": source["storage"],
					"source_index": source["index"],
					"target_storage": target["storage"],
					"target_index": target["index"],
				}
	return {}


func merge_auto_pair(pair: Dictionary) -> bool:
	if not pair.has("source_index") or not pair.has("target_index"):
		return false
	return move_or_merge(
		str(pair.get("source_storage", "inventory")), int(pair["source_index"]),
		str(pair.get("target_storage", "inventory")), int(pair["target_index"])
	)


func merge_inventory_pair(source_index: int, target_index: int) -> bool:
	return move_or_merge("inventory", source_index, "inventory", target_index)


func can_merge(first: Dictionary, second: Dictionary) -> bool:
	return not first.is_empty() and not second.is_empty() \
		and ItemPickup.is_equipment(str(first.get("item_id", ""))) \
		and str(first.get("item_id", "")) == str(second.get("item_id", "")) \
		and ItemPickup.get_item_grade(first) == ItemPickup.get_item_grade(second) \
		and ItemPickup.get_item_grade(first) < ItemPickup.GRADES.size() - 1


func consume_inventory_item(index: int) -> bool:
	if index < 0 or index >= inventory_slots.size() or inventory_slots[index].is_empty():
		return false
	var item := inventory_slots[index]
	var healing := ItemPickup.get_healing_amount(item)
	if healing <= 0 or health >= max_health:
		return false
	inventory_slots[index] = {}
	heal(max_health if ItemPickup.is_full_heal(item) else healing)
	inventory_changed.emit()
	var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
	if audio:
		audio.play_eating()
	return true


func unlock_auto_fight() -> void:
	if auto_fight_unlocked:
		return
	auto_fight_unlocked = true
	auto_fight_changed.emit()


func set_auto_fight_enabled(enabled: bool) -> void:
	auto_fight_enabled = enabled and auto_fight_unlocked
	auto_fight_changed.emit()


func increase_auto_fight_range(amount := 1) -> void:
	auto_fight_range_bonus = maxi(0, auto_fight_range_bonus + amount)
	_create_auto_fight_range()
	auto_fight_changed.emit()


func set_auto_fight_range_visible(value: bool) -> void:
	if is_instance_valid(_auto_fight_range_fill):
		_auto_fight_range_fill.visible = value
	if is_instance_valid(_auto_fight_range_border):
		_auto_fight_range_border.visible = value


func _create_auto_fight_range() -> void:
	if is_instance_valid(_auto_fight_range_fill):
		_auto_fight_range_fill.queue_free()
	if is_instance_valid(_auto_fight_range_border):
		_auto_fight_range_border.queue_free()
	var half_extent := (2.5 + float(auto_fight_range_bonus)) * 64.0
	var points := PackedVector2Array([
		Vector2(-half_extent, -half_extent), Vector2(half_extent, -half_extent),
		Vector2(half_extent, half_extent), Vector2(-half_extent, half_extent),
	])
	_auto_fight_range_fill = Polygon2D.new()
	_auto_fight_range_fill.polygon = points
	_auto_fight_range_fill.color = Color(1.0, 0.78, 0.12, 0.09)
	_auto_fight_range_fill.z_index = -2
	_auto_fight_range_fill.visible = false
	add_child(_auto_fight_range_fill)
	_auto_fight_range_border = Line2D.new()
	_auto_fight_range_border.points = PackedVector2Array([points[0], points[1], points[2], points[3], points[0]])
	_auto_fight_range_border.default_color = Color(1.0, 0.78, 0.12, 0.38)
	_auto_fight_range_border.width = 2.0
	_auto_fight_range_border.z_index = -1
	_auto_fight_range_border.visible = false
	add_child(_auto_fight_range_border)


func get_duplicate_inventory_indices() -> Array[int]:
	var indices: Array[int] = []
	for location in get_tutorial_merge_locations():
		if str(location["storage"]) == "inventory":
			indices.append(int(location["index"]))
	return indices


func get_tutorial_merge_locations() -> Array[Dictionary]:
	var locations: Array[Dictionary] = []
	for storage in ["weapon", "armor", "inventory"]:
		var slots := _get_slots(storage)
		for index in range(slots.size()):
			if ItemPickup.is_equipment(str(slots[index].get("item_id", ""))):
				locations.append({"storage": storage, "index": index, "item": slots[index]})
	for first_index in range(locations.size()):
		for second_index in range(first_index + 1, locations.size()):
			if can_merge(locations[first_index]["item"], locations[second_index]["item"]):
				return [locations[first_index], locations[second_index]]
	return []


func is_tutorial_merge_slot(storage: String, index: int) -> bool:
	if not duplicate_equipment_tutorial_seen:
		return false
	for location in get_tutorial_merge_locations():
		if str(location["storage"]) == storage and int(location["index"]) == index:
			return true
	return false


func _check_duplicate_equipment_tutorial() -> void:
	if duplicate_equipment_tutorial_seen or get_tutorial_merge_locations().is_empty():
		return
	duplicate_equipment_tutorial_seen = true
	duplicate_equipment_found.emit()


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
	var equipment_bonus := ItemPickup.get_damage_bonus(equipped_weapons[weapon_index]) \
		if color_index == COLOR_YELLOW and not is_in_dungeon() else 0
	var quick_roll_bonus := 2 if color_index == COLOR_YELLOW and _quick_roll_damage_time_left > 0.0 else 0
	return damage_by_color[color_index][weapon_index] + equipment_bonus + quick_roll_bonus


func get_total_block() -> int:
	return get_defense_for_color(COLOR_RED)


func get_base_defense_for_color(color_index: int) -> int:
	if color_index < 0 or color_index >= defense_by_color.size():
		return 0
	return defense_by_color[color_index]


func get_defense_for_color(color_index: int) -> int:
	var total := get_base_defense_for_color(color_index)
	if color_index == COLOR_YELLOW and _bulwark_time_left > 0.0:
		total += 20
	if color_index == COLOR_YELLOW and not is_in_dungeon():
		for item in equipped_armor:
			total += ItemPickup.get_block_amount(item)
	return total


func is_in_dungeon() -> bool:
	return _get_navigation_world() is DungeonLevel


func is_in_combat() -> bool:
	var world := _get_navigation_world()
	if world == null:
		return false
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is ChickenEnemy and is_instance_valid(node) and world.belongs_to_world(node) \
				and node.health > 0 and node.is_player_combat_sequence_active():
			return true
	return false


func set_snared_by(source: Object, enabled: bool) -> void:
	if source == null:
		return
	var source_id := source.get_instance_id()
	if enabled:
		_snare_sources[source_id] = true
		_path.clear()
		_path_index = 0
		velocity = Vector2.ZERO
		_show_snare_visuals()
	else:
		_snare_sources.erase(source_id)
		if _snare_sources.is_empty():
			_hide_snare_visuals()


func is_snared() -> bool:
	return not _snare_sources.is_empty()


func break_snare() -> void:
	if not is_snared():
		return
	_snare_sources.clear()
	_hide_snare_visuals()


func _show_snare_visuals() -> void:
	if not is_instance_valid(_snare_ring):
		_snare_ring = _create_combat_ring(Color.WHITE)
		_snare_ring.name = "SnareRing"
		_snare_ring.width = 3.0
		_snare_ring.position = Vector2.ZERO
		_snare_ring.clear_points()
		for index in range(33):
			var angle := TAU * float(index) / 32.0
			_snare_ring.add_point(Vector2(cos(angle), sin(angle)) * 31.0)
		_snare_ring.visible = true
		_snare_ring.z_index = 3
		add_child(_snare_ring)
	if not is_instance_valid(_snare_label):
		_snare_label = Label.new()
		_snare_label.name = "SnaredLabel"
		_snare_label.text = "Snared"
		_snare_label.position = Vector2(-42, -58)
		_snare_label.size = Vector2(84, 22)
		_snare_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_snare_label.add_theme_color_override("font_color", Color.WHITE)
		_snare_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_snare_label.add_theme_constant_override("outline_size", 3)
		_snare_label.z_index = 20
		add_child(_snare_label)
	_snare_ring.show()
	_snare_label.show()


func _hide_snare_visuals() -> void:
	if is_instance_valid(_snare_ring):
		_snare_ring.hide()
	if is_instance_valid(_snare_label):
		_snare_label.hide()


func _play_snare_blocked_feedback() -> void:
	if _snare_shake_tween and _snare_shake_tween.is_valid():
		return
	var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
	if audio:
		audio.play_skill_unavailable()
	var origin := fox_sprite.position
	_snare_shake_tween = create_tween()
	for offset in [Vector2(-4, 0), Vector2(4, 0), Vector2(-3, 0)]:
		_snare_shake_tween.tween_property(fox_sprite, "position", origin + offset, 0.05)
	_snare_shake_tween.tween_property(fox_sprite, "position", origin, 0.05)
	_snare_shake_tween.finished.connect(func() -> void: _snare_shake_tween = null)


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
	var unlocked_skill_ids: Array[String] = []
	for skill_id in unlocked_player_skills:
		unlocked_skill_ids.append(str(skill_id))
	var equipped_skill_ids: Array[String] = []
	for skill_id in equipped_player_skills:
		equipped_skill_ids.append(str(skill_id))
	var skill_slot_mask := 0
	for index in range(player_skill_slots_unlocked.size()):
		if bool(player_skill_slots_unlocked[index]):
			skill_slot_mask |= 1 << index
	var skill_cooldown_milliseconds: Array[int] = []
	for skill_id in PLAYER_SKILL_IDS:
		skill_cooldown_milliseconds.append(maxi(0, roundi(float(_skill_cooldowns.get(skill_id, 0.0)) * 1000.0)))
	return [
		roundi(global_position.x), roundi(global_position.y), health, max_health,
		passive_healing_amount, current_weapon_index, flattened_damage,
		_pack_items(inventory_slots), _pack_items(equipped_weapons), _pack_items(equipped_armor),
		ever_equipped_mask, cooldown_milliseconds, maxi(0, roundi(_heal_time_left * 1000.0)),
		maxi(1, roundi(_get_healing_speed_multiplier())),
		maxi(0, defense),
		defense_by_color.duplicate(), armor_ever_equipped,
		roundi(_spawn_position.x), roundi(_spawn_position.y),
		merge_count, duplicate_equipment_tutorial_seen, auto_fight_unlocked, auto_fight_enabled,
		_pack_items(trash_slots),
		mana, max_mana, passive_mana_regeneration_amount, unlocked_skill_ids, equipped_skill_ids,
		skill_slot_mask, skill_cooldown_milliseconds, maxi(0, roundi(_mana_regen_time_left * 1000.0)),
		enemy_skill_move_tutorial_seen, cascading_sweep_skill_tutorial_seen,
		inventory_slots.size(), equipment_slots_unlocked, skill_swap_tutorial_seen,
		snare_without_quick_roll_tutorial_seen,
		auto_fight_range_bonus,
	]


func load_save_data(data: Array, offline_seconds: int) -> bool:
	if data.size() < 14:
		return false
	stop()
	clear_attack_target()
	global_position = Vector2(float(data[0]), float(data[1]))
	max_health = maxi(1, int(data[3]))
	passive_healing_amount = maxi(1, int(data[4]))
	var legacy_defense := maxi(0, int(data[14])) if data.size() > 14 else 0
	defense_by_color = []
	var saved_color_defense := data[15] as Array if data.size() > 15 and data[15] is Array else []
	for color_index in range(3):
		defense_by_color.append(maxi(0, int(saved_color_defense[color_index])) if color_index < saved_color_defense.size() else legacy_defense)
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

	var saved_inventory: Array = data[7] as Array
	var inventory_slot_count := maxi(4, int(data[34])) if data.size() > 34 else maxi(4, saved_inventory.size())
	inventory_slots = _unpack_items(saved_inventory, inventory_slot_count)
	equipped_weapons = _unpack_items(data[8] as Array, 4)
	equipped_armor = _unpack_items(data[9] as Array, 4)
	equipment_slots_unlocked = clampi(int(data[35]), 1, 4) if data.size() > 35 else 1
	skill_swap_tutorial_seen = bool(data[36]) if data.size() > 36 else false
	snare_without_quick_roll_tutorial_seen = bool(data[37]) if data.size() > 37 else false
	auto_fight_range_bonus = maxi(0, int(data[38])) if data.size() > 38 else 0
	_bulwark_time_left = 0.0
	_quick_roll_damage_time_left = 0.0
	armor_ever_equipped = bool(data[16]) if data.size() > 16 else has_equipped_armor()
	if data.size() > 18:
		_spawn_position = Vector2(float(data[17]), float(data[18]))
	merge_count = maxi(0, int(data[19])) if data.size() > 19 else 0
	duplicate_equipment_tutorial_seen = bool(data[20]) if data.size() > 20 else false
	auto_fight_unlocked = bool(data[21]) if data.size() > 21 else false
	auto_fight_enabled = bool(data[22]) if data.size() > 22 else false
	var saved_trash: Array = data[23] as Array if data.size() > 23 and data[23] is Array else []
	trash_slots = _unpack_items(saved_trash, 1)
	max_mana = maxi(1, int(data[25])) if data.size() > 25 else 10
	mana = clampi(int(data[24]), 0, max_mana) if data.size() > 24 else max_mana
	passive_mana_regeneration_amount = maxi(1, int(data[26])) if data.size() > 26 else 1
	unlocked_player_skills.clear()
	var saved_unlocked_skills: Array = data[27] as Array if data.size() > 27 and data[27] is Array else []
	for raw_skill_id in saved_unlocked_skills:
		var skill_id := StringName(str(raw_skill_id))
		if SKILL_DATA.has(skill_id) and not unlocked_player_skills.has(skill_id):
			unlocked_player_skills.append(skill_id)
	equipped_player_skills = [&"", &"", &"", &""]
	var saved_equipped_skills: Array = data[28] as Array if data.size() > 28 and data[28] is Array else []
	for index in range(mini(4, saved_equipped_skills.size())):
		var skill_id := StringName(str(saved_equipped_skills[index]))
		if unlocked_player_skills.has(skill_id):
			equipped_player_skills[index] = skill_id
	var skill_slot_mask := int(data[29]) if data.size() > 29 else 1
	player_skill_slots_unlocked.clear()
	for index in range(4):
		player_skill_slots_unlocked.append((skill_slot_mask & (1 << index)) != 0)
	_skill_cooldowns.clear()
	var saved_skill_cooldowns: Array = data[30] as Array if data.size() > 30 and data[30] is Array else []
	for index in range(PLAYER_SKILL_IDS.size()):
		var saved_milliseconds := int(saved_skill_cooldowns[index]) if index < saved_skill_cooldowns.size() else 0
		_skill_cooldowns[PLAYER_SKILL_IDS[index]] = maxf(0.0, float(saved_milliseconds - offline_seconds * 1000) / 1000.0)
	var saved_mana_regeneration := int(data[31]) if data.size() > 31 else 3000
	enemy_skill_move_tutorial_seen = bool(data[32]) if data.size() > 32 else false
	cascading_sweep_skill_tutorial_seen = bool(data[33]) if data.size() > 33 else false
	var mana_regeneration_milliseconds := saved_mana_regeneration - offline_seconds * 1000 * maxi(1, int(data[13]))
	var mana_regeneration_interval_milliseconds := maxf(1.0, 3000.0 / float(maxi(1, passive_mana_regeneration_amount)))
	if mana_regeneration_milliseconds <= 0:
		var mana_ticks := 1 + floori(float(-mana_regeneration_milliseconds) / mana_regeneration_interval_milliseconds)
		mana = mini(max_mana, mana + mana_ticks)
		mana_regeneration_milliseconds += roundi(float(mana_ticks) * mana_regeneration_interval_milliseconds)
	_mana_regen_time_left = maxf(0.001, float(mana_regeneration_milliseconds) / 1000.0)
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
	_update_mana_display()
	damage_matrix_changed.emit()
	equipment_changed.emit()
	vitals_changed.emit()
	inventory_changed.emit()
	equipment_changed.emit()
	damage_matrix_changed.emit()
	_create_auto_fight_range()
	auto_fight_changed.emit()
	skills_changed.emit()
	mana_changed.emit()
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
		"trash":
			return trash_slots
	return []


func _storage_accepts(storage: String, item: Dictionary) -> bool:
	var item_id := str(item.get("item_id", ""))
	return storage == "inventory" \
		or storage == "trash" and not ItemPickup.is_protected(item_id) \
		or storage == "weapon" and ItemPickup.is_weapon(item_id) \
		or storage == "armor" and ItemPickup.is_armor(item_id)


func _physics_process(delta: float) -> void:
	if _is_dying:
		velocity = Vector2.ZERO
		return
	if _scripted_movement:
		velocity = Vector2.ZERO
		return
	var world := _get_navigation_world()
	if world and world.gameplay_paused:
		velocity = Vector2.ZERO
		_update_walk_animation(0.0)
		return
	if _dialogue_is_open():
		velocity = Vector2.ZERO
		_update_walk_animation(0.0)
		return
	for index in range(_weapon_cooldowns.size()):
		_weapon_cooldowns[index] = maxf(0.0, _weapon_cooldowns[index] - delta)
	for skill_id in _skill_cooldowns.keys():
		_skill_cooldowns[skill_id] = maxf(0.0, float(_skill_cooldowns[skill_id]) - delta)
	if _yellow_guard_time_left > 0.0:
		_yellow_guard_time_left = maxf(0.0, _yellow_guard_time_left - delta)
		if _yellow_guard_time_left <= 0.0 and is_instance_valid(_yellow_guard_ring):
			_yellow_guard_ring.queue_free()
			_yellow_guard_ring = null
	if _bulwark_time_left > 0.0:
		_bulwark_time_left = maxf(0.0, _bulwark_time_left - delta)
		if _bulwark_time_left <= 0.0:
			if is_instance_valid(_bulwark_ring):
				_bulwark_ring.queue_free()
			_bulwark_ring = null
			damage_matrix_changed.emit()
	if _quick_roll_damage_time_left > 0.0:
		_quick_roll_damage_time_left = maxf(0.0, _quick_roll_damage_time_left - delta)
		if _quick_roll_damage_time_left <= 0.0:
			damage_matrix_changed.emit()
	_attack_visual_time_left = maxf(0.0, _attack_visual_time_left - delta)
	_hit_visual_time_left = maxf(0.0, _hit_visual_time_left - delta)
	if world is DungeonLevel and (world as DungeonLevel).is_current_room_clear():
		if health < max_health:
			_heal_time_left -= delta
			while _heal_time_left <= 0.0 and health < max_health:
				heal(maxi(1, ceili(float(max_health) * 0.2)))
				_heal_time_left += 0.10
		else:
			_heal_time_left = 0.10
		if mana < max_mana:
			_mana_regen_time_left -= delta
			while _mana_regen_time_left <= 0.0 and mana < max_mana:
				restore_mana(maxi(1, ceili(float(max_mana) * 0.2)))
				_mana_regen_time_left += 0.10
		else:
			_mana_regen_time_left = 0.10
	elif not world is DungeonLevel:
		_regenerate_vitals_normally(delta)
	_update_campfire_healing_visual()
	if _skill_casting:
		velocity = Vector2.ZERO
		return
	if is_snared():
		velocity = Vector2.ZERO
		_path.clear()
		_path_index = 0
		_update_walk_animation(0.0)
		return
	_update_enemy_chase()
	_move_along_path(delta)
	_collect_pickups_on_current_tile()
	_attack_nearby_enemy()
	_update_walk_animation(delta)
	_update_combat_ring()
	_face_combat_enemy()


func _dialogue_is_open() -> bool:
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui") as DialogueBox
	return dialogue != null and dialogue.is_open()


func _move_along_path(delta: float) -> void:
	_advance_past_reached_points()
	if not is_moving():
		velocity = Vector2.ZERO
		var world := _get_navigation_world()
		if world == null or _get_adjacent_enemy(world) == null:
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
	var world := _get_navigation_world()
	if world and not world.can_enter_position(self, global_position + velocity * delta):
		velocity = Vector2.ZERO
		var detour := world.find_path(global_position, _destination, self)
		if detour.size() > 1:
			_path = detour
			_path_index = 1
		return
	move_and_slide()


func _attack_nearby_enemy() -> void:
	if _dialogue_is_open():
		return
	var world := _get_navigation_world()
	if world == null:
		return
	var target := _get_adjacent_enemy(world)
	var automatic := false
	if target:
		if target != _combat_alignment_enemy:
			_combat_alignment_enemy = target
			_combat_entry_aligned = false
		_combat_entry_aligned = world.center_stationary_combatants(self, target)
		if not _combat_entry_aligned:
			return
	else:
		if not is_instance_valid(_combat_alignment_enemy) \
			or not _combat_alignment_enemy.is_player_combat_sequence_active():
			_combat_alignment_enemy = null
			_combat_entry_aligned = false
	if _weapon_cooldowns[current_weapon_index] > 0.0:
		return
	if target == null and auto_fight_enabled and not is_moving() and _attack_target == null:
		var closest_distance := INF
		var player_cell := world.world_to_cell(global_position)
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not enemy is ChickenEnemy or not is_instance_valid(enemy) or not world.belongs_to_world(enemy) or enemy.health <= 0 or not enemy.can_be_auto_fought():
				continue
			var offset := world.world_to_cell(enemy.global_position) - player_cell
			var distance := Vector2(offset).length_squared()
			var auto_fight_radius := 2 + auto_fight_range_bonus
			if absi(offset.x) <= auto_fight_radius and absi(offset.y) <= auto_fight_radius and distance < closest_distance:
				target = enemy
				closest_distance = distance
		automatic = target != null
	if target:
		if not _can_apply_enemy_attack(target, world, automatic):
			return
		var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
		if audio:
			audio.play_damage()
		_face_toward(target)
		_play_attack_animation(target)
		_show_slash(target, ItemPickup.get_grade_color(ItemPickup.get_item_grade(equipped_weapons[current_weapon_index])))
		target.take_damage(get_damage_for_color(target.enemy_color), automatic)
		_weapon_cooldowns[current_weapon_index] = attack_cooldown


func _can_apply_enemy_attack(target: ChickenEnemy, world: WorldNavigation, automatic: bool) -> bool:
	if not is_instance_valid(target) or target.health <= 0 or world == null or not world.belongs_to_world(target):
		return false
	if not automatic:
		return world.are_adjacent(self, target)
	if not auto_fight_enabled or is_moving() or is_instance_valid(_attack_target) or not target.can_be_auto_fought():
		return false
	var offset := world.world_to_cell(target.global_position) - world.world_to_cell(global_position)
	var auto_fight_radius := 2 + auto_fight_range_bonus
	return absi(offset.x) <= auto_fight_radius and absi(offset.y) <= auto_fight_radius


func _get_adjacent_enemy(world: WorldNavigation) -> ChickenEnemy:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is ChickenEnemy and is_instance_valid(enemy) and world.belongs_to_world(enemy) and enemy.health > 0 and world.are_adjacent(self, enemy):
			return enemy as ChickenEnemy
	return null


func _stop_for_combat() -> void:
	_path.clear()
	_path_index = 0
	velocity = Vector2.ZERO


func _collect_pickups_on_current_tile() -> void:
	var world := _get_navigation_world()
	if world == null:
		return
	var player_cell := world.world_to_cell(global_position)
	for pickup in get_tree().get_nodes_in_group("item_pickups"):
		if pickup is ItemPickup and is_instance_valid(pickup) and world.belongs_to_world(pickup) \
			and world.world_to_cell(pickup.global_position) == player_cell:
			pickup.begin_collect(self)


func _update_combat_ring() -> void:
	var world := _get_navigation_world()
	_combat_ring.visible = false
	if world == null:
		return
	_combat_ring.visible = _get_adjacent_enemy(world) != null


func _face_combat_enemy() -> void:
	var world := _get_navigation_world()
	if world == null:
		return
	var enemy := _get_adjacent_enemy(world)
	if enemy:
		_face_toward(enemy)


func _face_toward(target: Node2D) -> void:
	var horizontal_offset := target.global_position.x - global_position.x
	if horizontal_offset > 0.1:
		fox_sprite.flip_h = true
	elif horizontal_offset < -0.1:
		fox_sprite.flip_h = false


func _get_healing_speed_multiplier() -> float:
	return 5.0 if _is_near_campfire() else 1.0


func _regenerate_vitals_normally(delta: float) -> void:
	var regeneration_delta := delta * _get_healing_speed_multiplier()
	_heal_time_left -= regeneration_delta
	while _heal_time_left <= 0.0:
		heal(1)
		_heal_time_left += _get_passive_heal_interval()
	_mana_regen_time_left -= regeneration_delta
	while _mana_regen_time_left <= 0.0:
		restore_mana(1)
		_mana_regen_time_left += _get_passive_mana_regeneration_interval()


func _get_passive_heal_interval() -> float:
	return 3.0 / float(maxi(1, passive_healing_amount))


func get_passive_healing_per_second() -> float:
	return float(maxi(1, passive_healing_amount)) / 3.0


func get_effective_passive_healing_per_second() -> float:
	return get_passive_healing_per_second() * _get_healing_speed_multiplier()


func _get_passive_mana_regeneration_interval() -> float:
	return 3.0 / float(maxi(1, passive_mana_regeneration_amount))


func get_passive_mana_regeneration_per_second() -> float:
	return float(maxi(1, passive_mana_regeneration_amount)) / 3.0


func get_effective_passive_mana_regeneration_per_second() -> float:
	return get_passive_mana_regeneration_per_second() * _get_healing_speed_multiplier()


static func get_healing_increase_per_second(amount: int) -> float:
	return float(amount) / 3.0


static func format_health_per_second(value: float) -> String:
	return "%s/s" % _format_decimal(value)


static func format_regeneration_value(value: float) -> String:
	return _format_decimal(value)


static func _format_decimal(value: float) -> String:
	var formatted := "%.1f" % value
	while formatted.contains(".") and formatted.ends_with("0"):
		formatted = formatted.trim_suffix("0")
	return formatted.trim_suffix(".")


func is_near_campfire() -> bool:
	if _get_navigation_world() is DungeonLevel:
		return false
	for campfire in get_tree().get_nodes_in_group("campfires"):
		if campfire is Campfire and is_instance_valid(campfire) and campfire.is_player_in_range(self):
			return true
	return false


func _is_near_campfire() -> bool:
	return is_near_campfire()


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
	var world := _get_navigation_world()
	if world == null:
		return
	if world.are_adjacent(self, _attack_target):
		_stop_for_combat()
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
	var world := _get_navigation_world()
	if world and world.is_walkable(world.world_to_cell(global_position)):
		global_position = world.cell_to_world(world.world_to_cell(global_position))


func _begin_death_sequence() -> void:
	if _is_dying:
		return
	_is_dying = true
	stop()
	clear_attack_target()
	var world := _get_navigation_world()
	var interaction_was_locked := world.interaction_locked if world else false
	if world:
		world.interaction_locked = true
	var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
	if audio:
		audio.play_death()
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	fox_sprite.position = Vector2.ZERO
	fox_sprite.scale = Vector2.ONE
	fox_sprite.modulate = Color.WHITE
	var death_tween := create_tween()
	death_tween.tween_property(fox_sprite, "rotation", fox_sprite.rotation + PI / 2.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await death_tween.finished
	_show_death_overlay()
	await get_tree().create_timer(0.5).timeout
	global_position = world.get_death_respawn_position() if world is DungeonLevel else _spawn_position
	if world:
		var asha := world.get_node_or_null("FoxAsha") as FoxAsha
		if asha and asha.is_recruited():
			asha.place_left_of_player_after_respawn()
	health = max_health if world is DungeonLevel else 1
	health_bar.value = health
	_update_health_label()
	_heal_time_left = 3.0
	fox_sprite.rotation = 0.0
	_hide_death_overlay()
	if audio:
		audio.play_respawn()
	_is_dying = false
	if world:
		world.interaction_locked = interaction_was_locked
	vitals_changed.emit()


func _get_navigation_world() -> WorldNavigation:
	var cursor := get_parent()
	while cursor:
		if cursor is WorldNavigation:
			return cursor as WorldNavigation
		cursor = cursor.get_parent()
	return get_tree().get_first_node_in_group("world_navigation") as WorldNavigation


func _show_death_overlay() -> void:
	if not is_instance_valid(_death_overlay):
		var canvas := CanvasLayer.new()
		canvas.name = "DeathFadeLayer"
		canvas.layer = 1000
		add_child(canvas)
		_death_overlay = ColorRect.new()
		_death_overlay.name = "DeathOverlay"
		_death_overlay.color = Color.BLACK
		_death_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		canvas.add_child(_death_overlay)
		_death_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_death_overlay.show()


func _hide_death_overlay() -> void:
	if is_instance_valid(_death_overlay):
		_death_overlay.hide()


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
		var previous_landing := floori(_walk_time / PI)
		_walk_time += delta * 11.0
		if floori(_walk_time / PI) != previous_landing:
			var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
			if audio:
				audio.play_walking_step()
		fox_sprite.position.y = -absf(sin(_walk_time)) * 5.0
		fox_sprite.rotation = sin(_walk_time) * 0.09
	else:
		fox_sprite.position = Vector2.ZERO
		fox_sprite.rotation = 0.0


func _update_health_label() -> void:
	health_label.text = str(health)


func _update_mana_display() -> void:
	if not is_instance_valid(mana_bar) or not is_instance_valid(mana_label):
		return
	mana_bar.max_value = max_mana
	mana_bar.value = mana
	mana_label.text = "%d / %d" % [mana, max_mana]
	var visible_for_skills := has_unlocked_player_skill()
	mana_bar.visible = visible_for_skills
	mana_label.visible = visible_for_skills


func _show_damage_popup(amount: int, color_index: int, blocked_damage: int, skill_hit := false, impact_direction := Vector2.ZERO) -> void:
	var popup := DAMAGE_POPUP_SCENE.instantiate() as DamagePopup
	popup.name = "SkillDamagePopup" if skill_hit else "DamagePopup"
	popup.position = global_position + Vector2(0, -38)
	get_parent().add_child(popup)
	popup.show_damage(amount, color_index, blocked_damage, skill_hit)
	if skill_hit:
		_play_enemy_skill_hit_animation(color_index, impact_direction)
	else:
		_play_hit_animation()


func _play_enemy_skill_hit_animation(color_index: int, impact_direction: Vector2) -> void:
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_visual_time_left = 0.32
	var recoil_direction := impact_direction.normalized() if not impact_direction.is_zero_approx() else Vector2.RIGHT
	var hit_color: Color = DAMAGE_COLORS[clampi(color_index, COLOR_RED, COLOR_BLUE)].lightened(0.25)
	fox_sprite.position = recoil_direction * 11.0
	fox_sprite.scale = Vector2(1.30, 0.70)
	fox_sprite.rotation = 0.12 * signf(recoil_direction.x if absf(recoil_direction.x) > 0.01 else recoil_direction.y)
	fox_sprite.modulate = hit_color
	_hit_tween = create_tween()
	_hit_tween.tween_interval(0.08)
	_hit_tween.set_parallel(true)
	_hit_tween.tween_property(fox_sprite, "position", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(fox_sprite, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(fox_sprite, "rotation", 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(fox_sprite, "modulate", Color.WHITE, 0.18)


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
