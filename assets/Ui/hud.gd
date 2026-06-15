extends CanvasLayer

@onready var health_bar: AnimatedSprite2D = $Control/healthBar
@onready var ult_bar: AnimatedSprite2D = $Control/ultimateBar
@onready var timer_label: Label = $Control/TimerLabel
@onready var score_label: Label = $Control/ScoreLabel

func update_health(current_hp: float, max_hp: float) -> void:
	if max_hp <= 0.0:
		return
	
	set_bar_frame(health_bar, (current_hp / max_hp) * 100.0, true)

func update_health_percent(percent: float) -> void:
	set_bar_frame(health_bar, percent, true)

func update_ultimate(current: float, max_ult: float) -> void:
	if max_ult <= 0.0:
		return
	
	set_bar_frame(ult_bar, (current / max_ult) * 100.0, false)

func update_ultimate_percent(percent: float) -> void:
	set_bar_frame(ult_bar, percent, false)

func update_timer(text: String) -> void:
	timer_label.text = text

func update_score(score: int) -> void:
	score_label.text = "Score %d" % score

func set_bar_frame(sprite: AnimatedSprite2D, percent: float, reversed: bool) -> void:
	if not sprite or not sprite.sprite_frames:
		return
	
	var animation_name: StringName = sprite.animation
	var frame_count: int = sprite.sprite_frames.get_frame_count(animation_name)
	if frame_count <= 0:
		return
	
	var normalized: float = clampf(percent / 100.0, 0.0, 1.0)
	var frame_index: int = int(round((frame_count - 1) * normalized))
	if reversed:
		frame_index = (frame_count - 1) - frame_index
	
	sprite.stop()
	sprite.frame = clampi(frame_index, 0, frame_count - 1)
