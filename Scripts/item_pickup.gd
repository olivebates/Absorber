class_name ItemPickup
extends Area2D

const ITEM_NAMES := {
	"weathered_armor": "Orange Shield",
	"weathered_sword": "Yellow Sword",
	"blue_sword": "Blue Sword",
	"red_damage_stone": "Red Damage Stone",
	"yellow_damage_stone": "Yellow Damage Stone",
	"blue_damage_stone": "Blue Damage Stone",
	"red_defense_stone": "Red Defense Stone",
	"yellow_defense_stone": "Yellow Defense Stone",
	"blue_defense_stone": "Blue Defense Stone",
	"potion_basic": "Basic Potion",
	"potion_rope": "Upgraded Potion",
	"potion_bronze": "Bronze Potion",
	"potion_silver": "Silver Potion",
	"potion_royal": "Royal Potion",
	"potion_holy": "Holy Potion",
	"spare_cart_parts": "Spare Part",
}

const ITEM_TEXTURES := {
	"weathered_armor": preload("res://Sprites/1Armor.webp"),
	"weathered_sword": preload("res://Sprites/1Sword.webp"),
	"blue_sword": preload("res://Sprites/1Sword.webp"),
	"red_damage_stone": preload("res://Sprites/statStone.webp"),
	"yellow_damage_stone": preload("res://Sprites/statStone.webp"),
	"blue_damage_stone": preload("res://Sprites/statStone.webp"),
	"red_defense_stone": preload("res://Sprites/statStone.webp"),
	"yellow_defense_stone": preload("res://Sprites/statStone.webp"),
	"blue_defense_stone": preload("res://Sprites/statStone.webp"),
	"potion_basic": preload("res://Sprites/PotionBasic.webp"),
	"potion_rope": preload("res://Sprites/PotionRope.webp"),
	"potion_bronze": preload("res://Sprites/PotionBronze.webp"),
	"potion_silver": preload("res://Sprites/PotionSilver.webp"),
	"potion_royal": preload("res://Sprites/PotionRoyal.webp"),
	"potion_holy": preload("res://Sprites/PotionHoly.webp"),
	"spare_cart_parts": preload("res://Sprites/SpareParts.webp"),
}

const GRADES := [
	{"name": "Crude", "color": Color("777777")},
	{"name": "Ordinary", "color": Color("f2f2f2")},
	{"name": "Superior", "color": Color("47b85c")},
	{"name": "Elite", "color": Color("4785e8")},
	{"name": "Masterwork", "color": Color("9a58d4")},
	{"name": "Mythic", "color": Color("e99032")},
	{"name": "Divine", "color": Color("e65ac5")},
	{"name": "Immortal", "color": Color("2ec4b6")},
	{"name": "Omnipotent", "color": Color("ff4d4d"), "animated": true},
	{"name": "Void", "color": Color("141414")},
]
const OMNIPOTENT_GRADE := 8
const VOID_GRADE := 9
const RAINBOW_CYCLES_PER_SECOND := 0.28
const MAX_SCALED_STAT := 0x7fffffffffffffff

const ITEM_DATA := {
	"weathered_armor": {"block": 2, "slot": "armor", "colors": [FoxPlayer.COLOR_RED, FoxPlayer.COLOR_YELLOW]},
	"weathered_sword": {"damage": 5, "slot": "weapon", "color": FoxPlayer.COLOR_YELLOW},
	"blue_sword": {"damage": 10, "slot": "weapon", "color": FoxPlayer.COLOR_BLUE, "tint": Color("4f8cff")},
	"red_damage_stone": {"stone_stat": "damage", "stone_amount": 2, "color": FoxPlayer.COLOR_RED, "slot": "stone", "tint": Color("ef5350")},
	"yellow_damage_stone": {"stone_stat": "damage", "stone_amount": 2, "color": FoxPlayer.COLOR_YELLOW, "slot": "stone", "tint": Color("ffd54f")},
	"blue_damage_stone": {"stone_stat": "damage", "stone_amount": 2, "color": FoxPlayer.COLOR_BLUE, "slot": "stone", "tint": Color("4f8cff")},
	"red_defense_stone": {"stone_stat": "defense", "stone_amount": 2, "color": FoxPlayer.COLOR_RED, "slot": "stone", "tint": Color("ef5350")},
	"yellow_defense_stone": {"stone_stat": "defense", "stone_amount": 2, "color": FoxPlayer.COLOR_YELLOW, "slot": "stone", "tint": Color("ffd54f")},
	"blue_defense_stone": {"stone_stat": "defense", "stone_amount": 2, "color": FoxPlayer.COLOR_BLUE, "slot": "stone", "tint": Color("4f8cff")},
	"potion_basic": {"healing": 40, "slot": "consumable"},
	"potion_rope": {"healing": 100, "slot": "consumable"},
	"potion_bronze": {"healing": 240, "slot": "consumable"},
	"potion_silver": {"healing": 520, "slot": "consumable"},
	"potion_royal": {"healing": 1350, "slot": "consumable"},
	"potion_holy": {"healing": 2147483647, "full_heal": true, "slot": "consumable"},
	"spare_cart_parts": {"slot": "quest", "protected": true, "description": "Give them to Deru in The Snakemouth Expanse."},
}

var item_id := "weathered_sword"
var grade := 0
var _float_time := 0.0
var _collecting := false
var _shadow: Polygon2D

@onready var icon: Sprite2D = $Icon


func setup(new_item_id: String, new_grade := 0) -> void:
	item_id = new_item_id
	grade = maxi(new_grade, 0)


func _ready() -> void:
	icon.texture = ITEM_TEXTURES.get(item_id, ITEM_TEXTURES["weathered_sword"])
	icon.modulate = get_icon_modulate(item_id)
	_shadow = Polygon2D.new()
	_shadow.polygon = _ellipse_points(19.0, 5.5)
	_shadow.position = Vector2(0, 18)
	_shadow.color = Color(0.0, 0.0, 0.0, 0.28)
	_shadow.z_index = -1
	add_child(_shadow)


func _process(delta: float) -> void:
	if not _collecting:
		_float_time += delta * 2.4
		icon.position.y = sin(_float_time) * 3.0 - 3.0


func collect(player: FoxPlayer) -> void:
	begin_collect(player)


func begin_collect(player: FoxPlayer) -> bool:
	if _collecting or not is_instance_valid(player) or not player.reserve_item_collection(item_id):
		return false
	_collecting = true
	$CollisionShape2D.set_deferred("disabled", true)
	var target_screen_position := player.get_item_collection_target_screen_position(item_id)
	var target_world_position := get_viewport().get_canvas_transform().affine_inverse() * target_screen_position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target_world_position, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(player):
			player.complete_item_collection(item_id, grade)
		queue_free()
	)
	return true


func _ellipse_points(radius_x: float, radius_y: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		points.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


func get_item_name() -> String:
	return ITEM_NAMES.get(item_id, item_id.capitalize())


static func get_grade_name(grade: int) -> String:
	var normalized_grade := maxi(grade, 0)
	if normalized_grade > VOID_GRADE:
		return "Void +%d" % (normalized_grade - VOID_GRADE)
	return str(GRADES[normalized_grade].get("name", "Crude"))


static func get_grade_color(grade: int, animation_time_seconds := -1.0) -> Color:
	var normalized_grade := maxi(grade, 0)
	if normalized_grade == OMNIPOTENT_GRADE:
		var elapsed_seconds := animation_time_seconds if animation_time_seconds >= 0.0 else float(Time.get_ticks_msec()) * 0.001
		var hue := fposmod(elapsed_seconds * RAINBOW_CYCLES_PER_SECOND, 1.0)
		return Color.from_hsv(hue, 0.72, 1.0)
	var base_grade := mini(normalized_grade, VOID_GRADE)
	return GRADES[base_grade].get("color", Color("777777")) as Color


static func is_animated_grade(grade: int) -> bool:
	return maxi(grade, 0) == OMNIPOTENT_GRADE


static func get_item_grade(item: Dictionary) -> int:
	return maxi(int(item.get("grade", 0)), 0)


static func get_merge_amount(item: Dictionary) -> int:
	if item.is_empty():
		return 0
	if item.has("merges"):
		return maxi(1, int(item.get("merges", 1)))
	# Old saves stored only a grade. Treat that grade as its exact milestone so
	# loading never lowers the item's power or its next upgrade threshold.
	var amount := 1
	for _step in range(mini(get_item_grade(item), 62)):
		amount *= 2
	return amount


static func get_grade_for_merge_amount(merge_amount: int) -> int:
	var amount := maxi(1, merge_amount)
	var result := 0
	while amount >= 2 and result < 62:
		amount = int(amount / 2)
		result += 1
	return result


static func get_damage_bonus(item: Dictionary) -> int:
	return _merged_stat(int(ITEM_DATA.get(str(item.get("item_id", "")), {}).get("damage", 0)), get_merge_amount(item))


static func get_block_amount(item: Dictionary) -> int:
	return _merged_stat(int(ITEM_DATA.get(str(item.get("item_id", "")), {}).get("block", 0)), get_merge_amount(item))


static func get_stone_bonus(item: Dictionary) -> int:
	if not is_stone(str(item.get("item_id", ""))):
		return 0
	return _merged_stat(int(ITEM_DATA[str(item.get("item_id"))].get("stone_amount", 0)), get_merge_amount(item))


static func get_equipped_stone(item: Dictionary) -> Dictionary:
	var stone: Variant = item.get("stone", {})
	return (stone as Dictionary).duplicate(true) if stone is Dictionary and is_stone(str(stone.get("item_id", ""))) else {}


static func get_stone_stat(item: Dictionary) -> StringName:
	return StringName(ITEM_DATA.get(str(item.get("item_id", "")), {}).get("stone_stat", ""))


static func get_block_colors(item: Dictionary) -> Array:
	var data := ITEM_DATA.get(str(item.get("item_id", "")), {}) as Dictionary
	if data.has("colors") and data["colors"] is Array:
		return (data["colors"] as Array).duplicate()
	return [clampi(int(data.get("color", FoxPlayer.COLOR_RED)), FoxPlayer.COLOR_RED, FoxPlayer.COLOR_BLUE)]


static func get_stat_color(item: Dictionary) -> int:
	return clampi(int(ITEM_DATA.get(str(item.get("item_id", "")), {}).get("color", FoxPlayer.COLOR_RED)), FoxPlayer.COLOR_RED, FoxPlayer.COLOR_BLUE)


static func is_weapon(item_id: String) -> bool:
	return str(ITEM_DATA.get(item_id, {}).get("slot", "")) == "weapon"


static func is_armor(item_id: String) -> bool:
	return str(ITEM_DATA.get(item_id, {}).get("slot", "")) == "armor"


static func is_equipment(item_id: String) -> bool:
	return is_weapon(item_id) or is_armor(item_id)


static func is_stone(item_id: String) -> bool:
	return str(ITEM_DATA.get(item_id, {}).get("slot", "")) == "stone"


static func get_icon_modulate(item_id: String) -> Color:
	var data := ITEM_DATA.get(item_id, {}) as Dictionary
	if data.has("tint"):
		return data["tint"] as Color
	return Color.WHITE


static func is_consumable(item_id: String) -> bool:
	return str(ITEM_DATA.get(item_id, {}).get("slot", "")) == "consumable"


static func is_protected(item_id: String) -> bool:
	return bool(ITEM_DATA.get(item_id, {}).get("protected", false))


static func get_description(item_id: String) -> String:
	return str(ITEM_DATA.get(item_id, {}).get("description", ""))


static func get_healing_amount(item: Dictionary) -> int:
	return maxi(0, int(ITEM_DATA.get(str(item.get("item_id", "")), {}).get("healing", 0)))


static func is_full_heal(item: Dictionary) -> bool:
	return bool(ITEM_DATA.get(str(item.get("item_id", "")), {}).get("full_heal", false))


static func make_item(new_item_id: String, new_grade := 0, merge_amount := -1, equipped_stone: Dictionary = {}) -> Dictionary:
	var normalized_grade := maxi(new_grade, 0)
	var normalized_merges := merge_amount
	if normalized_merges < 1:
		normalized_merges = 1
		for _step in range(mini(normalized_grade, 62)):
			normalized_merges *= 2
	var result := {
		"item_id": new_item_id,
		"grade": get_grade_for_merge_amount(normalized_merges),
		"merges": normalized_merges,
	}
	if is_equipment(new_item_id) and not equipped_stone.is_empty() and is_stone(str(equipped_stone.get("item_id", ""))):
		result["stone"] = make_item(
			str(equipped_stone.get("item_id", "")),
			get_item_grade(equipped_stone),
			get_merge_amount(equipped_stone)
		)
	return result


static func _merged_stat(base_amount: int, merge_amount: int) -> int:
	if base_amount <= 0 or merge_amount <= 0:
		return 0
	if merge_amount > int(MAX_SCALED_STAT / base_amount):
		return MAX_SCALED_STAT
	return base_amount * merge_amount


static func _scaled_stat(base_amount: int, grade: int) -> int:
	if base_amount <= 0:
		return 0
	var amount := float(base_amount)
	# Sixty-four steps exceed a signed 64-bit stat even from the smallest
	# positive base, so malformed or far-future save grades cannot cause a long loop.
	for _step in range(mini(maxi(grade, 0), 64)):
		if amount >= float(MAX_SCALED_STAT) / 2.1:
			return MAX_SCALED_STAT
		amount = amount * 2.1
	return roundi(amount)
