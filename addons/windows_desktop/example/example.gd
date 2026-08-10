extends Node

## 用法：把这个脚本挂到任意节点上（或直接运行 example.tscn）。
## 运行时按 F6 / F7 / F8 查看输出（输出在 Godot 控制台）。

const POLL_INTERVAL := 0.15
const MAX_PRINT_ENTRIES := 20

var _desktop: WinDesktop
var _polling := false
var _timer := 0.0
var _last_path := ""


func _ready() -> void:
	_desktop = WinDesktop.new()

	print("=== Windows 桌面扩展示例 ===")
	print("桌面路径: ", _desktop.get_desktop_path())

	print("桌面条目（前 %d 个）:" % MAX_PRINT_ENTRIES)
	var entries: Array = _desktop.get_desktop_entries(false)
	for i in mini(entries.size(), MAX_PRINT_ENTRIES):
		print("  ", entries[i])
	if entries.is_empty():
		print("  （空）")

	print("F6: 探测一次鼠标悬停的文件")
	print("F7: 打印桌面全部文件路径（递归）")
	print("F8: 开关自动轮询悬停（每 %.2f 秒）" % POLL_INTERVAL)
	print("F9: 获取最近一次悬停文件的屏幕矩形（Rect2）")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_6:
				probe_hover()
			KEY_7:
				print("桌面全部路径（递归）:")
				for p in _desktop.get_desktop_file_paths(true):
					print("  ", p)
			KEY_8:
				_polling = not _polling
				print("轮询悬停: ", "开" if _polling else "关")
			KEY_9:
				if _last_path.is_empty():
					print("（还没有悬停记录，请先按 F6 或打开轮询）")
				else:
					var rect = _desktop.get_file_rect(_last_path)
					print("路径: ", _last_path)
					print("屏幕矩形: ", rect, "  位置: ", rect.position, "  大小: ", rect.size)


func _process(delta: float) -> void:
	if not _polling:
		return
	_timer += delta
	if _timer >= POLL_INTERVAL:
		_timer = 0.0
		probe_hover()


func probe_hover() -> void:
	var info: Dictionary = _desktop.get_hovered_file()
	if info.is_empty():
		print("（未悬停在文件上——请把鼠标移到桌面图标或文件资源管理器里的文件上）")
		return
	var kind := "文件夹" if info["is_dir"] else "文件"
	var line := "悬停%s: %s (%s)" % [kind, info["path"], _format_size(info["size"])]
	if info.get("is_shortcut", false):
		line += "  [快捷方式 → %s]" % info["source_path"]
	elif info.get("is_virtual", false):
		line += "  [虚拟项，无文件系统路径]"
	print(line)
	_last_path = info["path"]


func _format_size(size: int) -> String:
	if size < 1024:
		return "%d B" % size
	if size < 1024 * 1024:
		return "%.1f KB" % (size / 1024.0)
	if size < 1024 * 1024 * 1024:
		return "%.1f MB" % (size / 1024.0 / 1024.0)
	return "%.2f GB" % (size / 1024.0 / 1024.0 / 1024.0)
