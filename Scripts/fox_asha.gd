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
var _join_celebration: RecruitmentCelebration
var _join_previous_gameplay_paused := false
var _join_previous_interaction_locked := false

@onready var fox_sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("shopkeepers")
	add_to_group("npcs")
	add_to_group("story_characters")
	_world = get_parent() as WorldNavigation
	if _world:
		_world.register_navigation_actor(self)
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
	_highlight.visible = is_story_interactable() \
		and Rect2(Vector2(-32, -32), Vector2(64, 64)).has_point(to_local(get_global_mouse_position()))
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
		if value:
			close_shop()
		if value and celebrate:
			_play_recruitment_celebration()
		return
	_recruited = value
	if not value:
		if not is_in_group("shopkeepers"):
			add_to_group("shopkeepers")
		_last_player_cell = INVALID_CELL
		_follow_target_cell = INVALID_CELL
		return
	close_shop()
	remove_from_group("shopkeepers")
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


func is_story_interactable() -> bool:
	if not _recruited:
		return true
	var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
	return story != null and not story.has_seen_event(&"asha_post_recruitment")


func reset_smooch_cooldown() -> void:
	_smooch_cooldown_left = 8.0
	_smooch_in_progress = false


func place_left_of_player_after_respawn() -> void:
	if not _recruited or not is_instance_valid(_player) or not is_instance_valid(_world):
		return
	var player_cell := _world.world_to_cell(_player.global_position)
	var destination := player_cell + Vector2i.LEFT
	global_position = _world.cell_to_world(destination)
	_world.sync_navigation_actor(self)
	_last_player_cell = player_cell
	_follow_target_cell = INVALID_CELL
	_stop_patrol()


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
		_world.sync_navigation_actor(self)
		return
	var lerp_weight := minf(1.0, _player.move_speed * delta / distance)
	var previous_position := global_position
	global_position = global_position.lerp(target, lerp_weight)
	_world.sync_navigation_actor(self)
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


func play_roll_animation(delay := 0.2) -> void:
	if not _recruited or not is_instance_valid(fox_sprite):
		return
	var tween := fox_sprite.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(fox_sprite, "rotation", fox_sprite.rotation + TAU, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		if is_instance_valid(fox_sprite):
			fox_sprite.rotation = 0.0
	)


func get_smooch_cooldown_ratio() -> float:
	return clampf(_smooch_cooldown_left / 8.0, 0.0, 1.0)


func _play_recruitment_celebration() -> void:
	var hud := _world.get_node_or_null("HUD") as CanvasLayer if _world else null
	if hud == null:
		return
	if is_instance_valid(_join_celebration):
		return
	_join_previous_gameplay_paused = _world.gameplay_paused
	_join_previous_interaction_locked = _world.interaction_locked
	_world.gameplay_paused = true
	_world.interaction_locked = true
	var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
	if audio:
		audio.set_recruitment_music_ducked(true)
		audio.play_asha_joins()
	var celebration := RecruitmentCelebration.new()
	_join_celebration = celebration
	celebration.name = "AshaJoinCelebration"
	celebration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	celebration.z_index = 500
	hud.add_child(celebration)
	var center := get_viewport_rect().size * Vector2(0.5, 0.38)
	var ribbon := ColorRect.new()
	ribbon.name = "JoinRibbon"
	ribbon.color = Color(0.015, 0.012, 0.01, 0.94)
	ribbon.position = Vector2(get_viewport_rect().size.x, center.y + 24.0)
	ribbon.size = Vector2(get_viewport_rect().size.x, 72.0)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	celebration.add_child(ribbon)
	var ribbon_top := ColorRect.new()
	ribbon_top.color = Color("e9c64d")
	ribbon_top.position = Vector2(0, -2)
	ribbon_top.size = Vector2(ribbon.size.x, 2)
	ribbon.add_child(ribbon_top)
	var ribbon_bottom := ColorRect.new()
	ribbon_bottom.color = Color("e9c64d")
	ribbon_bottom.position = Vector2(0, ribbon.size.y)
	ribbon_bottom.size = Vector2(ribbon.size.x, 2)
	ribbon.add_child(ribbon_bottom)
	var burst := Node2D.new()
	burst.name = "JoinBurst"
	burst.position = center - Vector2(0, 36)
	burst.modulate.a = 0.0
	celebration.add_child(burst)
	for ray_index in range(16):
		var angle := TAU * float(ray_index) / 16.0
		var ray := Line2D.new()
		ray.width = 5.0 if ray_index % 2 == 0 else 3.0
		ray.default_color = Color(1.0, 0.88, 0.30, 0.82)
		ray.add_point(Vector2.from_angle(angle) * 72.0)
		ray.add_point(Vector2.from_angle(angle) * (150.0 if ray_index % 2 == 0 else 120.0))
		burst.add_child(ray)
	var portrait := TextureRect.new()
	portrait.name = "AshaJoinPortrait"
	portrait.texture = fox_sprite.texture
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = center - Vector2(54, 92)
	portrait.size = Vector2(108, 108)
	portrait.pivot_offset = portrait.size * 0.5
	portrait.scale = Vector2(0.58, 0.58)
	portrait.modulate.a = 0.0
	celebration.add_child(portrait)
	var title := Label.new()
	title.name = "JoinTitle"
	title.text = "Asha joins the party!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, center.y + 34.0)
	title.size = Vector2(get_viewport_rect().size.x, 52)
	title.pivot_offset = Vector2(title.size.x * 0.5, title.size.y * 0.5)
	title.scale = Vector2(0.20, 0.20)
	title.modulate.a = 0.0
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("fff176"))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 8)
	celebration.add_child(title)
	var continue_prompt := Label.new()
	continue_prompt.name = "JoinContinuePrompt"
	continue_prompt.text = "Click or press any key to continue"
	continue_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_prompt.position = Vector2(0, center.y + 104.0)
	continue_prompt.size = Vector2(get_viewport_rect().size.x, 32)
	continue_prompt.add_theme_font_size_override("font_size", 16)
	continue_prompt.add_theme_color_override("font_color", Color.WHITE)
	continue_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	continue_prompt.add_theme_constant_override("outline_size", 4)
	continue_prompt.hide()
	celebration.add_child(continue_prompt)
	var sequence := celebration.create_tween()
	sequence.tween_property(ribbon, "position:x", 0.0, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	sequence.tween_interval(0.25)
	sequence.tween_property(portrait, "modulate:a", 1.0, 0.24)
	sequence.parallel().tween_property(portrait, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sequence.tween_interval(0.25)
	sequence.tween_property(burst, "modulate:a", 1.0, 0.38)
	sequence.tween_interval(0.25)
	sequence.tween_callback(_play_join_impact)
	sequence.tween_property(title, "modulate:a", 1.0, 0.16)
	sequence.parallel().tween_property(title, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var sun_rotation := burst.create_tween().set_loops()
	sun_rotation.tween_property(burst, "rotation", TAU, 9.0).from(0.0).set_trans(Tween.TRANS_LINEAR)
	celebration.dismissed.connect(_finish_recruitment_celebration.bind(celebration))
	celebration.arm_after(3.05, continue_prompt)


func _play_join_impact() -> void:
	_play_join_camera_punch()


func _finish_recruitment_celebration(celebration: RecruitmentCelebration) -> void:
	if not is_instance_valid(celebration) or celebration != _join_celebration:
		return
	if is_instance_valid(_world):
		_world.gameplay_paused = _join_previous_gameplay_paused
		_world.interaction_locked = _join_previous_interaction_locked
	var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
	if audio:
		audio.set_recruitment_music_ducked(false)
	_join_celebration = null
	var tween := celebration.create_tween()
	tween.tween_property(celebration, "modulate:a", 0.0, 0.28)
	tween.tween_callback(celebration.queue_free)


func _play_join_camera_punch() -> void:
	var camera := _player.get_node_or_null("Camera2D") as Camera2D if is_instance_valid(_player) else null
	if camera == null:
		return
	var origin := camera.position
	var tween := camera.create_tween()
	tween.tween_property(camera, "position", origin + Vector2(5, -3), 0.05)
	tween.tween_property(camera, "position", origin + Vector2(-4, 3), 0.06)
	tween.tween_property(camera, "position", origin + Vector2(2, -1), 0.06)
	tween.tween_property(camera, "position", origin, 0.08)


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
	if _recruited:
		return
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
	# NPC placement belongs to the current scene. The trailing coordinates are
	# retained in the format only so older saves remain compatible.
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
		_world.sync_navigation_actor(self)
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
	_world.sync_navigation_actor(self)
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
	var destinations := _world.get_patrol_destinations(_home_cell, PATROL_RADIUS_TILES, self)
	if not destinations.is_empty() and _world.try_consume_path_request():
		var candidate := _world.get_patrol_path(global_position, destinations[0], _home_cell, PATROL_RADIUS_TILES, self)
		if candidate.size() > 1:
			_path = candidate
			_path_index = 1
			return
	if not destinations.is_empty() and _world.get_path_requests_used() >= WorldNavigation.PATH_REQUEST_BUDGET_PER_FRAME:
		_pause_time_left = randf_range(0.10, 0.20)
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
