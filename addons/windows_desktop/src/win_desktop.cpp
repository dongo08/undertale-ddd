#include "win_desktop.h"

#include "hover_tracker.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math_defs.hpp>
#include <godot_cpp/variant/char_string.hpp>

using namespace godot;

#ifdef _WIN32
#include <windows.h>
#include <knownfolders.h>
#include <shlobj.h>

#include <algorithm>
#include <chrono>
#include <cwchar> // _wcsicmp
#include <filesystem>
#include <optional>
#include <string>
#include <vector>
#endif // _WIN32

namespace windows_desktop {

#ifdef _WIN32
namespace {

namespace fs = std::filesystem;

/// Windows FILETIME 纪元（1601-01-01）到 Unix 纪元（1970-01-01）的秒偏移。
constexpr int64_t k_win_epoch_to_unix_sec = 11644473600LL;

struct Entry {
	std::wstring path;
	std::wstring name;
	bool is_dir = false;
	bool is_link = false;
	uint64_t size = 0;
	int64_t modified = 0;
};

std::wstring get_desktop_path_w() {
	PWSTR raw = nullptr;
	if (FAILED(SHGetKnownFolderPath(FOLDERID_Desktop, 0, nullptr, &raw)) || raw == nullptr) {
		return std::wstring();
	}
	std::wstring path = raw;
	CoTaskMemFree(raw);
	return path;
}

godot::String to_godot(const std::wstring &s) {
	// 注意：不能用 godot::String(const char*)——godot-cpp 4.4 里该构造按 Latin-1 解析，
	// UTF-8 字节会被逐字节误读导致中文乱码。String(const wchar_t*) 走 wide chars
	// （Windows 上 wchar_t 即 UTF-16），语义正确。
	return godot::String(s.c_str());
}

std::wstring to_wstring(const godot::String &s) {
	// Godot String -> UTF-8 -> UTF-16（wchar_t）。
	const CharString utf8 = s.utf8();
	const int len = MultiByteToWideChar(CP_UTF8, 0, utf8.ptr(), -1, nullptr, 0);
	if (len <= 0) {
		return std::wstring();
	}
	std::wstring w(static_cast<size_t>(len - 1), L'\0');
	MultiByteToWideChar(CP_UTF8, 0, utf8.ptr(), -1, &w[0], len);
	return w;
}

godot::Dictionary entry_to_dict(const Entry &e) {
	godot::Dictionary d;
	d["path"] = to_godot(e.path);
	d["name"] = to_godot(e.name);
	d["is_dir"] = e.is_dir;
	d["is_link"] = e.is_link;
	d["size"] = static_cast<int64_t>(e.size);
	d["modified"] = e.modified;
	return d;
}

int64_t file_time_to_unix(const fs::file_time_type &t) {
	const int64_t secs =
			std::chrono::duration_cast<std::chrono::seconds>(t.time_since_epoch()).count();
#ifdef _MSC_VER
	// MSVC 的 std::filesystem::file_time_type 基于 Windows FILETIME（1601-01-01），
	// 需要减去到 Unix 纪元的秒偏移。
	return secs - k_win_epoch_to_unix_sec;
#else
	// MinGW/libstdc++ 的 file_time_type 与 system_clock 同纪元（Unix 时间）。
	return secs;
#endif
}

bool cmp_entry(const Entry &a, const Entry &b) {
	if (a.is_dir != b.is_dir) {
		return a.is_dir; // 目录在前
	}
	return _wcsicmp(a.name.c_str(), b.name.c_str()) < 0;
}

void collect_entries(const std::wstring &base, bool recursive, std::vector<Entry> &out) {
	std::error_code ec;
	if (recursive) {
		fs::recursive_directory_iterator it(base, fs::directory_options::skip_permission_denied, ec);
		if (ec) {
			return;
		}
		fs::recursive_directory_iterator end;
		for (; it != end; it.increment(ec)) {
			if (ec) {
				ec.clear();
				continue;
			}
			const fs::directory_entry &de = *it;
			Entry e;
			e.path = de.path().wstring();
			e.name = de.path().filename().wstring();
			e.is_dir = de.is_directory(ec);
			e.is_link = de.is_symlink(ec);
			e.size = e.is_dir ? 0 : de.file_size(ec);
			e.modified = file_time_to_unix(de.last_write_time(ec));
			if (!ec) {
				out.push_back(std::move(e));
			}
		}
	} else {
		fs::directory_iterator it(base, fs::directory_options::skip_permission_denied, ec);
		if (ec) {
			return;
		}
		fs::directory_iterator end;
		for (; it != end; it.increment(ec)) {
			if (ec) {
				ec.clear();
				continue;
			}
			const fs::directory_entry &de = *it;
			Entry e;
			e.path = de.path().wstring();
			e.name = de.path().filename().wstring();
			e.is_dir = de.is_directory(ec);
			e.is_link = de.is_symlink(ec);
			e.size = e.is_dir ? 0 : de.file_size(ec);
			e.modified = file_time_to_unix(de.last_write_time(ec));
			if (!ec) {
				out.push_back(std::move(e));
			}
		}
	}
}

/// 用 GetFileAttributesExW 补充悬停文件的 size / modified（不依赖 std::filesystem）。
void fill_extra_from_win32(const std::wstring &path, Entry &e) {
	WIN32_FILE_ATTRIBUTE_DATA data = {};
	if (GetFileAttributesExW(path.c_str(), GetFileExInfoStandard, &data)) {
		e.size = (static_cast<uint64_t>(data.nFileSizeHigh) << 32) | data.nFileSizeLow;
		ULARGE_INTEGER ft;
		ft.LowPart = data.ftLastWriteTime.dwLowDateTime;
		ft.HighPart = data.ftLastWriteTime.dwHighDateTime;
		e.modified = static_cast<int64_t>(ft.QuadPart / 10000000ULL) - k_win_epoch_to_unix_sec;
		e.is_link = (data.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
	}
}

godot::Dictionary hovered_to_dict(const HoveredEntry &h) {
	godot::Dictionary d;
	d["path"] = to_godot(h.path);
	d["name"] = to_godot(h.name);
	d["is_dir"] = h.is_dir;
	d["is_shortcut"] = h.is_shortcut;
	d["is_virtual"] = h.is_virtual;
	if (h.is_shortcut) {
		d["source_path"] = to_godot(h.source_path);
	}

	// size / modified 等附加信息：快捷方式目标若是 URL 等非本地路径，这些字段为 0/0。
	Entry e;
	e.path = h.path;
	e.name = h.name;
	e.is_dir = h.is_dir;
	fill_extra_from_win32(h.path, e);
	d["is_link"] = e.is_link;
	d["size"] = static_cast<int64_t>(e.size);
	d["modified"] = e.modified;
	return d;
}

} // namespace
#endif // _WIN32

void WinDesktop::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_desktop_path"), &WinDesktop::get_desktop_path);
	ClassDB::bind_method(D_METHOD("get_desktop_entries", "recursive"), &WinDesktop::get_desktop_entries, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("get_desktop_file_paths", "recursive"), &WinDesktop::get_desktop_file_paths, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("get_hovered_file"), &WinDesktop::get_hovered_file);
	ClassDB::bind_method(D_METHOD("get_hovered_file_at", "screen_pos"), &WinDesktop::get_hovered_file_at);
	ClassDB::bind_method(D_METHOD("get_file_rect", "path"), &WinDesktop::get_file_rect);
}

godot::String WinDesktop::get_desktop_path() const {
#ifdef _WIN32
	std::wstring path = get_desktop_path_w();
	if (path.empty()) {
		return godot::String();
	}
	return to_godot(path);
#else
	return godot::String();
#endif
}

godot::Array WinDesktop::get_desktop_entries(bool recursive) const {
	godot::Array result;
#ifdef _WIN32
	std::wstring base = get_desktop_path_w();
	if (base.empty()) {
		return result;
	}
	std::vector<Entry> entries;
	collect_entries(base, recursive, entries);
	std::sort(entries.begin(), entries.end(), cmp_entry);
	for (const Entry &e : entries) {
		result.append(entry_to_dict(e));
	}
#endif
	return result;
}

godot::PackedStringArray WinDesktop::get_desktop_file_paths(bool recursive) const {
	godot::PackedStringArray result;
#ifdef _WIN32
	std::wstring base = get_desktop_path_w();
	if (base.empty()) {
		return result;
	}
	std::vector<Entry> entries;
	collect_entries(base, recursive, entries);
	std::sort(entries.begin(), entries.end(), cmp_entry);
	for (const Entry &e : entries) {
		result.append(to_godot(e.path));
	}
#endif
	return result;
}

godot::Dictionary WinDesktop::get_hovered_file() const {
#ifdef _WIN32
	POINT pt;
	if (!GetCursorPos(&pt)) {
		return godot::Dictionary();
	}
	return get_hovered_file_at(godot::Vector2i(pt.x, pt.y));
#else
	return godot::Dictionary();
#endif
}

godot::Dictionary WinDesktop::get_hovered_file_at(godot::Vector2i screen_pos) const {
#ifdef _WIN32
	POINT pt;
	pt.x = screen_pos.x;
	pt.y = screen_pos.y;
	std::optional<HoveredEntry> hovered = HoverTracker::query(pt);
	if (!hovered.has_value()) {
		return godot::Dictionary();
	}
	return hovered_to_dict(*hovered);
#else
	return godot::Dictionary();
#endif
}

godot::Rect2 WinDesktop::get_file_rect(godot::String path) const {
#ifdef _WIN32
	std::wstring p = to_wstring(path);
	if (p.empty()) {
		return godot::Rect2();
	}
	std::optional<RECT> r = HoverTracker::file_rect(p);
	if (!r.has_value()) {
		return godot::Rect2();
	}
	return godot::Rect2(
			static_cast<real_t>(r->left), static_cast<real_t>(r->top),
			static_cast<real_t>(r->right - r->left), static_cast<real_t>(r->bottom - r->top));
#else
	return godot::Rect2();
#endif
}

} // namespace windows_desktop
