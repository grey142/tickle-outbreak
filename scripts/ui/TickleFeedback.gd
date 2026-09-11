extends CanvasLayer
class_name TickleFeedback
## Full-screen pink flash + giggle SFX on EventBus.tickle_pulse (once per second while tickled).

const FLASH_PEAK_ALPHA := 0.52
const FLASH_FADE_SEC := 0.50
const PINK := Color(1.0, 0.25, 0.65, 0.0)

const GIGGLE_PATHS := [
	"res://assets/audio/giggle_01.ogg",
	"res://assets/audio/giggle_02.ogg",
]
const INTENSE_PATH := "res://assets/audio/laugh_intense.ogg"

const VOL_GIGGLE_DB := 5.0
const VOL_INTENSE_DB := 8.0

var _flash: ColorRect
var _players: Array[AudioStreamPlayer] = []
var _player_idx: int = 0
var _giggles: Array[AudioStream] = []
var _intense: AudioStream
var _tween: Tween

func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	_build_overlay()
	_load_audio()
	if not EventBus.tickle_pulse.is_connected(_on_tickle_pulse):
		EventBus.tickle_pulse.connect(_on_tickle_pulse)

func _build_overlay() -> void:
	_flash = ColorRect.new()
	_flash.name = "PinkFlash"
	_flash.color = PINK
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.anchor_left = 0.0
	_flash.anchor_top = 0.0
	_flash.anchor_right = 1.0
	_flash.anchor_bottom = 1.0
	_flash.offset_left = 0.0
	_flash.offset_top = 0.0
	_flash.offset_right = 0.0
	_flash.offset_bottom = 0.0
	_flash.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_flash.grow_vertical = Control.GROW_DIRECTION_BOTH
	_flash.visible = true
	_flash.z_index = 100
	add_child(_flash)

	# Dual players so overlapping pulses aren't cut off.
	for i in range(2):
		var p := AudioStreamPlayer.new()
		p.name = "GigglePlayer_%d" % i
		p.bus = "SFX"
		p.volume_db = VOL_GIGGLE_DB
		p.max_polyphony = 1
		add_child(p)
		_players.append(p)

func _load_audio() -> void:
	_giggles.clear()
	for path in GIGGLE_PATHS:
		var stream := load(path) as AudioStream
		if stream:
			_giggles.append(stream)
	_intense = load(INTENSE_PATH) as AudioStream

func _on_tickle_pulse(active_count: int, stamina_depleted: bool) -> void:
	_trigger_flash()
	_play_giggle(active_count, stamina_depleted)

func _trigger_flash() -> void:
	if _flash == null:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_flash.visible = true
	_flash.color = Color(PINK.r, PINK.g, PINK.b, FLASH_PEAK_ALPHA)
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# Brief hold, then fade out.
	_tween.tween_interval(0.06)
	_tween.tween_property(_flash, "color:a", 0.0, FLASH_FADE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _play_giggle(active_count: int, stamina_depleted: bool) -> void:
	var stream: AudioStream = null
	var use_intense := active_count >= 3 or stamina_depleted
	if use_intense and _intense:
		stream = _intense
	elif not _giggles.is_empty():
		stream = _giggles[randi() % _giggles.size()]
	elif _intense:
		stream = _intense
	if stream == null or _players.is_empty():
		return
	var player := _players[_player_idx]
	_player_idx = (_player_idx + 1) % _players.size()
	player.stream = stream
	player.volume_db = VOL_INTENSE_DB if use_intense else VOL_GIGGLE_DB
	player.pitch_scale = 1.0 + randf_range(-0.04, 0.06)
	player.play()
