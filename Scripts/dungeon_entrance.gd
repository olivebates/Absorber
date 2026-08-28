class_name DungeonEntrance
extends Node2D

const DIFFICULTY_NAMES := ["Simple", "Moderate", "Challenging", "Intense", "Overwhelming", "Diabolical"]
const CAVE_MOSS_ICON := preload("res://Sprites/IconCaveMoss.webp")
const DIFFICULTY_COLORS := [
	Color("4caf50"), Color("f4d03f"), Color("f39c3d"),
	Color("e53935"), Color("7f1d2d"), Color("8e44ad"),
]

@export var dungeon_id: StringName = &"test_dungeon"
@export var dungeon_scene: PackedScene
@export_range(1, 6, 1) var difficulty := 1
@export var dungeon_name := "Dungeon"

var _pending_player: FoxPlayer
var _pending_world: WorldNavigation
var _return_position := Vector2.ZERO
var _tooltip_layer: CanvasLayer
var _tooltip: PanelContainer
var _tooltip_title: Label
var _tooltip_cleared_label: Label
var _tooltip_difficulty: Label
var _tooltip_production: Label
var _tooltip_meter: Control
var _tooltip_production_row: HBoxContainer
var _cleared_badge: Label
var _manager: Node
var _cleared_shake_tween: Tween

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("world_interactables")
	add_to_group("solid_walls")
	add_to_group("dungeon_entrances")
	_build_cleared_label()
	_build_tooltip()
	call_deferred("_connect_manager")


func _connect_manager() -> void:
	_manager = get_tree().get_first_node_in_group("dungeon_manager")
	if _manager and _manager.has_signal("dungeon_state_changed"):
		var callback := Callable(self, "_on_dungeon_state_changed")
		if not _manager.is_connected("dungeon_state_changed", callback):
			_manager.connect("dungeon_state_changed", callback)
	_refresh_state()


func request_interaction(player: FoxPlayer, world: WorldNavigation) -> void:
	if player == null or world == null or _manager == null or not _manager.has_method("request_enter") \
		or (_manager.has_method("is_dungeon_active") and bool(_manager.call("is_dungeon_active"))):
		return
	if _manager.has_method("is_cleared") and bool(_manager.call("is_cleared", dungeon_id)):
		var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
		if audio:
			audio.play_skill_unavailable()
		_play_cleared_interaction_shake(player)
		return
	_pending_player = player
	_pending_world = world
	_return_position = player.global_position
	player.clear_attack_target()
	var path := _best_adjacent_path(player, world)
	if not path.is_empty():
		player.follow_path(path)


func _process(_delta: float) -> void:
	_update_hover()
	if not is_instance_valid(_pending_player) or not is_instance_valid(_pending_world):
		return
	if _pending_world.are_adjacent(_pending_player, self):
		_pending_player.stop()
		var player := _pending_player
		_pending_player = null
		_pending_world = null
		_return_position = player.global_position
		_manager.call("request_enter", self)
	elif not _pending_player.is_moving():
		_pending_player = null
		_pending_world = null


func get_return_position() -> Vector2:
	return _return_position


func get_sprite_texture() -> Texture2D:
	return _sprite.texture if is_instance_valid(_sprite) else null


func _best_adjacent_path(player: FoxPlayer, world: WorldNavigation) -> PackedVector2Array:
	var object_cell := world.world_to_cell(global_position)
	var best := PackedVector2Array()
	var best_distance := INF
	for offset: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		var cell := object_cell + offset
		if not world.is_walkable(cell) or world.is_cell_occupied(cell, player):
			continue
		var candidate := world.find_path(player.global_position, world.cell_to_world(cell), player)
		if candidate.is_empty():
			continue
		var distance := 0.0
		for index in range(1, candidate.size()):
			distance += candidate[index - 1].distance_to(candidate[index])
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _update_hover() -> void:
	if not is_instance_valid(_tooltip):
		return
	var active := _manager != null and _manager.has_method("is_dungeon_active") \
		and bool(_manager.call("is_dungeon_active"))
	var hovered := not active and global_position.distance_to(get_global_mouse_position()) <= 38.0
	_tooltip.visible = hovered
	if hovered:
		_tooltip.position = get_viewport().get_mouse_position() + Vector2(18, 18)
		var viewport_size := get_viewport_rect().size
		_tooltip.position.x = minf(_tooltip.position.x, viewport_size.x - _tooltip.size.x - 8.0)
		_tooltip.position.y = minf(_tooltip.position.y, viewport_size.y - _tooltip.size.y - 8.0)


func _build_cleared_label() -> void:
	_cleared_badge = Label.new()
	_cleared_badge.name = "ClearedBadge"
	_cleared_badge.text = "✓"
	_cleared_badge.position = Vector2(-37, -38)
	_cleared_badge.custom_minimum_size = Vector2(28, 28)
	_cleared_badge.size = Vector2(28, 28)
	_cleared_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cleared_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cleared_badge.add_theme_color_override("font_color", Color.WHITE)
	_cleared_badge.add_theme_color_override("font_outline_color", Color.BLACK)
	_cleared_badge.add_theme_constant_override("outline_size", 2)
	_cleared_badge.add_theme_font_size_override("font_size", 16)
	var cleared_style := StyleBoxFlat.new()
	cleared_style.bg_color = Color("43a047")
	cleared_style.border_color = Color("d9ffd9")
	cleared_style.set_border_width_all(2)
	cleared_style.set_corner_radius_all(14)
	_cleared_badge.add_theme_stylebox_override("normal", cleared_style)
	_cleared_badge.clip_contents = true
	_cleared_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cleared_badge.z_index = 5
	_cleared_badge.hide()
	add_child(_cleared_badge)


func _build_tooltip() -> void:
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.layer = 20
	add_child(_tooltip_layer)
	_tooltip = PanelContainer.new()
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.03, 0.045, 0.97)
	style.border_color = Color("d6b94c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	_tooltip.add_theme_stylebox_override("panel", style)
	_tooltip_layer.add_child(_tooltip)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	_tooltip.add_child(content)
	_tooltip_title = Label.new()
	_tooltip_title.text = dungeon_name
	_tooltip_title.add_theme_font_size_override("font_size", 18)
	_tooltip_title.add_theme_color_override("font_color", Color("ffe082"))
	content.add_child(_tooltip_title)
	_tooltip_meter = Control.new()
	_tooltip_meter.custom_minimum_size = Vector2(104, 18)
	content.add_child(_tooltip_meter)
	var line := ColorRect.new()
	line.position = Vector2(11, 8)
	line.size = Vector2(160, 2)
	line.color = Color(0.42, 0.43, 0.48, 1.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_meter.add_child(line)
	line.hide()
	var color: Color = DIFFICULTY_COLORS[difficulty - 1]
	for index in range(6):
		var dot := Label.new()
		dot.text = "●"
		dot.position = Vector2(index * 16, -5)
		dot.size = Vector2(18, 24)
		dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dot.add_theme_font_size_override("font_size", 18)
		dot.add_theme_color_override("font_color", color if index < difficulty else Color("555862"))
		dot.add_theme_color_override("font_outline_color", Color.BLACK)
		dot.add_theme_constant_override("outline_size", 2)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tooltip_meter.add_child(dot)
	_tooltip_difficulty = Label.new()
	_tooltip_difficulty.text = "Difficulty %d — %s" % [difficulty, DIFFICULTY_NAMES[difficulty - 1]]
	_tooltip_difficulty.add_theme_color_override("font_color", color)
	content.add_child(_tooltip_difficulty)
	_tooltip_difficulty.text = DIFFICULTY_NAMES[difficulty - 1]
	content.move_child(_tooltip_difficulty, 2)
	_tooltip_production_row = HBoxContainer.new()
	_tooltip_production_row.add_theme_constant_override("separation", 5)
	content.add_child(_tooltip_production_row)
	_tooltip_production_row.hide()
	var production_icon := TextureRect.new()
	production_icon.texture = CAVE_MOSS_ICON
	production_icon.custom_minimum_size = Vector2(20, 20)
	production_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	production_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	production_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_production_row.add_child(production_icon)
	_tooltip_production = Label.new()
	_tooltip_production.text = "Clear to produce Cave Moss"
	_tooltip_production.add_theme_color_override("font_color", Color("aeb3c1"))
	_tooltip_production_row.add_child(_tooltip_production)
	_tooltip.hide()


func _on_dungeon_state_changed(changed_id: StringName) -> void:
	if changed_id.is_empty() or changed_id == dungeon_id:
		_refresh_state()


func _refresh_state() -> void:
	var cleared := _manager != null and _manager.has_method("is_cleared") \
		and bool(_manager.call("is_cleared", dungeon_id))
	if is_instance_valid(_cleared_badge):
		_cleared_badge.visible = cleared
	if is_instance_valid(_tooltip_cleared_label):
		_tooltip_cleared_label.visible = cleared
	if is_instance_valid(_tooltip_meter):
		_tooltip_meter.visible = not cleared
	if is_instance_valid(_tooltip_difficulty):
		_tooltip_difficulty.visible = not cleared
	if is_instance_valid(_tooltip_production_row):
		_tooltip_production_row.visible = cleared
	if is_instance_valid(_tooltip_production):
		_tooltip_production.text = "Produces 1 Cave Moss / 10 min" if cleared else "Clear to produce Cave Moss"
		_tooltip_production.add_theme_color_override("font_color", Color("8bd66d") if cleared else Color("aeb3c1"))


func _play_cleared_interaction_shake(player: FoxPlayer) -> void:
	if player == null or not is_instance_valid(player.fox_sprite):
		return
	if _cleared_shake_tween and _cleared_shake_tween.is_valid():
		_cleared_shake_tween.kill()
	var sprite := player.fox_sprite
	var origin := sprite.position
	_cleared_shake_tween = sprite.create_tween()
	for offset in [-4.0, 4.0, -3.0, 0.0]:
		_cleared_shake_tween.tween_property(sprite, "position:x", origin.x + offset, 0.05)
	_cleared_shake_tween.finished.connect(func() -> void:
		if is_instance_valid(sprite):
			sprite.position = origin
		_cleared_shake_tween = null
	)
