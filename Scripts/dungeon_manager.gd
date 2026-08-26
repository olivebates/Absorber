class_name DungeonManager
extends Node

signal dungeon_entered(dungeon_id: StringName)
signal dungeon_left(dungeon_id: StringName)
signal dungeon_state_changed(dungeon_id: StringName)
signal dungeon_keys_changed(dungeon_id: StringName, amount: int)

const WARNING_TEXT := "You're about to enter a dungeon.\n\nIn a dungeon your stats are temporarily reset.\nYou will keep any rewards you gain during the dungeon.\nYour stats will be restored once you leave the dungeon again.\n\nLeave at any time through the map by pressing M/TAB."
const CAVE_MOSS_ID := &"cave_moss"
const CAVE_MOSS_INTERVAL := 600.0
const TRANSITION_GROW_TIME := 0.42
const TRANSITION_SHRINK_TIME := 0.24
const TRANSITION_FADE_TIME := 0.20
const DUNGEON_VIEW_SIZE := Vector2i(1280, 720)
const DAMAGE_ICON := preload("res://Sprites/DamageIcon.webp")
const HEALTH_ICON := preload("res://Sprites/Heart.webp")
const REGEN_ICON := preload("res://Sprites/RecoveryHeart.webp")
const DEFENSE_ICON := preload("res://Sprites/ShieldIcon.webp")
const KEY_ICON := preload("res://Sprites/IconKey.webp")
const PLAYER_PORTRAIT := preload("res://Sprites/Fox.webp")
const FIRST_EXIT_TEXT := "Phew, that was intense! But fun!"

var tutorial_seen := false
var first_exit_comment_seen := false
var dungeon_states: Dictionary = {}
var _last_moss_timestamp := 0
var _active_entrance: DungeonEntrance
var _active_level: DungeonLevel
var _active_id: StringName = &""
var _overworld_stats: Dictionary = {}
var _overworld_position := Vector2.ZERO
var _player_parent: Node
var _player_sibling_index := 0
var _camera: Camera2D
var _dungeon_camera: Camera2D
var _overworld_camera_screen_position := Vector2.ZERO
var _camera_smoothing_enabled := false
var _camera_smoothing_speed := 7.0
var _layer: CanvasLayer
var _container: SubViewportContainer
var _subviewport: SubViewport
var _key_panel: PanelContainer
var _key_label: Label
var _tutorial_layer: CanvasLayer
var _tutorial_overlay: Control
var _tutorial_button: Button
var _tutorial_pending_entrance: DungeonEntrance
var _transitioning := false

@onready var _world: WorldNavigation = get_parent() as WorldNavigation


func _ready() -> void:
	add_to_group("dungeon_manager")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_dungeon_layer()
	_build_key_hud()
	_build_tutorial_popup()
	_last_moss_timestamp = int(Time.get_unix_time_from_system())
	call_deferred("_refresh_cave_moss_production")


func _input(event: InputEvent) -> void:
	if is_instance_valid(_tutorial_overlay) and _tutorial_overlay.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			var tutorial_key_event := event as InputEventKey
			var tutorial_key := tutorial_key_event.physical_keycode if tutorial_key_event.physical_keycode != 0 else tutorial_key_event.keycode
			if tutorial_key == KEY_ENTER or tutorial_key == KEY_SPACE:
				_confirm_dungeon_tutorial()
				get_viewport().set_input_as_handled()
		return
	if not is_dungeon_active() or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	var key := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	if key == KEY_M or key == KEY_TAB:
		var world_map := _world.get_node_or_null("HUD/WorldMap") as WorldMap
		if world_map:
			if world_map.visible:
				world_map.close()
			else:
				world_map.open()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if is_instance_valid(_key_panel) and _key_panel.visible:
		var vitals := _world.get_node_or_null("HUD/PlayerVitals") as Control
		if vitals:
			_key_panel.position = Vector2(vitals.position.x, vitals.position.y + vitals.size.y + 4.0)


func is_dungeon_active() -> bool:
	return is_instance_valid(_active_level)


func is_transitioning() -> bool:
	return _transitioning


func get_active_level() -> DungeonLevel:
	return _active_level


func get_active_dungeon_id() -> StringName:
	return _active_id


func request_enter(entrance: DungeonEntrance) -> void:
	if entrance == null or entrance.dungeon_scene == null or is_dungeon_active() or _transitioning \
		or (is_instance_valid(_tutorial_overlay) and _tutorial_overlay.visible):
		return
	_active_entrance = entrance
	if not tutorial_seen:
		_show_dungeon_tutorial(entrance)
		return
	_begin_entry(entrance)


func _begin_entry(entrance: DungeonEntrance) -> void:
	if entrance == null or entrance.dungeon_scene == null or is_dungeon_active() or _transitioning:
		return
	_active_entrance = entrance
	_transitioning = true
	_world.interaction_locked = true
	var player := _world.player
	_overworld_position = player.global_position
	player.stop()
	player.begin_scripted_movement()
	var sprite := player.fox_sprite
	var original_sprite_position := sprite.position
	var original_sprite_scale := sprite.scale
	var tween := create_tween().set_parallel(true)
	tween.tween_property(player, "global_position", entrance.global_position, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", Vector2(0.05, 0.05), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var walk := create_tween().set_loops(5)
	walk.tween_property(sprite, "rotation", 0.08, 0.10).set_trans(Tween.TRANS_SINE)
	walk.parallel().tween_property(sprite, "position:y", original_sprite_position.y - 4.0, 0.10).set_trans(Tween.TRANS_SINE)
	walk.tween_property(sprite, "rotation", -0.08, 0.10).set_trans(Tween.TRANS_SINE)
	walk.parallel().tween_property(sprite, "position:y", original_sprite_position.y, 0.10).set_trans(Tween.TRANS_SINE)
	await tween.finished
	if walk and walk.is_valid():
		walk.kill()
	sprite.position = original_sprite_position
	sprite.rotation = 0.0
	sprite.scale = original_sprite_scale
	await _open_dungeon(entrance)


func _open_dungeon(entrance: DungeonEntrance) -> void:
	var player := _world.player
	_active_id = entrance.dungeon_id
	_overworld_stats = _capture_stats(player)
	_player_parent = player.get_parent()
	_player_sibling_index = player.get_index()
	_camera = player.get_node_or_null("Camera2D") as Camera2D
	if _camera:
		_camera_smoothing_enabled = _camera.position_smoothing_enabled
		_camera_smoothing_speed = _camera.position_smoothing_speed

	_clear_subviewport()
	var instance := entrance.dungeon_scene.instantiate()
	if not instance is DungeonLevel:
		push_error("Dungeon scene %s must have DungeonLevel as its root." % entrance.dungeon_scene.resource_path)
		player.end_scripted_movement()
		_transitioning = false
		_world.interaction_locked = false
		return
	_active_level = instance as DungeonLevel
	_subviewport.add_child(_active_level)
	if _camera:
		_overworld_camera_screen_position = _camera.get_screen_center_position()
		_camera.reparent(_world, true)
		_camera.global_position = _overworld_camera_screen_position
		_camera.position_smoothing_enabled = false
	player.reparent(_active_level, false)
	_dungeon_camera = Camera2D.new()
	_dungeon_camera.name = "DungeonCamera"
	_dungeon_camera.enabled = true
	_dungeon_camera.position_smoothing_enabled = false
	_active_level.add_child(_dungeon_camera)
	_active_level.attach_player(player, _dungeon_camera, self)

	var state := _get_or_create_state(_active_id)
	_apply_stats(player, state.get("stats", _make_reset_stats()) as Dictionary)
	player.health = clampi(int((state.get("stats", {}) as Dictionary).get("health", player.max_health)), 1, player.max_health)
	player.health_bar.value = player.health
	player._update_health_label()
	player.vitals_changed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_active_level.load_snapshot(state.get("level", {}) as Dictionary)
	_update_key_hud()
	_key_panel.show()

	_container.show()
	_container.pivot_offset = Vector2(DUNGEON_VIEW_SIZE) * 0.5
	_container.scale = Vector2(0.02, 0.02)
	_container.modulate.a = 0.0
	var grow := create_tween().set_parallel(true)
	grow.tween_property(_container, "scale", Vector2.ONE, TRANSITION_GROW_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grow.tween_property(_container, "modulate:a", 1.0, TRANSITION_GROW_TIME * 0.65)
	await grow.finished
	var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
	if audio:
		audio.show_area_name(entrance.dungeon_name)
	player.end_scripted_movement()
	_transitioning = false
	_active_level.interaction_locked = false
	dungeon_entered.emit(_active_id)


func leave_dungeon(dungeon_animation_remaining := 0.0) -> void:
	if not is_dungeon_active() or _transitioning:
		return
	_transitioning = true
	_active_level.interaction_locked = true
	_world.player.begin_scripted_movement()
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui") as DialogueBox
	if dialogue and dialogue.is_open():
		dialogue.close()
	_world.get_node("HUD/WorldMap").call("close")
	var leaving_id := _active_id
	var show_first_exit_comment := not first_exit_comment_seen
	first_exit_comment_seen = true
	var state := _get_or_create_state(leaving_id)
	var dungeon_stats := _capture_stats(_world.player)
	state["stats"] = dungeon_stats
	state["level"] = _active_level.capture_snapshot()
	var level_state := state["level"] as Dictionary
	state["cleared"] = bool(state.get("cleared", false)) or bool(level_state.get("cleared", false))
	var transferred := state.get("transferred_stats", _make_reset_stats()) as Dictionary
	var rewards := _collect_stat_rewards(transferred, dungeon_stats)
	state["transferred_stats"] = dungeon_stats.duplicate(true)
	dungeon_states[str(leaving_id)] = state
	_refresh_cave_moss_production()
	dungeon_state_changed.emit(leaving_id)

	var player := _world.player
	var overworld_entrance_position := _active_entrance.global_position if is_instance_valid(_active_entrance) else _overworld_position
	if _camera:
		_camera.position_smoothing_enabled = false
		_camera.global_position = overworld_entrance_position
		_camera.reset_smoothing()
		_camera.force_update_scroll()
	var shrink := create_tween().set_parallel(true)
	shrink.tween_property(_container, "scale", Vector2(0.02, 0.02), TRANSITION_SHRINK_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	shrink.tween_property(_container, "modulate:a", 0.0, TRANSITION_FADE_TIME)
	await shrink.finished
	var animation_hold := maxf(float(dungeon_animation_remaining) - TRANSITION_SHRINK_TIME, 0.0)
	if animation_hold > 0.0:
		await get_tree().create_timer(animation_hold).timeout

	player.reparent(_player_parent, false)
	_player_parent.move_child(player, mini(_player_sibling_index, _player_parent.get_child_count() - 1))
	player.global_position = overworld_entrance_position
	if _camera:
		_camera.reparent(player, true)
		_camera.position = Vector2.ZERO
		_camera.position_smoothing_speed = _camera_smoothing_speed
		_camera.position_smoothing_enabled = _camera_smoothing_enabled
		_camera.reset_smoothing()
		_camera.force_update_scroll()
	_apply_stats(player, _overworld_stats)
	player.health = clampi(int(_overworld_stats.get("health", player.max_health)), 1, player.max_health)
	player.health_bar.value = player.health
	player._update_health_label()
	player.vitals_changed.emit()

	_key_panel.hide()
	_container.hide()
	_subviewport.remove_child(_active_level)
	_active_level.queue_free()
	_active_level = null
	_dungeon_camera = null
	await _play_overworld_exit_animation(player, _overworld_position)
	_active_id = &""
	_active_entrance = null
	_world.interaction_locked = false
	_transitioning = false
	dungeon_left.emit(leaving_id)
	if show_first_exit_comment:
		_play_first_exit_comment()
	_apply_stat_rewards_over_time(rewards)
	var save_system := get_tree().get_first_node_in_group("save_system") as SaveSystem
	if save_system and save_system._automatic_saves_enabled:
		save_system.save_auto()


func _play_overworld_exit_animation(player: FoxPlayer, destination: Vector2) -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.fox_sprite):
		if is_instance_valid(player):
			player.end_scripted_movement()
		return
	var sprite := player.fox_sprite
	var original_sprite_position := sprite.position
	var original_sprite_rotation := sprite.rotation
	var original_sprite_scale := sprite.scale
	sprite.scale = Vector2(0.05, 0.05)
	var emerge := create_tween().set_parallel(true)
	emerge.tween_property(player, "global_position", destination, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	emerge.tween_property(sprite, "scale", original_sprite_scale, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var walk := create_tween().set_loops(5)
	walk.tween_property(sprite, "rotation", -0.08, 0.10).set_trans(Tween.TRANS_SINE)
	walk.parallel().tween_property(sprite, "position:y", original_sprite_position.y - 4.0, 0.10).set_trans(Tween.TRANS_SINE)
	walk.tween_property(sprite, "rotation", 0.08, 0.10).set_trans(Tween.TRANS_SINE)
	walk.parallel().tween_property(sprite, "position:y", original_sprite_position.y, 0.10).set_trans(Tween.TRANS_SINE)
	await emerge.finished
	if walk and walk.is_valid():
		walk.kill()
	if is_instance_valid(sprite):
		sprite.position = original_sprite_position
		sprite.rotation = original_sprite_rotation
		sprite.scale = original_sprite_scale
	if is_instance_valid(player):
		player.global_position = destination
		player.end_scripted_movement()


func get_key_count(dungeon_id: StringName = &"") -> int:
	var id := _active_id if dungeon_id.is_empty() else dungeon_id
	if id.is_empty():
		return 0
	return int(_get_or_create_state(id).get("keys", 0))


func add_key(amount := 1) -> void:
	if _active_id.is_empty() or amount <= 0:
		return
	var state := _get_or_create_state(_active_id)
	state["keys"] = int(state.get("keys", 0)) + amount
	dungeon_states[str(_active_id)] = state
	_update_key_hud()
	dungeon_keys_changed.emit(_active_id, int(state.get("keys", 0)))


func consume_key() -> bool:
	if get_key_count() <= 0:
		return false
	var state := _get_or_create_state(_active_id)
	state["keys"] = int(state.get("keys", 0)) - 1
	dungeon_states[str(_active_id)] = state
	_update_key_hud()
	dungeon_keys_changed.emit(_active_id, int(state.get("keys", 0)))
	return true


func is_cleared(dungeon_id: StringName) -> bool:
	return bool(_get_or_create_state(dungeon_id).get("cleared", false))


func get_save_data() -> Array:
	return [tutorial_seen, dungeon_states.duplicate(true), int(Time.get_unix_time_from_system()), first_exit_comment_seen]


func load_save_data(data: Array, offline_seconds: int) -> bool:
	if data.is_empty():
		return false
	tutorial_seen = bool(data[0])
	dungeon_states = (data[1] as Dictionary).duplicate(true) if data.size() > 1 and data[1] is Dictionary else {}
	_last_moss_timestamp = int(data[2]) if data.size() > 2 else int(Time.get_unix_time_from_system()) - offline_seconds
	first_exit_comment_seen = bool(data[3]) if data.size() > 3 else false
	var cleared_count := _get_cleared_count()
	if cleared_count > 0 and offline_seconds > 0:
		var resources := get_tree().get_first_node_in_group("resource_manager") as ResourceManager
		if resources:
			resources.add_resource(CAVE_MOSS_ID, float(offline_seconds * cleared_count) / CAVE_MOSS_INTERVAL)
	_refresh_cave_moss_production()
	dungeon_state_changed.emit(&"")
	return true


func _get_or_create_state(dungeon_id: StringName) -> Dictionary:
	var key := str(dungeon_id)
	if not dungeon_states.has(key):
		var reset := _make_reset_stats()
		dungeon_states[key] = {
			"keys": 0,
			"stats": reset.duplicate(true),
			"transferred_stats": reset.duplicate(true),
			"level": {},
			"cleared": false,
		}
	return dungeon_states[key] as Dictionary


func _capture_stats(player: FoxPlayer) -> Dictionary:
	return {
		"health": player.health,
		"max_health": player.max_health,
		"regeneration": player.passive_healing_amount,
		"damage": player.damage_by_color.duplicate(true),
		"defense": player.defense_by_color.duplicate(),
	}


func _make_reset_stats() -> Dictionary:
	return {
		"health": 1,
		"max_health": 1,
		"regeneration": 1,
		"damage": [[1, 1, 1, 1], [1, 1, 1, 1], [1, 1, 1, 1]],
		"defense": [1, 1, 1],
	}


func _apply_stats(player: FoxPlayer, stats: Dictionary) -> void:
	player.max_health = maxi(1, int(stats.get("max_health", 1)))
	player.passive_healing_amount = maxi(1, int(stats.get("regeneration", 1)))
	var raw_damage := stats.get("damage", [[1, 1, 1, 1], [1, 1, 1, 1], [1, 1, 1, 1]]) as Array
	player.damage_by_color = raw_damage.duplicate(true)
	var raw_defense := stats.get("defense", [1, 1, 1]) as Array
	player.defense_by_color.clear()
	for value in raw_defense:
		player.defense_by_color.append(maxi(0, int(value)))
	while player.defense_by_color.size() < 3:
		player.defense_by_color.append(1)
	player.attack_damage = player.get_damage_for_color(FoxPlayer.COLOR_RED)
	player.health_bar.max_value = player.max_health
	player.damage_matrix_changed.emit()


func _collect_stat_rewards(previous: Dictionary, current: Dictionary) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	var health_delta := int(current.get("max_health", 1)) - int(previous.get("max_health", 1))
	if health_delta > 0:
		rewards.append({"kind": "health", "amount": health_delta, "icon": HEALTH_ICON})
	var regen_delta := int(current.get("regeneration", 1)) - int(previous.get("regeneration", 1))
	if regen_delta > 0:
		rewards.append({"kind": "regeneration", "amount": regen_delta, "icon": REGEN_ICON})
	var old_damage := previous.get("damage", []) as Array
	var new_damage := current.get("damage", []) as Array
	for color in range(mini(old_damage.size(), new_damage.size())):
		for weapon in range(mini((old_damage[color] as Array).size(), (new_damage[color] as Array).size())):
			var delta := int(new_damage[color][weapon]) - int(old_damage[color][weapon])
			if delta > 0:
				rewards.append({"kind": "damage", "amount": delta, "color": color, "weapon": weapon, "icon": DAMAGE_ICON})
	var old_defense := previous.get("defense", []) as Array
	var new_defense := current.get("defense", []) as Array
	for color in range(mini(old_defense.size(), new_defense.size())):
		var delta := int(new_defense[color]) - int(old_defense[color])
		if delta > 0:
			rewards.append({"kind": "defense", "amount": delta, "color": color, "icon": DEFENSE_ICON})
	return rewards


func _apply_stat_rewards_over_time(rewards: Array[Dictionary]) -> void:
	for reward in rewards:
		for _frame in range(10):
			await get_tree().process_frame
		await _fly_stat_reward(reward)
	var save_system := get_tree().get_first_node_in_group("save_system") as SaveSystem
	if save_system and save_system._automatic_saves_enabled:
		save_system.save_auto()


func _fly_stat_reward(reward: Dictionary) -> void:
	if not is_instance_valid(_world.player):
		return
	var icon := TextureRect.new()
	icon.texture = reward.get("icon") as Texture2D
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.get_node("HUD").add_child(icon)
	var start := _world.player.get_global_transform_with_canvas().origin - icon.size * 0.5
	var target := _get_reward_target(reward) - icon.size * 0.5
	icon.position = start
	var tween := icon.create_tween().set_parallel(true)
	tween.tween_property(icon, "position", target, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(icon, "rotation", TAU, 0.38)
	tween.tween_property(icon, "scale", Vector2(0.7, 0.7), 0.38)
	await tween.finished
	_apply_single_stat_reward(reward)
	icon.queue_free()


func _get_reward_target(reward: Dictionary) -> Vector2:
	var kind := str(reward.get("kind", ""))
	if kind == "damage":
		var grid := _world.get_node_or_null("HUD/DamageGrid") as DamageGrid
		return grid.get_color_target_screen_position(int(reward.get("color", 0))) if grid else Vector2(42, 42)
	if kind == "defense":
		var armor = _world.get_node_or_null("HUD/ArmorGrid")
		return armor.get_color_target_screen_position(int(reward.get("color", 0))) if armor else Vector2(90, 42)
	var vitals := _world.get_node_or_null("HUD/PlayerVitals") as PlayerVitals
	return vitals.get_stat_target_screen_position(&"regeneration" if kind == "regeneration" else &"health") if vitals else Vector2(60, 120)


func _apply_single_stat_reward(reward: Dictionary) -> void:
	var player := _world.player
	var amount := int(reward.get("amount", 0))
	match str(reward.get("kind", "")):
		"health":
			player.add_max_health(amount)
		"regeneration":
			player.add_passive_healing(amount)
		"damage":
			var color := int(reward.get("color", 0))
			var weapon := int(reward.get("weapon", 0))
			player.damage_by_color[color][weapon] += amount
			player.attack_damage = player.get_damage_for_color(FoxPlayer.COLOR_RED)
			player.damage_matrix_changed.emit()
		"defense":
			player.add_color_defense(int(reward.get("color", 0)), amount)
	var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
	if audio:
		audio.play_upgrade()


func _build_dungeon_layer() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "DungeonLayer"
	_layer.layer = 0
	add_child(_layer)
	_container = SubViewportContainer.new()
	_container.name = "DungeonViewportContainer"
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_container.hide()
	_layer.add_child(_container)
	_subviewport = SubViewport.new()
	_subviewport.name = "DungeonViewport"
	_subviewport.size = DUNGEON_VIEW_SIZE
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_subviewport.handle_input_locally = true
	_container.add_child(_subviewport)


func _build_tutorial_popup() -> void:
	_tutorial_layer = CanvasLayer.new()
	_tutorial_layer.name = "DungeonTutorialLayer"
	_tutorial_layer.layer = 1100
	add_child(_tutorial_layer)
	var backdrop := ColorRect.new()
	_tutorial_overlay = backdrop
	backdrop.name = "DungeonTutorialPopup"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.62)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_tutorial_layer.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.065, 0.98)
	style.border_color = Color("d6b94c")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)
	var title := Label.new()
	title.text = "Entering a Dungeon"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("ffe082"))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	content.add_child(title)
	var message := Label.new()
	message.text = WARNING_TEXT
	message.custom_minimum_size = Vector2(564, 0)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 18)
	message.add_theme_color_override("font_color", Color.WHITE)
	content.add_child(message)
	_tutorial_button = Button.new()
	_tutorial_button.text = "Enter Dungeon"
	_tutorial_button.custom_minimum_size = Vector2(0, 42)
	_tutorial_button.pressed.connect(_confirm_dungeon_tutorial)
	content.add_child(_tutorial_button)
	backdrop.hide()


func _show_dungeon_tutorial(entrance: DungeonEntrance) -> void:
	_tutorial_pending_entrance = entrance
	_world.interaction_locked = true
	_tutorial_overlay.show()
	_tutorial_button.grab_focus()


func _confirm_dungeon_tutorial() -> void:
	if not is_instance_valid(_tutorial_overlay) or not _tutorial_overlay.visible:
		return
	var entrance := _tutorial_pending_entrance
	_tutorial_pending_entrance = null
	_tutorial_overlay.hide()
	tutorial_seen = true
	if is_instance_valid(entrance):
		_begin_entry(entrance)
	else:
		_world.interaction_locked = false


func _play_first_exit_comment() -> void:
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui") as DialogueBox
	if dialogue:
		dialogue.play([{
			"speaker": "Mira",
			"text": FIRST_EXIT_TEXT,
			"portrait": PLAYER_PORTRAIT,
		}])


func _clear_subviewport() -> void:
	for child in _subviewport.get_children():
		_subviewport.remove_child(child)
		child.queue_free()


func _build_key_hud() -> void:
	_key_panel = PanelContainer.new()
	_key_panel.name = "DungeonKeyCounter"
	_key_panel.position = Vector2(12, 154)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.15, 0.95)
	style.border_color = Color(0.28, 0.33, 0.42, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_key_panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_key_panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = KEY_ICON
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	_key_label = Label.new()
	_key_label.add_theme_color_override("font_color", Color.WHITE)
	_key_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_key_label.add_theme_constant_override("outline_size", 2)
	row.add_child(_key_label)
	_key_panel.hide()
	_world.get_node("HUD").add_child(_key_panel)


func _update_key_hud() -> void:
	if is_instance_valid(_key_label):
		_key_label.text = str(get_key_count())


func _refresh_cave_moss_production() -> void:
	var resources := get_tree().get_first_node_in_group("resource_manager") as ResourceManager
	if resources == null:
		return
	var definition := resources.get_definition(CAVE_MOSS_ID)
	if definition == null:
		return
	definition.production_speed = float(_get_cleared_count()) / CAVE_MOSS_INTERVAL
	resources.production_changed.emit(CAVE_MOSS_ID, resources.get_production_speed(CAVE_MOSS_ID))


func _get_cleared_count() -> int:
	var result := 0
	for raw_state in dungeon_states.values():
		if raw_state is Dictionary and bool((raw_state as Dictionary).get("cleared", false)):
			result += 1
	return result
