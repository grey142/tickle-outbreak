extends Node
class_name TickleSystem
## Applies tickle DPS rules and tracks active ticklers for cinematic overlay.

var player: PlayerController
var active_count: int = 0

func setup(p: PlayerController) -> void:
	player = p

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not player.is_alive():
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

	if count != active_count:
		active_count = count
		EventBus.active_ticklers_changed.emit(active_count)

	if total_dps > 0.0:
		player.apply_tickle_damage(total_dps, delta)
		EventBus.player_tickled.emit(total_dps, count)
