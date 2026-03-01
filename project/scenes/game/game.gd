extends Node2D
## Game — root scene. Manages waves, HUD, and the ESC pause/menu overlay.
##
## Customization guide
## -------------------
## • Background color   — change background_color export on this node (default: white).
## • Background image   — set background_texture export; scales to fill the 320×200 viewport.
## • Player sprites     — replace PNGs inside project/assets/player/ (keep filenames identical).
## • Enemy sprites      — replace PNGs inside project/assets/enemy/ (keep filenames identical).
## • Projectile sprites — replace PNGs inside project/assets/projectile/fire_arrow/.

@export var background_color: Color = Color.WHITE
@export var background_texture: Texture2D

var _enemy_scene: PackedScene = preload("res://scenes/enemy/enemy.tscn")

# HUD node refs (built in _ready)
var _hp_label: Label
var _wave_label: Label
var _currency_label: Label

# Pause menu refs (built in _ready)
var _pause_overlay: ColorRect
var _pause_panel: Panel
var _status_label: Label
var _start_btn: Button

var _enemies_alive: int = 0
var _menu_open: bool = true


func _ready() -> void:
	_setup_background()
	_setup_hud()
	_setup_pause_menu()

	GameState.hp_changed.connect(func(v): _hp_label.text = "HP: %d" % v)
	GameState.currency_changed.connect(func(v): _currency_label.text = "Gold: %d" % v)
	GameState.player_died.connect(_on_player_died)

	_show_menu("", "New Game")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and GameState.game_started:
		if _menu_open:
			_resume()
		else:
			_show_menu("PAUSED", "Resume")


# ---------------------------------------------------------------------------
# Wave management
# ---------------------------------------------------------------------------

func _start_new_game() -> void:
	for child in $Enemies.get_children():
		child.queue_free()

	GameState.reset()
	GameState.game_started = true
	$Player.position = Vector2(160, 100)
	$Player.modulate = Color.WHITE
	_enemies_alive = 0
	_resume()
	_refresh_hud()

	await get_tree().create_timer(1.0).timeout
	_spawn_wave(GameState.next_wave())


func _spawn_wave(wave_num: int) -> void:
	_wave_label.text = "Wave %d" % wave_num
	var count := GameState.enemies_for_wave(wave_num)
	var speed_scale := 1.0 + (wave_num - 1) * 0.08
	_enemies_alive = count

	for i in count:
		var enemy: CharacterBody2D = _enemy_scene.instantiate()
		enemy.position = _random_edge_pos()
		enemy.speed *= speed_scale
		enemy.enemy_died.connect(_on_enemy_died)
		$Enemies.add_child(enemy)


func _on_enemy_died(reward: int) -> void:
	GameState.add_currency(reward)
	_enemies_alive -= 1
	if _enemies_alive <= 0 and GameState.game_started:
		_wave_complete()


func _wave_complete() -> void:
	await get_tree().create_timer(2.0).timeout
	if GameState.game_started:
		_spawn_wave(GameState.next_wave())


func _on_player_died() -> void:
	await get_tree().create_timer(0.9).timeout
	_show_menu("GAME OVER", "Play Again")


func _random_edge_pos() -> Vector2:
	match randi() % 4:
		0: return Vector2(randf_range(0, 320), -15)
		1: return Vector2(randf_range(0, 320), 215)
		2: return Vector2(-15, randf_range(0, 200))
		_: return Vector2(335, randf_range(0, 200))


# ---------------------------------------------------------------------------
# HUD helpers
# ---------------------------------------------------------------------------

func _refresh_hud() -> void:
	_hp_label.text       = "HP: %d"   % GameState.player_hp
	_wave_label.text     = "Wave %d"  % GameState.wave
	_currency_label.text = "Gold: %d" % GameState.currency


# ---------------------------------------------------------------------------
# Pause / menu helpers
# ---------------------------------------------------------------------------

func _show_menu(status: String, btn_text: String) -> void:
	_menu_open = true
	_status_label.text = status
	_start_btn.text    = btn_text
	_pause_overlay.visible = true
	_pause_panel.visible   = true
	_start_btn.grab_focus()
	get_tree().paused = true


func _resume() -> void:
	_menu_open = false
	_pause_overlay.visible = false
	_pause_panel.visible   = false
	get_tree().paused = false


# ---------------------------------------------------------------------------
# Node setup — background, HUD, and pause menu are built in code so the
# .tscn stays minimal and artists only need to swap assets or export vars.
# ---------------------------------------------------------------------------

func _setup_background() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BackgroundLayer"
	layer.layer = -1
	add_child(layer)

	if background_texture:
		var tr := TextureRect.new()
		tr.texture = background_texture
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(tr)
	else:
		var cr := ColorRect.new()
		cr.color = background_color
		cr.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(cr)


func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	layer.layer = 1
	add_child(layer)

	_hp_label = Label.new()
	_hp_label.position = Vector2(2, 2)
	_hp_label.text = "HP: 100"
	_hp_label.add_theme_color_override("font_color", Color.BLACK)
	layer.add_child(_hp_label)

	_wave_label = Label.new()
	_wave_label.position = Vector2(128, 2)
	_wave_label.text = "Wave 0"
	_wave_label.add_theme_color_override("font_color", Color.BLACK)
	layer.add_child(_wave_label)

	_currency_label = Label.new()
	_currency_label.position = Vector2(248, 2)
	_currency_label.text = "Gold: 0"
	_currency_label.add_theme_color_override("font_color", Color.BLACK)
	layer.add_child(_currency_label)


func _setup_pause_menu() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PauseMenu"
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	_pause_overlay = ColorRect.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.color = Color(0, 0, 0, 0.65)
	layer.add_child(_pause_overlay)

	_pause_panel = Panel.new()
	_pause_panel.position = Vector2(100, 48)
	_pause_panel.size = Vector2(120, 84)
	layer.add_child(_pause_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	_pause_panel.add_child(vbox)

	var title := Label.new()
	title.text = "GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status_label)

	_start_btn = Button.new()
	_start_btn.text = "New Game"
	_start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(_start_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.pressed.connect(get_tree().quit)
	vbox.add_child(quit_btn)

	_start_btn.focus_neighbor_bottom = _start_btn.get_path_to(quit_btn)
	_start_btn.focus_neighbor_top    = _start_btn.get_path_to(quit_btn)
	quit_btn.focus_neighbor_top      = quit_btn.get_path_to(_start_btn)
	quit_btn.focus_neighbor_bottom   = quit_btn.get_path_to(_start_btn)


func _on_start_pressed() -> void:
	_start_new_game()
