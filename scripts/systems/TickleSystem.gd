extends Node
class_name TickleSystem
## Applies tickle DPS rules and tracks active ticklers for Olivia face reactions.
## Emits EventBus.tickle_pulse once per second while ≥1 zombie is actively tickling.

const PULSE_INTERVAL := 1.0
const DEBUG_PULSE := false

var player: PlayerController
var active_count: int = 0
var _last_stamina_depleted: bool = false
## Counts down to next flash/SFX; ≤0 means fire immediately on next tickling frame.
var _pulse_timer: float = 0.0

func setup(p: PlayerController) -> void:
	player = p

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not player.is_alive():
		if active_count != 0:
			active_count = 0
			_last_stamina_depleted = false
			EventBus.active_ticklers_changed.emit(0, false)
		_pulse_timer = 0.0
		return
	var total_dps := 0.0
	var count := 0
	for z in get_tree().get_nodes_in_group("zombies"):
		if not is_instance_valid(z) or not (z is Zombie):
			continue
		var zombie := z as Zombie
		var range_m := zombie.get_tickle_range()
		if range_m <= 0.0 or zombie.tickle_dps <= 0.0:
			zombie.actively_tickling = false
			continue
		var dist := player.global_position.distance_to(zombie.global_position)
		if dist <= range_m:
			zombie.actively_tickling = true
			total_dps += zombie.tickle_dps
			count += 1
			if zombie.slow_on_tickle > 0.0:
				player.apply_slow(zombie.slow_on_tickle)
		else:
			zombie.actively_tickling = false

	# Apply damage first so stamina_depleted reflects this frame's drain.
	# Infinite-health cheat skips HP loss inside apply_tickle_damage but contact
	# still counts — pulse/flash feedback uses `count`, not actual HP drained.
	if total_dps > 0.0:
		player.apply_tickle_damage(total_dps, delta)
		EventBus.player_tickled.emit(total_dps, count)

	var depleted := player.stamina <= 0.0
	if count != active_count or depleted != _last_stamina_depleted:
		active_count = count
		_last_stamina_depleted = depleted
		EventBus.active_ticklers_changed.emit(active_count, depleted)

	_update_pulse(delta, count, depleted)

func _update_pulse(delta: float, count: int, depleted: bool) -> void:
	if count <= 0:
		# Reset so the next tickle bout flashes soon (first pulse immediate).
		_pulse_timer = 0.0
		return
	if _pulse_timer <= 0.0:
		EventBus.tickle_pulse.emit(count, depleted)
		if DEBUG_PULSE:
			print("[TickleSystem] tickle_pulse count=%d depleted=%s" % [count, depleted])
		_pulse_timer = PULSE_INTERVAL
	else:
		_pulse_timer -= delta
