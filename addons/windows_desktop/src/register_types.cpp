#include "register_types.h"

#include "win_desktop.h"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_windows_desktop_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(windows_desktop::WinDesktop);
}

void uninitialize_windows_desktop_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
}

extern "C" {
// 扩展入口：符号名与 .gdextension 中的 entry_symbol 一致。
// GDE_EXPORT 必须保留（Windows 下展开为 __declspec(dllexport)），否则 MSVC 构建的 DLL 不导出该符号。
GDExtensionBool GDE_EXPORT GDExtensionInit(GDExtensionInterfaceGetProcAddress p_get_proc_address,
		const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

	init_obj.register_initializer(initialize_windows_desktop_module);
	init_obj.register_terminator(uninitialize_windows_desktop_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

	return init_obj.init();
}
}
