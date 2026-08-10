#ifndef WINDOWS_DESKTOP_HOVER_TRACKER_H
#define WINDOWS_DESKTOP_HOVER_TRACKER_H

#ifdef _WIN32

#include <windows.h>

#include <mutex>
#include <optional>
#include <string>

// 前置声明，避免在头文件中引入 uiautomation.h 的全局宏。
struct IUIAutomation;

namespace windows_desktop {

struct HoveredEntry {
	std::wstring path;        ///< 最终路径（快捷方式 = 解析后的目标；虚拟项 = "::{CLSID}" 形式）
	std::wstring name;        ///< 显示名（UIA 提供的名字）
	bool is_dir = false;      ///< 是否为目录
	bool is_shortcut = false; ///< 是否为 .lnk / .url 快捷方式
	bool is_virtual = false;  ///< 是否为无文件系统路径的虚拟项（回收站/控制面板/此电脑等）
	std::wstring source_path; ///< 快捷方式自身路径（非快捷方式时为空）
};

/**
 * 鼠标悬停文件追踪器（仅 Windows）。
 *
 * 原理：
 *  1. IUIAutomation::ElementFromPoint —— 取得鼠标位置对应的自动化元素，
 *     向上找 ListItem / DataItem，取其 Name（文件名；快捷方式为不带扩展名的显示名）；
 *  2. GetWindowFromPoint + GetClassNameW —— 判断鼠标位于文件资源管理器
 *     （CabinetWClass）还是桌面（Progman / WorkerW）；
 *  3. 资源管理器窗口通过 IShellWindows 枚举，对其自动化对象（IWebBrowser2）
 *     用 get_HWND 匹配窗口句柄、get_LocationURL 取当前目录；桌面则取桌面路径；
 *  4. 拼接路径并校验；快捷方式（.lnk / .url）用 IShellLinkW 解析目标路径。
 *
 * 线程安全：内部用互斥锁保护 COM/UIA 单例。
 */
class HoverTracker {
public:
	static std::optional<HoveredEntry> query(const POINT &pt);

	/// 在桌面或资源管理器中按路径查找文件/文件夹/快捷方式图标的屏幕矩形（物理像素）。
	/// 返回 std::nullopt 表示未找到。
	static std::optional<RECT> file_rect(const std::wstring &path);

private:
	static bool ensure_uia();
	static bool is_desktop_window(HWND hwnd);
	static bool is_explorer_window(HWND hwnd);
	static std::optional<std::wstring> explorer_current_path(HWND hwnd);
	static std::optional<std::wstring> desktop_path();

	static std::mutex s_mutex;
	static IUIAutomation *s_uia;
	static bool s_com_initialized;
};

} // namespace windows_desktop

#endif // _WIN32

#endif // WINDOWS_DESKTOP_HOVER_TRACKER_H
