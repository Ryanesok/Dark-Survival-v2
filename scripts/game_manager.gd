extends CanvasLayer

const MATCH_DURATION: float = 90.0
const ULTIMATE_FILL_DURATION: float = 3.0

@export var player_path: NodePath
@export var hud_scene: PackedScene = preload("res://assets/Ui/hud.tscn")
@export var game_over_overlay_scene: PackedScene = preload("res://assets/Ui/game_over.tscn")
@export var pause_ui_scene: PackedScene = preload("res://assets/Ui/pause_ui.tscn")

var pause_ui: CanvasLayer
var player: Node
var time_left: float = MATCH_DURATION
var enemies_defeated: int = 0
var health_percent: float = 100.0
var ultimate_percent: float = 0.0
var round_finished: bool = false
var is_pause_menu_open = false

var hud: CanvasLayer
var active_overlay: Node

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_manager")
	get_tree().paused = false
	setup_hud()
	setup_pause_ui()
	player = get_node_or_null(player_path)
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
		if player.has_signal("died"):
			player.died.connect(_on_player_died)
		if player.has_method("set_ultimate_percent"):
			player.set_ultimate_percent(ultimate_percent)
	update_hud()

func _process(delta: float) -> void:
	if round_finished:
		return
		
	if is_pause_menu_open:
		return 
	
	time_left = maxf(time_left - delta, 0.0)
	ultimate_percent = minf(ultimate_percent + (100.0 / ULTIMATE_FILL_DURATION) * delta, 100.0)
	
	if player and player.has_method("set_ultimate_percent"):
		player.set_ultimate_percent(ultimate_percent)
	
	update_hud()
	
	if time_left <= 0.0:
		finish_round(true)

func setup_hud() -> void:
	if not hud_scene:
		return
	
	hud = hud_scene.instantiate() as CanvasLayer
	if not hud:
		return
	
	hud.layer = 11
	add_child(hud)

func update_hud() -> void:
	var seconds_left: int = int(ceil(time_left))
	var minutes: int = floori(float(seconds_left) / 60.0)
	var seconds: int = seconds_left % 60
	var score: int = calculate_score(health_percent)
	var timer_text: String = "%02d:%02d" % [minutes, seconds]
	
	if hud:
		if hud.has_method("update_timer"):
			hud.update_timer(timer_text)
		if hud.has_method("update_health_percent"):
			hud.update_health_percent(health_percent)
		if hud.has_method("update_ultimate_percent"):
			hud.update_ultimate_percent(ultimate_percent)
		if hud.has_method("update_score"):
			hud.update_score(score)

func calculate_score(score_health_percent: float) -> int:
	return int(round(score_health_percent)) * enemies_defeated

func consume_ultimate() -> bool:
	if ultimate_percent < 100.0 or round_finished:
		return false
	
	ultimate_percent = 0.0
	if player and player.has_method("set_ultimate_percent"):
		player.set_ultimate_percent(ultimate_percent)
	update_hud()
	return true

func register_enemy_defeated() -> void:
	if round_finished:
		return
	
	enemies_defeated += 1
	update_hud()

func _on_player_health_changed(current_health: float, max_health: float) -> void:
	if max_health <= 0.0:
		return
	
	health_percent = clampf((current_health / max_health) * 100.0, 0.0, 100.0)
	update_hud()

func _on_player_died(last_health_before_death: float, max_health: float) -> void:
	if round_finished:
		return
	
	if time_left <= 0.0:
		finish_round(true)
		return
	
	var final_health_percent: float = 0.0
	if max_health > 0.0:
		final_health_percent = clampf((last_health_before_death / max_health) * 100.0, 0.0, 100.0)
	finish_round(false, final_health_percent)

func finish_round(player_won: bool, score_health_percent: float = -1.0) -> void:
	if round_finished:
		return
	
	round_finished = true
	get_tree().paused = true
	if score_health_percent < 0.0:
		score_health_percent = health_percent
	
	var final_score: int = calculate_score(score_health_percent)
	if pause_ui:
		pause_ui.visible = false
	show_result_overlay(player_won, final_score)

func setup_pause_ui() -> void:
	if not pause_ui_scene:
		return

	pause_ui = pause_ui_scene.instantiate() as CanvasLayer

	if not pause_ui:
		return

	pause_ui.layer = 12
	pause_ui.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	add_child(pause_ui)

	if pause_ui.has_signal("pause_pressed"):
		pause_ui.pause_pressed.connect(_on_pause_requested)

	if pause_ui.has_signal("start_pressed"):
		pause_ui.start_pressed.connect(_on_resume_requested)
	
	if pause_ui.has_signal("restart_pressed"):
		pause_ui.restart_pressed.connect(_on_restart_requested)

	if pause_ui.has_signal("menu_pressed"):
		pause_ui.menu_pressed.connect(_on_menu_requested)

func _on_restart_requested() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(
		"res://assets/Ui/main_menu.tscn"
	)

func _on_pause_requested() -> void:
	if round_finished:
		return
	
	is_pause_menu_open = true
	get_tree().paused = true

	if pause_ui and pause_ui.has_method("show_pause_menu"):
		pause_ui.show_pause_menu()

func _on_resume_requested() -> void:
	is_pause_menu_open = false
	get_tree().paused = false

	if pause_ui and pause_ui.has_method("hide_pause_menu"):
		pause_ui.hide_pause_menu()

func _unhandled_input(event: InputEvent) -> void:
	if round_finished:
		return

	if event.is_action_pressed("pause"):
		if get_tree().paused:
			_on_resume_requested()
		else:
			_on_pause_requested()

func show_result_overlay(player_won: bool, final_score: int) -> void:
	if active_overlay:
		return
	
	if not game_over_overlay_scene:
		return
	
	active_overlay = game_over_overlay_scene.instantiate()
	if active_overlay is CanvasLayer:
		var overlay_layer: CanvasLayer = active_overlay as CanvasLayer
		overlay_layer.layer = 20
	add_child(active_overlay)
	
	if active_overlay.has_method("setup_result"):
		active_overlay.setup_result(player_won, final_score, enemies_defeated)
