class_name ItemPickup
extends Area2D

const ITEM_NAMES := {
	"weathered_armor": "Weathered Armor",
	"weathered_sword": "Weathered Sword",
	"potion_basic": "Basic Potion",
	"potion_rope": "Upgraded Potion",
	"potion_bronze": "Bronze Potion",
	"potion_silver": "Silver Potion",
	"potion_royal": "Royal Potion",
	"potion_holy": "Holy Potion",
}

const ITEM_TEXTURES := {
	"weathered_armor": preload("res://Sprites/1Armor.webp"),
	"weathered_sword": preload("res://Sprites/1Sword.webp"),
	"potion_basic": preload("res://Sprites/PotionBasic.webp"),
	"potion_rope": preload("res://Sprites/PotionRope.webp"),
	"potion_bronze": preload("res://Sprites/PotionBronze.webp"),
	"potion_silver": preload("res://Sprites/PotionSilver.webp"),
	"potion_royal": preload("res://Sprites/PotionRoyal.webp"),
	"potion_holy": preload("res://Sprites/PotionHoly.webp"),
}

const GRADES := [
	{"name": "Gray", "color": Color("777777")},
	{"name": "White", "color": Color("f2f2f2")},
	{"name": "Green", "color": Color("47b85c")},
	{"name": "Blue", "color": Color("4785e8")},
	{"name": "Purple", "color": Color("9a58d4")},
	{"name": "Orange", "color": Color("e99032")},
	{"name": "Pink", "color": Color("e65ac5")},
	{"name": "Black", "color": Color("141414")},
]

const ITEM_DATA := {
	"weathered_armor": {"block": 2, "slot": "armor"},
	"weathered_sword": {"damage": 3, "slot": "weapon"},
	"potion_basic": {"healing": 40, "slot": "consumable"},
	"potion_rope": {"healing": 100, "slot": "consumable"},
	"potion_bronze": {"healing": 240, "slot": "consumable"},
	"potion_silver": {"healing": 520, "slot": "consumable"},
	"potion_royal": {"healing": 1350, "slot": "consumable"},
	"potion_holy": {"healing": 2147483647, "full_heal": true, "slot": "consumable"},
}

var item_id := "weathered_sword"
var grade := 0
var _float_time := 0.0
var _collecting := false
var _shadow: Polygon2D

@onready var icon: Sprite2D = $Icon


func setup(new_item_id: String, new_grade := 0) -> void:
	item_id = new_item_id
	grade = clampi(new_grade, 0, GRADES.size() - 1)


func _ready() -> void:
	icon.texture = ITEM_TEXTURES.get(item_id, ITEM_TEXTURES["weathered_sword"])
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
	return str(GRADES[clampi(grade, 0, GRADES.size() - 1)].get("name", "Gray"))


static func get_grade_color(grade: int) -> Color:
	return GRADES[clampi(grade, 0, GRADES.size() - 1)].get("color", Color("777777")) as Color


static func get_item_grade(item: Dictionary) -> int:
	return clampi(int(item.get("grade", 0)), 0, GRADES.size() - 1)


static func get_damage_bonus(item: Dictionary) -> int:
	return _scaled_stat(int(ITEM_DATA.get(str(item.get("item_id", "")), {}).get("damage", 0)), get_item_grade(item))


static func get_block_amount(item: Dictionary) -> int:
	return _scaled_stat(int(ITEM_DATA.get(str(item.get("item_id", "")), {}).get("block", 0)), get_item_grade(item))


static func is_weapon(item_id: String) -> bool:
	return str(ITEM_DATA.get(item_id, {}).get("slot", "")) == "weapon"


static func is_armor(item_id: String) -> bool:
	return str(ITEM_DATA.get(item_id, {}).get("slot", "")) == "armor"


static func is_equipment(item_id: String) -> bool:
	return is_weapon(item_id) or is_armor(item_id)


static func is_consumable(item_id: String) -> bool:
	return str(ITEM_DATA.get(item_id, {}).get("slot", "")) == "consumable"


static func get_healing_amount(item: Dictionary) -> int:
	return maxi(0, int(ITEM_DATA.get(str(item.get("item_id", "")), {}).get("healing", 0)))


static func is_full_heal(item: Dictionary) -> bool:
	return bool(ITEM_DATA.get(str(item.get("item_id", "")), {}).get("full_heal", false))


static func make_item(new_item_id: String, new_grade := 0) -> Dictionary:
	return {"item_id": new_item_id, "grade": clampi(new_grade, 0, GRADES.size() - 1)}


static func _scaled_stat(base_amount: int, grade: int) -> int:
	var amount := float(base_amount)
	for _step in range(clampi(grade, 0, GRADES.size() - 1)):
		amount = amount * 2.1
	return roundi(amount)
