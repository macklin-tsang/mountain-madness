extends CharacterBody2D
## Player — keyboard movement + spacebar auto-lock attack, with full sprite animation.

@export var move_speed: float = 60.0
@export var attack_range: float = 80.0
@export var attack_damage: int = 30
@export var attack_cooldown: float = 0.5

var _attack_ready: bool = true
var _attack_timer: float = 0.0
var _is_attacking: bool = false
var _is_hurt: bool = false
var _last_hp: int = 100

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("player")
	_build_sprite_frames()
	_anim.animation_finished.connect(_on_animation_finished)
	GameState.hp_changed.connect(_on_hp_changed)
	GameState.player_died.connect(_on_player_died)
	_play("idle")


# ---------------------------------------------------------------------------
# Build SpriteFrames from the copied assets at runtime.
# All frames live under res://assets/player/ so they work in exported builds.
# ---------------------------------------------------------------------------

func _build_sprite_frames() -> void:
	var sf := SpriteFrames.new()

	_add_anim(sf, "idle",   "idle",      "Idle",           12,  8.0,  true)
	_add_anim(sf, "walk",   "walking",   "Moving Forward", 12, 12.0,  true)
	_add_anim(sf, "attack", "attacking", "Attack",         12, 15.0,  false)
	_add_anim(sf, "hurt",   "hurt",      "Hurt",           12, 10.0,  false)
	_add_anim(sf, "die",    "dying",     "Dying",          15, 10.0,  false)

	_anim.sprite_frames = sf


## folder   — subfolder name under res://assets/player/
## prefix   — the part of the filename between "Wraith_01_" and "_NNN.png"
## count    — total frame count
func _add_anim(sf: SpriteFrames, anim: String, folder: String,
		prefix: String, count: int, fps: float, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_loop(anim, loop)
	sf.set_animation_speed(anim, fps)
	for i in count:
		var path := "res://assets/player/%s/Wraith_01_%s_%03d.png" % [folder, prefix, i]
		sf.add_frame(anim, load(path))


# ---------------------------------------------------------------------------
# Physics / input
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not GameState.game_started:
		return
	_handle_movement()
	_tick_attack_cooldown(delta)


func _handle_movement() -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_up"):    dir.y -= 1
	if Input.is_action_pressed("move_down"):  dir.y += 1
	if Input.is_action_pressed("move_left"):  dir.x -= 1
	if Input.is_action_pressed("move_right"): dir.x += 1
	velocity = dir.normalized() * move_speed
	move_and_slide()

	# Flip sprite to face the direction of horizontal movement
	if dir.x != 0:
		_anim.flip_h = dir.x < 0

	# Update walk / idle animation only when not in a one-shot state
	if not _is_attacking and not _is_hurt:
		_play("walk" if dir != Vector2.ZERO else "idle")


func _tick_attack_cooldown(delta: float) -> void:
	if not _attack_ready:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_attack_ready = true


func _input(event: InputEvent) -> void:
	if not GameState.game_started:
		return
	if event.is_action_pressed("attack") and _attack_ready:
		_perform_attack()


# ---------------------------------------------------------------------------
# Attack logic
# ---------------------------------------------------------------------------

func _perform_attack() -> void:
	_attack_ready = false
	_attack_timer = attack_cooldown
	_is_attacking = true
	_play("attack")

	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	var nearest: Node2D = null
	var nearest_dist := INF
	for e: Node2D in enemies:
		var d := global_position.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e

	if nearest and nearest_dist <= attack_range:
		nearest.take_damage(attack_damage)


# ---------------------------------------------------------------------------
# Animation callbacks
# ---------------------------------------------------------------------------

func _play(anim: String) -> void:
	if _anim.animation != anim:
		_anim.play(anim)


func _on_animation_finished() -> void:
	_is_attacking = false
	_is_hurt = false
	# Return to idle; the next _physics_process will switch to walk if moving
	_play("idle")


func _on_hp_changed(new_hp: int) -> void:
	if new_hp < _last_hp and not _is_hurt:
		_is_hurt = true
		_play("hurt")
	_last_hp = new_hp


func _on_player_died() -> void:
	_is_attacking = false
	_is_hurt = false
	_play("die")
