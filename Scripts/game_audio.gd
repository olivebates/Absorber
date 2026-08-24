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
const PURCHASE_SFX: AudioStream = preload("res://Music/sfxPurchase.ogg")
const UPGRADE_SFX: AudioStream = preload("res://Music/sfxUpgrade.ogg")
const DAMAGE_SFX: AudioStream = preload("res://Music/sfxDamage.ogg")
const DEATH_SFX: AudioStream = preload("res://Music/sfxDeath.ogg")
const RESPAWN_SFX: AudioStream = preload("res://Music/sfxRespawn.mp3")
const BUILDING_SFX: AudioStream = preload("res://Music/sfxBuilding.ogg")
const WALKING_SFX: AudioStream = preload("res://Music/sfxWalking.ogg")

const SILENT_DB := -80.0
const MUSIC_DB := -8.0
const FADE_SECONDS := 3.0
const MUSIC_CHECK_INTERVAL := 0.15
const GRASS_AREA_NAME := "~ Tiny Woods ~"
const DESERT_AREA_NAME := "~ The Snakeland Expanse ~"

enum Biome { NONE, GRASS, DESERT }

var _world: WorldNavigation
var _grass_player: AudioStreamPlayer
var _desert_player: AudioStreamPlayer
var _walking_player: AudioStreamPlayer
var _area_label: Label
var _area_title_tween: Tween
var _grass_track_index := 0
var _desert_track_index := 0
var _desert_tracks: Array[AudioStream] = []
var _active_biome := Biome.NONE
var _check_time_left := 0.0
var _fade_tweens: Dictionary = {}
var _music_enabled := false
var _grass_heard := false
var _desert_heard := false


func setup(world: WorldNavigation) -> void:
	_world = world


func _ready() -> void:
	add_to_group("game_audio")
	_desert_tracks.assign(DESERT_TRACKS)
	_grass_player = _make_music_player("GrassMusic")
	_desert_player = _make_music_player("DesertMusic")
	_walking_player = AudioStreamPlayer.new()
	_walking_player.name = "WalkingSfx"
	_walking_player.stream = WALKING_SFX
	_walking_player.volume_db = linear_to_db(0.05)
	add_child(_walking_player)
	_grass_player.finished.connect(_on_grass_finished)
	_desert_player.finished.connect(_on_desert_finished)
	_start_current_track(Biome.GRASS)
	_start_current_track(Biome.DESERT)
	_grass_player.stream_paused = true
	_desert_player.stream_paused = true
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
	_play_sfx(PURCHASE_SFX, false)


func play_upgrade() -> void:
	_play_sfx(UPGRADE_SFX, true, 0.245)


func play_damage() -> void:
	_play_sfx(DAMAGE_SFX)


func play_death() -> void:
	_play_sfx(DEATH_SFX, false)


func play_respawn() -> void:
	_play_sfx(RESPAWN_SFX, false)


func play_building() -> void:
	_play_sfx(BUILDING_SFX, false)


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
	add_child(player)
	return player


func _update_biome_music() -> void:
	if not is_instance_valid(_world) or not is_instance_valid(_world.player):
		_set_active_biome(Biome.NONE)
		return
	var player_cell := _world.world_to_cell(_world.player.global_position)
	if _has_nearby_floor_tile(player_cell, 0):
		_set_active_biome(Biome.GRASS)
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
	_fade_music(_desert_player, biome == Biome.DESERT, Biome.DESERT)
	if biome != Biome.NONE:
		_show_area_name(GRASS_AREA_NAME if biome == Biome.GRASS else DESERT_AREA_NAME)


func _fade_music(player: AudioStreamPlayer, fade_in: bool, biome: Biome) -> void:
	if not is_instance_valid(player):
		return
	var old_tween := _fade_tweens.get(player) as Tween
	if old_tween and old_tween.is_valid():
		old_tween.kill()
	var first_listen := fade_in and (not _grass_heard if biome == Biome.GRASS else not _desert_heard)
	if first_listen:
		if biome == Biome.GRASS:
			_grass_heard = true
		else:
			_desert_heard = true
		player.stream_paused = false
		player.play(0.0)
	elif fade_in and player.stream_paused:
		player.stream_paused = false
	if not player.playing:
		_start_current_track(biome)
	var tween := create_tween()
	_fade_tweens[player] = tween
	tween.tween_property(player, "volume_db", MUSIC_DB if fade_in else SILENT_DB, FADE_SECONDS)


func _start_current_track(biome: Biome) -> void:
	if biome == Biome.GRASS:
		_grass_player.stream = GRASS_TRACKS[_grass_track_index]
		_grass_player.play()
	elif biome == Biome.DESERT and not _desert_tracks.is_empty():
		_desert_player.stream = _desert_tracks[_desert_track_index]
		_desert_player.play()


func _on_grass_finished() -> void:
	_grass_track_index = (_grass_track_index + 1) % GRASS_TRACKS.size()
	_start_current_track(Biome.GRASS)


func _on_desert_finished() -> void:
	_desert_track_index = (_desert_track_index + 1) % _desert_tracks.size()
	_start_current_track(Biome.DESERT)


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
	player.pitch_scale = randf_range(0.8, 1.2) if randomize_pitch else 1.0
	player.volume_db = linear_to_db(clampf(volume_scale, 0.0001, 1.0))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
