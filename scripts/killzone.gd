extends Area2D

func _on_body_entered(body: CharacterBody2D) -> void:
	if body.has_method("die"):
		var last_health: float = 0.0
		if body.has_method("get_current_health"):
			last_health = float(body.get_current_health())
		body.die(last_health)


func _on_timer_timeout() -> void:
	pass
