extends Node
## Global gameplay signals.

signal player_damaged(amount: float, source: String)
signal player_tickled(dps: float, active_count: int)
signal player_died(reason: String)
signal zombie_killed(zombie_id: String, by_melee: bool, bonus_coins: int)
signal hit_registered(is_head: bool, by_melee: bool, damage: float)
signal mission_progress(kills: int, quota: int)
signal mission_cleared
signal active_ticklers_changed(count: int)
signal hud_refresh
