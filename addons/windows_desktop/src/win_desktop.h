#ifndef WINDOWS_DESKTOP_WIN_DESKTOP_H
#define WINDOWS_DESKTOP_WIN_DESKTOP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2i.hpp>

namespace windows_desktop {

/**
 * WinDesktop
 *
 * 提供两个能力（仅 Windows）：
 *  1. 枚举当前用户桌面（含 OneDrive 重定向）下的所有文件夹和文件；
 *  2. 探测鼠标当前悬停在桌面图标或文件资源管理器列表上的文件。
 *
 * 在非 Windows 平台上所有方法返回空值，不会报错。
 */
class WinDesktop : public godot::RefCounted {
	GDCLASS(WinDesktop, godot::RefCounted)

protected:
	static void _bind_methods();

public:
	/// 返回桌面文件夹的绝对路径（UTF-8）。失败时返回空字符串。
	godot::String get_desktop_path() const;

	/// 枚举桌面下的条目。
	/// recursive 为 true 时递归所有子目录。
	/// 返回 Array[Dictionary]，每个元素键：
	///   path: String     完整路径
	///   name: String     文件名/文件夹名
	///   is_dir: bool     是否为目录
	///   is_link: bool    是否为符号链接
	///   size: int        字节大小（目录为 0）
	///   modified: int    Unix 时间戳（秒）
	/// 排序：目录在前，其余按名称（不区分大小写）。
	godot::Array get_desktop_entries(bool recursive) const;

	/// 桌面下所有条目（含目录）的完整路径（排序同 get_desktop_entries）。
	godot::PackedStringArray get_desktop_file_paths(bool recursive) const;

	/// 探测鼠标当前悬停位置的文件。返回键同 get_desktop_entries，
	/// 另含 is_shortcut / source_path / is_virtual（见 README）。
	/// 未悬停在文件上（或不在桌面/资源管理器）时返回空 Dictionary。
	godot::Dictionary get_hovered_file() const;

	/// 同上，但使用指定的屏幕坐标（物理像素，原点在屏幕左上角）。
	godot::Dictionary get_hovered_file_at(godot::Vector2i screen_pos) const;

	/// 按路径查找桌面或资源管理器中文件/文件夹/快捷方式图标的屏幕矩形。
	/// 返回 Rect2（position = 左上角，size = 宽高，物理像素）；
	/// 未找到时返回 Rect2()（全零）。
	godot::Rect2 get_file_rect(godot::String path) const;
};

} // namespace windows_desktop

#endif // WINDOWS_DESKTOP_WIN_DESKTOP_H
