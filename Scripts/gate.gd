class_name Gate
extends StaticBody2D

## The gate stays solid until an enemy made by this spawn point is defeated.
@export var unlock_enemy_spawn: EnemySpawnPoint:
	set(value):
		if _unlock_enemy_spawn and _unlock_enemy_spawn.enemy_killed.is_connected(_on_unlock_enemy_killed):
			_unlock_enemy_spawn.enemy_killed.disconnect(_on_unlock_enemy_killed)
		_unlock_enemy_spawn = value
		_connect_unlock_spawn()
	get:
		return _unlock_enemy_spawn

var _unlock_enemy_spawn: EnemySpawnPoint
var unlocked := false


func _ready() -> void:
	_connect_unlock_spawn()
	set_unlocked(unlocked)


func _exit_tree() -> void:
	if _unlock_enemy_spawn and _unlock_enemy_spawn.enemy_killed.is_connected(_on_unlock_enemy_killed):
		_unlock_enemy_spawn.enemy_killed.disconnect(_on_unlock_enemy_killed)


func _connect_unlock_spawn() -> void:
	if not is_inside_tree() or _unlock_enemy_spawn == null:
		return
	if not _unlock_enemy_spawn.enemy_killed.is_connected(_on_unlock_enemy_killed):
		_unlock_enemy_spawn.enemy_killed.connect(_on_unlock_enemy_killed)


func _on_unlock_enemy_killed(_enemy: ChickenEnemy) -> void:
	set_unlocked(true)


func set_unlocked(value: bool) -> void:
	unlocked = value
	visible = not unlocked
	if unlocked:
		remove_from_group("gates")
	else:
		add_to_group("gates")
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision:
		collision.set_deferred("disabled", unlocked)
