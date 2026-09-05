class_name EnemySpawnPoint
extends Marker2D

const ENEMY_SCENES: Array[String] = [
	"res://Scenes/chicken_enemy.tscn",
	"res://Scenes/cow_enemy.tscn",
	"res://Scenes/bull_enemy.tscn",
	"res://Scenes/mole_enemy.tscn",
	"res://Scenes/mole2_enemy.tscn",
	"res://Scenes/goat_enemy.tscn",
	"res://Scenes/evil_goat_enemy.tscn",
	"res://Scenes/crab_enemy.tscn",
	"res://Scenes/snake_enemy.tscn",
	"res://Scenes/camel_enemy.tscn",
	"res://Scenes/crocodile_enemy.tscn",
	"res://Scenes/mouse_enemy.tscn",
	"res://Scenes/kangaroo_rat_enemy.tscn",
	"res://Scenes/mad_coyote_enemy.tscn",
	"res://Scenes/squirrel_enemy.tscn",
	"res://Scenes/deer_enemy.tscn",
	"res://Scenes/porcupine_enemy.tscn",
	"res://Scenes/bunny_enemy.tscn",
	"res://Scenes/evil_raccoon_enemy.tscn",
	"res://Scenes/evil_owl_enemy.tscn",
	"res://Scenes/bat_enemy.tscn",
	"res://Scenes/millipede_enemy.tscn",
	"res://Scenes/evil_scorpion_enemy.tscn",
	"res://Scenes/toad_enemy.tscn",
	"res://Scenes/dung_beetle_enemy.tscn",
	"res://Scenes/spider_enemy.tscn",
	"res://Scenes/salamander_enemy.tscn",
]

signal enemy_killed(enemy: ChickenEnemy)
signal enemy_respawned(enemy: ChickenEnemy)

const SPAWN_RADIUS_TILES := 2

@export var respawn_time := 8.0
@export var max_enemies := 2
@export var area_id := 1
@export_category("Rewards")
@export_range(0, 999, 1) var stat_reward_amount := 1
@export_enum("Damage", "Health", "Resource", "Regenerate", "Defense", "Mana", "Mana Regenerate") var reward_type := ChickenEnemy.REWARD_DAMAGE
@export_enum("Red", "Yellow", "Blue") var damage_reward_color := FoxPlayer.COLOR_RED
@export_enum("Red", "Yellow", "Blue") var defense_reward_color := FoxPlayer.COLOR_RED
@export_enum("gold_ore", "jewels", "fish", "wood", "cave_moss", "herbs") var reward_resource_id := "gold_ore"
@export_category("Enemy Stats")
@export_range(1, 100000000, 1) var enemy_health := 3
@export_range(1, 999, 1) var enemy_damage := 1
@export_enum("Red", "Yellow", "Blue") var enemy_damage_color := FoxPlayer.COLOR_RED
@export_range(0, 999, 1) var enemy_armor := 0
@export_range(0, 100000000, 1) var enemy_thorn := 0
@export var aggressive := false
@export var boss := false
@export var dungeon_once := false
@export_category("Enemy Skills")
## Damage 0 uses the skill's default of five times this spawn's enemy damage.
@export_enum("None", "Crushing Blow", "Cascading Sweep", "Cascading Surround", "Fan Strike (Quick)", "Fan Strike (Charged)", "Driving Strike (Quick)", "Driving Strike (Charged)", "Scatter Strike") var enemy_skill_1 := ChickenEnemy.SKILL_NONE
@export_range(0, 999, 1) var enemy_skill_1_damage := 0
@export_enum("Red", "Yellow", "Blue") var enemy_skill_1_damage_type := FoxPlayer.COLOR_RED
## Cooldown 0 uses the selected skill's default cooldown.
@export_range(0.0, 999.0, 0.1) var enemy_skill_1_cooldown := 0.0
## Delay before this skill's first use in each engagement. Its regular cooldown begins after use.
@export_range(0.0, 999.0, 0.1) var enemy_skill_1_initial_cooldown_offset := 0.0
@export_enum("None", "Crushing Blow", "Cascading Sweep", "Cascading Surround", "Fan Strike (Quick)", "Fan Strike (Charged)", "Driving Strike (Quick)", "Driving Strike (Charged)", "Scatter Strike") var enemy_skill_2 := ChickenEnemy.SKILL_NONE
@export_range(0, 999, 1) var enemy_skill_2_damage := 0
@export_enum("Red", "Yellow", "Blue") var enemy_skill_2_damage_type := FoxPlayer.COLOR_RED
@export_range(0.0, 999.0, 0.1) var enemy_skill_2_cooldown := 0.0
## Delay before this skill's first use in each engagement. Its regular cooldown begins after use.
@export_range(0.0, 999.0, 0.1) var enemy_skill_2_initial_cooldown_offset := 0.0
@export_enum("None", "Crushing Blow", "Cascading Sweep", "Cascading Surround", "Fan Strike (Quick)", "Fan Strike (Charged)", "Driving Strike (Quick)", "Driving Strike (Charged)", "Scatter Strike") var enemy_skill_3 := ChickenEnemy.SKILL_NONE
@export_range(0, 999, 1) var enemy_skill_3_damage := 0
@export_enum("Red", "Yellow", "Blue") var enemy_skill_3_damage_type := FoxPlayer.COLOR_RED
@export_range(0.0, 999.0, 0.1) var enemy_skill_3_cooldown := 0.0
## Delay before this skill's first use in each engagement. Its regular cooldown begins after use.
@export_range(0.0, 999.0, 0.1) var enemy_skill_3_initial_cooldown_offset := 0.0
@export_category("Spawning")
@export_enum("Chicken", "Cow", "Bull", "Mole", "Mole 2", "Goat", "Evil Goat", "Crab", "Snake", "Camel", "Crocodile", "Mouse", "Kangaroo Rat", "Mad Coyote", "Squirrel", "Deer", "Porcupine", "Bunny", "Evil Raccoon", "Evil Owl", "Bat", "Millipede", "Evil Scorpion", "Toad", "Dung Beetle", "Spider", "Salamander") var enemy_type := 0
@export var enemy_scene: PackedScene
## Mirrors this spawn's enemies relative to their normal facing direction.
@export var flip_enemy_sprites_horizontally := false
@export_category("Drops")
## Add one EnemyDropEntry per possible item. Each entry exposes a simple item,
## chance, and grade picker in the Inspector.
@export var item_drops: Array[EnemyDropEntry] = []
## Kept only so existing placed spawners and old scenes retain their drop data.
@export_storage var drop_table: Array[Dictionary] = []

var _respawn_time_left := 0.0
var _spawned_enemies: Array[ChickenEnemy] = []
var _was_empty := true
var _was_full := false
var _timer_label: Label
var _initial_spawn_complete := false
var emptied_once := false


func _physics_process(delta: float) -> void:
	if not _initial_spawn_complete:
		return
	var active_enemies: Array[ChickenEnemy] = []
	for enemy in _spawned_enemies:
		if is_instance_valid(enemy):
			active_enemies.append(enemy)
	_spawned_enemies = active_enemies
	if dungeon_once and emptied_once and _spawned_enemies.is_empty():
		_respawn_time_left = 0.0
		_update_respawn_indicator()
		return
	if _spawned_enemies.size() < max_enemies and _was_full:
		_respawn_time_left = respawn_time
	_was_empty = _spawned_enemies.is_empty()
	_was_full = _spawned_enemies.size() >= max_enemies
	if _spawned_enemies.size() >= max_enemies:
		return
	_respawn_time_left -= delta
	if _respawn_time_left <= 0.0:
		if _spawn_enemy():
			_respawn_time_left = respawn_time
	_update_respawn_indicator()


func _spawn_enemy(rewards_enabled := true) -> bool:
	var world := _get_navigation_world()
	if world == null:
		return false
	var spawn_cell := _get_available_spawn_cell(world)
	if spawn_cell == Vector2i(-1, -1):
		return false
	var enemy := _create_enemy(world, world.cell_to_world(spawn_cell), spawn_cell, [], rewards_enabled)
	if enemy and _initial_spawn_complete:
		enemy_respawned.emit(enemy)
	return enemy != null


func get_active_enemies() -> Array[ChickenEnemy]:
	var result: Array[ChickenEnemy] = []
	for enemy in _spawned_enemies:
		if is_instance_valid(enemy) and enemy.health > 0:
			result.append(enemy)
	return result


func get_respawn_progress() -> float:
	if respawn_time <= 0.0 or not get_active_enemies().is_empty():
		return 0.0
	return clampf(1.0 - _respawn_time_left / respawn_time, 0.0, 1.0)


func _create_enemy(world: WorldNavigation, spawn_position: Vector2, home: Vector2i, saved_data: Array = [], rewards_enabled := true) -> ChickenEnemy:
	var enemy := _get_enemy_scene().instantiate() as ChickenEnemy
	enemy.spawn_point = self
	enemy.rewards_enabled = rewards_enabled
	enemy.global_position = spawn_position
	enemy.setup(home, stat_reward_amount, reward_type, _get_drop_table(), StringName(reward_resource_id), damage_reward_color, enemy_health, enemy_damage, enemy_damage_color, enemy_armor, defense_reward_color, aggressive, _get_enemy_skills(), flip_enemy_sprites_horizontally, enemy_thorn)
	enemy.died.connect(_on_spawned_enemy_died)
	get_parent().add_child(enemy)
	if not saved_data.is_empty():
		enemy.load_save_data(saved_data, 0)
	_spawned_enemies.append(enemy)
	queue_redraw()
	return enemy


func get_save_data() -> Array:
	var saved_enemies: Array = []
	for enemy in _spawned_enemies:
		if is_instance_valid(enemy) and enemy.health > 0:
			saved_enemies.append(enemy.get_save_data())
	return [maxi(0, roundi(_respawn_time_left * 1000.0)), saved_enemies, emptied_once]


func clear_for_load() -> void:
	for enemy in _spawned_enemies:
		if is_instance_valid(enemy):
			enemy.free()
	_spawned_enemies.clear()
	_initial_spawn_complete = true
	_was_empty = true
	_was_full = false


func respawn_all_immediately() -> void:
	# Preserve the reward carried by every survivor. Only missing wave members
	# represent enemies the player already killed, so only those replacements
	# are rewardless.
	var surviving_reward_flags: Array[bool] = []
	for enemy in _spawned_enemies:
		if is_instance_valid(enemy):
			if enemy.health > 0:
				surviving_reward_flags.append(enemy.rewards_enabled)
			enemy.free()
	_spawned_enemies.clear()
	emptied_once = false
	_initial_spawn_complete = true
	_was_empty = true
	_was_full = false
	for index in range(maxi(0, max_enemies)):
		var rewards_enabled := surviving_reward_flags[index] if index < surviving_reward_flags.size() else false
		if not _spawn_enemy(rewards_enabled):
			break
	_respawn_time_left = respawn_time
	_was_empty = _spawned_enemies.is_empty()
	_was_full = _spawned_enemies.size() >= max_enemies
	_update_respawn_indicator()


func ensure_initial_wave_spawned() -> void:
	if emptied_once:
		return
	var active_enemies: Array[ChickenEnemy] = []
	for enemy in _spawned_enemies:
		if is_instance_valid(enemy) and enemy.health > 0:
			active_enemies.append(enemy)
	_spawned_enemies = active_enemies
	if _spawned_enemies.size() >= max_enemies:
		return
	# A dungeon room outside the initial navigation region cannot spawn during
	# _ready(). Treat this as the rest of its initial wave, not as a respawn.
	_initial_spawn_complete = false
	while _spawned_enemies.size() < max_enemies:
		if not _spawn_enemy():
			break
	_initial_spawn_complete = true
	_was_empty = _spawned_enemies.is_empty()
	_was_full = _spawned_enemies.size() >= max_enemies
	_respawn_time_left = respawn_time
	_update_respawn_indicator()


func load_save_data(data: Array, offline_seconds: int, preserve_enemy_positions := false) -> bool:
	if data.size() < 2:
		return false
	var world := _get_navigation_world()
	if world == null:
		return false
	emptied_once = bool(data[2]) if data.size() > 2 else false
	var saved_enemies := data[1] as Array
	for raw_enemy_data in saved_enemies:
		if _spawned_enemies.size() >= max_enemies or not raw_enemy_data is Array:
			break
		var enemy_data := raw_enemy_data as Array
		if enemy_data.size() < 9:
			continue
		var saved_position := Vector2(float(enemy_data[0]), float(enemy_data[1]))
		var saved_home := Vector2i(int(enemy_data[2]), int(enemy_data[3]))
		var saved_cell := world.world_to_cell(saved_position)
		var spawn_cell := saved_cell if preserve_enemy_positions and world.is_walkable(saved_cell) else _get_available_spawn_cell(world)
		if spawn_cell == Vector2i(-1, -1):
			continue
		var home_cell := saved_home if preserve_enemy_positions and world.is_walkable(saved_home) else spawn_cell
		var enemy_position := saved_position if preserve_enemy_positions and world.is_walkable(saved_cell) else world.cell_to_world(spawn_cell)
		var enemy := _create_enemy(world, enemy_position, home_cell)
		if enemy:
			enemy.load_save_data(enemy_data, offline_seconds)

	var interval_milliseconds := maxi(1, roundi(respawn_time * 1000.0))
	var time_left_milliseconds := clampi(int(data[0]), 0, interval_milliseconds)
	if _spawned_enemies.size() < max_enemies and not (dungeon_once and emptied_once):
		time_left_milliseconds -= maxi(0, offline_seconds) * 1000
		while _spawned_enemies.size() < max_enemies and time_left_milliseconds <= 0:
			if not _spawn_enemy():
				break
			time_left_milliseconds += interval_milliseconds
	_respawn_time_left = float(maxi(0, time_left_milliseconds)) / 1000.0
	if _spawned_enemies.size() >= max_enemies:
		_respawn_time_left = respawn_time
	_initial_spawn_complete = true
	_was_empty = _spawned_enemies.is_empty()
	_was_full = _spawned_enemies.size() >= max_enemies
	_update_respawn_indicator()
	return true


func _ready() -> void:
	add_to_group("enemy_spawns")
	_timer_label = Label.new()
	_timer_label.position = Vector2(-24, -9)
	_timer_label.size = Vector2(48, 18)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_color_override("font_color", Color.WHITE)
	_timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_timer_label.add_theme_constant_override("outline_size", 3)
	_timer_label.add_theme_font_size_override("font_size", 12)
	_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_timer_label)
	_update_respawn_indicator()
	call_deferred("_spawn_starting_enemies")


func _spawn_starting_enemies() -> void:
	while _spawned_enemies.size() < maxi(0, max_enemies):
		if not _spawn_enemy():
			break
	_initial_spawn_complete = true
	_was_empty = _spawned_enemies.is_empty()
	_was_full = _spawned_enemies.size() >= max_enemies
	_respawn_time_left = respawn_time
	_update_respawn_indicator()


func _get_available_spawn_cell(world: WorldNavigation) -> Vector2i:
	var origin := world.world_to_cell(global_position)
	for radius in range(SPAWN_RADIUS_TILES + 1):
		for y_offset in range(-radius, radius + 1):
			for x_offset in range(-radius, radius + 1):
				if maxi(absi(x_offset), absi(y_offset)) != radius:
					continue
				var candidate := origin + Vector2i(x_offset, y_offset)
				if world.is_walkable(candidate) and not world.is_cell_occupied(candidate) and not world.is_gold_ore_cell(candidate):
					return candidate
	return Vector2i(-1, -1)


func _get_drop_table() -> Array[Dictionary]:
	if not item_drops.is_empty():
		var result: Array[Dictionary] = []
		for entry in item_drops:
			if entry != null:
				result.append(entry.to_drop_dictionary())
		return result
	return drop_table.duplicate(true)


func _get_enemy_skills() -> Array[Dictionary]:
	var skills: Array[Dictionary] = []
	var configured := [
		[enemy_skill_1, enemy_skill_1_damage, enemy_skill_1_damage_type, enemy_skill_1_cooldown, enemy_skill_1_initial_cooldown_offset],
		[enemy_skill_2, enemy_skill_2_damage, enemy_skill_2_damage_type, enemy_skill_2_cooldown, enemy_skill_2_initial_cooldown_offset],
		[enemy_skill_3, enemy_skill_3_damage, enemy_skill_3_damage_type, enemy_skill_3_cooldown, enemy_skill_3_initial_cooldown_offset],
	]
	for values in configured:
		var skill_id := int(values[0])
		if skill_id == ChickenEnemy.SKILL_NONE:
			continue
		skills.append({
			"skill_id": skill_id,
			"damage": maxi(0, int(values[1])),
			"damage_type": clampi(int(values[2]), FoxPlayer.COLOR_RED, FoxPlayer.COLOR_BLUE),
			"cooldown": maxf(0.0, float(values[3])),
			"initial_offset": maxf(0.0, float(values[4])),
		})
	return skills


func _get_enemy_scene() -> PackedScene:
	if enemy_scene:
		return enemy_scene
	return load(ENEMY_SCENES[clampi(enemy_type, 0, ENEMY_SCENES.size() - 1)]) as PackedScene


func _get_navigation_world() -> WorldNavigation:
	var cursor := get_parent()
	while cursor:
		if cursor is WorldNavigation:
			return cursor as WorldNavigation
		cursor = cursor.get_parent()
	return get_tree().get_first_node_in_group("world_navigation") as WorldNavigation


func _on_spawned_enemy_died(enemy: ChickenEnemy) -> void:
	var was_full := _spawned_enemies.size() >= max_enemies
	_spawned_enemies.erase(enemy)
	if _spawned_enemies.is_empty():
		emptied_once = true
	if was_full and _spawned_enemies.size() < max_enemies:
		_respawn_time_left = respawn_time
	_was_full = false
	enemy_killed.emit(enemy)
	queue_redraw()


func _update_respawn_indicator() -> void:
	var show_timer := _spawned_enemies.is_empty() and _respawn_time_left > 0.0
	if _timer_label:
		_timer_label.visible = show_timer
		_timer_label.text = _format_respawn_time(_respawn_time_left) if show_timer else ""
	queue_redraw()


func _format_respawn_time(time_left: float) -> String:
	var remaining_seconds := maxi(0, ceili(time_left))
	return "%d:%02d" % [remaining_seconds / 60, remaining_seconds % 60]


func _draw() -> void:
	if not _spawned_enemies.is_empty() or _respawn_time_left <= 0.0:
		return
	var radius := 21.0
	var progress := clampf(1.0 - _respawn_time_left / maxf(respawn_time, 0.01), 0.0, 1.0)
	if progress > 0.0:
		draw_arc(Vector2.ZERO, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color.BLACK, 8.0, true)
		draw_arc(Vector2.ZERO, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color("78d7ff"), 5.0, true)
