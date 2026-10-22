cmake_minimum_required(VERSION 3.16)
cmake_policy(SET CMP0091 NEW)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
project(MyOpenKey LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(ENGINE_SOURCES
    Sources/OpenKey/engine/ConvertTool.cpp
    Sources/OpenKey/engine/Engine.cpp
    Sources/OpenKey/engine/Macro.cpp
    Sources/OpenKey/engine/SmartSwitchKey.cpp
    Sources/OpenKey/engine/Vietnamese.cpp
)

add_library(openkey_engine STATIC ${ENGINE_SOURCES})
target_include_directories(openkey_engine PUBLIC Sources/OpenKey/engine)

if(MSVC)
    target_compile_options(openkey_engine PUBLIC /utf-8)
    target_compile_definitions(openkey_engine PUBLIC _SILENCE_CXX17_CODECVT_HEADER_DEPRECATION_WARNING)
endif()

enable_testing()

add_executable(engine_test Tests/engine_test.cpp)
target_link_libraries(engine_test PRIVATE openkey_engine)

if(MSVC)
    target_compile_options(engine_test PRIVATE /utf-8)
    target_compile_definitions(engine_test PRIVATE _SILENCE_CXX17_CODECVT_HEADER_DEPRECATION_WARNING)
endif()

add_test(NAME engine_regression_test COMMAND engine_test)

if(WIN32)
    add_executable(MyOpenKey WIN32
        Sources/OpenKey/win32/main.cpp
        Sources/OpenKey/win32/Hook.cpp
        Sources/OpenKey/win32/Settings.cpp
        Sources/OpenKey/win32/SettingsDlg.cpp
        Sources/OpenKey/win32/resource.rc
        Sources/OpenKey/win32/app.manifest
    )
    target_include_directories(MyOpenKey PRIVATE
        Sources/OpenKey/engine
        Sources/OpenKey/macOS/ModernKey
        Sources/OpenKey/win32
    )
    target_compile_definitions(MyOpenKey PRIVATE
        OPENKEY_WIN32_KEYS
        NOMINMAX
        WIN32_LEAN_AND_MEAN
        UNICODE
        _UNICODE
    )
    target_link_libraries(MyOpenKey PRIVATE
        openkey_engine
        user32
        shell32
        advapi32
        comctl32
        comdlg32
        gdi32
    )
    if(MSVC)
        target_compile_options(MyOpenKey PRIVATE /utf-8 /W4)
        target_compile_definitions(MyOpenKey PRIVATE _SILENCE_CXX17_CODECVT_HEADER_DEPRECATION_WARNING)
    endif()
endif()
