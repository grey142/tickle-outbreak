# Tickle Outbreak

First-person **tickle-zombie survival FPS** vertical slice for **Godot 4.3+**.

## Play now (browser)

**[Play Tickle Outbreak in your browser](https://grey142.github.io/tickle-outbreak/)** — no Godot install required.

- Hosted on **GitHub Pages** from the `docs/` Web export on `main`.
- **First load** downloads a ~35MB WebAssembly build; subsequent visits are faster if the browser cache hits.
- **Chrome** (desktop or Android) recommended; Firefox also works. Safari may be more limited.
- Prefer **landscape** on phones/tablets. On-screen touch controls appear when a touchscreen is detected (or enable **Touch controls (desktop test)** on the main menu).
- Browsers often require a **user gesture** before audio can play — tap/click the game once if sound is muted.
- This Web build uses Godot’s **no-threads** export (no SharedArrayBuffer / COOP-COEP headers), so it works on stock GitHub Pages.

Tongue-in-cheek tone; zombies use random billboard sprite variants; survivor **Olivia Grace** has outfit sprites per armor (hub shop preview) and **face reaction** sprites when tickled (`assets/survivor/faces/`); while tickled, a strong pink full-screen flash + audible giggle/laugh SFX pulse once per second; missions layer apocalyptic city + Dead Island–scary zombie ambience under the SFX bus. Simple FPS arms remain placeholders. Not pornographic — soft feet/stomach lore appears only in item descriptions.

## Open & run (Godot editor)

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
| Bullets (pack of 25) | 3 |
| Alcohol | 4 |
| Toggle mouse capture | Esc |

## Mobile / landscape touch controls

On Android/iOS, or when a touchscreen is available, missions show an on-screen **landscape** control overlay (`MobileControls`):

```
[Olivia face panel]  [==== Health bar (top) ====]  [ammo/mission…]
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
| Top health (+ stamina) | Primary bars; leave room for face panel |
| Top-left **Olivia face** panel | Calm face at 0 ticklers; 1–5 intensity; tired/tears when stamina depleted |

Display defaults: `sensor_landscape` orientation, stretch `canvas_items` + `expand` aspect so phones fill the screen while desktop stays usable.

### Force-enable for desktop / editor testing

1. **Main Menu** → check **Touch controls (desktop test)** before starting a run, **or**
2. In a running mission press **Esc** while touch UI is forced to turn it back off, **or**
3. In the Godot editor: **Project → Project Settings → Parse Options / Input Devices** enable **Emulate Touch From Mouse** (Editor Settings → General → Pointing also has “Emulate Touch From Mouse”) so mouse clicks become `InputEventScreenTouch` / `ScreenDrag`. With the main-menu toggle on, mouse drag on the D-pad / look zone also works without that setting.
4. Or set `GameState.force_mobile_controls = true` from the debugger.

Touch look sensitivity default: `0.002` (`data/player_stats.json` → `touch_look_sensitivity`), with light swipe/mouse look smoothing. Mouse sensitivity default: `0.002`.

Desktop keyboard/mouse keep working when the touch overlay is hidden.

## Loop

1. **Main Menu** → New Run (starts with 100 coins for shop testing), **Gallery / Compendium**, or **CHEATS**.
2. **Hub** — **Missions** tab to select/replay unlocked missions for coin farming; buy/equip guns, melee, armor; upgrades; consumables (bullets: pack of **25** for **5** coins).
3. **Deploy** → city-block mission arena. Kill quota scales with the **selected** mission number. Meta (coins/gear/upgrades) is kept on replay.
4. Clear → hub unlocks the next frontier mission (`highest_mission_unlocked`); replaying an older mission does not lock you out. Health 0 → **Tickle Infected** game over (retry or hub).
5. **Gallery** — zombie compendium (stats + 3 sprite variants) and tickle-scene mockups; unlocks when campaign frontier reaches each type’s `unlock_mission`.

## Cheats

Prototype **CHEATS** panel on Main Menu and Hub (persisted lightly via `user://tickle_outbreak_meta.cfg` with mission unlocks):

| Cheat | Effect |
|-------|--------|
| Infinite health | Tickle damage ignored; health stays at max |
| Infinite ammo | Clip/reserve not consumed |
| All items free | Shop prices treated as 0 |
| Unlock all levels | Mission list unlocks through mission 20; elite gallery entries available |

## Balance data

All tunable numbers live under `data/*.json` (guns, melee, armor, consumables, zombies, upgrades, missions, currency, player stats). Prefer editing JSON over hardcoding.

## Project layout

```
assets/survivor/ Olivia Grace outfit PNGs (one per armor id)
assets/zombies/  Per-type PNG sprite variants (3 each)
data/           JSON balance tables
scenes/         MainMenu, Hub, Mission (+ embedded HUD/Olivia face/game over/mobile controls)
scripts/
  autoload/     DataManager, GameState, EventBus
  player/       FPS controller + combat (+ touch move/look/fire APIs)
  zombies/      Zombie AI / hitboxes / behaviors
  systems/      TickleSystem
  mission/      ArenaBuilder, MissionManager, MissionRoot
  hub/          Shop UI
  ui/           HUD, MobileControls, Olivia face reaction, menus, Gallery
```


## Zombie sprite variants

Each of the six zombie types has **three PNG variants** under `assets/zombies/<type>/` (e.g. `drone_01.png` … `drone_03.png`). Paths are listed per type in `data/zombies.json` as `sprite_variants`. On spawn, `Zombie.gd` **randomly picks one** of the three and shows it as a camera-facing `Sprite3D` billboard (capsule body mesh is hidden; head/body hitboxes remain). The top-left HUD shows Olivia Grace face sprites (`assets/survivor/faces/`) from mission start: calm at 0 ticklers, intensity 1–5 while tickled, tired variants when stamina is depleted.

## Survivor outfit sprites (Olivia Grace)

Each armor entry in `data/armor.json` has a `sprite` path under `assets/survivor/<id>.png` (11 outfits: bikini → hero_jacket). Hub Armor shop shows thumbnails plus a large equipped portrait. Equipping armor emits `GameState.equipment_changed`, which swaps those hub preview textures. Mission HUD no longer shows an outfit portrait (it blocked the FPS view).

## Web export

Static Web build is committed under `docs/` for GitHub Pages (`main` → `/docs`).

```bash
# Godot 4.3 + matching export templates required
godot --headless --path . --export-release "Web" docs/index.html
```

Preset `export_presets.cfg`: platform **Web**, **`variant/thread_support=false`**, canvas resize policy **Adaptive** (2). Renderer for the project is **gl_compatibility** (required for WebGL).

`docs/.gdignore` prevents the editor from importing the exported `.wasm` / `.pck` back into the project.

## Design notes

See [DESIGN.md](DESIGN.md) for GDD summary, resolved ambiguities, and progression.

**Auto Rifle #3** rate of fire is `1/s` as specified in the design brief (possible typo); implemented as written and called out in `data/guns.json`.
