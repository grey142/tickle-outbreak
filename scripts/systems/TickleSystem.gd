extends Node
class_name TickleSystem
## Applies tickle DPS rules and tracks active ticklers for Olivia face reactions.

var player: PlayerController
var active_count: int = 0
var _last_stamina_depleted: bool = false

func setup(p: PlayerController) -> void:
	player = p

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not player.is_alive():
		if active_count != 0:
			active_count = 0
			_last_stamina_depleted = false
			EventBus.active_ticklers_changed.emit(0, false)
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
	if total_dps > 0.0:
		player.apply_tickle_damage(total_dps, delta)
		EventBus.player_tickled.emit(total_dps, count)

	var depleted := player.stamina <= 0.0
	if count != active_count or depleted != _last_stamina_depleted:
		active_count = count
		_last_stamina_depleted = depleted
		EventBus.active_ticklers_changed.emit(active_count, depleted)
