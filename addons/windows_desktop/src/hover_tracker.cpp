#include "hover_tracker.h"

#ifdef _WIN32

// 注意：即使构建定义了 WIN32_LEAN_AND_MEAN，也要在 uiautomation.h 之前包含
// objbase.h（提供 interface 宏）与 oaidl.h（VARIANT/BSTR/IDispatch），
// 否则 SDK 的 UIAutomationCore.h 会因缺少 interface 宏而报 C2146/C4430。
#include <objbase.h>
#include <oaidl.h>

#include <uiautomation.h>
#include <exdisp.h> // IShellWindows / IWebBrowser2
#include <shobjidl.h>
#include <shlobj.h>
#include <shlwapi.h> // StrRetToStrW
#include <knownfolders.h>

#include <cstring>
#include <cwchar>
#include <string>
#include <vector>

namespace windows_desktop {

std::mutex HoverTracker::s_mutex;
IUIAutomation *HoverTracker::s_uia = nullptr;
bool HoverTracker::s_com_initialized = false;

namespace {

constexpr int k_max_parent_steps = 8;

/// 取自动化元素 Name 的第一行（Windows 11 的 DataItem Name 可能包含多行）。
std::wstring first_line(const wchar_t *s) {
	std::wstring out;
	for (; s != nullptr && *s != L'\0' && *s != L'\r' && *s != L'\n'; ++s) {
		out += *s;
	}
	return out;
}

int hex_val(wchar_t c) {
	if (c >= L'0' && c <= L'9') {
		return c - L'0';
	}
	if (c >= L'a' && c <= L'f') {
		return c - L'a' + 10;
	}
	if (c >= L'A' && c <= L'F') {
		return c - L'A' + 10;
	}
	return -1;
}

/// 把 IWebBrowser2 的 LocationURL（形如 file:///C:/Users/...) 转换为本地路径。
/// 虚拟位置（此电脑、回收站等）返回 nullopt。
std::optional<std::wstring> url_to_path(const std::wstring &url) {
	const std::wstring prefix = L"file://";
	if (url.size() < prefix.size() || _wcsnicmp(url.c_str(), prefix.c_str(), prefix.size()) != 0) {
		return std::nullopt;
	}
	size_t pos = prefix.size();
	while (pos < url.size() && url[pos] == L'/') {
		++pos; // 兼容 file:// 与 file:///
	}

	// URL 解码 %XX。
	std::wstring path;
	path.reserve(url.size() - pos);
	for (size_t i = pos; i < url.size(); ++i) {
		const int hi = (i + 1 < url.size()) ? hex_val(url[i + 1]) : -1;
		const int lo = (i + 2 < url.size()) ? hex_val(url[i + 2]) : -1;
		if (url[i] == L'%' && hi >= 0 && lo >= 0) {
			path += static_cast<wchar_t>((hi << 4) | lo);
			i += 2;
		} else {
			path += url[i];
		}
	}

	if (path.empty()) {
		return std::nullopt;
	}
	// 盘符路径（C:/...）原样；其余按 UNC（file://server/share）补 \\ 前缀。
	if (path.size() < 2 || path[1] != L':') {
		if (path[0] != L'\\') {
			path = L"\\\\" + path;
		}
	}
	for (wchar_t &c : path) {
		if (c == L'/') {
			c = L'\\';
		}
	}
	return path;
}

/// 解析 .lnk 快捷方式指向的目标路径（文件或文件夹）。失败返回 nullopt。
std::optional<std::wstring> resolve_shortcut(const std::wstring &lnk_path) {
	IShellLinkW *shell_link = nullptr;
	HRESULT hr = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER, IID_IShellLinkW,
			reinterpret_cast<void **>(&shell_link));
	if (FAILED(hr) || shell_link == nullptr) {
		return std::nullopt;
	}

	std::optional<std::wstring> result = std::nullopt;
	IPersistFile *persist_file = nullptr;
	if (SUCCEEDED(shell_link->QueryInterface(IID_IPersistFile, reinterpret_cast<void **>(&persist_file))) &&
			persist_file != nullptr) {
		if (SUCCEEDED(persist_file->Load(lnk_path.c_str(), STGM_READ))) {
			// 1) Resolve + GetPath：处理目标路径可能失效/环境变量等情况。
			//    SLR_NOUI 不弹对话框；SLR_NOUPDATE 不重写快捷方式文件。
			shell_link->Resolve(nullptr, SLR_NO_UI | SLR_NOUPDATE);
			wchar_t buf[MAX_PATH] = {0};
			WIN32_FIND_DATAW fd = {};
			if (SUCCEEDED(shell_link->GetPath(buf, MAX_PATH, &fd, SLGP_UNCPRIORITY)) && buf[0] != L'\0') {
				result = std::wstring(buf);
			}
			// 2) 兜底：直接读 .lnk 内嵌的 PIDL（目标被移动或为 UWP 应用时 Resolve 可能失败）。
			if (!result.has_value()) {
				LPITEMIDLIST pidl = nullptr;
				if (SUCCEEDED(shell_link->GetIDList(&pidl)) && pidl != nullptr) {
					wchar_t path[MAX_PATH] = {0};
					if (SHGetPathFromIDListW(pidl, path) && path[0] != L'\0') {
						result = std::wstring(path);
					}
					CoTaskMemFree(pidl);
				}
			}
		}
		persist_file->Release();
	}
	shell_link->Release();
	return result;
}

/// 解析 .url 快捷方式：读 INI 文本中的 URL= 行（可能是网址，也可能是本地路径）。
std::optional<std::wstring> resolve_url(const std::wstring &url_path) {
	HANDLE h = CreateFileW(url_path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING,
			FILE_ATTRIBUTE_NORMAL, nullptr);
	if (h == INVALID_HANDLE_VALUE) {
		return std::nullopt;
	}
	std::string bytes;
	{
		char buf[4096];
		DWORD read = 0;
		while (ReadFile(h, buf, sizeof(buf), &read, nullptr) && read > 0) {
			bytes.append(buf, read);
		}
	}
	CloseHandle(h);
	if (bytes.empty()) {
		return std::nullopt;
	}

	// 解码为宽字符：UTF-16LE（有 BOM）或按系统 ANSI 代码页。
	std::wstring text;
	if (bytes.size() >= 2 && static_cast<unsigned char>(bytes[0]) == 0xFF &&
			static_cast<unsigned char>(bytes[1]) == 0xFE) {
		text.assign(reinterpret_cast<const wchar_t *>(bytes.data() + 2), (bytes.size() - 2) / 2);
	} else {
		const int len = MultiByteToWideChar(CP_ACP, 0, bytes.data(), static_cast<int>(bytes.size()), nullptr, 0);
		if (len > 0) {
			text.resize(static_cast<size_t>(len));
			MultiByteToWideChar(CP_ACP, 0, bytes.data(), static_cast<int>(bytes.size()), &text[0], len);
		}
	}

	// 逐行找 URL= 键（键名忽略大小写）。
	size_t pos = 0;
	while (pos < text.size()) {
		size_t eol = text.find(L'\n', pos);
		if (eol == std::wstring::npos) {
			eol = text.size();
		}
		std::wstring line = text.substr(pos, eol - pos);
		if (!line.empty() && line.back() == L'\r') {
			line.pop_back();
		}
		const size_t key_begin = line.find_first_not_of(L" \t");
		if (key_begin != std::wstring::npos) {
			const size_t eq = line.find(L'=', key_begin);
			if (eq != std::wstring::npos) {
				std::wstring key = line.substr(key_begin, eq - key_begin);
				if (key == L"URL" || key == L"url" || key == L"Url" || key == L"uRL" || key == L"uRl" || key == L"UrL") {
					std::wstring val = line.substr(eq + 1);
					const size_t end = val.find_last_not_of(L" \t");
					if (end != std::wstring::npos) {
						val = val.substr(0, end + 1);
					}
					if (!val.empty()) {
						return val;
					}
				}
			}
		}
		pos = eol + 1;
	}
	return std::nullopt;
}

/// 判断路径是否存在。
bool path_exists(const std::wstring &p) {
	return GetFileAttributesW(p.c_str()) != INVALID_FILE_ATTRIBUTES;
}

/// 桌面 Shell 命名空间解析结果。
struct DesktopItemResult {
	std::wstring path;      ///< 文件系统路径，或虚拟项的 "::{CLSID}" 形式路径
	bool is_virtual = false;
	bool is_dir = false;
};

/// 在桌面 Shell 命名空间里按显示名匹配一项（回收站、控制面板、此电脑等虚拟项也在此）。
std::optional<DesktopItemResult> resolve_desktop_item(const std::wstring &display_name) {
	IShellFolder *desktop = nullptr;
	if (FAILED(SHGetDesktopFolder(&desktop)) || desktop == nullptr) {
		return std::nullopt;
	}

	std::optional<DesktopItemResult> result = std::nullopt;
	IEnumIDList *items = nullptr;
	const HRESULT enum_hr = desktop->EnumObjects(nullptr,
			SHCONTF_FOLDERS | SHCONTF_NONFOLDERS | SHCONTF_INCLUDEHIDDEN, &items);
	if (SUCCEEDED(enum_hr) && items != nullptr) {
		LPITEMIDLIST pidl = nullptr;
		while (!result.has_value() && items->Next(1, &pidl, nullptr) == S_OK) {
			STRRET sr = {};
			if (SUCCEEDED(desktop->GetDisplayNameOf(pidl, SHGDN_INFOLDER, &sr))) {
				LPWSTR name_out = nullptr;
				if (SUCCEEDED(StrRetToStrW(&sr, pidl, &name_out)) && name_out != nullptr) {
					const std::wstring disp = name_out;
					CoTaskMemFree(name_out);
					if (disp == display_name) {
						DesktopItemResult item;
						SFGAOF attrs = 0;
						LPCITEMIDLIST apidl = pidl; // PCUITEMID_CHILD_ARRAY = const ITEMIDLIST**
						desktop->GetAttributesOf(1, &apidl, &attrs);
						item.is_dir = (attrs & SFGAO_FOLDER) != 0;
						if (attrs & SFGAO_FILESYSTEM) {
							wchar_t path[MAX_PATH] = {0};
							if (SHGetPathFromIDListW(pidl, path) && path[0] != L'\0') {
								item.path = path;
								result = item;
							}
						} else {
							// 虚拟项：用 FORPARSING 解析名取 "::{CLSID}" 形式路径。
							// （此 SDK 裁剪版缺少 SHGetNameFromIDListW，故用 GetDisplayNameOf）
							STRRET sr_parse = {};
							if (SUCCEEDED(desktop->GetDisplayNameOf(pidl, SHGDN_FORPARSING, &sr_parse))) {
								LPWSTR parse_out = nullptr;
								if (SUCCEEDED(StrRetToStrW(&sr_parse, pidl, &parse_out)) && parse_out != nullptr) {
									item.path = parse_out;
									item.is_virtual = true;
									CoTaskMemFree(parse_out);
									if (!item.path.empty()) {
										result = item;
									}
								}
							}
						}
					}
				}
			}
			ILFree(pidl);
		}
		items->Release();
	}
	desktop->Release();
	return result;
}

/// 判断路径是否为目录。
bool path_is_dir(const std::wstring &p) {
	const DWORD attr = GetFileAttributesW(p.c_str());
	return attr != INVALID_FILE_ATTRIBUTES && (attr & FILE_ATTRIBUTE_DIRECTORY) != 0;
}

/// 取小写扩展名（含点）。
std::wstring lowercase_extension(const std::wstring &p) {
	const size_t dot = p.find_last_of(L'.');
	const size_t sep = p.find_last_of(L"\\/");
	if (dot == std::wstring::npos || (sep != std::wstring::npos && dot < sep)) {
		return std::wstring();
	}
	std::wstring ext = p.substr(dot);
	for (wchar_t &c : ext) {
		if (c >= L'A' && c <= L'Z') {
			c += (L'a' - L'A');
		}
	}
	return ext;
}

/// 在指定窗口的 UIA 子树中按显示名查找文件列表项，返回其屏幕矩形（物理像素）。
std::optional<RECT> find_item_rect_in_window(IUIAutomation *uia, HWND hwnd, const std::wstring &display_name) {
	IUIAutomationElement *root_elem = nullptr;
	if (FAILED(uia->ElementFromHandle(hwnd, &root_elem)) || root_elem == nullptr) {
		return std::nullopt;
	}

	std::optional<RECT> result = std::nullopt;
	VARIANT vname;
	VariantInit(&vname);
	vname.vt = VT_BSTR;
	vname.bstrVal = SysAllocString(display_name.c_str());
	IUIAutomationCondition *cond = nullptr;
	if (SUCCEEDED(uia->CreatePropertyCondition(UIA_NamePropertyId, vname, &cond)) && cond != nullptr) {
		IUIAutomationElementArray *found = nullptr;
		if (SUCCEEDED(root_elem->FindAll(TreeScope_Descendants, cond, &found)) && found != nullptr) {
			int length = 0;
			if (SUCCEEDED(found->get_Length(&length))) {
				for (int i = 0; i < length && !result.has_value(); ++i) {
					IUIAutomationElement *elem = nullptr;
					if (FAILED(found->GetElement(i, &elem)) || elem == nullptr) {
						continue;
					}
					CONTROLTYPEID ctype = 0;
					elem->get_CurrentControlType(&ctype);
					if (ctype == UIA_ListItemControlTypeId || ctype == UIA_DataItemControlTypeId) {
						RECT r = {};
						// 注意：本 SDK（10.0.22621）的签名是 RECT*（非旧版文档中的 UiaRect*）。
						if (SUCCEEDED(elem->get_CurrentBoundingRectangle(&r))) {
							result = r;
						}
					}
					elem->Release();
				}
			}
			found->Release();
		}
		cond->Release();
	}
	VariantClear(&vname);
	root_elem->Release();
	return result;
}

/// EnumWindows 回调：在所有 WorkerW 窗口里找桌面图标。
struct DesktopSearchCtx {
	IUIAutomation *uia = nullptr;
	std::wstring name;
	std::optional<RECT> result;
};

BOOL CALLBACK enum_desktop_windows(HWND hwnd, LPARAM lparam) {
	DesktopSearchCtx *ctx = reinterpret_cast<DesktopSearchCtx *>(lparam);
	wchar_t cls[64] = {0};
	if (GetClassNameW(hwnd, cls, 64) != 0 && wcscmp(cls, L"WorkerW") == 0) {
		std::optional<RECT> r = find_item_rect_in_window(ctx->uia, hwnd, ctx->name);
		if (r.has_value()) {
			ctx->result = r;
			return FALSE; // 停止枚举
		}
	}
	return TRUE;
}

/// 在桌面（Progman / WorkerW 下的图标列表）查找显示名为 name 的项。
std::optional<RECT> find_desktop_item_rect(IUIAutomation *uia, const std::wstring &display_name) {
	HWND hwnd = FindWindowW(L"Progman", nullptr);
	if (hwnd != nullptr) {
		std::optional<RECT> r = find_item_rect_in_window(uia, hwnd, display_name);
		if (r.has_value()) {
			return r;
		}
	}
	DesktopSearchCtx ctx;
	ctx.uia = uia;
	ctx.name = display_name;
	EnumWindows(enum_desktop_windows, reinterpret_cast<LPARAM>(&ctx));
	return ctx.result;
}

/// 在 IShellWindows 里找当前目录为 dir 的资源管理器窗口。
std::optional<HWND> find_explorer_window_for_dir(const std::wstring &dir) {
	IShellWindows *shell_windows = nullptr;
	HRESULT hr = CoCreateInstance(CLSID_ShellWindows, nullptr, CLSCTX_ALL, IID_IShellWindows,
			reinterpret_cast<void **>(&shell_windows));
	if (FAILED(hr) || shell_windows == nullptr) {
		return std::nullopt;
	}

	std::optional<HWND> result = std::nullopt;
	long count = 0;
	if (SUCCEEDED(shell_windows->get_Count(&count))) {
		for (long i = 0; i < count && !result.has_value(); ++i) {
			VARIANT index;
			VariantInit(&index);
			index.vt = VT_I4;
			index.lVal = i;

			IDispatch *item = nullptr;
			if (FAILED(shell_windows->Item(index, &item)) || item == nullptr) {
				VariantClear(&index);
				continue;
			}
			IWebBrowser2 *browser = nullptr;
			if (SUCCEEDED(item->QueryInterface(IID_IWebBrowser2, reinterpret_cast<void **>(&browser))) &&
					browser != nullptr) {
				BSTR url = nullptr;
				if (SUCCEEDED(browser->get_LocationURL(&url)) && url != nullptr) {
					std::optional<std::wstring> path = url_to_path(std::wstring(url, SysStringLen(url)));
					if (path.has_value() && _wcsicmp(path->c_str(), dir.c_str()) == 0) {
						LONG_PTR hwnd = 0;
						if (SUCCEEDED(browser->get_HWND(&hwnd)) && hwnd != 0) {
							result = reinterpret_cast<HWND>(hwnd);
						}
					}
				}
				if (url != nullptr) {
					SysFreeString(url);
				}
				browser->Release();
			}
			item->Release();
			VariantClear(&index);
		}
	}
	shell_windows->Release();
	return result;
}

} // namespace

bool HoverTracker::ensure_uia() {
	if (s_uia != nullptr) {
		return true;
	}
	if (!s_com_initialized) {
		HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
		if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
			return false;
		}
		// RPC_E_CHANGED_MODE 表示线程已用其他模式初始化过：继续尝试，多数情况下 UIA 仍可用。
		s_com_initialized = true;
	}
	HRESULT hr = CoCreateInstance(CLSID_CUIAutomation, nullptr, CLSCTX_INPROC_SERVER,
			IID_IUIAutomation, reinterpret_cast<void **>(&s_uia));
	return SUCCEEDED(hr) && s_uia != nullptr;
}

bool HoverTracker::is_desktop_window(HWND hwnd) {
	wchar_t cls[64] = {0};
	if (GetClassNameW(hwnd, cls, 64) == 0) {
		return false;
	}
	return wcscmp(cls, L"Progman") == 0 || wcscmp(cls, L"WorkerW") == 0;
}

bool HoverTracker::is_explorer_window(HWND hwnd) {
	wchar_t cls[64] = {0};
	if (GetClassNameW(hwnd, cls, 64) == 0) {
		return false;
	}
	return wcscmp(cls, L"CabinetWClass") == 0;
}

std::optional<std::wstring> HoverTracker::desktop_path() {
	PWSTR raw = nullptr;
	if (FAILED(SHGetKnownFolderPath(FOLDERID_Desktop, 0, nullptr, &raw)) || raw == nullptr) {
		return std::nullopt;
	}
	std::wstring path = raw;
	CoTaskMemFree(raw);
	return path;
}

/// 通过 IShellWindows 找到句柄为 hwnd 的资源管理器窗口，返回其当前目录。
/// 资源管理器窗口的自动化 Document 实现 IWebBrowser2：get_HWND 匹配窗口，
/// get_LocationURL 返回 file:/// 形式的当前目录。
std::optional<std::wstring> HoverTracker::explorer_current_path(HWND hwnd) {
	IShellWindows *shell_windows = nullptr;
	HRESULT hr = CoCreateInstance(CLSID_ShellWindows, nullptr, CLSCTX_ALL, IID_IShellWindows,
			reinterpret_cast<void **>(&shell_windows));
	if (FAILED(hr) || shell_windows == nullptr) {
		return std::nullopt;
	}

	std::optional<std::wstring> result = std::nullopt;
	long count = 0;
	if (SUCCEEDED(shell_windows->get_Count(&count))) {
		for (long i = 0; i < count && !result.has_value(); ++i) {
			VARIANT index;
			VariantInit(&index);
			index.vt = VT_I4;
			index.lVal = i;

			IDispatch *item = nullptr;
			if (FAILED(shell_windows->Item(index, &item)) || item == nullptr) {
				VariantClear(&index);
				continue;
			}

			IWebBrowser2 *browser = nullptr;
			if (SUCCEEDED(item->QueryInterface(IID_IWebBrowser2, reinterpret_cast<void **>(&browser))) &&
					browser != nullptr) {
				LONG_PTR item_hwnd = 0;
				if (SUCCEEDED(browser->get_HWND(&item_hwnd)) && reinterpret_cast<HWND>(item_hwnd) == hwnd) {
					BSTR url = nullptr;
					if (SUCCEEDED(browser->get_LocationURL(&url)) && url != nullptr) {
						result = url_to_path(std::wstring(url, SysStringLen(url)));
					}
					if (url != nullptr) {
						SysFreeString(url);
					}
				}
				browser->Release();
			}
			item->Release();
			VariantClear(&index);
		}
	}
	shell_windows->Release();
	return result;
}

std::optional<HoveredEntry> HoverTracker::query(const POINT &pt) {
	std::lock_guard<std::mutex> lock(s_mutex);
	if (!ensure_uia()) {
		return std::nullopt;
	}

	// 1. 判断鼠标所在的顶层窗口：资源管理器或桌面。
	HWND hwnd_at = WindowFromPoint(pt);
	HWND root = hwnd_at != nullptr ? GetAncestor(hwnd_at, GA_ROOT) : nullptr;
	const bool is_desktop = root != nullptr && is_desktop_window(root);
	const bool is_explorer = root != nullptr && is_explorer_window(root);
	if (!is_desktop && !is_explorer) {
		return std::nullopt;
	}

	// 2. 用 UI Automation 从鼠标位置取元素，向上找 ListItem / DataItem 拿文件名。
	IUIAutomationElement *element = nullptr;
	if (FAILED(s_uia->ElementFromPoint(pt, &element)) || element == nullptr) {
		return std::nullopt;
	}

	IUIAutomationTreeWalker *walker = nullptr;
	s_uia->get_ControlViewWalker(&walker);

	std::wstring name;
	IUIAutomationElement *cur = element;
	for (int depth = 0; cur != nullptr && depth < k_max_parent_steps && name.empty(); ++depth) {
		CONTROLTYPEID ctype = 0;
		BSTR bname = nullptr;
		cur->get_CurrentControlType(&ctype);
		cur->get_CurrentName(&bname);

		if (bname != nullptr) {
			name = first_line(bname);
		}
		SysFreeString(bname);

		if (ctype == UIA_ListItemControlTypeId || ctype == UIA_DataItemControlTypeId) {
			break; // 找到文件列表项（name 已是文件名）
		}
		// 到窗口/面板仍未命中列表项，说明悬停在空白处或非文件区域。
		if (ctype == UIA_WindowControlTypeId || ctype == UIA_PaneControlTypeId) {
			name.clear();
			break;
		}
		name.clear();

		IUIAutomationElement *parent = nullptr;
		if (walker != nullptr) {
			walker->GetParentElement(cur, &parent);
		}
		cur->Release();
		cur = parent;
	}
	if (cur != nullptr) {
		cur->Release();
	}
	if (walker != nullptr) {
		walker->Release();
	}

	if (name.empty()) {
		return std::nullopt;
	}

	// 3. 取当前目录：资源管理器窗口用 IShellWindows，桌面用桌面路径。
	std::optional<std::wstring> base = std::nullopt;
	if (is_explorer) {
		base = explorer_current_path(root);
	}
	if (!base.has_value() && is_desktop) {
		base = desktop_path();
	}

	// 4. 拼接候选路径并校验。快捷方式在桌面/资源管理器中的 UIA Name 是
	//    不带扩展名的显示名（如 "98K加速器"），所以额外尝试补 .lnk / .url。
	auto join_base = [&](const std::wstring &n) {
		std::wstring p = base.has_value() ? *base : std::wstring();
		if (!p.empty() && p.back() != L'\\') {
			p += L'\\';
		}
		return p + n;
	};

	std::vector<std::wstring> candidates;
	candidates.push_back(join_base(name));
	candidates.push_back(join_base(name + L".lnk"));
	candidates.push_back(join_base(name + L".url"));
	candidates.push_back(name); // 极少数情况下 UIA 的 Name 本身就是完整路径

	for (const std::wstring &cand : candidates) {
		if (!path_exists(cand)) {
			continue;
		}
		HoveredEntry entry;
		entry.name = name;
		const std::wstring ext = lowercase_extension(cand);
		if (ext == L".lnk") {
			entry.is_shortcut = true;
			entry.source_path = cand;
			std::optional<std::wstring> target = resolve_shortcut(cand);
			if (target.has_value() && path_exists(*target)) {
				entry.path = *target;
				entry.is_dir = path_is_dir(*target);
			} else {
				entry.path = cand; // 解析失败回退为 .lnk 自身
				entry.is_dir = false;
			}
		} else if (ext == L".url") {
			entry.is_shortcut = true;
			entry.source_path = cand;
			std::optional<std::wstring> target = resolve_url(cand);
			entry.path = target.has_value() ? *target : cand;
			entry.is_dir = false;
		} else {
			entry.path = cand;
			entry.is_dir = path_is_dir(cand);
		}
		return entry;
	}

	// 5. 桌面特殊项兜底：回收站、控制面板、此电脑等虚拟项没有文件系统路径，
	//    改用桌面 Shell 命名空间按显示名匹配。
	if (is_desktop) {
		std::optional<DesktopItemResult> item = resolve_desktop_item(name);
		if (item.has_value()) {
			HoveredEntry entry;
			entry.name = name;
			entry.path = item->path;
			entry.is_dir = item->is_dir;
			entry.is_virtual = item->is_virtual;
			if (!item->is_virtual) {
				const std::wstring ext = lowercase_extension(item->path);
				if (ext == L".lnk") {
					entry.is_shortcut = true;
					entry.source_path = item->path;
					std::optional<std::wstring> target = resolve_shortcut(item->path);
					if (target.has_value() && path_exists(*target)) {
						entry.path = *target;
						entry.is_dir = path_is_dir(*target);
					}
				}
			}
			return entry;
		}
	}
	return std::nullopt;
}

std::optional<RECT> HoverTracker::file_rect(const std::wstring &path) {
	std::lock_guard<std::mutex> lock(s_mutex);
	if (!ensure_uia()) {
		return std::nullopt;
	}
	if (path.empty()) {
		return std::nullopt;
	}

	// 拆出文件名与父目录。
	const size_t sep = path.find_last_of(L"\\/");
	const std::wstring fname = (sep == std::wstring::npos) ? path : path.substr(sep + 1);
	const std::wstring parent = (sep == std::wstring::npos) ? std::wstring() : path.substr(0, sep);
	if (fname.empty()) {
		return std::nullopt;
	}

	// 显示名候选：原名；快捷方式显示名不带扩展名。
	std::vector<std::wstring> names;
	names.push_back(fname);
	const std::wstring ext = lowercase_extension(fname);
	if ((ext == L".lnk" || ext == L".url") && fname.size() > ext.size()) {
		names.push_back(fname.substr(0, fname.size() - ext.size()));
	}

	// 目标窗口：父目录为桌面路径 → 桌面图标；否则在资源管理器中找当前目录 == 父目录的窗口。
	const std::wstring desktop = desktop_path().value_or(std::wstring());
	const bool is_desktop = !parent.empty() && !desktop.empty() && _wcsicmp(parent.c_str(), desktop.c_str()) == 0;

	for (const std::wstring &name : names) {
		if (is_desktop) {
			std::optional<RECT> r = find_desktop_item_rect(s_uia, name);
			if (r.has_value()) {
				return r;
			}
		} else {
			std::optional<HWND> hwnd = find_explorer_window_for_dir(parent);
			if (hwnd.has_value()) {
				std::optional<RECT> r = find_item_rect_in_window(s_uia, *hwnd, name);
				if (r.has_value()) {
					return r;
				}
			}
		}
	}
	return std::nullopt;
}

} // namespace windows_desktop

#endif // _WIN32
