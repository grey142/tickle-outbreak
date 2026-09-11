# Audio sources

Tickle laughs and mission ambience are built from **Mixkit** free SFX (Mixkit License — free for commercial games; no attribution required, but credited here) plus light procedural beds (Python/NumPy) and ffmpeg pitch/trim/mix.

| File | Role | Source / notes |
|------|------|----------------|
| `giggle_01.ogg` | Tickle pulse giggle A (~1.4s) | Mixkit **Funny Giggling** (id 2885) + light **Females laugh** (425) / **Cartoon giggle** (743); pitched +1.5–2.5 st; loud peak-normalized |
| `giggle_02.ogg` | Tickle pulse giggle B (~1.9s) | Mixkit **Kid giggle laugh** (431); pitched +1.2 st; brightened; teenage tickle energy (no words) |
| `laugh_intense.ogg` | Intense / multi-tickler / stamina-depleted (~2.0s) | Mixkit **Female cheerful laughter** (416) + **Laughing teenager** (428) + **Females laugh** (425); pitched +1–2 st; no speech |
| `ambience_city.ogg` | Mission apocalyptic bed (~8s loop) | Prior procedural city bed, lightly retuned with sub rumble |
| `ambience_zombies.ogg` | Scary zombie layer (~10s loop, ~95KB) | Mixkit **Horror ambience** (1775), **Scary wind** (1776), **Monster breath** (1960), **Zombie monster growl** (1972 / 773), **Monster growl** (2231), **Wild creature growl** (1978), **Gasping zombie** (263), **Single zombie breath** (2241), **Creepy demon heavy breathing** (1966), **Terrifying creature breath** (1976), **Angry monster scream** (2234), **Monsters scream** (2208), **Zombie pain** (1957), **Wild animal hungry grunting** (413); layered over procedural sub-drone / dissonant pads / filtered noise for Dead Island–style dread |

## Licenses

- **Mixkit License**: https://mixkit.co/license/#sfxFree — free to use in commercial/personal projects; no attribution required. Clips were downloaded as Mixkit preview MP3s from `assets.mixkit.co/active_storage/sfx/…`, then trimmed/pitched/mixed.
- Procedural elements (drones, noise beds, city rumble): original to this repo (treat as CC0 within the game).

Character targets: giggles = girly teenage tickle laughs (cute/bubbly, no words); zombies = wet snarls / feral growls / distant shrieks / oppressive dread (not cute cartoon moans).

## Custom player laughs (Sonny)

Replaced Mixkit tickle laughs with user-recorded clips (2026-09-11):

| Game file | Source |
|-----------|--------|
| `giggle_01.ogg` | `custom_src/sonny_01_light_giggle.wav` — light giggle A |
| `giggle_02.ogg` | `custom_src/sonny_02_ticklish_forced_laugh.wav` — ticklish forced laugh B |
| `laugh_intense.ogg` | `custom_src/sonny_03_open_mouth_laugh.wav` — open-mouth intense (3+ ticklers / stamina empty) |

Converted with ffmpeg loudnorm → Ogg Vorbis. Owned by the project author / user-provided.
