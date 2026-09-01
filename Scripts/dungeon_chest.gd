class_name DungeonChest
extends Node2D

enum RewardType { ITEM, DAMAGE, HEALTH, REGENERATION, DEFENSE, KEY, RESOURCE, SKILL, MANA, MANA_REGENERATION, INVENTORY_SLOT, EQUIPMENT_SLOT, SKILL_SLOT, BOSS_KEY }

const PLAYER_PORTRAIT := preload("res://Sprites/Fox.webp")
const CLOSED_TEXTURE := preload("res://Sprites/ChestClosed.webp")
const OPEN_TEXTURE := preload("res://Sprites/ChestOpen.webp")
const KEY_ICON := preload("res://Sprites/IconKey.webp")
const BOSS_KEY_ICON := preload("res://Sprites/bossKey.webp")
const DAMAGE_ICON := preload("res://Sprites/DamageIcon.webp")
const HEALTH_ICON := preload("res://Sprites/Heart.webp")
const REGEN_ICON := preload("res://Sprites/RecoveryHeart.webp")
const DEFENSE_ICON := preload("res://Sprites/ShieldIcon.webp")
const MANA_ICON := preload("res://Sprites/IconMana.webp")
const MANA_REGEN_ICON := preload("res://Sprites/iconManaRegen.webp")
const SKILL_BOOK_ICON := preload("res://Sprites/IconSkillBook.webp")
const ROLL_ICON := preload("res://Sprites/skillRoll.webp")
const EQUIPMENT_SLOT_ICON := preload("res://Sprites/HelmetIcon.webp")
const CHEST_SKILLS: Array[StringName] = [FoxPlayer.SKILL_ROLL_CLOCKWISE, FoxPlayer.SKILL_YELLOW_GUARD, FoxPlayer.SKILL_ROLL_BACK, FoxPlayer.SKILL_ROLL_ARC]
const HIDDEN_OUTLINE_COLOR := Color.WHITE
const HIDDEN_OUTLINE_INSET := 3.0
const HIDDEN_OUTLINE_SPACING := 8.0
const HIDDEN_OUTLINE_RADIUS := 1.5

@export_enum("Item", "Damage", "Health", "Regeneration", "Defense", "Key", "Resource", "Skill", "Mana", "Mana Regeneration", "Inventory Slot", "Equipment Slot", "Skill Slot", "Boss Key") var reward_type: int = RewardType.KEY
@export_range(1, 999, 1) var reward_amount := 1
@export_enum("Red", "Yellow", "Blue") var reward_color := FoxPlayer.COLOR_RED
@export var item_id := "weathered_sword"
@export_enum("Crude", "Ordinary", "Superior", "Elite", "Masterwork", "Mythic", "Divine", "Immortal", "Omnipotent", "Void") var item_grade := 0
@export var resource_id: StringName = &"cave_moss"
@export_enum("Quick Roll", "Golden Guard", "Back Roll", "Arc Roll") var reward_skill := 0

var opened := false
var _revealed := false
var _armed := false
var _pending_player: FoxPlayer
var _level: DungeonLevel
var _reward_display: Node2D

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("dungeon_room_objects")
	add_to_group("dungeon_chests")
	_sprite.texture = OPEN_TEXTURE if opened else CLOSED_TEXTURE
	_set_revealed(opened, false)
	_arm_after_spawns()


func _arm_after_spawns() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_armed = true


func request_interaction(player: FoxPlayer, world: WorldNavigation) -> void:
	if not _revealed or opened or player == null or not world is DungeonLevel:
		return
	_pending_player = player
	_level = world as DungeonLevel
	player.clear_attack_target()
	var path := _best_adjacent_path(player, _level)
	if not path.is_empty():
		player.follow_path(path)


func _process(_delta: float) -> void:
	if not is_instance_valid(_pending_player) or not is_instance_valid(_level):
		return
	if _level.are_adjacent(_pending_player, self):
		_pending_player.stop()
		var player := _pending_player
		_pending_player = null
		_open(player)
	elif not _pending_player.is_moving():
		_pending_player = null


func refresh_for_room(level_value: DungeonLevel) -> void:
	_level = level_value
	if _revealed or not _armed or level_value == null:
		return
	var room := level_value.cell_to_room(level_value.world_to_cell(global_position))
	if room != level_value.current_room:
		return
	if not level_value.has_current_room_enemies():
		_set_revealed(true, true)


func get_save_data() -> bool:
	return opened


func load_opened(value: bool) -> void:
	opened = value
	if is_instance_valid(_sprite):
		_sprite.texture = OPEN_TEXTURE if opened else CLOSED_TEXTURE
	_set_revealed(opened, false)


func _set_revealed(value: bool, play_sound: bool) -> void:
	_revealed = value
	visible = true
	if is_instance_valid(_sprite):
		_sprite.visible = value
	queue_redraw()
	if value:
		add_to_group("solid_walls")
		if opened:
			remove_from_group("dungeon_interactables")
		else:
			add_to_group("dungeon_interactables")
		if play_sound:
			var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
			if audio:
				audio.play_chest_visible()
	else:
		remove_from_group("solid_walls")
		remove_from_group("dungeon_interactables")


func _draw() -> void:
	if _revealed or opened:
		return
	var half_size := WorldNavigation.TILE_SIZE * 0.5 - HIDDEN_OUTLINE_INSET
	var corners := [
		Vector2(-half_size, -half_size),
		Vector2(half_size, -half_size),
		Vector2(half_size, half_size),
		Vector2(-half_size, half_size),
	]
	for side in range(corners.size()):
		var start: Vector2 = corners[side]
		var finish: Vector2 = corners[(side + 1) % corners.size()]
		var length := start.distance_to(finish)
		var direction := start.direction_to(finish)
		var distance := 0.0
		while distance <= length:
			draw_circle(start + direction * distance, HIDDEN_OUTLINE_RADIUS, HIDDEN_OUTLINE_COLOR)
			distance += HIDDEN_OUTLINE_SPACING


func _open(player: FoxPlayer) -> void:
	if opened:
		return
	opened = true
	remove_from_group("dungeon_interactables")
	_sprite.texture = OPEN_TEXTURE
	var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
	if audio:
		audio.play_purchase()
	var reward_name := _grant_reward(player)
	_show_reward_over_player(player, _get_reward_icon())
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui") as DialogueBox
	if dialogue and dialogue.play([{
		"speaker": "Mira",
		"text": "I found %s!\nHow exciting!" % reward_name,
		"portrait": PLAYER_PORTRAIT,
	}]):
		dialogue.dialogue_finished.connect(_finish_opening, CONNECT_ONE_SHOT)
	else:
		_finish_opening()


func _finish_opening() -> void:
	_clear_reward_display()
	if is_instance_valid(_level):
		_level.notify_chest_opened()


func _grant_reward(player: FoxPlayer) -> String:
	match reward_type:
		RewardType.ITEM:
			player.collect_item(item_id, item_grade)
			return str(ItemPickup.ITEM_NAMES.get(item_id, item_id.capitalize()))
		RewardType.DAMAGE:
			player.add_color_damage(reward_color, reward_amount)
			return "+%d %s damage" % [reward_amount, _color_name()]
		RewardType.HEALTH:
			player.add_max_health(reward_amount)
			return "+%d health" % reward_amount
		RewardType.REGENERATION:
			player.add_passive_healing(reward_amount)
			return "+%d regeneration" % reward_amount
		RewardType.DEFENSE:
			player.add_color_defense(reward_color, reward_amount)
			return "+%d %s defense" % [reward_amount, _color_name()]
		RewardType.KEY:
			if _level and _level.manager and _level.manager.has_method("add_key"):
				_level.manager.call("add_key", reward_amount)
			return "%d dungeon key%s" % [reward_amount, "" if reward_amount == 1 else "s"]
		RewardType.RESOURCE:
			var resources := get_tree().get_first_node_in_group("resource_manager") as ResourceManager
			var definition := resources.get_definition(resource_id) if resources else null
			if resources:
				resources.add_resource(resource_id, reward_amount)
			return "%d %s" % [reward_amount, definition.display_name if definition else str(resource_id)]
		RewardType.SKILL:
			var skill_id := CHEST_SKILLS[clampi(reward_skill, 0, CHEST_SKILLS.size() - 1)]
			player.unlock_player_skill(skill_id)
			return str(player.get_player_skill_data(skill_id).get("name", "a new skill"))
		RewardType.MANA:
			player.add_max_mana(reward_amount)
			return "+%d mana" % reward_amount
		RewardType.MANA_REGENERATION:
			player.add_passive_mana_regeneration(reward_amount)
			return "+%d mana regeneration" % reward_amount
		RewardType.INVENTORY_SLOT:
			var unlocked := player.unlock_inventory_slots(reward_amount)
			return "%d inventory slot%s" % [unlocked, "" if unlocked == 1 else "s"]
		RewardType.EQUIPMENT_SLOT:
			var unlocked := player.unlock_equipment_slots(reward_amount)
			return "%d equipment slot%s" % [unlocked, "" if unlocked == 1 else "s"]
		RewardType.SKILL_SLOT:
			var unlocked := player.unlock_next_player_skill_slots(reward_amount)
			return "%d skill slot%s" % [unlocked, "" if unlocked == 1 else "s"]
		RewardType.BOSS_KEY:
			if _level and _level.manager and _level.manager.has_method("add_boss_key"):
				_level.manager.call("add_boss_key", reward_amount)
			return "%d boss key%s" % [reward_amount, "" if reward_amount == 1 else "s"]
	return "a reward"


func _get_reward_icon() -> Texture2D:
	match reward_type:
		RewardType.ITEM:
			return ItemPickup.ITEM_TEXTURES.get(item_id, ItemPickup.ITEM_TEXTURES["weathered_sword"]) as Texture2D
		RewardType.DAMAGE:
			return DAMAGE_ICON
		RewardType.HEALTH:
			return HEALTH_ICON
		RewardType.REGENERATION:
			return REGEN_ICON
		RewardType.DEFENSE:
			return DEFENSE_ICON
		RewardType.KEY:
			return KEY_ICON
		RewardType.RESOURCE:
			var resources := get_tree().get_first_node_in_group("resource_manager") as ResourceManager
			var definition := resources.get_definition(resource_id) if resources else null
			return definition.icon if definition else null
		RewardType.SKILL:
			return ROLL_ICON if clampi(reward_skill, 0, CHEST_SKILLS.size() - 1) != 1 else SKILL_BOOK_ICON
		RewardType.MANA:
			return MANA_ICON
		RewardType.MANA_REGENERATION:
			return MANA_REGEN_ICON
		RewardType.INVENTORY_SLOT:
			return CLOSED_TEXTURE
		RewardType.EQUIPMENT_SLOT:
			return EQUIPMENT_SLOT_ICON
		RewardType.SKILL_SLOT:
			return SKILL_BOOK_ICON
		RewardType.BOSS_KEY:
			return BOSS_KEY_ICON
	return null


func _show_reward_over_player(player: FoxPlayer, texture: Texture2D) -> void:
	_clear_reward_display()
	_reward_display = Node2D.new()
	_reward_display.position = Vector2(0, -76)
	_reward_display.z_index = 80
	player.add_child(_reward_display)
	var rays := Node2D.new()
	_reward_display.add_child(rays)
	for index in range(12):
		var ray := Polygon2D.new()
		var angle := TAU * float(index) / 12.0
		ray.polygon = PackedVector2Array([Vector2(8, -2), Vector2(34, 0), Vector2(8, 2)])
		ray.rotation = angle
		ray.color = Color(1.0, 0.92, 0.42, 0.42)
		rays.add_child(ray)
	var icon := Sprite2D.new()
	icon.texture = texture
	if texture:
		icon.scale = Vector2.ONE * (32.0 / maxf(texture.get_size().x, texture.get_size().y))
	_reward_display.add_child(icon)
	var tween := rays.create_tween().set_loops()
	tween.tween_property(rays, "rotation", TAU, 2.6).from(0.0)


func _clear_reward_display() -> void:
	if is_instance_valid(_reward_display):
		_reward_display.queue_free()
	_reward_display = null


func _color_name() -> String:
	return ["red", "yellow", "blue"][clampi(reward_color, 0, 2)]


func _best_adjacent_path(player: FoxPlayer, level: DungeonLevel) -> PackedVector2Array:
	var object_cell := level.world_to_cell(global_position)
	var best := PackedVector2Array()
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var cell := object_cell + offset
		if not level.is_walkable(cell) or level.is_cell_occupied(cell, player):
			continue
		var candidate := level.find_path(player.global_position, level.cell_to_world(cell), player)
		if not candidate.is_empty() and (best.is_empty() or candidate.size() < best.size()):
			best = candidate
	return best
