extends CanvasLayer
class_name TickleFeedback
## Full-screen pink flash on tickle_pulse; longer laugh clips play through and only restart/switch when intensity changes.

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
var _laugh_tier: int = -1  ## 0 light, 1 intense, -1 none
var _laugh_player: AudioStreamPlayer

func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	_build_overlay()
	_load_audio()
	if not EventBus.tickle_pulse.is_connected(_on_tickle_pulse):
		EventBus.tickle_pulse.connect(_on_tickle_pulse)
	if not EventBus.active_ticklers_changed.is_connected(_on_ticklers_changed):
		EventBus.active_ticklers_changed.connect(_on_ticklers_changed)

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

	# One primary laugh player (~5s clips). Flash still pulses; audio only restarts on tier change.
	_laugh_player = AudioStreamPlayer.new()
	_laugh_player.name = "LaughPlayer"
	_laugh_player.bus = "SFX"
	_laugh_player.volume_db = VOL_GIGGLE_DB
	add_child(_laugh_player)
	_players = [_laugh_player]

func _load_audio() -> void:
	_giggles.clear()
	for path in GIGGLE_PATHS:
		var stream := load(path) as AudioStream
		if stream:
			_giggles.append(stream)
	_intense = load(INTENSE_PATH) as AudioStream

func _on_tickle_pulse(active_count: int, stamina_depleted: bool) -> void:
	_trigger_flash()
	_ensure_laugh(active_count, stamina_depleted)

func _on_ticklers_changed(count: int, stamina_depleted: bool) -> void:
	if count <= 0:
		_stop_laugh()
	else:
		_ensure_laugh(count, stamina_depleted)

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

func _ensure_laugh(active_count: int, stamina_depleted: bool) -> void:
	if _laugh_player == null:
		return
	var use_intense := active_count >= 3 or stamina_depleted
	var tier := 1 if use_intense else 0
	# Still playing the same intensity — let the ~5s clip finish / continue.
	if _laugh_player.playing and tier == _laugh_tier:
		return
	var stream: AudioStream = null
	if use_intense and _intense:
		stream = _intense
	elif not _giggles.is_empty():
		# Pick a light clip (reroll only when starting/switching).
		stream = _giggles[randi() % _giggles.size()]
	elif _intense:
		stream = _intense
	if stream == null:
		return
	_laugh_tier = tier
	_laugh_player.stream = stream
	_laugh_player.volume_db = VOL_INTENSE_DB if use_intense else VOL_GIGGLE_DB
	_laugh_player.pitch_scale = 1.0 + randf_range(-0.03, 0.03)
	_laugh_player.play()

func _stop_laugh() -> void:
	_laugh_tier = -1
	if _laugh_player and _laugh_player.playing:
		_laugh_player.stop()
