class_name FoxDeru
extends FoxAsha

const DERU_SHOP_SCRIPT := preload("res://Scripts/fox_deru_shop.gd")
const SAD_TEXTURE := preload("res://Sprites/FoxDeruSad.webp")
const HAPPY_TEXTURE := preload("res://Sprites/FoxDeruHappy.webp")
const BROKEN_CART_TEXTURE := preload("res://Sprites/BrokenCart.webp")
const FIXED_CART_TEXTURE := preload("res://Sprites/FixedCart.webp")

var _repaired := false


func _ready() -> void:
	stationary = true
	purchase_counts = [0, 0, 0, 0]
	super._ready()


func _finish_setup() -> void:
	super._finish_setup()
	_apply_repair_visuals()


func set_repaired(value: bool) -> void:
	_repaired = value
	_apply_repair_visuals()


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
	if story and story.interact_with(&"deru"):
		return
	if story and story.is_deru_quest_completed():
		open_shop()


func open_shop() -> void:
	var hud := _world.get_node_or_null("HUD") as CanvasLayer if _world else null
	if hud == null:
		return
	if not is_instance_valid(_shop):
		_shop = DERU_SHOP_SCRIPT.new()
		hud.add_child(_shop)
		_shop.setup(self)
	_shop.open()
