class_name RecruitmentCelebration
extends Control

signal dismissed

var can_continue := false
var _dismissed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)


func arm_after(seconds: float, continue_prompt: Label) -> void:
	await get_tree().create_timer(maxf(0.0, seconds), true).timeout
	if not is_instance_valid(self) or _dismissed:
		return
	can_continue = true
	if is_instance_valid(continue_prompt):
		continue_prompt.modulate.a = 0.0
		continue_prompt.show()
		var tween := continue_prompt.create_tween()
		tween.tween_property(continue_prompt, "modulate:a", 1.0, 0.22)
		tween.tween_callback(_pulse_prompt.bind(continue_prompt))


func try_dismiss() -> bool:
	if not can_continue or _dismissed:
		return false
	_dismissed = true
	dismissed.emit()
	return true


func _input(event: InputEvent) -> void:
	var is_pressed_key: bool = event is InputEventKey and event.pressed and not event.echo
	var is_pressed_click: bool = event is InputEventMouseButton and event.pressed
	if not is_pressed_key and not is_pressed_click:
		return
	get_viewport().set_input_as_handled()
	try_dismiss()


func _pulse_prompt(prompt: Label) -> void:
	if not is_instance_valid(prompt) or _dismissed:
		return
	var tween := prompt.create_tween().set_loops()
	tween.tween_property(prompt, "modulate:a", 0.52, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(prompt, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
