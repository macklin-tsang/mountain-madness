# Mountain Madness

A 2D survival wave-based game developed using Godot 4.6. Fight against infinite waves of enemy wraiths and use your rewarded gold to upgrade your attributes.

## Gameplay

- **Move** — WASD
- **Attack** — Hold Space to continuously fire flaming arrows at the nearest enemy
- **Pause** — Escape

The player automatically aims towards the nearest enemy. Contact with an enemy deals 20% of your max HP per tick.

### Wave Progression

| Wave | Enemies | Speed Scale |
|------|---------|-------------|
| 1    | 3       | 1.00×       |
| 2    | 5       | 1.08×       |
| 3    | 7       | 1.16×       |
| N    | 3 + (N−1)×2 | 1 + (N−1)×0.08× |

After clearing a wave, the upgrade shop opens automatically.

### Upgrade Shop

| Upgrade     | Effect           | Cost  |
|-------------|------------------|-------|
| MAX HP      | +25 HP           | 30 G  |
| DAMAGE      | +8 damage/arrow  | 40 G  |
| SPEED       | +15 move speed   | 35 G  |
| FIRE RATE   | Cooldown ×0.8    | 50 G  |

Upgrades can be purchased multiple times. Press **CONTINUE** to start the next wave.

### Starting Stats

| Stat           | Base Value |
|----------------|------------|
| HP             | 100        |
| Move speed     | 80         |
| Arrow damage   | 10         |
| Fire cooldown  | 0.35 s     |

## Project Structure

```
project/
├── project.godot
├── assets/
│   ├── player/          # Wraith_01 sprites (idle, walking, attacking, hurt, dying)
│   ├── enemy/           # Wraith_02 sprites (same structure)
│   └── projectile/fire_arrow/  # 8-frame fire arrow animation
├── autoload/
│   └── game_state.gd    # Global singleton — HP, currency, wave state
└── scenes/
    ├── game/            # Root scene, wave manager, HUD, pause menu, shop
    ├── player/          # Player movement, auto-aim, projectile firing
    ├── enemy/           # Enemy AI, contact damage, death effects
    ├── projectile/      # Fire arrow area2D
    └── effects/         # Floating damage numbers
```

## Tech Stack

- **Engine:** Godot 4.6
- **Renderer:** GL Compatibility
