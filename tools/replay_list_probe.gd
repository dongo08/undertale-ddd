extends Node

## 临时探针：量 list_replays 的耗时

func _ready() -> void:
	var t0 := Time.get_ticks_usec()
	var list := BattleReplay.list_replays()
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	print("list_replays：%.1f ms，%d 份" % [dt, list.size()])
	for h in list:
		print("  %s | %s | 结果 %d | %d tick" % [h.get("date", ""), h.get("scene", ""), h.get("result", 0), h.get("ticks", 0)])
	# 逐档量一遍 load_replay，看是谁慢
	var dir := DirAccess.open(BattleReplay.REPLAY_DIR)
	if dir:
		dir.list_dir_begin()
		var name := dir.get_next()
		var path := ""
		while name != "":
			if not dir.current_is_dir() and name.get_extension() == "rpy":
				path = BattleReplay.REPLAY_DIR.path_join(name)
				var t1 := Time.get_ticks_usec()
				var data := BattleReplay.load_replay(path)
				print("  load %-52s %7.1f ms  %s" % [name, (Time.get_ticks_usec() - t1) / 1000.0, "OK" if not data.is_empty() else "读取失败"])
			name = dir.get_next()
		dir.list_dir_end()
	get_tree().quit(0)
