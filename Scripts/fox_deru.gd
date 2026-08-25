class_name FoxDeru
extends FoxLio

const SAD_TEXTURE := preload("res://Sprites/FoxDeruSad.webp")
const HAPPY_TEXTURE := preload("res://Sprites/FoxDeruHappy.webp")
const BROKEN_CART_TEXTURE := preload("res://Sprites/BrokenCart.webp")
const FIXED_CART_TEXTURE := preload("res://Sprites/FixedCart.webp")
const DERU_REWARD_FEE := {&"jewels": 3}
const DERU_HUNT_DAMAGE := 7

var _repaired := false


func _ready() -> void:
	super._ready()


func _finish_setup() -> void:
	super._finish_setup()
	_apply_repair_visuals()


func set_repaired(value: bool) -> void:
	_repaired = value
	_apply_repair_visuals()
	set_hunter_recruited(value)


func is_repaired() -> bool:
	return _repaired


func _apply_repair_visuals() -> void:
	if is_instance_valid(fox_sprite):
		fox_sprite.texture = HAPPY_TEXTURE if _repaired else SAD_TEXTURE
	var cart := get_parent().get_node_or_null("ObstacleBrokenCart") if get_parent() else null
	var cart_sprite := cart.get_node_or_null("Sprite2D") as Sprite2D if cart else null
	if cart_sprite:
		cart_sprite.texture = FIXED_CART_TEXTURE if _repaired else BROKEN_CART_TEXTURE


func interact() -> void:
	var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
	if story:
		story.interact_with(&"deru")


func open_shop() -> void:
	# Repairing the cart changes Deru into a field helper permanently; he never
	# opens the former post-quest shop.
	pass


func load_save_data(data: Array) -> bool:
	var loaded := super.load_save_data(data)
	var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
	if story and story.is_deru_quest_completed() and not is_hunter_recruited():
		set_hunter_recruited(true)
	return loaded


func _get_hunt_area_id() -> int:
	return 2


func get_hunt_damage() -> int:
	return DERU_HUNT_DAMAGE


func get_reward_fee() -> Dictionary:
	return DERU_REWARD_FEE


func _get_reward_price_text() -> String:
	return "Free" if is_reward_handoff_free() else "3 Gems"


func _is_stationary_before_recruitment() -> bool:
	return true


func _get_helper_name() -> String:
	return "Deru"


func _notify_reward_delivery_finished(story: StoryManager) -> void:
	story.on_deru_reward_delivery_finished()
