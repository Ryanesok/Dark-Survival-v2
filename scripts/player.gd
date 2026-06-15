extends CharacterBody2D

signal health_changed(current_health: float, max_health: float)
signal died(last_health_before_death: float, max_health: float)

const SPEED = 130.0
const JUMP_VELOCITY = -300.0
const DASH_SPEED = 350.0
const DASH_DURATION = 0.20
const DASH_COOLDOWN = 0.6
const COMBO_TIMEOUT = 0.3
const MAX_HEALTH := 100.0
const ENEMY_DAMAGE := 15.0
const ATTACK_DAMAGE := {
	"basic_attack_1": 3.2,
	"basic_attack_2": 2.5,
	"basic_attack_3": 6.0,
	"dash_attack": 7.0,
	"plunge_attack": 8.0,
	"ultimate": 10.0,
}
const CAMERA_NORMAL_OFFSET := Vector2(1, -24)
const CAMERA_MOVE_LOOK_AHEAD := 18.0
const CAMERA_ULTIMATE_LOOK_AHEAD := 240.0
const CAMERA_LERP_SPEED := 6.0
const ATTACK_ACTIVE_FRAMES := {
	"dash_attack": [3, 4, 5, 7, 8],
	"plunge_attack": [1, 2, 8],
	"ultimate": [3, 11],
	"basic_attack_1": [2, 3, 4],
	"basic_attack_2": [0, 1, 2, 3],
	"basic_attack_3": [2, 3],
}
const ATTACK_HITBOX_SETTINGS := {
	"dash_attack": {"offset": Vector2(82, -18), "size": Vector2(130, 46)},
	"plunge_attack": {"offset": Vector2(45, 10), "size": Vector2(90, 85)},
	"ultimate": {"offset": Vector2(80, -20), "size": Vector2(140, 80)},
	"basic_attack_1": {"offset": Vector2(58, -18), "size": Vector2(95, 50)},
	"basic_attack_2": {"offset": Vector2(64, -18), "size": Vector2(105, 54)},
	"basic_attack_3": {"offset": Vector2(70, -18), "size": Vector2(120, 58)},
}
const VFX_HITBOX_OFFSET := Vector2(83, -10)
const VFX_HITBOX_SIZE := Vector2(250, 90)

enum State { NORMAL, ATTACKING, DASHING, PLUNGING, ULTIMATE, HURT }
var current_state = State.NORMAL

@export var player_vfx: PackedScene 

@onready var camera_2d: Camera2D = $Camera2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var weapon_marker: Marker2D = $WeaponMarker

var dash_timer = 0.0
var dash_cooldown_timer = 0.0
var combo_timer = 0.0
var combo_step = 0
var buffered_attack = false
var combo_dash_cancel_used = false
var resume_combo_after_dash = false
var was_falling = false
var vfx_spawned = false 
var camera_target_offset := CAMERA_NORMAL_OFFSET
var attack_hitbox: Area2D
var attack_hitbox_shape: CollisionShape2D
var hit_targets: Array[Node] = []
var health := MAX_HEALTH
var ultimate_percent := 0.0
var is_dead := false

func _ready():
	add_to_group("player")
	setup_attack_hitbox()
	animated_sprite.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
	animated_sprite.frame_changed.connect(_on_animated_sprite_frame_changed)
	health_changed.emit(health, MAX_HEALTH)
	
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		
	if combo_timer > 0 and current_state != State.ATTACKING:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_step = 0
			combo_dash_cancel_used = false
			resume_combo_after_dash = false

	match current_state:
		State.NORMAL:
			state_normal(delta)
		State.ATTACKING:
			state_attacking(delta)
		State.DASHING:
			state_dashing(delta)
		State.PLUNGING:
			state_plunging(delta)
		State.ULTIMATE:
			if not is_on_floor(): velocity += get_gravity() * delta
			velocity.x = move_toward(velocity.x, 0, SPEED)
		State.HURT:
			if not is_on_floor(): velocity += get_gravity() * delta
			velocity.x = move_toward(velocity.x, 0, SPEED)

	if current_state == State.NORMAL:
		if not is_on_floor():
			was_falling = true
		elif was_falling:
			was_falling = false
			animated_sprite.play("recover_fall")

	move_and_slide()
	update_camera(delta)
	update_attack_hitbox()

# --- STATE LOGIC FUNCTIONS ---

func state_normal(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if animated_sprite.animation == "recover_fall":
		velocity.x = move_toward(velocity.x, 0, SPEED)
		return

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if Input.is_action_just_pressed("dash") and is_on_floor() and dash_cooldown_timer <= 0:
		start_dash()
		return

	if Input.is_action_just_pressed("attack"):
		if is_on_floor():
			start_combo()
		else:
			current_state = State.PLUNGING
			animated_sprite.play("plunge_attack")
		return

	if Input.is_action_just_pressed("ultimate") and is_on_floor() and can_use_ultimate():
		current_state = State.ULTIMATE
		vfx_spawned = false 
		animated_sprite.play("ultimate") 
		return

	var direction := Input.get_axis("move_left", "move_right")
	
	if direction:
		animated_sprite.flip_h = (direction < 0)
		weapon_marker.position.x = abs(weapon_marker.position.x) * (-1 if direction < 0 else 1)
		velocity.x = direction * SPEED
		if is_on_floor():
			animated_sprite.play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		if is_on_floor():
			animated_sprite.play("idle")
			
	if not is_on_floor():
		if velocity.y < 0:
			animated_sprite.play("jump")
		else:
			animated_sprite.play("fall")

func state_attacking(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	velocity.x = move_toward(velocity.x, 0, SPEED)
	
	if Input.is_action_just_pressed("dash") and is_on_floor() and dash_cooldown_timer <= 0 and not combo_dash_cancel_used and animated_sprite.animation.begins_with("basic_attack"):
		combo_dash_cancel_used = true
		resume_combo_after_dash = true
		buffered_attack = false
		start_dash()
		return
	
	if Input.is_action_just_pressed("attack"):
		buffered_attack = true

func state_dashing(delta: float) -> void:
	dash_timer -= delta
	velocity.y = 0
	velocity.x = -DASH_SPEED if animated_sprite.flip_h else DASH_SPEED
	
	if Input.is_action_just_pressed("attack"):
		if resume_combo_after_dash:
			resume_combo_after_dash = false
			dash_cooldown_timer = DASH_COOLDOWN
			start_combo()
			return
		current_state = State.ATTACKING
		animated_sprite.play("dash_attack")
		return
		
	if dash_timer <= 0:
		current_state = State.NORMAL
		dash_cooldown_timer = DASH_COOLDOWN
		if resume_combo_after_dash:
			resume_combo_after_dash = false
			combo_timer = COMBO_TIMEOUT

func state_plunging(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta * 1.5 
		velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		velocity.x = 0
		if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0:
			start_dash()

# --- HELPER FUNCTIONS ---

func start_dash() -> void:
	current_state = State.DASHING
	dash_timer = DASH_DURATION
	animated_sprite.play("dash")

func start_combo() -> void:
	current_state = State.ATTACKING
	buffered_attack = false
	combo_timer = 0.0 
	
	match combo_step:
		0:
			combo_dash_cancel_used = false
			resume_combo_after_dash = false
			animated_sprite.play("basic_attack_1")
			combo_step = 1
		1:
			animated_sprite.play("basic_attack_2")
			combo_step = 2
		2:
			animated_sprite.play("basic_attack_3")
			combo_step = 0

func take_damage(amount: float = ENEMY_DAMAGE) -> void:
	if is_dead:
		return
	
	var last_health: float = health
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, MAX_HEALTH)
	
	current_state = State.HURT
	combo_step = 0
	combo_dash_cancel_used = false
	resume_combo_after_dash = false
	animated_sprite.play("hurt")
	
	if health <= 0.0:
		die(last_health)

func die(last_health_before_death: float) -> void:
	if is_dead:
		return
	
	is_dead = true
	disable_attack_hitbox()
	velocity = Vector2.ZERO
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	died.emit(last_health_before_death, MAX_HEALTH)

func get_current_health() -> float:
	return health

func set_ultimate_percent(value: float) -> void:
	ultimate_percent = clampf(value, 0.0, 100.0)

func can_use_ultimate() -> bool:
	if ultimate_percent < 100.0:
		return false
	
	var game_manager: Node = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("consume_ultimate"):
		return game_manager.consume_ultimate()
	
	ultimate_percent = 0.0
	return true

func setup_attack_hitbox() -> void:
	attack_hitbox = Area2D.new()
	attack_hitbox.name = "AttackHitbox"
	attack_hitbox.collision_layer = 0
	attack_hitbox.collision_mask = 1
	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false
	add_child(attack_hitbox)
	
	attack_hitbox_shape = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = ATTACK_HITBOX_SETTINGS["basic_attack_1"]["size"]
	attack_hitbox_shape.shape = shape
	attack_hitbox_shape.disabled = true
	attack_hitbox.add_child(attack_hitbox_shape)
	
	attack_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)
	attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)

func update_attack_hitbox() -> void:
	var animation := String(animated_sprite.animation)
	var active_frames: Array = ATTACK_ACTIVE_FRAMES.get(animation, [])
	var is_active := active_frames.has(animated_sprite.frame)
	
	if not is_active:
		disable_attack_hitbox()
		return
	
	var settings: Dictionary = ATTACK_HITBOX_SETTINGS.get(animation, ATTACK_HITBOX_SETTINGS["basic_attack_1"])
	var offset: Vector2 = settings["offset"]
	var size: Vector2 = settings["size"]
	var facing := -1.0 if animated_sprite.flip_h else 1.0
	var shape := attack_hitbox_shape.shape as RectangleShape2D
	
	shape.size = size
	attack_hitbox.position = Vector2(offset.x * facing, offset.y)
	attack_hitbox.set_deferred("monitoring", true)
	attack_hitbox_shape.set_deferred("disabled", false)
	call_deferred("check_attack_hitbox_overlaps")

func check_attack_hitbox_overlaps() -> void:
	if not attack_hitbox or not attack_hitbox.monitoring:
		return
	
	for area in attack_hitbox.get_overlapping_areas():
		register_attack_hit(area)
	
	for body in attack_hitbox.get_overlapping_bodies():
		register_attack_hit(body)

func disable_attack_hitbox() -> void:
	if not attack_hitbox:
		return
	
	if attack_hitbox.monitoring:
		hit_targets.clear()
	
	attack_hitbox.set_deferred("monitoring", false)
	attack_hitbox_shape.set_deferred("disabled", true)

func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	register_attack_hit(area)

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	register_attack_hit(body)

func register_attack_hit(target: Node) -> void:
	if target in hit_targets:
		return
	
	hit_targets.append(target)
	apply_attack_hit_effects(target, attack_hitbox.global_position, get_current_attack_damage())

func apply_attack_hit_effects(target: Node, source_position: Vector2, damage_amount: float) -> void:
	var receiver: Node = target.get_parent() if target is Area2D else target
	
	if receiver and receiver.has_method("take_damage"):
		receiver.call("take_damage", damage_amount, source_position)
	else:
		print("Hit: ", String(animated_sprite.animation), " frame ", animated_sprite.frame, " -> ", target.name)

func get_current_attack_damage() -> float:
	var animation_name := String(animated_sprite.animation)
	return float(ATTACK_DAMAGE.get(animation_name, 1.0))

func update_camera(delta: float) -> void:
	if not camera_2d:
		return

	var facing := -1.0 if animated_sprite.flip_h else 1.0

	if current_state == State.ULTIMATE:
		camera_target_offset = CAMERA_NORMAL_OFFSET + Vector2(CAMERA_ULTIMATE_LOOK_AHEAD * facing, 0)
	elif abs(velocity.x) > 1.0:
		camera_target_offset = CAMERA_NORMAL_OFFSET + Vector2(CAMERA_MOVE_LOOK_AHEAD * facing, 0)
	else:
		camera_target_offset = CAMERA_NORMAL_OFFSET

	camera_2d.position = camera_2d.position.lerp(camera_target_offset, CAMERA_LERP_SPEED * delta)

# --- LOGIKA VFX GENERATION ---

func spawn_ultimate_vfx() -> void:
	if not player_vfx:
		push_error("Gagal memunculkan VFX: Scene player_vfx belum dimasukkan di Inspector!")
		return
		
	var vfx_instance = player_vfx.instantiate()
	get_parent().add_child(vfx_instance)
	vfx_instance.global_position = weapon_marker.global_position
	
	if animated_sprite.flip_h:
		vfx_instance.scale.x = -1
	else:
		vfx_instance.scale.x = 1

	# Mencari AnimatedSprite2D di dalam scene VFX
	var vfx_sprite = vfx_instance if vfx_instance is AnimatedSprite2D else vfx_instance.get_node_or_null("AnimatedSprite2D")
	setup_ultimate_vfx_hitbox(vfx_instance, vfx_sprite)
	
	if vfx_sprite:
		vfx_sprite.frame = 0 # Memastikan dimulai dari frame awal (0)
		vfx_sprite.play()    # Memutar runtunan sequence frame 0 - 3
		
		# Hubungkan sinyal agar saat frame 3 selesai (animasi tamat), objek langsung terhapus
		vfx_sprite.animation_finished.connect(vfx_instance.queue_free)
	else:
		# Jika gagal mendeteksi node sprite, hapus manual setelah estimasi durasi selesai (misal 0.4 detik)
		get_tree().create_timer(0.4).timeout.connect(vfx_instance.queue_free)

func setup_ultimate_vfx_hitbox(vfx_instance: Node, vfx_sprite: AnimatedSprite2D) -> void:
	var vfx_hitbox := vfx_instance.get_node_or_null("Area2D") as Area2D
	if not vfx_hitbox:
		return
	
	vfx_hitbox.name = "UltimateVfxHitbox"
	vfx_hitbox.collision_layer = 0
	vfx_hitbox.collision_mask = 1
	vfx_hitbox.monitoring = true
	vfx_hitbox.monitorable = false
	vfx_hitbox.position = VFX_HITBOX_OFFSET
	vfx_hitbox.set_meta("hit_targets", [])
	
	var vfx_hitbox_shape := vfx_hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not vfx_hitbox_shape:
		vfx_hitbox_shape = CollisionShape2D.new()
		vfx_hitbox_shape.name = "CollisionShape2D"
		vfx_hitbox.add_child(vfx_hitbox_shape)
	
	var shape := RectangleShape2D.new()
	shape.size = VFX_HITBOX_SIZE
	vfx_hitbox_shape.shape = shape
	vfx_hitbox_shape.disabled = false
	
	vfx_hitbox.area_entered.connect(_on_ultimate_vfx_hitbox_area_entered.bind(vfx_hitbox, vfx_sprite))
	vfx_hitbox.body_entered.connect(_on_ultimate_vfx_hitbox_body_entered.bind(vfx_hitbox, vfx_sprite))
	call_deferred("check_ultimate_vfx_hitbox_overlaps", vfx_hitbox, vfx_sprite)

func _on_ultimate_vfx_hitbox_area_entered(area: Area2D, vfx_hitbox: Area2D, vfx_sprite: AnimatedSprite2D) -> void:
	register_ultimate_vfx_hit(area, vfx_hitbox, vfx_sprite)

func _on_ultimate_vfx_hitbox_body_entered(body: Node2D, vfx_hitbox: Area2D, vfx_sprite: AnimatedSprite2D) -> void:
	register_ultimate_vfx_hit(body, vfx_hitbox, vfx_sprite)

func register_ultimate_vfx_hit(target: Node, vfx_hitbox: Area2D, vfx_sprite: AnimatedSprite2D) -> void:
	if not vfx_sprite or vfx_sprite.frame < 0 or vfx_sprite.frame > 3:
		return
	
	var vfx_hit_targets: Array = vfx_hitbox.get_meta("hit_targets", [])
	if target in vfx_hit_targets:
		return
	
	vfx_hit_targets.append(target)
	vfx_hitbox.set_meta("hit_targets", vfx_hit_targets)
	var receiver: Node = target.get_parent() if target is Area2D else target
	
	if receiver and receiver.has_method("take_damage"):
		receiver.call("take_damage", get_current_attack_damage(), vfx_hitbox.global_position)
	else:
		print("Hit: ultimate_vfx frame ", vfx_sprite.frame, " -> ", target.name)


func check_ultimate_vfx_hitbox_overlaps(vfx_hitbox: Area2D, vfx_sprite: AnimatedSprite2D) -> void:
	if not vfx_hitbox or not vfx_hitbox.monitoring:
		return
	
	for area in vfx_hitbox.get_overlapping_areas():
		register_ultimate_vfx_hit(area, vfx_hitbox, vfx_sprite)
	
	for body in vfx_hitbox.get_overlapping_bodies():
		register_ultimate_vfx_hit(body, vfx_hitbox, vfx_sprite)

# --- SIGNAL CALLBACKS ---

func _on_animated_sprite_frame_changed() -> void:
	update_attack_hitbox()
	
	# Membaca Frame 4 dari urutan 0 (yaitu gambar ke-5 di sheet karakter)
	if animated_sprite.animation == "ultimate" and animated_sprite.frame == 4:
		if not vfx_spawned:
			vfx_spawned = true
			spawn_ultimate_vfx()

func _on_animated_sprite_2d_animation_finished() -> void:
	disable_attack_hitbox()
	
	match animated_sprite.animation:
		"recover_fall":
			animated_sprite.play("idle")
			
		"basic_attack_1", "basic_attack_2":
			if buffered_attack:
				start_combo()
			else:
				current_state = State.NORMAL
				combo_timer = COMBO_TIMEOUT 
				
		"basic_attack_3":
			current_state = State.NORMAL
			combo_step = 0
			combo_dash_cancel_used = false
			resume_combo_after_dash = false
			
		"dash_attack", "plunge_attack", "hurt", "ultimate":
			current_state = State.NORMAL
			animated_sprite.play("idle") # FIX BUG 2: Paksa ganti ke animasi idle setelah ultimate selesai
