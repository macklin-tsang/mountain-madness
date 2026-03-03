extends Node2D
## Floating damage number that rises and fades out in world space.
## Instantiate, call init(), then add_child() to any Node2D in the scene.

var _amount: int = 0
var _col: Color = Color.WHITE
var _timer: float = 0.0

const _LIFETIME: float = 0.65
const _RISE: float = 28.0   # pixels per second upward
const _FONT_SIZE: int = 10


func init(amount: int, col: Color) -> void:
	_amount = amount
	_col = col


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= _LIFETIME:
		queue_free()
		return
	position.y -= _RISE * delta
	queue_redraw()


func _draw() -> void:
	var alpha := 1.0 - (_timer / _LIFETIME)
	var font := ThemeDB.fallback_font
	# Small black shadow for readability
	draw_string(font, Vector2(1, 1), str(_amount),
		HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE,
		Color(0.0, 0.0, 0.0, alpha * 0.7))
	# Coloured text
	draw_string(font, Vector2(0, 0), str(_amount),
		HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE,
		Color(_col.r, _col.g, _col.b, alpha))
