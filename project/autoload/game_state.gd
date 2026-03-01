extends Node
## GameState — global singleton (autoload).
## Single source of truth for currency, wave, and player HP.

signal hp_changed(new_hp: int)
signal currency_changed(new_amount: int)
signal player_died()

var currency: int = 0
var wave: int = 0
var player_hp: int = 100
var max_hp: int = 100
var game_started: bool = false


func reset() -> void:
	currency = 0
	wave = 0
	player_hp = 100
	max_hp = 100
	game_started = false


func take_damage(amount: int) -> void:
	if not game_started:
		return
	player_hp = max(0, player_hp - amount)
	hp_changed.emit(player_hp)
	if player_hp <= 0:
		game_started = false
		player_died.emit()


func add_currency(amount: int) -> void:
	currency += amount
	currency_changed.emit(currency)


func next_wave() -> int:
	wave += 1
	return wave


## Returns how many enemies spawn on a given wave number (1-indexed).
func enemies_for_wave(n: int) -> int:
	return 3 + (n - 1) * 2
