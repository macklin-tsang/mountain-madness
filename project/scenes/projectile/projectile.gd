extends Area2D
## Projectile — fire arrow with a glowing laser trail effect.
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
		return
	queue_redraw()


# ---------------------------------------------------------------------------
# Glow effect — drawn in Area2D local space, behind AnimatedSprite2D child.
# Local X axis runs along the arrow shaft; -X = tip (direction of travel).
# Antialiased lines produce smooth rounded-cap beams with no hard edges.
# ---------------------------------------------------------------------------

func _draw() -> void:
	var pulse := 0.80 + 0.20 * sin(_timer * 22.0)
	var tip  := Vector2(-9.0, 0.0)
	var tail := Vector2( 9.0, 0.0)

	# Wide outer glow
	draw_line(tip, tail, Color(1.00, 0.28, 0.00, 0.18 * pulse), 9.0, true)
	# Mid bloom
	draw_line(tip, tail, Color(1.00, 0.58, 0.08, 0.35 * pulse), 5.0, true)
	# Inner bright band
	draw_line(tip, tail, Color(1.00, 0.85, 0.32, 0.65 * pulse), 2.5, true)
	# Hot white core
	draw_line(tip, tail, Color(1.00, 0.98, 0.80, 1.00),          0.8, true)

	# Tip flare
	draw_circle(tip, 3.5, Color(1.00, 0.68, 0.12, 0.30 * pulse))
	draw_circle(tip, 1.8, Color(1.00, 0.95, 0.55, 0.70 * pulse))
	draw_circle(tip, 0.9, Color(1.00, 1.00, 1.00, 1.00))


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
