class_name DungeonBossDoorLocked
extends DungeonDoorLocked


func _attempt_unlock() -> void:
	if _level == null or _level.manager == null:
		return
	if _level.manager.has_method("consume_boss_key") and bool(_level.manager.call("consume_boss_key")):
		_unlock(true)
		return
	var dialogue := get_tree().get_first_node_in_group("dialogue_ui") as DialogueBox
	if dialogue:
		dialogue.play([{
			"speaker": "Mira",
			"text": "I need a boss key to get through here.",
			"portrait": PLAYER_PORTRAIT,
		}])
