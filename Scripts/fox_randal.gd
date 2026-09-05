class_name FoxRandal
extends FoxLio

const RANDAL_HUNT_DAMAGE := 17


func _ready() -> void:
	super._ready()
	remove_from_group("shopkeepers")


func interact() -> void:
	var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
	if story:
		story.interact_with(&"randal")


func open_shop() -> void:
	pass


func load_save_data(data: Array) -> bool:
	var loaded := super.load_save_data(data)
	var story := get_tree().get_first_node_in_group("story_manager") as StoryManager
	if story and story.is_randal_quest_completed() and not is_hunter_recruited():
		set_hunter_recruited(true)
	return loaded


func _get_hunt_area_id() -> int:
	return 5


func get_hunt_damage() -> int:
	return RANDAL_HUNT_DAMAGE


func _is_stationary_before_recruitment() -> bool:
	return true


func _get_helper_name() -> String:
	return "Randal"


func _notify_reward_delivery_finished(story: StoryManager) -> void:
	story.on_randal_reward_delivery_finished()
