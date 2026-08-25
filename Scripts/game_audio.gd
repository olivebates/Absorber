class_name GameAudio
extends Node

const GRASS_TRACKS: Array[AudioStream] = [
	preload("res://Music/Grass1.mp3"),
	preload("res://Music/Grass2.mp3"),
]
const DESERT_TRACKS: Array[AudioStream] = [
	preload("res://Music/Desert1.mp3"),
	preload("res://Music/Desert2.mp3"),
]
const FOREST_TRACKS: Array[AudioStream] = [
	preload("res://Music/Forrest1.mp3"),
	preload("res://Music/Forrest2.mp3"),
]
const BOSS_TRACK: AudioStream = preload("res://Music/Boss.mp3")
const PURCHASE_SFX: AudioStream = preload("res://Music/sfxPurchase.ogg")
const UPGRADE_SFX: AudioStream = preload("res://Music/sfxUpgrade.ogg")
const DAMAGE_SFX: AudioStream = preload("res://Music/sfxDamage.ogg")
const DEATH_SFX: AudioStream = preload("res://Music/sfxDeath.ogg")
const RESPAWN_SFX: AudioStream = preload("res://Music/sfxRespawn.mp3")
const BUILDING_SFX: AudioStream = preload("res://Music/sfxBuilding.ogg")
const WALKING_SFX: AudioStream = preload("res://Music/sfxWalking.ogg")
const EATING_SFX: AudioStream = preload("res://Music/sfxEating.ogg")
const OPEN_GATE_SFX: AudioStream = preload("res://Music/sfxOpenGate.mp3")
const ASHA_JOINS_SFX: AudioStream = preload("res://Music/AshaJoins.mp3")

const SILENT_DB := -80.0
const MUSIC_DB := -8.0
const FADE_SECONDS := 3.0
const BOSS_FADE_IN_SECONDS := 0.12
const MUSIC_CHECK_INTERVAL := 0.15
const RECRUITMENT_MUSIC_FADE_SECONDS := 0.22
const LIO_FIGHT_AUDIBLE_TILES := 8.0
const BOSS_CAMERA_ZOOM := Vector2(1.12, 1.12)
const GRASS_AREA_NAME := "~ Tiny Woods ~"
const FOREST_AREA_NAME := "~ Whippersnapper Woods ~"
const DESERT_AREA_NAME := "~ The Snakemouth Expanse ~"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const AUDIO_SETTINGS_PATH := "user://audio_settings.json"

enum Biome { NONE, GRASS, FOREST, DESERT, BOSS }

var _world: WorldNavigation
var _grass_player: AudioStreamPlayer
var _forest_player: AudioStreamPlayer
var _desert_player: AudioStreamPlayer
var _boss_player: AudioStreamPlayer
var _walking_player: AudioStreamPlayer
var _area_label: Label
var _area_title_tween: Tween
var _grass_track_index := 0
var _forest_track_index := 0
var _desert_track_index := 0
var _desert_tracks: Array[AudioStream] = []
var _active_biome := Biome.NONE
var _check_time_left := 0.0
var _fade_tweens: Dictionary = {}
var _music_enabled := false
var _grass_heard := false
var _forest_heard := false
var _desert_heard := false
var _boss_heard := false
var _boss_zoom_active := false
var _normal_camera_zoom := Vector2.ONE
var _camera_zoom_initialized := false
var _boss_zoom_tween: Tween
var _recruitment_music_ducked := false
var music_volume := 1.0
var sfx_volume := 1.0


func setup(world: WorldNavigation) -> void:
	_world = world


func _ready() -> void:
	add_to_group("game_audio")
	_ensure_audio_buses()
	_load_volume_settings()
	_desert_tracks.assign(DESERT_TRACKS)
	_grass_player = _make_music_player("GrassMusic")
	_forest_player = _make_music_player("ForestMusic")
	_desert_player = _make_music_player("DesertMusic")
	_boss_player = _make_music_player("BossMusic")
	_walking_player = AudioStreamPlayer.new()
	_walking_player.name = "WalkingSfx"
	_walking_player.stream = WALKING_SFX
	_walking_player.bus = SFX_BUS
	_walking_player.volume_db = linear_to_db(0.05)
	add_child(_walking_player)
	_grass_player.finished.connect(_on_grass_finished)
	_forest_player.finished.connect(_on_forest_finished)
	_desert_player.finished.connect(_on_desert_finished)
	_boss_player.finished.connect(_on_boss_finished)
	_start_current_track(Biome.GRASS)
	_start_current_track(Biome.FOREST)
	_start_current_track(Biome.DESERT)
	_start_current_track(Biome.BOSS)
	_grass_player.stream_paused = true
	_forest_player.stream_paused = true
	_desert_player.stream_paused = true
	_boss_player.stream_paused = true
	_create_area_label()


func _process(delta: float) -> void:
	if not _music_enabled:
		return
	_check_time_left -= delta
	if _check_time_left > 0.0:
		return
	_check_time_left = MUSIC_CHECK_INTERVAL
	_update_biome_music()


func play_purchase() -> void:
	_play_sfx(PURCHASE_SFX, false, 0.6)


func play_upgrade() -> void:
	_play_sfx(UPGRADE_SFX, true, 0.245)


func play_damage() -> void:
	_play_sfx(DAMAGE_SFX)


func play_lio_fight(source_position: Vector2) -> void:
	var volume_scale := get_lio_fight_volume_scale(source_position)
	if volume_scale <= 0.0:
		return
	_play_sfx(DAMAGE_SFX, true, volume_scale)


func get_lio_fight_volume_scale(source_position: Vector2) -> float:
	if not is_instance_valid(_world) or not is_instance_valid(_world.player):
		return 0.0
	var distance_tiles := source_position.distance_to(_world.player.global_position) / WorldNavigation.TILE_SIZE
	if distance_tiles <= 1.0:
		return 1.0
	return 1.0 - clampf((distance_tiles - 1.0) / (LIO_FIGHT_AUDIBLE_TILES - 1.0), 0.0, 1.0)


func play_death() -> void:
	_play_sfx(DEATH_SFX, false)


func play_respawn() -> void:
	_play_sfx(RESPAWN_SFX, false)


func play_building() -> void:
	_play_sfx(BUILDING_SFX, false)


func play_eating() -> void:
	_play_sfx(EATING_SFX, false)


func play_open_gate() -> void:
	_play_sfx(OPEN_GATE_SFX, false, 0.65)


func play_asha_joins() -> void:
	_play_sfx(ASHA_JOINS_SFX, false)


func set_recruitment_music_ducked(ducked: bool) -> void:
	if ducked == _recruitment_music_ducked:
		return
	_recruitment_music_ducked = ducked
	var players := {
		Biome.GRASS: _grass_player,
		Biome.FOREST: _forest_player,
		Biome.DESERT: _desert_player,
		Biome.BOSS: _boss_player,
	}
	for biome in players:
		var player := players[biome] as AudioStreamPlayer
		if not is_instance_valid(player):
			continue
		var old_tween := _fade_tweens.get(player) as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()
		var target_db := MUSIC_DB if not ducked and biome == _active_biome else SILENT_DB
		var tween := create_tween()
		_fade_tweens[player] = tween
		tween.tween_property(player, "volume_db", target_db, RECRUITMENT_MUSIC_FADE_SECONDS)


func play_walking_step() -> void:
	_walking_player.pitch_scale = randf_range(0.8, 1.2)
	_walking_player.play()


func enable_biome_music() -> void:
	_music_enabled = true
	_check_time_left = 0.0


func _make_music_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.volume_db = SILENT_DB
	player.bus = MUSIC_BUS
	add_child(player)
	return player


func _update_biome_music() -> void:
	if not is_instance_valid(_world) or not is_instance_valid(_world.player):
		_set_boss_camera_zoom(false)
		_set_active_biome(Biome.NONE)
		return
	var fighting_boss := _is_player_fighting_boss()
	_set_boss_camera_zoom(fighting_boss)
	if fighting_boss:
		_set_active_biome(Biome.BOSS)
		return
	var player_cell := _world.world_to_cell(_world.player.global_position)
	if _has_nearby_floor_tile(player_cell, 0):
		_set_active_biome(Biome.GRASS)
	elif _has_nearby_floor_tile(player_cell, 1):
		_set_active_biome(Biome.FOREST)
	elif _has_nearby_floor_tile(player_cell, 2):
		_set_active_biome(Biome.DESERT)
	else:
		_set_active_biome(Biome.NONE)


func _has_nearby_floor_tile(center: Vector2i, atlas_row: int) -> bool:
	for y in range(-2, 3):
		for x in range(-2, 3):
			var offset := Vector2i(x, y)
			if offset.length_squared() >= 9:
				continue
			var atlas := _world.floor_layer.get_cell_atlas_coords(center + offset)
			if atlas.y == atlas_row and atlas.x >= 0 and atlas.x < 3:
				return true
	return false


func _set_active_biome(biome: Biome) -> void:
	if not _music_enabled:
		return
	if biome == _active_biome:
		return
	_active_biome = biome
	_fade_music(_grass_player, biome == Biome.GRASS, Biome.GRASS)
	_fade_music(_forest_player, biome == Biome.FOREST, Biome.FOREST)
	_fade_music(_desert_player, biome == Biome.DESERT, Biome.DESERT)
	_fade_music(_boss_player, biome == Biome.BOSS, Biome.BOSS)
	if biome == Biome.BOSS:
		_boss_player.play(0.0)
	elif biome != Biome.NONE:
		var area_name := GRASS_AREA_NAME if biome == Biome.GRASS else FOREST_AREA_NAME if biome == Biome.FOREST else DESERT_AREA_NAME
		_show_area_name(area_name)


func _fade_music(player: AudioStreamPlayer, fade_in: bool, biome: Biome) -> void:
	if not is_instance_valid(player):
		return
	var old_tween := _fade_tweens.get(player) as Tween
	if old_tween and old_tween.is_valid():
		old_tween.kill()
	var first_listen := fade_in and not _has_heard_biome(biome)
	if first_listen:
		_mark_biome_heard(biome)
		player.stream_paused = false
		player.play(0.0)
	elif fade_in and player.stream_paused:
		player.stream_paused = false
	if fade_in and not player.playing:
		_start_current_track(biome)
	var tween := create_tween()
	_fade_tweens[player] = tween
	var target_db := MUSIC_DB if fade_in and not _recruitment_music_ducked else SILENT_DB
	var fade_seconds := BOSS_FADE_IN_SECONDS if fade_in and biome == Biome.BOSS else FADE_SECONDS
	tween.tween_property(player, "volume_db", target_db, fade_seconds)


func _start_current_track(biome: Biome) -> void:
	if biome == Biome.GRASS:
		_grass_player.stream = GRASS_TRACKS[_grass_track_index]
		_grass_player.play()
	elif biome == Biome.FOREST:
		_forest_player.stream = FOREST_TRACKS[_forest_track_index]
		_forest_player.play()
	elif biome == Biome.DESERT and not _desert_tracks.is_empty():
		_desert_player.stream = _desert_tracks[_desert_track_index]
		_desert_player.play()
	elif biome == Biome.BOSS:
		_boss_player.stream = BOSS_TRACK
		_boss_player.play()


func _on_grass_finished() -> void:
	_grass_track_index = (_grass_track_index + 1) % GRASS_TRACKS.size()
	_start_current_track(Biome.GRASS)


func _on_forest_finished() -> void:
	_forest_track_index = (_forest_track_index + 1) % FOREST_TRACKS.size()
	_start_current_track(Biome.FOREST)


func _on_desert_finished() -> void:
	_desert_track_index = (_desert_track_index + 1) % _desert_tracks.size()
	_start_current_track(Biome.DESERT)


func _on_boss_finished() -> void:
	if _active_biome == Biome.BOSS:
		_start_current_track(Biome.BOSS)


func _has_heard_biome(biome: Biome) -> bool:
	match biome:
		Biome.GRASS:
			return _grass_heard
		Biome.FOREST:
			return _forest_heard
		Biome.DESERT:
			return _desert_heard
		Biome.BOSS:
			return _boss_heard
	return false


func _mark_biome_heard(biome: Biome) -> void:
	match biome:
		Biome.GRASS:
			_grass_heard = true
		Biome.FOREST:
			_forest_heard = true
		Biome.DESERT:
			_desert_heard = true
		Biome.BOSS:
			_boss_heard = true


func _is_player_fighting_boss() -> bool:
	if not is_instance_valid(_world) or not is_instance_valid(_world.player) or _world.player.health <= 0 or _world.gameplay_paused:
		return false
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is ChickenEnemy or not is_instance_valid(node) or node.health <= 0:
			continue
		var enemy := node as ChickenEnemy
		if is_instance_valid(enemy.spawn_point) and enemy.spawn_point.boss \
			and not enemy.spawn_point.emptied_once and _world.are_adjacent(_world.player, enemy):
			return true
	return false


func _set_boss_camera_zoom(active: bool) -> void:
	if not is_instance_valid(_world) or not is_instance_valid(_world.player):
		return
	var camera := _world.player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	if not _camera_zoom_initialized:
		_normal_camera_zoom = camera.zoom
		_camera_zoom_initialized = true
	if active == _boss_zoom_active:
		return
	_boss_zoom_active = active
	if _boss_zoom_tween and _boss_zoom_tween.is_valid():
		_boss_zoom_tween.kill()
	_boss_zoom_tween = camera.create_tween()
	_boss_zoom_tween.tween_property(camera, "zoom", _normal_camera_zoom * BOSS_CAMERA_ZOOM if active else _normal_camera_zoom, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _create_area_label() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "AreaTitleLayer"
	canvas.layer = 900
	add_child(canvas)
	_area_label = Label.new()
	_area_label.name = "AreaTitle"
	canvas.add_child(_area_label)
	_area_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_area_label.offset_top = 28.0
	_area_label.offset_bottom = 82.0
	_area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_area_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_area_label.add_theme_font_size_override("font_size", 36)
	_area_label.add_theme_color_override("font_color", Color.WHITE)
	_area_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_area_label.add_theme_constant_override("outline_size", 8)
	_area_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area_label.modulate.a = 0.0


func _show_area_name(area_name: String) -> void:
	if _area_title_tween and _area_title_tween.is_valid():
		_area_title_tween.kill()
	_area_label.text = area_name
	_area_label.modulate.a = 0.0
	_area_title_tween = create_tween()
	_area_title_tween.tween_property(_area_label, "modulate:a", 1.0, 0.25)
	_area_title_tween.tween_interval(1.5)
	_area_title_tween.tween_property(_area_label, "modulate:a", 0.0, 0.5)


func _play_sfx(stream: AudioStream, randomize_pitch := true, volume_scale := 1.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = SFX_BUS
	player.pitch_scale = randf_range(0.8, 1.2) if randomize_pitch else 1.0
	player.volume_db = linear_to_db(clampf(volume_scale, 0.0001, 1.0))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_set_bus_linear_volume(MUSIC_BUS, music_volume)
	_save_volume_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_set_bus_linear_volume(SFX_BUS, sfx_volume)
	_save_volume_settings()


func _ensure_audio_buses() -> void:
	for bus_name in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _set_bus_linear_volume(bus_name: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
		AudioServer.set_bus_mute(index, value <= 0.0)


func _load_volume_settings() -> void:
	if FileAccess.file_exists(AUDIO_SETTINGS_PATH):
		var file := FileAccess.open(AUDIO_SETTINGS_PATH, FileAccess.READ)
		if file:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				music_volume = clampf(float(parsed.get("music", 1.0)), 0.0, 1.0)
				sfx_volume = clampf(float(parsed.get("sfx", 1.0)), 0.0, 1.0)
	_set_bus_linear_volume(MUSIC_BUS, music_volume)
	_set_bus_linear_volume(SFX_BUS, sfx_volume)


func _save_volume_settings() -> void:
	var file := FileAccess.open(AUDIO_SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"music": music_volume, "sfx": sfx_volume}))
		file.close()
