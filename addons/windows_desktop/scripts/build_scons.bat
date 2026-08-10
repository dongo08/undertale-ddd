@echo off
setlocal
REM ============================================================
REM  使用 SCons 构建 windows_desktop GDExtension (x86_64)
REM  用法:  build_scons.bat [debug|release|all]   默认 all
REM  前置要求: git、Python、scons
REM  说明: godot-cpp 与 DLL 命名由 SConstruct 自动处理
REM ============================================================

set MODE=%1
if "%MODE%"=="" set MODE=all

set ROOT=%~dp0..\..\..
cd /d "%ROOT%" || goto :error
echo 工作目录: %CD%

pushd addons\windows_desktop || goto :error

if /i "%MODE%"=="release" goto :build_release
echo [*] 构建 template_debug ...
scons platform=windows target=template_debug arch=x86_64 -j %NUMBER_OF_PROCESSORS% || goto :pop_error

:build_release
if /i "%MODE%"=="debug" goto :scons_done
echo [*] 构建 template_release ...
scons platform=windows target=template_release arch=x86_64 -j %NUMBER_OF_PROCESSORS% || goto :pop_error

:scons_done
popd
echo.
echo 构建完成！输出:
echo   addons\windows_desktop\bin\windows_desktop.debug.dll
echo   addons\windows_desktop\bin\windows_desktop.dll
exit /b 0

:pop_error
popd
:error
echo 构建失败，请检查上方错误信息。
exit /b 1
