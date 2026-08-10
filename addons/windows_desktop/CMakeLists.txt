cmake_minimum_required(VERSION 3.17)
project(windows_desktop_gdextension LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# godot-cpp 源码路径（默认取仓库根下的 godot-cpp，可用 -DGODOT_CPP_PATH=... 覆盖）
set(GODOT_CPP_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../godot-cpp" CACHE PATH
    "Path to the godot-cpp source tree")

# 构建目标：template_debug | template_release | editor
set(GODOTCPP_TARGET "template_debug" CACHE STRING "Which godot-cpp target to build")
set_property(CACHE GODOTCPP_TARGET PROPERTY STRINGS template_debug template_release editor)

add_subdirectory(${GODOT_CPP_PATH} godot-cpp)

add_library(windows_desktop SHARED
    src/register_types.cpp
    src/win_desktop.cpp
    src/hover_tracker.cpp
)

target_include_directories(windows_desktop PRIVATE src)
target_link_libraries(windows_desktop PRIVATE godot-cpp)

if(WIN32)
    target_compile_definitions(windows_desktop PRIVATE
        NOMINMAX
        # 不要定义 WIN32_LEAN_AND_MEAN：会令 windows.h 缺少 ole2.h，
        # 导致 UIAutomationCore.h 因 interface 宏缺失而编译失败。
        _WIN32_WINNT=0x0A00
    )
    target_link_libraries(windows_desktop PRIVATE
        ole32
        oleaut32
        shell32
        shlwapi
        user32
        uiautomationcore
    )
    if(MSVC)
        # /utf-8: 源码为 UTF-8（含中文注释）；/EHsc: 允许 C++ 异常
        target_compile_options(windows_desktop PRIVATE /EHsc /utf-8)
    endif()
    # 让 DLL 直接输出到插件 bin/ 目录（避免 VS 多配置生成器追加 /Release、/Debug）
    set_target_properties(windows_desktop PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin"
        RUNTIME_OUTPUT_DIRECTORY_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/bin"
        RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/bin"
    )
endif()
