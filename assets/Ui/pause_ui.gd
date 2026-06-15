extends CanvasLayer

signal pause_pressed
signal start_pressed
signal restart_pressed
signal menu_pressed

@onready var pause_button: Button = $PauseButton
@onready var pausepanel: Control = $Pausepanel
@onready var restart_button: TextureButton = $Pausepanel/HBoxContainer/RestartButton
@onready var menu_button: TextureButton = $Pausepanel/HBoxContainer/MenuButton
@onready var start_button: TextureButton = $Pausepanel/HBoxContainer/StartButton

func _ready() -> void:
	pausepanel.visible = false

	pause_button.pressed.connect(
		func(): pause_pressed.emit()
	)

	start_button.pressed.connect(
		func(): start_pressed.emit()
	)

	restart_button.pressed.connect(
		func(): restart_pressed.emit()
	)

	menu_button.pressed.connect(
		func(): menu_pressed.emit()
	)

func show_pause_menu() -> void:
	pausepanel.visible = true
	pause_button.visible = false

func hide_pause_menu() -> void:
	pausepanel.visible = false
	pause_button.visible = true
