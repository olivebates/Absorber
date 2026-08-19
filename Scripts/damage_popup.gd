class_name DamagePopup
extends Label


func show_damage(amount: int) -> void:
	text = "-%d" % amount
	modulate.a = 1.0
	scale = Vector2(0.7, 0.7)
	var animation := create_tween().set_parallel()
	animation.tween_property(self, "position:y", position.y - 30.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	animation.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	animation.tween_property(self, "modulate:a", 0.0, 0.22).set_delay(0.43)
	animation.finished.connect(queue_free)
