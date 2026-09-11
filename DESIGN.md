# Tickle Outbreak — Design Document (GDD Summary)

## Fantasy

You are a lightly dressed survivor clearing city blocks of **tickle-zombies**. Getting swarmed drains stamina then health; at 0 HP you become **Tickle Infected**. Earn coins, shop in the hub, push deeper missions.

Tone: tongue-in-cheek action comedy. Placeholder capsules labeled by type. Soft feet/stomach references stay in armor/item flavor text only.

## Pillars

1. **FPS fundamentals** — hitscan guns, melee, reload, ammo capacity, dash.
2. **Tickle pressure** — proximity DPS with stamina buffer, cinematic overlay when 1–5 ticklers are active.
3. **Meta progression** — permanent upgrades + weapons/armor shops between missions.
4. **Data-driven balance** — JSON under `data/`.

## Player

| Stat | Base |
|------|------|
| Health | 100 |
| Stamina | 100 |
| Speed | 100 |
| Ammo capacity | 50 |

- **Speed mapping:** `godot_speed = stat * 0.08` (see `player_stats.json` / `zombies.json`). Baseline player outruns Drones (25), cannot outrun Bolters (140) without upgrades/dash.
- **Dash:** costs stamina (`dash_stamina_cost`), brief speed burst.
- **Tickle rules:** While stamina > 0: full tickle DPS to stamina **and** half DPS to health. Stamina == 0: full DPS to health. Alcohol multiplies incoming tickle DPS.

## Starter loadout

- Senas Pistol #1 (reload 3s, 1/s, clip 12, dmg 1)
- Kitchen Knife (dmg 3, recharge 0.5s)
- Bikini outfit (+1 health)

## Combat

- **Hitscan** raycasts with spread; shotguns fire center + outer pellet cones; ineffective beyond ~8 m.
- **Head vs body** hitboxes (areas + height fallback on body collider).
- **Currency:** body +3, head +20, melee hit +5, gun kill +5, melee kill +20, plus per-zombie bonus coins.

## Zombies

| Type | Head/Body | Spd | Weight | Tickle DPS | Notes | Unlock |
|------|-----------|-----|--------|------------|-------|--------|
| Drone | 1/10 | 25 | 65% | 3 | Chase | 1 |
| Bolter | 1/5 | 140 | 18% | 4 | Tickle-and-run | 1 |
| Screamer | 3/20 | 25 | 3% | 0 | Doubles spawn rate while alive | 1 |
| Spider | 1/15 | 60 | 10% | 15 | Slow −13 while tickling | Mission 5+ |
| Tendril | 1/35 | 25 | 10% | 20 | Mid-range tickle, slow −30 | 5+ |
| Volatile | 8/35 | 75 | 3% | 45 | Mid-range, slow −45 | 5+ |

Spawn weights are relative among **unlocked** types for the current mission.

## Missions

- Kill quota = `15 + (mission−1) * 5`
- Spawn interval shrinks with mission; max alive scales up (capped).
- Clear → hub shops → next mission number.
- Fail → game over “Tickle Infected” → retry or hub (mission number unchanged).

## Shops

- **Weapons:** 10 guns (see `data/guns.json`).
- **Melee:** Kitchen Knife + Cleaver, Pipe Wrench, Street Machete, Thunder Bat.
- **Armor:** Bikini + 10 outfits, each +6 HP and small ammo bonus (`data/armor.json`).
- **Character upgrades (L1–10):** +25 ammo cap, +5 speed, +10 health, +20 stamina. Costs scale exponentially (`base_cost * cost_scale^level`).
- **Consumables:** Health potion (50% max HP, max 2/mission), Energy drink, Bullets, Alcohol (max 3/mission; 50/50 half or double tickle DPS; worsens aim; stacks/negates).

## Tickle cinematic

When **1–5** zombies are **actively** dealing tickle damage, a top-center panel shows count + placeholder copy. Hidden at 0 or >5 (swarm beyond cinematic band).

## Resolved ambiguities

1. **Auto Rifle #3 RoF 1/s** — kept as written; noted in data/README as possible typo.
2. **Screamer “doubles all spawn rates”** — implemented as halving spawn interval while any Screamer lives.
3. **Alcohol stack/negate** — each drink multiplies tickle taken by 0.5 or 2.0; aim penalty uses `|net_stacks| * degrees`.
4. **Elite unlock “after mission 4”** — unlock_mission = 5 (available starting mission 5).
5. **Shotgun damage** — each pellet deals `damage` (1); effectiveness comes from pellet count; range hard-capped ~8 m.
6. **Starter coins** — new run grants 100 coins so hub shops are immediately testable in the vertical slice.
7. **Mid-range tickle** — Tendril/Volatile use `mid_range_tickle` (6 m) from `zombies.json`.

## Out of scope / placeholders

- Final art, animations, sound, particles.
- Save/load persistence across app restarts (run state is in-memory).
- Networking / multiplayer.
- Full campaign narrative.
