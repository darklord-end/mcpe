# Toolchain configurations for Minecraft Potet Edition
# This file provides toolchain configurations for different platforms

# Android toolchain
function(setup_android_toolchain)
    if(NOT ANDROID_NDK)
        set(ANDROID_NDK "$ENV{ANDROID_NDK_HOME}" CACHE PATH "Android NDK path")
    endif()
    
    if(NOT ANDROID_ABI)
        set(ANDROID_ABI "arm64-v8a" CACHE STRING "Android ABI")
    endif()
    
    if(NOT ANDROID_PLATFORM)
        set(ANDROID_PLATFORM android-29 CACHE STRING "Android platform")
    endif()
    
    # Set up Android toolchain
    set(CMAKE_SYSTEM_NAME Android)
    set(CMAKE_SYSTEM_VERSION ${ANDROID_PLATFORM})
    set(CMAKE_ANDROID_ARCH_ABI ${ANDROID_ABI})
    set(CMAKE_ANDROID_NDK ${ANDROID_NDK})
    set(CMAKE_ANDROID_STL_TYPE c++_static)
    
    # Android compiler
    set(CMAKE_C_COMPILER ${ANDROID_NDK}/toolchains/llvm/prebuilt/windows-x86_64/bin/clang)
    set(CMAKE_CXX_COMPILER ${ANDROID_NDK}/toolchains/llvm/prebuilt/windows-x86_64/bin/clang++)
    
    # Android find root path
    set(CMAKE_FIND_ROOT_PATH ${ANDROID_NDK}/sysroot)
    set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
    set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
    set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
    set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
endfunction()

# Linux toolchain
function(setup_linux_toolchain)
    set(CMAKE_SYSTEM_NAME Linux)
    set(CMAKE_SYSTEM_VERSION 1)
    
    # Use ccache if available
    find_program(CCACHE_PROGRAM ccache)
    if(CCACHE_PROGRAM)
        set(CMAKE_C_COMPILER_LAUNCHER ${CCACHE_PROGRAM})
        set(CMAKE_CXX_COMPILER_LAUNCHER ${CCACHE_PROGRAM})
    endif()
    
    # Enable all warnings
    add_compile_options(-Wall -Wextra -Wpedantic)
    
    # Platform-specific optimizations
    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        add_compile_options(-O3 -DNDEBUG)
    elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
        add_compile_options(-O2 -g)
    elseif(CMAKE_BUILD_TYPE STREQUAL "Debug")
        add_compile_options(-O0 -g)
    endif()
endfunction()

# Windows toolchain
function(setup_windows_toolchain)
    set(CMAKE_SYSTEM_NAME Windows)
    
    # Use MSVC or MinGW
    if(MSVC)
        # Microsoft Visual C++
        add_compile_options(/W4 /WX)
        
        if(CMAKE_BUILD_TYPE STREQUAL "Release")
            add_compile_options(/O2 /DNDEBUG)
        elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
            add_compile_options(/O2 /Zi)
        elseif(CMAKE_BUILD_TYPE STREQUAL "Debug")
            add_compile_options(/Od /Zi)
        endif()
    else()
        # MinGW
        add_compile_options(-Wall -Wextra)
        
        if(CMAKE_BUILD_TYPE STREQUAL "Release")
            add_compile_options(-O3 -DNDEBUG)
        elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
            add_compile_options(-O2 -g)
        elseif(CMAKE_BUILD_TYPE STREQUAL "Debug")
            add_compile_options(-O0 -g)
        endif()
    endif()
endfunction()

# macOS toolchain
function(setup_macos_toolchain)
    set(CMAKE_SYSTEM_NAME Darwin)
    
    # Use ccache if available
    find_program(CCACHE_PROGRAM ccache)
    if(CCACHE_PROGRAM)
        set(CMAKE_C_COMPILER_LAUNCHER ${CCACHE_PROGRAM})
        set(CMAKE_CXX_COMPILER_LAUNCHER ${CCACHE_PROGRAM})
    endif()
    
    # Enable all warnings
    add_compile_options(-Wall -Wextra -Wpedantic)
    
    # Platform-specific settings
    set(CMAKE_MACOSX_RPATH ON)
    set(CMAKE_INSTALL_RPATH "@executable_path/../lib")
    
    # Optimizations
    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        add_compile_options(-O3 -DNDEBUG)
    elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
        add_compile_options(-O2 -g)
    elseif(CMAKE_BUILD_TYPE STREQUAL "Debug")
        add_compile_options(-O0 -g)
    endif()
endfunction()

# Cross-platform setup
function(setup_platform_toolchain)
    if(ANDROID)
        setup_android_toolchain()
    elseif(APPLE)
        setup_macos_toolchain()
    elseif(WIN32)
        setup_windows_toolchain()
    elseif(UNIX AND NOT APPLE)
        setup_linux_toolchain()
    endif()
    
    # Set output directory based on platform and build type
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin/${CMAKE_BUILD_TYPE})
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib/${CMAKE_BUILD_TYPE})
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib/${CMAKE_BUILD_TYPE})
endfunction()
