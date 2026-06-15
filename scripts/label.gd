extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().create_timer(5.0).timeout
	var tween = create_tween()
	
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.parallel().tween_property(self, "position:y", position.y - 20, 1.0)
	tween.finished.connect(queue_free)
