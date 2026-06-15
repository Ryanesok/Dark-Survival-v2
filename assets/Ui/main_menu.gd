extends CanvasLayer

@export var game_scene_path := "res://scene/game.tscn"

@onready var main_button: Button = $HBoxContainer/MenuContainer/MainButton
@onready var credit_button: Button = $HBoxContainer/MenuContainer/CreditButton
@onready var exit_button: Button = $HBoxContainer/MenuContainer/ExitButton

@onready var credit_panel: Panel = $CreditPanel
@onready var back_button: Button = $CreditPanel/BackButton


func _ready() -> void:
	get_tree().paused = false
	
	credit_panel.visible = false

	main_button.pressed.connect(_on_main_pressed)
	credit_button.pressed.connect(_on_credit_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	back_button.pressed.connect(_on_back_pressed)

func _on_main_pressed() -> void:
	get_tree().change_scene_to_file(game_scene_path)

func _on_credit_pressed() -> void:
	credit_panel.visible = true

func _on_back_pressed() -> void:
	credit_panel.visible = false

func _on_exit_pressed() -> void:
	get_tree().quit()
