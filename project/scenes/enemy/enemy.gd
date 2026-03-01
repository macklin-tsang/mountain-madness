extends CharacterBody2D
## Enemy — chases the player, deals contact damage, plays Wraith_02 animations.

signal enemy_died(reward: int)

@export var max_hp: int = 30
@export var speed: float = 40.0
## Damage as a fraction of the player's max HP (0.20 = 20 % per hit).
@export var damage_fraction: float = 0.20
@export var contact_range: float = 24.0
@export var damage_cooldown: float = 1.0
@export var currency_reward: int = 10

var _hp: int
var _player: Node2D = null
var _damage_timer: float = 0.0
var _dead: bool = false
var _is_hurt: bool = false
var _is_attacking: bool = false

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D

const _DamageNumber = preload("res://scenes/effects/damage_number.gd")


func _ready() -> void:
	add_to_group("enemies")
	_hp = max_hp
	_build_sprite_frames()
	_anim.animation_finished.connect(_on_animation_finished)
	_play("idle")


# ---------------------------------------------------------------------------
# Build SpriteFrames from res://assets/enemy/ (Wraith_02 frames)
# ---------------------------------------------------------------------------

func _build_sprite_frames() -> void:
	var sf := SpriteFrames.new()
	_add_anim(sf, "idle",   "idle",      "Idle",           12,  8.0,  true)
	_add_anim(sf, "walk",   "walking",   "Moving Forward", 12, 12.0,  true)
	_add_anim(sf, "attack", "attacking", "Attack",         12, 15.0,  false)
	_add_anim(sf, "hurt",   "hurt",      "Hurt",           12, 10.0,  false)
	_add_anim(sf, "die",    "dying",     "Dying",          15, 10.0,  false)
	_anim.sprite_frames = sf


func _add_anim(sf: SpriteFrames, anim: String, folder: String,
		prefix: String, count: int, fps: float, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_loop(anim, loop)
	sf.set_animation_speed(anim, fps)
	for i in count:
		var path := "res://assets/enemy/%s/Wraith_02_%s_%03d.png" % [folder, prefix, i]
		sf.add_frame(anim, load(path))


# ---------------------------------------------------------------------------
# Physics
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _dead:
		return

	if not _player:
		var group := get_tree().get_nodes_in_group("player")
		if group.is_empty():
			return
		_player = group[0]

	# Chase and face the player
	var dir := (_player.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()
	_anim.flip_h = dir.x < 0

	# Animate movement (only when not in a one-shot state)
	if not _is_hurt and not _is_attacking:
		_play("walk")

	# Contact damage with cooldown
	if _damage_timer > 0.0:
		_damage_timer -= delta
	elif global_position.distance_to(_player.global_position) < contact_range:
		GameState.take_damage(max(1, int(GameState.max_hp * damage_fraction)))
		_damage_timer = damage_cooldown
		if not _is_hurt and not _dead:
			_is_attacking = true
			_play("attack")


# ---------------------------------------------------------------------------
# Damage / death
# ---------------------------------------------------------------------------

func take_damage(amount: int) -> void:
	if _dead:
		return
	_hp -= amount
	_is_hurt = true
	_play("hurt")

	# Spawn floating damage number
	var num := _DamageNumber.new()
	num.init(amount, Color(1.0, 0.75, 0.15))
	num.global_position = global_position + Vector2(randf_range(-4.0, 4.0), -12.0)
	get_parent().add_child(num)

	# White hit flash
	var tw := create_tween()
	tw.tween_property(_anim, "modulate", Color(2.5, 2.5, 2.5, 1.0), 0.04)
	tw.tween_property(_anim, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.10)

	if _hp <= 0:
		_die()


func _die() -> void:
	_dead = true
	remove_from_group("enemies")
	set_physics_process(false)
	enemy_died.emit(currency_reward)
	_play("die")


func _on_animation_finished() -> void:
	if _dead:
		# Death glow: warm orange bloom then fade out
		var tw := create_tween()
		tw.tween_property(_anim, "modulate", Color(2.8, 1.8, 0.4, 1.0), 0.12)
		tw.tween_property(_anim, "modulate", Color(1.5, 0.8, 0.2, 0.0), 0.28)
		tw.tween_callback(queue_free)
		return
	_is_hurt = false
	_is_attacking = false
	_play("idle")


func _play(anim: String) -> void:
	if _anim.animation != anim:
		_anim.play(anim)
