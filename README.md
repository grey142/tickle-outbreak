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

## Controls (desktop)

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

## Mobile / landscape touch controls

On Android/iOS, or when a touchscreen is available, missions show an on-screen **landscape** control overlay (`MobileControls`):

```
[Tickle cinematic square]  [==== Health bar (top) ====]  [ammo/mission…]
                           [==== Stamina (secondary) ==]

[ D-pad: ▲ ▼ ◀ ▶ ]                              [DASH]
  (hold; diagonals OK)                          [FIRE] [MELEE]
                                                [RELOAD] [JUMP]
                                                [HP][NRG][AMMO][ALC]

[  swipe / drag empty game area to LOOK (never fires)  ]
```

| Control | Behavior |
|---------|----------|
| Bottom-left **D-pad** (Forward / Back / Left / Right) | Hold a button to move; hold two for diagonals (not a virtual joystick) |
| Press + drag on empty / non-button area | Look / aim (does **not** fire) |
| **FIRE** / **MELEE** (right cluster) | Hold FIRE to shoot; MELEE tap/hold |
| **DASH** (stacked above fire/melee) | Tap |
| **RELOAD** / **JUMP** (smaller, near cluster) | Tap |
| HP / NRG / AMMO / ALC | Compact consumables strip |
| Top health (+ stamina) | Primary bars; leave room for cinematic |
| Top-left **tickle cinematic** square | Stacked tickler silhouettes (1–5) when tickling |

Display defaults: `sensor_landscape` orientation, stretch `canvas_items` + `expand` aspect so phones fill the screen while desktop stays usable.

### Force-enable for desktop / editor testing

1. **Main Menu** → check **Touch controls (desktop test)** before starting a run, **or**
2. In a running mission press **Esc** while touch UI is forced to turn it back off, **or**
3. In the Godot editor: **Project → Project Settings → Parse Options / Input Devices** enable **Emulate Touch From Mouse** (Editor Settings → General → Pointing also has “Emulate Touch From Mouse”) so mouse clicks become `InputEventScreenTouch` / `ScreenDrag`. With the main-menu toggle on, mouse drag on the D-pad / look zone also works without that setting.
4. Or set `GameState.force_mobile_controls = true` from the debugger.

Touch look sensitivity default: `0.004` (`data/player_stats.json` → `touch_look_sensitivity`). Mouse sensitivity remains `0.0025`.

Desktop keyboard/mouse keep working when the touch overlay is hidden.

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
scenes/         MainMenu, Hub, Mission (+ embedded HUD/cinematic/game over/mobile controls)
scripts/
  autoload/     DataManager, GameState, EventBus
  player/       FPS controller + combat (+ touch move/look/fire APIs)
  zombies/      Zombie AI / hitboxes / behaviors
  systems/      TickleSystem
  mission/      ArenaBuilder, MissionManager, MissionRoot
  hub/          Shop UI
  ui/           HUD, MobileControls, cinematic overlay, menus
```

## Design notes

See [DESIGN.md](DESIGN.md) for GDD summary, resolved ambiguities, and progression.

**Auto Rifle #3** rate of fire is `1/s` as specified in the design brief (possible typo); implemented as written and called out in `data/guns.json`.
