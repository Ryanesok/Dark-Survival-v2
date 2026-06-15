extends Node

@export var enemy_scene: PackedScene = preload("res://assets/enemy/enemy.tscn")
@export var player_path: NodePath
@export var left_spawn_position := Vector2(-520, 33)
@export var right_spawn_position := Vector2(720, 33)
@export var spawn_interval := 2.5
@export var max_enemies := 6

var spawn_timer := 0.0
var player: Node2D

func _ready() -> void:
	player = get_node_or_null(player_path) as Node2D
	spawn_timer = spawn_interval

func _process(delta: float) -> void:
	if not enemy_scene:
		return
	
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	
	spawn_timer = spawn_interval
	
	if get_tree().get_nodes_in_group("enemy").size() >= max_enemies:
		return
	
	spawn_enemy()

func spawn_enemy() -> void:
	var enemy := enemy_scene.instantiate() as Node2D
	if not enemy:
		return
	
	var spawn_position := left_spawn_position
	if randi() % 2 == 0:
		spawn_position = right_spawn_position
	
	enemy.global_position = spawn_position
	get_parent().add_child(enemy)
