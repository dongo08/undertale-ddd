extends Node

## 回放系统：录制 / 保存 / 读取 / 播放。
## 原理和东方一样：只存"随机种子 + 每物理帧的按键掩码"，播放时把同一个场景重跑一遍。
## 所以回放文件很小（按住不放的连续帧会被游程压缩掉）。

enum Result { UNKNOWN, WIN, DEAD, QUIT }

const REPLAY_DIR := "user://replays"
const MAGIC := "DDDRPL"
## 文件格式版本：改存法就 +1，旧档直接拒绝播放
const FORMAT_VERSION := 1
## 一帧最多多少步物理模拟（超过就认为引擎在追赶、丢过帧）
const DROP_TOLERANCE := 0
## 一份回放最多多少 tick（1 小时）：坏档读出来的天文数字在这里被挡住
const MAX_TICKS := 5184000
## 头部里的短字符串（场景路径 / 日期 / 引擎版本）最多多少字节
const MAX_STRING_BYTES := 4096

var recording: bool = false
var playing: bool = false
## 正在播放的这份回放的头部信息
var current: Dictionary = {}
## 最近一次存档的路径
var last_saved_path: String = ""

var _scene_path: String = ""
var _difficulty: int = 0
var _dropped: bool = false
var _drop_hits: int = 0
var _frames_seen: int = 0
var _last_physics_frames: int = 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(REPLAY_DIR)
	_last_physics_frames = Engine.get_physics_frames()


## 丢帧检测：物理步被 max_physics_steps_per_frame 截断时，逻辑会少走一步，
## 这种录制出来/放出来的回放不可靠，标记一下（东方也有跑歪的档）。
## 只是粗略判断：加载时的卡顿也会命中一次，所以连续命中几次才算。
func _process(_delta: float) -> void:
	_frames_seen += 1
	var now := Engine.get_physics_frames()
	if now - _last_physics_frames >= Engine.max_physics_steps_per_frame:
		_drop_hits += 1
		if _drop_hits >= 3 and _frames_seen > 120:
			_dropped = true
			#print("!!!")
	_last_physics_frames = now


## 录制中按 F5 立刻存一份（F5 不是游戏按键，不会被录进输入里）
func _input(event: InputEvent) -> void:
	if not recording:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		end_battle(Result.QUIT)
		get_viewport().set_input_as_handled()


# ── 录制 ──

## 战斗场景 _ready 里调一次：开始记录这一场
func begin_battle(scene_path: String = "") -> void:
	if playing or recording:
		return                      # 已经开始录了（子类或测试可能先调过一次）
	if scene_path.is_empty():
		scene_path = _current_scene_path()
	_scene_path = scene_path
	_difficulty = int(Global.difficulty)
	_dropped = false
	recording = true
	BattleInput.begin_record()


## 战斗结束（赢 / 死 / 中途退出）时调：把这一场写成回放文件
func end_battle(result: Result = Result.UNKNOWN, checksum: int = 0) -> String:
	if not recording:
		return ""
	recording = false
	var frames := BattleInput.recorded_frames()
	BattleInput.stop()
	if frames.is_empty():
		push_warning("这一场没有录到任何帧，不保存。")
		return ""
	var header := {
		"scene": _scene_path,
		"difficulty": _difficulty,
		"seed": BattleRNG.used_seed,
		"ticks": frames.size(),
		"result": int(result),
		"dropped": _dropped,
		"checksum": checksum,
		"date": Time.get_datetime_string_from_system(false, true),
		"engine": Engine.get_version_info()["string"],
	}
	var path := _new_path(result)
	var err := save_replay(path, header, frames)
	if err != OK:
		push_warning("回放保存失败：%s" % error_string(err))
		return ""
	last_saved_path = path
	_drop_hits = 0
	print("回放已保存：%s（%d tick，种子 %d，%s）" % [path, frames.size(), header["seed"], _result_text(result)])
	return path


# ── 播放 ──

## 准备好播放：读档 + 设难度/种子/输入源。调用方随后加载 header.scene 那个场景。
func prepare_playback(path: String) -> bool:
	print(Time.get_ticks_msec())
	var data := load_replay(path)

	if data.is_empty():
		return false
	var header: Dictionary = data["header"]
	current = header
	playing = true
	recording = false
	_dropped = false
	Global.difficulty = header["difficulty"]
	BattleRNG.begin(int(header["seed"]))

	BattleInput.begin_playback(data["frames"])

	print("开始回放：%s（%d tick，种子 %d）" % [path.get_file(), header["ticks"], header["seed"]])

	return true


## 播放中战斗结束时调：比对校验值（对不上说明这份回放跑歪了）
func finish_playback(checksum: int) -> bool:
	if not playing:
		return true
	var expected := int(current.get("checksum", 0))
	playing = false
	BattleInput.stop()
	if expected == 0:
		return true
	if expected == checksum:
		print("回放校验通过（checksum=%d）" % checksum)
		return true
	push_warning("回放校验失败：期望 %d，实际 %d —— 这份回放跑歪了。" % [expected, checksum])
	return false


# ── 存档格式 ──

func save_replay(path: String, header: Dictionary, frames: PackedInt32Array) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	_write_string(file, MAGIC)
	file.store_32(FORMAT_VERSION)
	file.store_32(0)                                        # 玩法哈希：以后要让"玩法改了旧回放就废"就填这里
	_write_string(file, str(header.get("scene", "")))
	file.store_32(int(header.get("difficulty", 0)))
	file.store_64(int(header.get("seed", 0)))
	file.store_32(int(header.get("ticks", frames.size())))
	file.store_8(int(header.get("result", 0)))
	file.store_8(1 if header.get("dropped", false) else 0)
	_write_string(file, str(header.get("date", "")))
	_write_string(file, str(header.get("engine", "")))
	file.store_32(int(header.get("checksum", 0)))
	var bytes := encode_frames(frames)
	file.store_32(bytes.size())
	file.store_buffer(bytes)
	file.close()
	return OK


## 带长度前缀的字符串（不用 FileAccess.get_string，各版本行为不一致）
func _write_string(file: FileAccess, text: String) -> void:
	var bytes := text.to_utf8_buffer()
	file.store_32(bytes.size())
	file.store_buffer(bytes)


func _read_string(file: FileAccess) -> String:
	var size := file.get_32()
	var remaining := file.get_length() - file.get_position()
	# 长度必须先跟文件剩余大小对比再 get_buffer：
	# 坏档（比如裸 MAGIC 的旧文件）读出来的长度可能是 13 亿，直接分配 1.4GB
	if size <= 0 or size > remaining or size > MAX_STRING_BYTES:
		return ""
	return file.get_buffer(size).get_string_from_utf8()


func load_replay(path: String) -> Dictionary:
	var file := _open_replay(path)
	if file == null:
		return {}
	var header := _read_header(file, false)
	if header.is_empty():
		file.close()
		return {}
	var byte_count := file.get_32()
	var remaining := file.get_length() - file.get_position()
	if byte_count <= 0 or byte_count > remaining:
		push_warning("回放数据长度不对，这份档坏了：%s" % path)
		file.close()
		return {}
	var bytes := file.get_buffer(byte_count)
	file.close()
	return {"header": header, "frames": decode_frames(bytes, int(header["ticks"]))}


## 只读头部（列表用）：不解帧数据，坏档安静跳过
func read_header_only(path: String) -> Dictionary:
	var file := _open_replay(path, true)
	if file == null:
		return {}
	var header := _read_header(file, true)
	file.close()
	return header


func _open_replay(path: String, quiet: bool = false) -> FileAccess:
	if not FileAccess.file_exists(path):
		if not quiet:
			push_warning("回放文件不存在：%s" % path)
		return null
	return FileAccess.open(path, FileAccess.READ)


## 读头部。旧格式 / 截断的坏档在这里就被挡住 ——
## 这一步很关键：长度字段在使用前一定要跟文件剩余大小对比，
## 否则一个坏档就能让我们去 get_buffer(1.4GB)，列表直接卡 0.2 秒（实测过）。
func _read_header(file: FileAccess, quiet: bool) -> Dictionary:
	if file == null:
		return {}
	if _read_string(file) != MAGIC:
		if not quiet:
			push_warning("这不是回放文件（或格式太旧）")
		return {}
	var version := file.get_32()
	if version != FORMAT_VERSION:
		if not quiet:
			push_warning("回放格式版本不符（文件 %d，当前 %d），放不了。" % [version, FORMAT_VERSION])
		return {}
	file.get_32()                                           # 玩法哈希占位
	var header := {
		"scene": _read_string(file),
		"difficulty": file.get_32(),
		"seed": file.get_64(),
		"ticks": file.get_32(),
		"result": file.get_8(),
		"dropped": file.get_8() == 1,
		"date": _read_string(file),
		"engine": _read_string(file),
		"checksum": file.get_32(),
	}
	if not str(header["scene"]).begins_with("res://"):
		if not quiet:
			push_warning("回放头部坏了（场景字段不对）")
		return {}
	if int(header["ticks"]) <= 0 or int(header["ticks"]) > MAX_TICKS:
		if not quiet:
			push_warning("回放头部坏了（tick 数不对：%d）" % int(header["ticks"]))
		return {}
	return header


## 列举所有回放（只读头部，给主菜单用）
func list_replays() -> Array:
	var out: Array = []
	var dir := DirAccess.open(REPLAY_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.get_extension() == "rpy":
			var header := read_header_only(REPLAY_DIR.path_join(name))
			if not header.is_empty():
				header["path"] = REPLAY_DIR.path_join(name)
				out.append(header)
		name = dir.get_next()
	dir.list_dir_end()
	out.sort_custom(func(a, b): return str(a["date"]) > str(b["date"]))
	return out


# ── 帧数据的游程压缩 ──

## 每帧两个字节掩码 + 一个字节重复次数（最多 255）
func encode_frames(frames: PackedInt32Array) -> PackedByteArray:
	var out := PackedByteArray()
	var i := 0
	while i < frames.size():
		var mask := frames[i]
		var run := 1
		while i + run < frames.size() and frames[i + run] == mask and run < 255:
			run += 1
		out.append(mask & 0xFF)
		out.append((mask >> 8) & 0xFF)
		out.append(run)
		i += run
	return out


func decode_frames(bytes: PackedByteArray, count: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var i := 0
	while i + 2 < bytes.size() and out.size() < count:
		var mask := bytes[i] | (bytes[i + 1] << 8)
		var run := bytes[i + 2]
		for r in run:
			if out.size() >= count:
				break
			out.append(mask)
		i += 3
	return out


func _current_scene_path() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	return scene.scene_file_path


func _new_path(result: Result) -> String:
	var stamp := Time.get_datetime_string_from_system(false, true)
	stamp = stamp.replace(":", "-").replace("T", "_")
	var scene_name := _scene_path.get_file().get_basename()
	if scene_name.is_empty():
		scene_name = "battle"
	return REPLAY_DIR.path_join("%s_%s_%s.rpy" % [stamp, scene_name, _result_text(result)])


func _result_text(result: Result) -> String:
	match result:
		Result.WIN: return "win"
		Result.DEAD: return "dead"
		Result.QUIT: return "quit"
		_: return "unknown"
