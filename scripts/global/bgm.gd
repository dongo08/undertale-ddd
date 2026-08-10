extends Node
## 全局 BGM 管理系统（autoload：BGM）
##
## 用法示例：
##   BGM.play(preload("res://assets/audio/battle/level1/Fallen Down.ogg"), -6.0, 1.0)
##   BGM.play(stream, 0.0, 0.0, false)   # 立即播放、不循环
##   BGM.set_slow(true)                  # 切到 SlowBGM 总线（Undertale 慢速变奏）
##   BGM.set_pitch_scale(0.8)            # 变调（配合慢速使用，模拟慢速版 BGM）
##   BGM.set_volume_db(-10.0, 1.0)       # 1 秒渐变到 -10 dB
##   BGM.stop(1.5)                       # 1.5 秒淡出后停止
##   BGM.is_playing() / BGM.get_player() # 查询状态 / 拿到底层播放器
##
## 说明：
## - 使用全局单例后，场景内无需再挂 AudioStreamPlayer 播 BGM。
## - BGM / SlowBGM 两条总线已在 default_bus_layout.tres 中定义，
##   SlowBGM 带 HighPassFilter，可自行在总线上挂其他效果。

signal started(stream: AudioStream)  ## 开始播放（含循环重播）
signal stopped                       ## 停止播放
signal finished                      ## 自然播放完毕（仅 loop=false 时触发）

const BUS_BGM: StringName = &"BGM"
const BUS_SLOW: StringName = &"SlowBGM"

const DEFAULT_VOLUME_DB: float = 0.0
const DEFAULT_FADE: float = 0.5
## 淡入/淡出的起点音量（-80 dB 视为静音）
const MUTE_DB: float = -80.0

var _player: AudioStreamPlayer
var _volume_db: float = DEFAULT_VOLUME_DB
var _loop: bool = true
var _slow: bool = false
var _fade_tween: Tween

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "BGMPlayer"
	_player.bus = BUS_BGM
	_player.finished.connect(_on_finished)
	add_child(_player)

# ── 播放控制 ──

## 播放 BGM。fade > 0 时从静音淡入；loop 为 true 时循环播放。
func play(stream: AudioStream, volume_db: float = DEFAULT_VOLUME_DB, fade: float = DEFAULT_FADE, loop: bool = true) -> void:
	if stream == null:
		push_warning("BGM.play: stream 为 null，已忽略")
		return
	_kill_fade()
	_player.stream = stream
	_player.volume_db = MUTE_DB if fade > 0.0 else volume_db
	_player.play()
	_volume_db = volume_db
	_loop = loop
	_fade_volume(volume_db, fade)
	started.emit(stream)

## 停止播放，可选淡出（秒）。
func stop(fade: float = DEFAULT_FADE) -> void:
	_kill_fade()
	if not _player.playing:
		return
	if fade > 0.0:
		_fade_volume(MUTE_DB, fade)
		await get_tree().create_timer(fade).timeout
	_player.stop()
	stopped.emit()

## 暂停（保留播放位置）。
func pause() -> void:
	_player.stream_paused = true

## 从暂停处继续。
func resume() -> void:
	_player.stream_paused = false

## 跳转到指定秒数（从该位置播放）。
func seek(position_sec: float) -> void:
	_player.play(position_sec)

# ── 变奏 / 音量 ──

## 切换慢速变奏：在 BGM 与 SlowBGM 总线之间平滑切换（保持播放同步）。
func set_slow(enabled: bool, fade: float = DEFAULT_FADE) -> void:
	if enabled == _slow:
		return
	_slow = enabled
	_kill_fade()
	if not _player.playing or fade <= 0.0:
		_player.bus = BUS_SLOW if enabled else BUS_BGM
		return
	# 先淡出 → 切总线 → 再淡回目标音量，避免切换爆音
	_fade_volume(MUTE_DB, fade / 2.0)
	await get_tree().create_timer(fade / 2.0).timeout
	_player.bus = BUS_SLOW if enabled else BUS_BGM
	_fade_volume(_volume_db, fade / 2.0)

## 变调播放（1.0 = 原速，<1 更慢更低沉）。
func set_pitch_scale(value: float) -> void:
	_player.pitch_scale = value

## 渐变音量到指定 dB。
func set_volume_db(db: float, fade: float = DEFAULT_FADE) -> void:
	_volume_db = db
	_fade_volume(db, fade)

# ── 查询 ──

func is_playing() -> bool:
	return _player.playing

func is_slow() -> bool:
	return _slow

func get_volume_db() -> float:
	return _volume_db

## 拿到底层 AudioStreamPlayer（例如需要 stream 本身时）。
func get_player() -> AudioStreamPlayer:
	return _player

# ── 内部 ──

func _fade_volume(target: float, duration: float) -> void:
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()
	if duration <= 0.0:
		_player.volume_db = target
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", target, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _kill_fade() -> void:
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()

func _on_finished() -> void:
	if _loop and _player.stream:
		_player.play()
		started.emit(_player.stream)
	else:
		finished.emit()
