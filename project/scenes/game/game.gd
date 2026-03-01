extends Node2D
## Game — root scene. Manages waves, HUD, menus, and the upgrade shop.
##
## Customization guide
## -------------------
## • Background color   — change background_color export on this node (default: white).
## • Background image   — set background_texture export; scales to fill the viewport.
## • Player sprites     — replace PNGs inside project/assets/player/ (keep filenames identical).
## • Enemy sprites      — replace PNGs inside project/assets/enemy/ (keep filenames identical).
## • Projectile sprites — replace PNGs inside project/assets/projectile/fire_arrow/.

@export var background_color: Color = Color.WHITE
@export var background_texture: Texture2D

## World size in game units — must match the Camera2D limits in player.gd.
const WORLD_W: float = 1280.0
const WORLD_H: float = 800.0

var _enemy_scene: PackedScene = preload("res://scenes/enemy/enemy.tscn")

# HUD node refs (built in _ready)
var _hp_label: Label
var _hp_bar_fill: ColorRect
var _wave_label: Label
var _currency_label: Label
const _HP_BAR_W: float = 50.0

# Pause menu refs
var _pause_overlay: ColorRect
var _pause_panel: Panel
var _status_label: Label
var _start_btn: Button

# Upgrade shop refs
var _shop_layer: CanvasLayer
var _shop_panel: Panel
var _shop_gold_label: Label
var _shop_buy_btns: Array[Button] = []
var _shop_open: bool = false

var _enemies_alive: int = 0
var _menu_open: bool = true

const _UPGRADES := [
	{"label": "MAX HP    +25 HP",  "cost": 30, "id": "hp"},
	{"label": "DAMAGE   +8 DMG",   "cost": 40, "id": "damage"},
	{"label": "SPEED    +15 SPD",  "cost": 35, "id": "speed"},
	{"label": "FIRE RATE   ×0.8",  "cost": 50, "id": "firerate"},
]


func _ready() -> void:
	_setup_background()
	_setup_hud()
	_setup_pause_menu()
	_setup_shop()

	GameState.hp_changed.connect(_update_hp_display)
	GameState.currency_changed.connect(_on_currency_changed)
	GameState.player_died.connect(_on_player_died)

	_show_menu("", "NEW GAME")


func _on_currency_changed(v: int) -> void:
	_currency_label.text = "%d" % v
	if _shop_open:
		_refresh_shop_buttons()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and GameState.game_started and not _shop_open:
		if _menu_open:
			_resume()
		else:
			_show_menu("PAUSED", "RESUME")


# ---------------------------------------------------------------------------
# Wave management
# ---------------------------------------------------------------------------

func _start_new_game() -> void:
	for child in $Enemies.get_children():
		child.queue_free()

	GameState.reset()
	GameState.game_started = true
	$Player.position = Vector2(WORLD_W * 0.5, WORLD_H * 0.5)
	$Player.modulate = Color.WHITE
	_enemies_alive = 0
	_resume()
	_refresh_hud()

	await get_tree().create_timer(1.0).timeout
	_spawn_wave(GameState.next_wave())


func _spawn_wave(wave_num: int) -> void:
	_wave_label.text = "WAVE %d" % wave_num
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
	await get_tree().create_timer(1.0).timeout
	if GameState.game_started:
		_open_shop()


func _on_player_died() -> void:
	await get_tree().create_timer(0.9).timeout
	_show_menu("GAME OVER", "PLAY AGAIN")


## Spawn at the edges of the current camera view (viewport = 320×200),
## offset slightly outside so enemies walk in from off-screen.
func _random_edge_pos() -> Vector2:
	var cx: float = $Player.position.x
	var cy: float = $Player.position.y
	var hw := 175.0   # viewport half-width + margin
	var hh := 115.0   # viewport half-height + margin
	var x1 := maxf(8.0, cx - hw)
	var x2 := minf(WORLD_W - 8.0, cx + hw)
	var y1 := maxf(8.0, cy - hh)
	var y2 := minf(WORLD_H - 8.0, cy + hh)
	match randi() % 4:
		0: return Vector2(randf_range(x1, x2), y1)
		1: return Vector2(randf_range(x1, x2), y2)
		2: return Vector2(x1, randf_range(y1, y2))
		_: return Vector2(x2, randf_range(y1, y2))


# ---------------------------------------------------------------------------
# HUD helpers
# ---------------------------------------------------------------------------

func _update_hp_display(hp: int) -> void:
	_hp_label.text = "%d" % hp
	var ratio := clampf(float(hp) / float(GameState.max_hp), 0.0, 1.0)
	_hp_bar_fill.size.x = _HP_BAR_W * ratio
	if ratio > 0.6:
		_hp_bar_fill.color = Color(0.15, 0.75, 0.15)
	elif ratio > 0.3:
		_hp_bar_fill.color = Color(0.85, 0.50, 0.05)
	else:
		_hp_bar_fill.color = Color(0.85, 0.15, 0.15)


func _refresh_hud() -> void:
	_update_hp_display(GameState.player_hp)
	_wave_label.text     = "WAVE %d" % GameState.wave
	_currency_label.text = "%d" % GameState.currency


# ---------------------------------------------------------------------------
# Pause / menu helpers
# ---------------------------------------------------------------------------

func _show_menu(status: String, btn_text: String) -> void:
	_menu_open = true
	_status_label.text = status
	match status:
		"GAME OVER":
			_status_label.add_theme_color_override("font_color", Color(1.0, 0.22, 0.12))
		"PAUSED":
			_status_label.add_theme_color_override("font_color", Color(0.75, 0.55, 1.0))
		_:
			_status_label.add_theme_color_override("font_color", Color(0.65, 0.48, 0.08))
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
# Upgrade shop
# ---------------------------------------------------------------------------

func _open_shop() -> void:
	_shop_open = true
	_shop_gold_label.text = "GOLD: %d" % GameState.currency
	_refresh_shop_buttons()
	_shop_layer.visible = true
	get_tree().paused = true
	if not _shop_buy_btns.is_empty():
		_shop_buy_btns[0].grab_focus()


func _close_shop() -> void:
	_shop_open = false
	_shop_layer.visible = false
	get_tree().paused = false
	_spawn_wave(GameState.next_wave())


func _refresh_shop_buttons() -> void:
	_shop_gold_label.text = "GOLD: %d" % GameState.currency
	for i in _shop_buy_btns.size():
		_shop_buy_btns[i].disabled = GameState.currency < _UPGRADES[i]["cost"]


func _on_buy_pressed(idx: int) -> void:
	var up: Dictionary = _UPGRADES[idx]
	var cost: int = up["cost"]
	if GameState.currency < cost:
		return
	GameState.currency -= cost
	GameState.currency_changed.emit(GameState.currency)
	match up["id"]:
		"hp":
			GameState.max_hp += 25
			GameState.player_hp = GameState.max_hp
			GameState.hp_changed.emit(GameState.player_hp)
		"damage":
			$Player.attack_damage += 8
		"speed":
			$Player.move_speed += 15
		"firerate":
			$Player.attack_cooldown = maxf(0.08, $Player.attack_cooldown * 0.8)
	_refresh_shop_buttons()


# ---------------------------------------------------------------------------
# Node setup helpers
# ---------------------------------------------------------------------------

func _apply_btn_style(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.07, 0.16)
	normal.border_width_top    = 1
	normal.border_width_bottom = 1
	normal.border_width_left   = 1
	normal.border_width_right  = 1
	normal.border_color = Color(0.55, 0.40, 0.06)
	normal.content_margin_top    = 4
	normal.content_margin_bottom = 4
	normal.content_margin_left   = 6
	normal.content_margin_right  = 6

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color    = Color(0.20, 0.13, 0.30)
	hover.border_color = Color(0.90, 0.70, 0.18)

	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color    = Color(0.06, 0.04, 0.10)
	pressed_style.border_color = Color(0.90, 0.70, 0.18)

	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("focus",   hover)
	btn.add_theme_color_override("font_color",         Color(1.00, 0.82, 0.28))
	btn.add_theme_color_override("font_hover_color",   Color(1.00, 0.95, 0.50))
	btn.add_theme_color_override("font_pressed_color", Color(0.80, 0.65, 0.20))
	btn.add_theme_font_size_override("font_size", 10)


func _apply_buy_btn_style(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.14, 0.06)
	normal.border_width_top    = 1
	normal.border_width_bottom = 1
	normal.border_width_left   = 1
	normal.border_width_right  = 1
	normal.border_color = Color(0.30, 0.60, 0.20)
	normal.content_margin_top    = 2
	normal.content_margin_bottom = 2
	normal.content_margin_left   = 5
	normal.content_margin_right  = 5

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color    = Color(0.10, 0.26, 0.10)
	hover.border_color = Color(0.50, 1.00, 0.40)

	var dis := normal.duplicate() as StyleBoxFlat
	dis.bg_color    = Color(0.08, 0.08, 0.08)
	dis.border_color = Color(0.25, 0.25, 0.25)

	btn.add_theme_stylebox_override("normal",   normal)
	btn.add_theme_stylebox_override("hover",    hover)
	btn.add_theme_stylebox_override("focus",    hover)
	btn.add_theme_stylebox_override("disabled", dis)
	btn.add_theme_color_override("font_color",          Color(0.50, 1.00, 0.40))
	btn.add_theme_color_override("font_hover_color",    Color(0.80, 1.00, 0.70))
	btn.add_theme_color_override("font_disabled_color", Color(0.30, 0.30, 0.30))
	btn.add_theme_font_size_override("font_size", 8)


# ---------------------------------------------------------------------------
# Scene node construction
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

	# Translucent dark strip across the top
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.05, 0.03, 0.08, 0.90)
	bar_bg.size = Vector2(320, 13)
	layer.add_child(bar_bg)

	# ── HP section (left) ────────────────────────────────────────────────
	var hp_tag := Label.new()
	hp_tag.text = "HP"
	hp_tag.position = Vector2(3, 2)
	hp_tag.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	hp_tag.add_theme_font_size_override("font_size", 8)
	layer.add_child(hp_tag)

	var hp_bar_bg := ColorRect.new()
	hp_bar_bg.color = Color(0.20, 0.05, 0.05)
	hp_bar_bg.position = Vector2(17, 4)
	hp_bar_bg.size = Vector2(_HP_BAR_W, 5)
	layer.add_child(hp_bar_bg)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color = Color(0.15, 0.75, 0.15)
	_hp_bar_fill.position = Vector2(17, 4)
	_hp_bar_fill.size = Vector2(_HP_BAR_W, 5)
	layer.add_child(_hp_bar_fill)

	_hp_label = Label.new()
	_hp_label.text = "100"
	_hp_label.position = Vector2(70, 2)
	_hp_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.78))
	_hp_label.add_theme_font_size_override("font_size", 8)
	layer.add_child(_hp_label)

	# ── Wave section (centre) ─────────────────────────────────────────────
	_wave_label = Label.new()
	_wave_label.text = "WAVE 0"
	_wave_label.position = Vector2(118, 2)
	_wave_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.18))
	_wave_label.add_theme_font_size_override("font_size", 8)
	layer.add_child(_wave_label)

	# ── Gold section (right) ──────────────────────────────────────────────
	var gold_tag := Label.new()
	gold_tag.text = "G"
	gold_tag.position = Vector2(248, 2)
	gold_tag.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
	gold_tag.add_theme_font_size_override("font_size", 8)
	layer.add_child(gold_tag)

	_currency_label = Label.new()
	_currency_label.text = "0"
	_currency_label.position = Vector2(256, 2)
	_currency_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
	_currency_label.add_theme_font_size_override("font_size", 8)
	layer.add_child(_currency_label)


func _setup_pause_menu() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PauseMenu"
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	_pause_overlay = ColorRect.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.color = Color(0.00, 0.00, 0.04, 0.78)
	layer.add_child(_pause_overlay)

	_pause_panel = Panel.new()
	_pause_panel.position = Vector2(80, 42)
	_pause_panel.size = Vector2(160, 116)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.04, 0.10)
	panel_style.border_width_top    = 2
	panel_style.border_width_bottom = 2
	panel_style.border_width_left   = 2
	panel_style.border_width_right  = 2
	panel_style.border_color = Color(0.65, 0.48, 0.08)
	_pause_panel.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(_pause_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   =  8.0
	vbox.offset_top    =  6.0
	vbox.offset_right  = -8.0
	vbox.offset_bottom = -6.0
	vbox.add_theme_constant_override("separation", 5)
	_pause_panel.add_child(vbox)

	var title := Label.new()
	title.text = "MOUNTAIN MADNESS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.18))
	title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(title)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color(0.50, 0.36, 0.06)
	vbox.add_child(divider)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 9)
	vbox.add_child(_status_label)

	_start_btn = Button.new()
	_start_btn.text = "NEW GAME"
	_start_btn.pressed.connect(_on_start_pressed)
	_apply_btn_style(_start_btn)
	vbox.add_child(_start_btn)

	var quit_btn := Button.new()
	quit_btn.text = "QUIT"
	quit_btn.pressed.connect(get_tree().quit)
	_apply_btn_style(quit_btn)
	vbox.add_child(quit_btn)

	_start_btn.focus_neighbor_bottom = _start_btn.get_path_to(quit_btn)
	_start_btn.focus_neighbor_top    = _start_btn.get_path_to(quit_btn)
	quit_btn.focus_neighbor_top      = quit_btn.get_path_to(_start_btn)
	quit_btn.focus_neighbor_bottom   = quit_btn.get_path_to(_start_btn)


func _setup_shop() -> void:
	_shop_layer = CanvasLayer.new()
	_shop_layer.name = "Shop"
	_shop_layer.layer = 9
	_shop_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_shop_layer.visible = false
	add_child(_shop_layer)

	# Dark overlay
	var ov := ColorRect.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.color = Color(0.00, 0.00, 0.04, 0.72)
	_shop_layer.add_child(ov)

	# Panel — centered in 320×200
	_shop_panel = Panel.new()
	_shop_panel.position = Vector2(28, 18)
	_shop_panel.size = Vector2(264, 164)

	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.04, 0.10)
	ps.border_width_top    = 2
	ps.border_width_bottom = 2
	ps.border_width_left   = 2
	ps.border_width_right  = 2
	ps.border_color = Color(0.65, 0.48, 0.08)
	_shop_panel.add_theme_stylebox_override("panel", ps)
	_shop_layer.add_child(_shop_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   =  10.0
	vbox.offset_top    =   7.0
	vbox.offset_right  = -10.0
	vbox.offset_bottom =  -7.0
	vbox.add_theme_constant_override("separation", 4)
	_shop_panel.add_child(vbox)

	# Title row
	var title := Label.new()
	title.text = "WAVE COMPLETE!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.18))
	title.add_theme_font_size_override("font_size", 11)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "UPGRADE SHOP"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.75, 0.58, 0.20))
	sub.add_theme_font_size_override("font_size", 8)
	vbox.add_child(sub)

	var div1 := ColorRect.new()
	div1.custom_minimum_size = Vector2(0, 1)
	div1.color = Color(0.50, 0.36, 0.06)
	vbox.add_child(div1)

	# Gold display
	_shop_gold_label = Label.new()
	_shop_gold_label.text = "GOLD: 0"
	_shop_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_shop_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
	_shop_gold_label.add_theme_font_size_override("font_size", 8)
	vbox.add_child(_shop_gold_label)

	# Upgrade rows
	_shop_buy_btns.clear()
	for i in _UPGRADES.size():
		var up: Dictionary = _UPGRADES[i]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		vbox.add_child(row)

		var lbl := Label.new()
		lbl.text = "%s  [%dG]" % [up["label"], up["cost"]]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", Color(0.88, 0.84, 0.78))
		lbl.add_theme_font_size_override("font_size", 8)
		row.add_child(lbl)

		var buy_btn := Button.new()
		buy_btn.text = "BUY"
		buy_btn.custom_minimum_size = Vector2(30, 0)
		var idx := i  # capture for lambda
		buy_btn.pressed.connect(func(): _on_buy_pressed(idx))
		_apply_buy_btn_style(buy_btn)
		row.add_child(buy_btn)
		_shop_buy_btns.append(buy_btn)

	var div2 := ColorRect.new()
	div2.custom_minimum_size = Vector2(0, 1)
	div2.color = Color(0.50, 0.36, 0.06)
	vbox.add_child(div2)

	# Continue button
	var cont_btn := Button.new()
	cont_btn.text = "CONTINUE  ▶"
	cont_btn.pressed.connect(_close_shop)
	_apply_btn_style(cont_btn)
	vbox.add_child(cont_btn)


func _on_start_pressed() -> void:
	_start_new_game()
