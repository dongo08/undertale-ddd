@echo off
setlocal
REM ============================================================
REM  使用 CMake 构建 windows_desktop GDExtension (x86_64)
REM  用法:  build_cmake.bat [debug|release|all]   默认 all
REM  前置要求: git、CMake >= 3.17、Visual Studio 2022 或
REM           VS Build Tools（勾选"使用 C++ 的桌面开发"）
REM ============================================================

set MODE=%1
if "%MODE%"=="" set MODE=all

set ROOT=%~dp0..\..\..
cd /d "%ROOT%" || goto :error
echo 工作目录: %CD%

REM ---------- 1. 准备 godot-cpp ----------
if not exist godot-cpp (
    echo [*] 克隆 godot-cpp 4.4 ...
    git clone -b 4.4 --depth 1 https://github.com/godotengine/godot-cpp.git godot-cpp || goto :error
) else (
    echo [*] godot-cpp 已存在，跳过克隆
)

REM ---------- 2. 构建 template_debug ----------
if /i "%MODE%"=="release" goto :build_release
echo [*] 构建 template_debug ...
cmake -S addons/windows_desktop -B build/template_debug ^
    -DGODOT_CPP_PATH=godot-cpp ^
    -DGODOTCPP_TARGET=template_debug ^
    -DCMAKE_BUILD_TYPE=Release || goto :error
cmake --build build/template_debug --config Release || goto :error
if exist addons\windows_desktop\bin\windows_desktop.debug.dll del addons\windows_desktop\bin\windows_desktop.debug.dll
copy /y addons\windows_desktop\bin\windows_desktop.dll addons\windows_desktop\bin\windows_desktop.debug.dll >nul || goto :error
echo [*] 生成 addons\windows_desktop\bin\windows_desktop.debug.dll

:build_release
if /i "%MODE%"=="debug" goto :done
REM ---------- 3. 构建 template_release ----------
echo [*] 构建 template_release ...
cmake -S addons/windows_desktop -B build/template_release ^
    -DGODOT_CPP_PATH=godot-cpp ^
    -DGODOTCPP_TARGET=template_release ^
    -DCMAKE_BUILD_TYPE=Release || goto :error
cmake --build build/template_release --config Release || goto :error
echo [*] 生成 addons\windows_desktop\bin\windows_desktop.dll

:done
echo.
echo 构建完成！输出:
echo   addons\windows_desktop\bin\windows_desktop.debug.dll
echo   addons\windows_desktop\bin\windows_desktop.dll
exit /b 0

:error
echo 构建失败，请检查上方错误信息。
exit /b 1
