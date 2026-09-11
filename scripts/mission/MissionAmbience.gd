extends Node
class_name MissionAmbience
## Looping apocalyptic city + Dead Island-scary zombie ambience for mission scenes.

const CITY_PATH := "res://assets/audio/ambience_city.ogg"
const ZOMBIE_PATH := "res://assets/audio/ambience_zombies.ogg"
const CITY_VOL_DB := -11.0
const ZOMBIE_VOL_DB := -6.5

var _city: AudioStreamPlayer
var _zombies: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_city = _make_player("CityAmbience", CITY_PATH, CITY_VOL_DB)
	_zombies = _make_player("ZombieAmbience", ZOMBIE_PATH, ZOMBIE_VOL_DB)
	_start()

func _make_player(p_name: String, path: String, vol_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = p_name
	p.bus = "Ambience"
	p.volume_db = vol_db
	var stream := load(path) as AudioStream
	if stream:
		# Ensure looping even if import missed the flag.
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		p.stream = stream
	add_child(p)
	return p

func _start() -> void:
	if _city and _city.stream:
		_city.play()
	if _zombies and _zombies.stream:
		_zombies.play()

func stop_ambience() -> void:
	if _city and _city.playing:
		_city.stop()
	if _zombies and _zombies.playing:
		_zombies.stop()

func _exit_tree() -> void:
	stop_ambience()
