extends Area2D
## Projectile — fire arrow that travels toward a target direction.
## SpriteFrames are cached statically so they are only loaded once
## regardless of how many projectiles are on screen simultaneously.

@export var speed: float = 300.0
@export var damage: int = 15
@export var lifetime: float = 2.0

## Set by the spawner before add_child().
var direction: Vector2 = Vector2.RIGHT

static var _cached_frames: SpriteFrames

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
var _timer: float = 0.0


func _ready() -> void:
	if not _cached_frames:
		_cached_frames = _build_frames()
	_anim.sprite_frames = _cached_frames
	_anim.play("fly")

	# The source sprite faces LEFT, so add PI to flip it toward the target.
	rotation = direction.angle() + PI

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	position += direction * speed * delta
	_timer += delta
	if _timer >= lifetime:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()


# ---------------------------------------------------------------------------
# Build (and cache) the SpriteFrames from res://assets/projectile/fire_arrow/
# Filenames: "Fire Arrow_Frame_01.png" … "Fire Arrow_Frame_08.png"
# ---------------------------------------------------------------------------

static func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation("fly")
	sf.set_animation_loop("fly", true)
	sf.set_animation_speed("fly", 12.0)
	for i in range(1, 9):
		var path := "res://assets/projectile/fire_arrow/Fire Arrow_Frame_%02d.png" % i
		sf.add_frame("fly", load(path))
	return sf
