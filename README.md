# Tickle Outbreak

First-person **tickle-zombie survival FPS** vertical slice for **Godot 4.3+**.

Tongue-in-cheek tone, placeholder art (colored capsules + simple FPS arms). Not pornographic — soft feet/stomach lore appears only in item descriptions.

## Open & run

1. Install [Godot 4.3+](https://godotengine.org/download) (Standard build is fine).
2. Launch Godot → **Import** → select `project.godot` in this folder.
3. Press **F5** (or Play). Main scene: `scenes/main/MainMenu.tscn`.

```bash
# If godot is on PATH:
godot --path /path/to/tickle-outbreak
```

## Controls

| Action | Binding |
|--------|---------|
| Move | WASD |
| Look | Mouse |
| Jump | Space |
| Dash (costs stamina) | Shift |
| Fire | LMB |
| Reload | R |
| Melee | F |
| Health potion | 1 |
| Energy drink | 2 |
| Bullets refill | 3 |
| Alcohol | 4 |
| Toggle mouse capture | Esc |

## Loop

1. **Main Menu** → New Run (starts with 100 coins for shop testing).
2. **Hub** — buy/equip guns, melee, armor; permanent character upgrades; buy consumables.
3. **Deploy** → city-block mission arena. Kill quota scales with mission number.
4. Clear → hub (mission advances). Health 0 → **Tickle Infected** game over (retry or hub).

## Balance data

All tunable numbers live under `data/*.json` (guns, melee, armor, consumables, zombies, upgrades, missions, currency, player stats). Prefer editing JSON over hardcoding.

## Project layout

```
data/           JSON balance tables
scenes/         MainMenu, Hub, Mission (+ embedded HUD/cinematic/game over)
scripts/
  autoload/     DataManager, GameState, EventBus
  player/       FPS controller + combat
  zombies/      Zombie AI / hitboxes / behaviors
  systems/      TickleSystem
  mission/      ArenaBuilder, MissionManager, MissionRoot
  hub/          Shop UI
  ui/           HUD, cinematic overlay, menus
```

## Design notes

See [DESIGN.md](DESIGN.md) for GDD summary, resolved ambiguities, and progression.

**Auto Rifle #3** rate of fire is `1/s` as specified in the design brief (possible typo); implemented as written and called out in `data/guns.json`.
