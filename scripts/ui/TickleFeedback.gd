extends CanvasLayer
class_name TickleFeedback
## Full-screen pink flash + giggle SFX on EventBus.tickle_pulse (once per second while tickled).

const FLASH_PEAK_ALPHA := 0.24
const FLASH_FADE_SEC := 0.32
const PINK := Color(1.0, 0.35, 0.72, 0.0)

const GIGGLE_PATHS := [
	"res://assets/audio/giggle_01.ogg",
	"res://assets/audio/giggle_02.ogg",
]
const INTENSE_PATH := "res://assets/audio/laugh_intense.ogg"

var _flash: ColorRect
var _player: AudioStreamPlayer
var _giggles: Array[AudioStream] = []
var _intense: AudioStream
var _tween: Tween

func _ready() -> void:
	layer = 8
	_build_overlay()
	_load_audio()
	EventBus.tickle_pulse.connect(_on_tickle_pulse)

func _build_overlay() -> void:
	_flash = ColorRect.new()
	_flash.name = "PinkFlash"
	_flash.color = PINK
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.anchor_right = 1.0
	_flash.anchor_bottom = 1.0
	_flash.offset_left = 0.0
	_flash.offset_top = 0.0
	_flash.offset_right = 0.0
	_flash.offset_bottom = 0.0
	_flash.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_flash.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_flash)

	_player = AudioStreamPlayer.new()
	_player.name = "GigglePlayer"
	_player.bus = "SFX"
	_player.volume_db = -4.0
	add_child(_player)

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
	if _tween and _tween.is_valid():
		_tween.kill()
	_flash.color = Color(PINK.r, PINK.g, PINK.b, FLASH_PEAK_ALPHA)
	_tween = create_tween()
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
	if stream == null:
		return
	_player.stream = stream
	# Slightly louder when intense
	_player.volume_db = -2.0 if use_intense else -5.0
	_player.pitch_scale = 1.0 + randf_range(-0.04, 0.06)
	_player.play()
