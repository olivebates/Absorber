class_name EnemySpawnPoint
extends Marker2D

const ENEMY_SCENES: Array[PackedScene] = [
	preload("res://Scenes/chicken_enemy.tscn"),
	preload("res://Scenes/cow_enemy.tscn"),
	preload("res://Scenes/bull_enemy.tscn"),
	preload("res://Scenes/mole_enemy.tscn"),
	preload("res://Scenes/mole2_enemy.tscn"),
	preload("res://Scenes/goat_enemy.tscn"),
]

signal enemy_killed(enemy: ChickenEnemy)

const SPAWN_RADIUS_TILES := 2

@export var respawn_time := 8.0
@export var max_enemies := 2
@export_category("Rewards")
@export_range(0, 999, 1) var stat_reward_amount := 1
@export_enum("Damage", "Health", "Resource", "Regenerate") var reward_type := ChickenEnemy.REWARD_DAMAGE
@export_enum("Red", "Yellow", "Blue") var damage_reward_color := FoxPlayer.COLOR_RED
@export var reward_resource_id: StringName = &"gold_ore"
@export_category("Enemy Stats")
@export_range(1, 999, 1) var enemy_health := 3
@export_range(0, 999, 1) var enemy_damage := 1
@export_category("Spawning")
@export_enum("Chicken", "Cow", "Bull", "Mole", "Mole 2", "Goat") var enemy_type := 0
@export var enemy_scene: PackedScene
@export_category("Drops")
@export var drop_table: Array[Dictionary] = []

var _respawn_time_left := 0.0
var _spawned_enemies: Array[ChickenEnemy] = []
var _was_empty := true
var _timer_label: Label
var _initial_spawn_complete := false


func _physics_process(delta: float) -> void:
	if not _initial_spawn_complete:
		return
	var active_enemies: Array[ChickenEnemy] = []
	for enemy in _spawned_enemies:
		if is_instance_valid(enemy):
			active_enemies.append(enemy)
	_spawned_enemies = active_enemies
	if _spawned_enemies.is_empty() and not _was_empty:
		_respawn_time_left = respawn_time
	_was_empty = _spawned_enemies.is_empty()
	if _spawned_enemies.size() >= max_enemies:
		queue_redraw()
		return
	_respawn_time_left -= delta
	if _respawn_time_left <= 0.0:
		if _spawn_enemy():
			_respawn_time_left = respawn_time
	_update_respawn_indicator()


func _spawn_enemy() -> bool:
	var world := get_tree().get_first_node_in_group("world_navigation") as WorldNavigation
	if world == null:
		return false
	var spawn_cell := _get_available_spawn_cell(world)
	if spawn_cell == Vector2i(-1, -1):
		return false
	var enemy := _get_enemy_scene().instantiate() as ChickenEnemy
	enemy.global_position = world.cell_to_world(spawn_cell)
	enemy.setup(spawn_cell, stat_reward_amount, reward_type, _get_drop_table(), reward_resource_id, damage_reward_color, enemy_health, enemy_damage)
	enemy.died.connect(_on_spawned_enemy_died)
	get_parent().add_child(enemy)
	_spawned_enemies.append(enemy)
	queue_redraw()
	return true


func _ready() -> void:
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
	for _index in range(maxi(0, max_enemies)):
		if not _spawn_enemy():
			break
	_initial_spawn_complete = true
	_was_empty = _spawned_enemies.is_empty()
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
	return drop_table.duplicate(true)


func _get_enemy_scene() -> PackedScene:
	if enemy_scene:
		return enemy_scene
	return ENEMY_SCENES[clampi(enemy_type, 0, ENEMY_SCENES.size() - 1)]


func _on_spawned_enemy_died(enemy: ChickenEnemy) -> void:
	_spawned_enemies.erase(enemy)
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
