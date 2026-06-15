extends CanvasLayer

@onready var title_label: Label = $Control/Label
@onready var score_label: Label = $Control/ScoreLabel
@onready var menu_button: Button = $Control/HBoxContainer/MenuButton
@onready var restart_button: Button = $Control/HBoxContainer/RestartButton

func _ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_main_menu_pressed)

func setup_result(player_won: bool, final_score: int, _enemies_defeated: int) -> void:
	title_label.text = "You Win" if player_won else "Game Over"
	score_label.text = "Score: %d" % final_score

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://assets/Ui/main_menu.tscn")
