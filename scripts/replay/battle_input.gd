extends Node

## 战斗输入层：每物理帧采样一次，游戏里的输入都从这里读。
##
## LIVE   = 读真实按键
## RECORD = 读真实按键，并把每帧掩码记下来
## PLAY   = 从记下来的帧数据里读（真实按键被忽略，回放不会被按乱）
##
## 好处：输入天然对齐物理帧（回放可复现），且不需要在业务代码里判断“现在是回放还是游玩”。

enum Mode { LIVE, RECORD, PLAY }

## 参与记录的按键：顺序就是位掩码的位序，改动会让旧回放失效
const ACTIONS: Array[StringName] = [
	&"up", &"down", &"left", &"right", &"accept", &"cancel", &"skip", &"slow",
]

## 菜单按住不放的重复节奏（物理帧）：先等 21 帧，然后每 4 帧一次
const REPEAT_DELAY_TICKS := 21
const REPEAT_INTERVAL_TICKS := 4

var mode: Mode = Mode.LIVE

var _mask: int = 0
var _prev_mask: int = 0
var _frames: PackedInt32Array = []
var _play_index: int = 0
var _held: Dictionary = {}
## 战斗是否已经开始：场景 _ready 里 attach() 之后才真正喂帧 / 录帧。
## 不这么分两步的话，"装好回放数据"和"场景真正开始跑"之间插进一个物理帧，
## 录好的第 0 帧就会被白白吃掉（实测过：两边会差一次按键）。
var _started: bool = false


## 自动加载节点比主场景先进树，所以这里一定比游戏逻辑先跑
func _physics_process(_delta: float) -> void:
	_prev_mask = _mask
	match mode:
		Mode.PLAY:
			if _started and _play_index < _frames.size():
				_mask = _frames[_play_index]
				_play_index += 1
			else:
				_mask = 0
		Mode.RECORD:
			_mask = _sample_device()
			if _started:
				_frames.append(_mask)
		_:
			_mask = _sample_device()


## 战斗场景 _ready 里调一次：从这一 tick 开始真正喂输入 / 录输入。
## 重复调用无效果（子类可能先 super._ready() 之后才轮到基类）。
func attach() -> void:
	if _started:
		return
	_mask = 0
	_prev_mask = 0
	_held.clear()
	_play_index = 0
	_started = true


func is_started() -> bool:
	return _started


func is_replaying() -> bool:
	return mode == Mode.PLAY


func is_recording() -> bool:
	return mode == Mode.RECORD


## 已经喂掉/录下的帧数（回放进度，也用来算结束时的校验值）
func progress_ticks() -> int:
	if mode == Mode.PLAY:
		return _play_index
	return _frames.size()


func _sample_device() -> int:
	var mask := 0
	for i in ACTIONS.size():
		if Input.is_action_pressed(ACTIONS[i]):
			mask |= 1 << i
	return mask


## 本帧按着吗（移动这类持续输入用）
func pressed(action: StringName) -> bool:
	var bit := _bit_of(action)
	return bit >= 0 and (_mask & (1 << bit)) != 0


## 本帧是刚按下的吗（菜单、推进对话用）
func just_pressed(action: StringName) -> bool:
	var bit := _bit_of(action)
	if bit < 0:
		return false
	var m := 1 << bit
	return (_mask & m) != 0 and (_prev_mask & m) == 0


## 刚按下 + 按住后按固定节奏重复（替代原来的 allow_echo）
func repeated(action: StringName) -> bool:
	var bit := _bit_of(action)
	if bit < 0:
		return false
	var m := 1 << bit
	if (_mask & m) == 0:
		_held.erase(action)
		return false
	if (_prev_mask & m) == 0:
		_held[action] = 0
		return true
	var held: int = int(_held.get(action, 0)) + 1
	_held[action] = held
	if held < REPEAT_DELAY_TICKS:
		return false
	return (held - REPEAT_DELAY_TICKS) % REPEAT_INTERVAL_TICKS == 0


## 方向向量（灵魂移动用），替代 Input.get_vector
func vector(negative_x: StringName, positive_x: StringName, negative_y: StringName, positive_y: StringName) -> Vector2:
	var v := Vector2(
		float(pressed(positive_x)) - float(pressed(negative_x)),
		float(pressed(positive_y)) - float(pressed(negative_y)))
	return v.normalized() if v.length() > 1.0 else v


## 本帧掩码（调试 / 校验用）
func mask() -> int:
	return _mask


## 开始录制（战斗 _ready 里的 attach() 之后才真的往缓冲里写）
func begin_record() -> void:
	mode = Mode.RECORD
	_frames = PackedInt32Array()
	_mask = 0
	_prev_mask = 0
	_held.clear()
	_started = false
	_play_index = 0


## 装好一段要回放的输入（同样等 attach() 才开始喂）
func begin_playback(frames: PackedInt32Array) -> void:
	mode = Mode.PLAY
	_frames = frames
	_play_index = 0
	_mask = 0
	_prev_mask = 0
	_held.clear()
	_started = false


## 录到的帧数据
func recorded_frames() -> PackedInt32Array:
	return _frames


## 回到正常游玩
func stop() -> void:
	mode = Mode.LIVE
	_play_index = 0
	_held.clear()
	_started = false


func _bit_of(action: StringName) -> int:
	return ACTIONS.find(action)
