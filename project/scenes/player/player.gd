extends CharacterBody2D
## Player — WASD movement, auto-aim fire arrow projectiles on Space.
## No weapon held; projectiles are spawned toward the nearest enemy.

@export var move_speed: float = 80.0

## Cooldown between shots in seconds.
@export var attack_cooldown: float = 0.35

## Damage dealt per projectile.
@export var attack_damage: int = 10

## World size limits (must match game.gd constants).
const WORLD_W: float = 1280.0
const WORLD_H: float = 800.0

var _attack_timer: float = 0.0
var _last_move_dir: Vector2 = Vector2.UP  # fallback fire direction
var _is_attacking: bool = false
var _is_hurt: bool = false
var _last_hp: int = 100

var _projectile_scene: PackedScene = preload("res://scenes/projectile/projectile.tscn")

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("player")
	_build_sprite_frames()
	_anim.animation_finished.connect(_on_animation_finished)
	GameState.hp_changed.connect(_on_hp_changed)
	GameState.player_died.connect(_on_player_died)
	_play("idle")
	queue_redraw()

	# Camera — follows the player with smooth lag, bounded to world size.
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.limit_left   = 0
	cam.limit_top    = 0
	cam.limit_right  = int(WORLD_W)
	cam.limit_bottom = int(WORLD_H)
	add_child(cam)
	cam.make_current()


# ---------------------------------------------------------------------------
# SpriteFrames — Wraith_01 animations.
# ---------------------------------------------------------------------------

func _build_sprite_frames() -> void:
	var sf := SpriteFrames.new()
	_add_anim(sf, "idle",   "idle",      "Idle",           12,  8.0, true)
	_add_anim(sf, "walk",   "walking",   "Moving Forward", 12, 12.0, true)
	_add_anim(sf, "attack", "attacking", "Attack",         12, 15.0, false)
	_add_anim(sf, "hurt",   "hurt",      "Hurt",           12, 10.0, false)
	_add_anim(sf, "die",    "dying",     "Dying",          15, 10.0, false)
	_anim.sprite_frames = sf


func _add_anim(sf: SpriteFrames, anim: String, folder: String,
		prefix: String, count: int, fps: float, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_loop(anim, loop)
	sf.set_animation_speed(anim, fps)
	for i in count:
		var path := "res://assets/player/%s/Wraith_01_%s_%03d.png" % [folder, prefix, i]
		sf.add_frame(anim, load(path))


# ---------------------------------------------------------------------------
# Physics — movement + continuous fire while Space is held
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not GameState.game_started:
		return
	_handle_movement()
	_handle_attack(delta)


func _handle_movement() -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_up"):    dir.y -= 1
	if Input.is_action_pressed("move_down"):  dir.y += 1
	if Input.is_action_pressed("move_left"):  dir.x -= 1
	if Input.is_action_pressed("move_right"): dir.x += 1
	velocity = dir.normalized() * move_speed
	move_and_slide()

	# Clamp to world bounds
	position.x = clampf(position.x, 0.0, WORLD_W)
	position.y = clampf(position.y, 0.0, WORLD_H)

	if dir != Vector2.ZERO:
		_last_move_dir = dir.normalized()
		_anim.flip_h = dir.x < 0

	if not _is_hurt and not _is_attacking:
		_play("walk" if dir != Vector2.ZERO else "idle")


func _handle_attack(delta: float) -> void:
	_attack_timer -= delta
	if _attack_timer <= 0.0 and Input.is_action_pressed("attack"):
		_fire()
		_attack_timer = attack_cooldown


# ---------------------------------------------------------------------------
# Fire a projectile aimed at the nearest enemy (or last move direction).
# ---------------------------------------------------------------------------

func _fire() -> void:
	var direction := _aim_direction()
	var proj: Area2D = _projectile_scene.instantiate()
	proj.global_position = global_position
	proj.direction = direction
	proj.damage = attack_damage
	# Spawn as sibling so projectiles don't move with the player
	get_parent().add_child(proj)
	# Play attack animation once per burst; let it finish before resetting
	if not _is_attacking:
		_is_attacking = true
		_anim.play("attack")


func _aim_direction() -> Vector2:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return _last_move_dir

	var nearest: Node2D = null
	var nearest_dist := INF
	for e: Node2D in enemies:
		var d := global_position.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e

	return (nearest.global_position - global_position).normalized()


# ---------------------------------------------------------------------------
# Animation callbacks
# ---------------------------------------------------------------------------

func _play(anim: String) -> void:
	if _anim.animation != anim:
		_anim.play(anim)


func _on_animation_finished() -> void:
	_is_hurt = false
	_is_attacking = false
	_play("idle")


func _on_hp_changed(new_hp: int) -> void:
	if new_hp < _last_hp and not _is_hurt:
		_is_hurt = true
		_play("hurt")
	_last_hp = new_hp
	queue_redraw()


# ---------------------------------------------------------------------------
# Floating health bar drawn in world space above the character.
# ---------------------------------------------------------------------------

func _draw() -> void:
	var bar_w := 30.0
	var bar_h := 3.0
	# Position bar above the sprite top (sprite is ~42 px tall, centered).
	var bar_x := -bar_w * 0.5
	var bar_y := -26.0
	var hp_ratio := clampf(float(GameState.player_hp) / float(GameState.max_hp), 0.0, 1.0)

	# Dark background
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.15, 0.15, 0.15))
	# Coloured fill: green when full, red when empty
	if hp_ratio > 0.0:
		var fill_color := Color(1.0 - hp_ratio, hp_ratio, 0.0)
		draw_rect(Rect2(bar_x, bar_y, bar_w * hp_ratio, bar_h), fill_color)


func _on_player_died() -> void:
	_is_hurt = false
	_is_attacking = false
	_play("die")
