extends Node2D

const FRAME_SIZE := Vector2i(64, 64)
const ANIMATION_ROWS := {
	"idle": {"row": 0, "frames": 4, "loop": true, "speed": 8.0},
	"run": {"row": 1, "frames": 4, "loop": true, "speed": 10.0},
	"prepare_attack": {"row": 2, "frames": 5, "loop": false, "speed": 10.0},
	"attack": {"row": 3, "frames": 3, "loop": false, "speed": 12.0},
	"after_attack": {"row": 4, "frames": 4, "loop": false, "speed": 10.0},
	"get_hit": {"row": 5, "frames": 2, "loop": false, "speed": 10.0},
	"die": {"row": 6, "frames": 9, "loop": false, "speed": 10.0},
}
const ATTACK_ACTIVE_FRAMES := [0, 1]
const ATTACK_RANGE := 34.0
const STOP_RANGE := 24.0
const SPEED := 48.0
const MAX_HEALTH := 15.0
const KNOCKBACK_DISTANCE := 26.0
const KNOCKBACK_LIFT := -12.0
const KNOCKBACK_DURATION := 0.20
const ATTACK_HITBOX_OFFSET := Vector2(24, 4)
const ATTACK_HITBOX_SIZE := Vector2(30, 30)

enum State { IDLE, RUN, PREPARE_ATTACK, ATTACK, AFTER_ATTACK, GET_HIT, DIE }

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $killzone

var current_state := State.IDLE
var player: Node2D
var attack_hitbox: Area2D
var attack_hitbox_shape: CollisionShape2D
var hit_player_this_attack := false
var knockback_tween: Tween
var health := MAX_HEALTH
var defeat_registered := false

func _ready() -> void:
	add_to_group("enemy")
	build_enemy_animations()
	setup_hurtbox()
	setup_attack_hitbox()
	find_player()
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.frame_changed.connect(_on_frame_changed)
	play_state_animation("idle")

func _process(delta: float) -> void:
	if current_state in [State.PREPARE_ATTACK, State.ATTACK, State.AFTER_ATTACK, State.GET_HIT, State.DIE]:
		update_attack_hitbox()
		return
	
	if not is_instance_valid(player):
		find_player()
		change_state(State.IDLE)
		return
	
	var distance_x: float = player.global_position.x - global_position.x
	var distance: float = absf(distance_x)
	
	if distance <= ATTACK_RANGE:
		change_state(State.PREPARE_ATTACK)
		return
	
	if distance > STOP_RANGE:
		var direction: float = signf(distance_x)
		global_position.x += direction * SPEED * delta
		animated_sprite.flip_h = direction < 0
		change_state(State.RUN)
	else:
		change_state(State.IDLE)
	
	update_attack_hitbox()

func build_enemy_animations() -> void:
	var source_texture: Texture2D = get_enemy_texture()
	if not source_texture:
		return
	
	var frames := SpriteFrames.new()
	
	for animation_name: String in ANIMATION_ROWS.keys():
		var data: Dictionary = ANIMATION_ROWS[animation_name]
		var row: int = int(data["row"])
		var frame_count: int = int(data["frames"])
		var should_loop: bool = bool(data["loop"])
		var animation_speed: float = float(data["speed"])
		
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, should_loop)
		frames.set_animation_speed(animation_name, animation_speed)
		
		for frame_index in range(frame_count):
			var atlas_frame := AtlasTexture.new()
			atlas_frame.atlas = source_texture
			atlas_frame.region = Rect2(
				frame_index * FRAME_SIZE.x,
				row * FRAME_SIZE.y,
				FRAME_SIZE.x,
				FRAME_SIZE.y
			)
			frames.add_frame(animation_name, atlas_frame)
	
	animated_sprite.sprite_frames = frames

func get_enemy_texture() -> Texture2D:
	var sprite_frames := animated_sprite.sprite_frames
	if not sprite_frames or not sprite_frames.has_animation("default"):
		return null
	
	var first_frame := sprite_frames.get_frame_texture("default", 0)
	if first_frame is AtlasTexture:
		return first_frame.atlas
	
	return first_frame

func setup_hurtbox() -> void:
	if not hurtbox:
		return
	
	hurtbox.collision_layer = 1
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.monitorable = true

func setup_attack_hitbox() -> void:
	attack_hitbox = Area2D.new()
	attack_hitbox.name = "EnemyAttackHitbox"
	attack_hitbox.collision_layer = 0
	attack_hitbox.collision_mask = 2
	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false
	add_child(attack_hitbox)
	
	attack_hitbox_shape = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = ATTACK_HITBOX_SIZE
	attack_hitbox_shape.shape = shape
	attack_hitbox_shape.disabled = true
	attack_hitbox.add_child(attack_hitbox_shape)
	
	attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)

func find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		player = get_tree().root.find_child("player", true, false) as Node2D

func change_state(next_state: State) -> void:
	if current_state == next_state:
		return
	
	current_state = next_state
	
	match current_state:
		State.IDLE:
			play_state_animation("idle")
		State.RUN:
			play_state_animation("run")
		State.PREPARE_ATTACK:
			hit_player_this_attack = false
			play_state_animation("prepare_attack")
		State.ATTACK:
			play_state_animation("attack")
		State.AFTER_ATTACK:
			disable_attack_hitbox()
			play_state_animation("after_attack")
		State.GET_HIT:
			disable_attack_hitbox()
			play_state_animation("get_hit")
		State.DIE:
			disable_attack_hitbox()
			if hurtbox:
				hurtbox.set_deferred("monitorable", false)
			register_defeat()
			play_state_animation("die")

func play_state_animation(animation_name: String) -> void:
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)

func update_attack_hitbox() -> void:
	var is_active := current_state == State.ATTACK and ATTACK_ACTIVE_FRAMES.has(animated_sprite.frame)
	
	if not is_active:
		disable_attack_hitbox()
		return
	
	var facing := -1.0 if animated_sprite.flip_h else 1.0
	attack_hitbox.position = Vector2(ATTACK_HITBOX_OFFSET.x * facing, ATTACK_HITBOX_OFFSET.y)
	attack_hitbox.set_deferred("monitoring", true)
	attack_hitbox_shape.set_deferred("disabled", false)
	call_deferred("check_attack_hitbox_overlaps")

func disable_attack_hitbox() -> void:
	if not attack_hitbox:
		return
	
	attack_hitbox.set_deferred("monitoring", false)
	attack_hitbox_shape.set_deferred("disabled", true)

func play_knockback_transform(source_position: Vector2) -> void:
	if current_state == State.DIE:
		return

	var direction := signf(global_position.x - source_position.x)
	if direction == 0.0:
		direction = -1.0 if animated_sprite.flip_h else 1.0

	if knockback_tween and knockback_tween.is_running():
		knockback_tween.kill()

	var start_position := global_position

	knockback_tween = create_tween()

	# Naik dan terdorong ke samping
	knockback_tween.tween_property(
		self,
		"global_position",
		start_position + Vector2(direction * KNOCKBACK_DISTANCE, KNOCKBACK_LIFT),
		KNOCKBACK_DURATION * 0.5
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Turun kembali ke lantai
	knockback_tween.tween_property(
		self,
		"global_position",
		start_position + Vector2(direction * KNOCKBACK_DISTANCE, 0),
		KNOCKBACK_DURATION * 0.5
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func check_attack_hitbox_overlaps() -> void:
	if not attack_hitbox or not attack_hitbox.monitoring:
		return
	
	for body in attack_hitbox.get_overlapping_bodies():
		_try_hit_player(body)

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	_try_hit_player(body)

func _try_hit_player(body: Node2D) -> void:
	if hit_player_this_attack:
		return
	
	if body and body.has_method("take_damage"):
		hit_player_this_attack = true
		body.take_damage()

func take_damage(amount: float = 1.0, source_position: Vector2 = global_position) -> void:
	if current_state == State.DIE:
		return
	
	health = maxf(health - amount, 0.0)
	
	if health <= 0:
		change_state(State.DIE)
	else:
		play_knockback_transform(source_position)
		change_state(State.GET_HIT)

func register_defeat() -> void:
	if defeat_registered:
		return
	
	defeat_registered = true
	var game_manager: Node = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("register_enemy_defeated"):
		game_manager.register_enemy_defeated()

func _on_frame_changed() -> void:
	update_attack_hitbox()

func _on_animation_finished() -> void:
	match current_state:
		State.PREPARE_ATTACK:
			change_state(State.ATTACK)
		State.ATTACK:
			change_state(State.AFTER_ATTACK)
		State.AFTER_ATTACK:
			change_state(State.IDLE)
		State.GET_HIT:
			change_state(State.IDLE)
		State.DIE:
			queue_free()
