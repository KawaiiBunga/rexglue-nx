# ReXGlue SDK - Xbox 360 Recompilation Toolkit
cmake_minimum_required(VERSION 3.25)

if(APPLE)
    set(REXGLUE_LANGUAGES C CXX OBJC OBJCXX)
else()
    set(REXGLUE_LANGUAGES C CXX)
endif()

project(ReXGlue
    VERSION 0.10.0
    LANGUAGES ${REXGLUE_LANGUAGES}
    DESCRIPTION "Xbox 360 Recompilation SDK"
)
# Floor only: bump MAJOR.MINOR for API changes. Patch is derived from git tags
# in cmake/rex_version.cmake. See docs/RELEASING.md.

#==========================================================
# Build Options
#==========================================================
option(REXGLUE_BUILD_TESTS       "Build PPC instruction and unit tests" OFF)
option(REXGLUE_BUILD_SWITCH_LINK_PROBE "Link the Switch SDK host without game code" OFF)
option(REXGLUE_BUILD_SWITCH_THREAD_SMOKE "Build a libnx NRO testing core thread primitives" OFF)
option(REXGLUE_ENABLE_SANITIZERS "Enable UndefinedBehaviorSanitizer" OFF)
option(REXGLUE_ENABLE_FIDELITYFX "Enable optional AMD FidelityFX integration (experimental)" OFF)
option(REXGLUE_ENABLE_TRACY                "Enable Tracy profiler integration" ON)
option(REXGLUE_ENABLE_PERF_COUNTERS        "Enable lightweight perf counter registry and overlay" ON)
# A title project can consume this SDK with add_subdirectory() under the
# devkitPro Switch toolchain without setting an extra platform option.
if(CMAKE_SYSTEM_NAME STREQUAL "NintendoSwitch")
    set(_rexglue_switch_default ON)
else()
    set(_rexglue_switch_default OFF)
endif()
option(REXGLUE_PLATFORM_SWITCH "Build the runtime for Nintendo Switch homebrew" ${_rexglue_switch_default})
if(REXGLUE_PLATFORM_SWITCH AND NOT CMAKE_SYSTEM_NAME STREQUAL "NintendoSwitch")
    message(FATAL_ERROR "The Switch runtime requires the devkitPro Switch toolchain")
endif()
# Propagate profiling defines globally (compiled out in Release)
if(REXGLUE_ENABLE_TRACY)
    add_compile_definitions($<$<NOT:$<CONFIG:Release>>:REXGLUE_ENABLE_PROFILING>)
endif()
if(REXGLUE_ENABLE_PERF_COUNTERS)
    add_compile_definitions($<$<NOT:$<CONFIG:Release>>:REXGLUE_ENABLE_PERF_COUNTERS>)
endif()

# Graphics backend selection
# D3D12: Windows only, ON by default.
# Vulkan: Cross-platform, ON by default on Linux, OFF by default on Windows.
if(REXGLUE_PLATFORM_SWITCH)
    set(REXGLUE_USE_D3D12 OFF)
    option(REXGLUE_USE_VULKAN "Enable Vulkan graphics backend" ON)
elseif(WIN32)
    option(REXGLUE_USE_D3D12  "Enable D3D12 graphics backend" ON)
    option(REXGLUE_USE_VULKAN "Enable Vulkan graphics backend" OFF)
else()
    set(REXGLUE_USE_D3D12 OFF)
    option(REXGLUE_USE_VULKAN "Enable Vulkan graphics backend" ON)
endif()

if(NOT REXGLUE_USE_D3D12 AND NOT REXGLUE_USE_VULKAN)
    message(FATAL_ERROR "At least one graphics backend must be enabled (REXGLUE_USE_D3D12 or REXGLUE_USE_VULKAN)")
endif()

if (REXGLUE_ENABLE_FIDELITYFX AND
    NOT (REXGLUE_USE_VULKAN OR REXGLUE_USE_D3D12))
    message(FATAL_ERROR
        "REXGLUE_ENABLE_FIDELITYFX requires at least one graphics backend")
endif()

# Root of the SDK source tree
set(REXGLUE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}")
set(REXGLUE_SHARE_DIR "${REXGLUE_ROOT}/src/ui")

# SDK install support
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/rexglue_helpers.cmake)
if(REXGLUE_PLATFORM_SWITCH)
    include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/rexglue_switch_nro.cmake)
endif()

if(UNIX AND NOT APPLE)
    # Keep installed binaries self-contained by resolving shared libs relative
    # to the install prefix (for example, bin -> ../lib).
    set(CMAKE_BUILD_RPATH_USE_ORIGIN ON)
    list(APPEND CMAKE_INSTALL_RPATH
        "$ORIGIN"
        "$ORIGIN/../${CMAKE_INSTALL_LIBDIR}"
    )
    set(CMAKE_INSTALL_RPATH_USE_LINK_PATH ON)
elseif(APPLE)
    # Use loader-relative install names on macOS so installed binaries remain
    # self-contained within the install prefix.
    list(APPEND CMAKE_INSTALL_RPATH
        "@loader_path"
        "@loader_path/../${CMAKE_INSTALL_LIBDIR}"
    )
    set(CMAKE_INSTALL_RPATH_USE_LINK_PATH ON)
endif()

# Desktop builds require Clang. devkitA64 currently provides GCC for Switch.
if(REXGLUE_PLATFORM_SWITCH)
    if(NOT CMAKE_CXX_COMPILER_ID MATCHES "^(GNU|Clang)$")
        message(FATAL_ERROR "Switch builds require devkitA64 GCC or AArch64 Clang")
    endif()
elseif(NOT CMAKE_CXX_COMPILER_ID MATCHES "^(Apple)?Clang$")
    message(FATAL_ERROR "ReXGlue requires the Clang compiler (LLVM Clang or AppleClang). Please set CMAKE_CXX_COMPILER to clang++")
endif()

if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "18.0")
        message(FATAL_ERROR "ReXGlue requires Clang 18 or newer (found ${CMAKE_CXX_COMPILER_VERSION})")
    endif()
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
    if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "16.0")
        message(FATAL_ERROR "ReXGlue requires AppleClang 16 or newer / Xcode 16+ for C++23 support (found ${CMAKE_CXX_COMPILER_VERSION})")
    endif()
endif()

# Enforce x64 architecture
if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
    message(FATAL_ERROR "ReXGlue only supports 64‑bit architectures (x86_64 or ARM64)")
endif()

# Set C++23 standard
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_DEBUG_POSTFIX d)
set(CMAKE_RELWITHDEBINFO_POSTFIX rd)

# CMAKE_<CONFIG>_POSTFIX seeds libraries only, so without this every config of an
# executable installs over the last one.
function(rex_config_postfix target)
    set_target_properties(${target} PROPERTIES
        DEBUG_POSTFIX "${CMAKE_DEBUG_POSTFIX}"
        RELWITHDEBINFO_POSTFIX "${CMAKE_RELWITHDEBINFO_POSTFIX}")
endfunction()

if(NOT WIN32)
    # Use appropriate code model based on architecture
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "AMD64|x86_64" AND NOT APPLE)
        # Large code model on Linux x86_64 for linking with very large recompiled executables (35MB+).
        # macOS uses small: the ld64 linker on macOS 15+ rejects text relocations produced
        # by -mcmodel=large, and macOS maps binaries in the low address space so ±2GB is sufficient.
        add_compile_options(-mcmodel=large)
    else()
        add_compile_options(-mcmodel=small)
    endif()
    # Position-independent code for all targets
    set(CMAKE_POSITION_INDEPENDENT_CODE ON)
endif()

# Global compile options
add_compile_options(
    -fno-strict-aliasing
    $<$<NOT:$<CXX_COMPILER_ID:GNU>>:-ffp-model=strict>
    $<$<CXX_COMPILER_ID:GNU>:-frounding-math>
    $<$<CXX_COMPILER_ID:GNU>:-ffp-contract=off>
    $<$<CONFIG:DEBUG>:-g>
    $<$<CONFIG:DEBUG>:-O0>
    $<$<CONFIG:RELEASE>:-O3>
    $<$<CONFIG:RELEASE>:-DNDEBUG>
    $<$<COMPILE_LANGUAGE:CXX>:-fno-char8_t>
)

# Platform detection (supports AMD64 and ARM64)
set(REX_TARGET_PROCESSOR "${CMAKE_SYSTEM_PROCESSOR}")
if(APPLE AND CMAKE_OSX_ARCHITECTURES)
    list(LENGTH CMAKE_OSX_ARCHITECTURES REX_OSX_ARCH_COUNT)
    if(REX_OSX_ARCH_COUNT GREATER 1)
        message(FATAL_ERROR "ReXGlue macOS presets expect a single CMAKE_OSX_ARCHITECTURES value")
    endif()
    list(GET CMAKE_OSX_ARCHITECTURES 0 REX_TARGET_PROCESSOR)
endif()

if(REXGLUE_PLATFORM_SWITCH)
    if(NOT REX_TARGET_PROCESSOR MATCHES "aarch64|ARM64|arm64")
        message(FATAL_ERROR "Switch builds require an AArch64 target")
    endif()
    set(REX_PLATFORM "switch-arm64")
    # newlib's tm has no tm_gmtoff; ask spdlog to omit that optional feature.
    add_compile_definitions(REX_PLATFORM_SWITCH=1 SPDLOG_NO_TZ_OFFSET
        VULKAN_HPP_ENABLE_DYNAMIC_LOADER_TOOL=0 _GNU_SOURCE)
elseif(WIN32)
    if(REX_TARGET_PROCESSOR MATCHES "AMD64|x86_64")
        set(REX_PLATFORM "win-amd64")
    elseif(REX_TARGET_PROCESSOR MATCHES "aarch64|ARM64|arm64")
        set(REX_PLATFORM "win-arm64")
    else()
        message(FATAL_ERROR "Unsupported Windows architecture: ${REX_TARGET_PROCESSOR}")
    endif()
    add_compile_definitions(REX_PLATFORM_WINDOWS=1)
elseif(UNIX AND NOT APPLE)
    if(REX_TARGET_PROCESSOR MATCHES "AMD64|x86_64")
        set(REX_PLATFORM "linux-amd64")
    elseif(REX_TARGET_PROCESSOR MATCHES "aarch64|ARM64|arm64")
        set(REX_PLATFORM "linux-arm64")
    else()
        set(REX_PLATFORM "linux-${REX_TARGET_PROCESSOR}")
    endif()
    add_compile_definitions(REX_PLATFORM_LINUX=1)
elseif(APPLE)
    if(REX_TARGET_PROCESSOR MATCHES "AMD64|x86_64")
        set(REX_PLATFORM "mac-amd64")
    elseif(REX_TARGET_PROCESSOR MATCHES "aarch64|ARM64|arm64")
        set(REX_PLATFORM "mac-arm64")
    else()
        set(REX_PLATFORM "mac-${REX_TARGET_PROCESSOR}")
    endif()
    add_compile_definitions(REX_PLATFORM_MAC=1)
else()
    message(FATAL_ERROR "Unsupported platform. ReXGlue supports Windows, Linux, and macOS only.")
endif()

# Build config as compile definition (multi-config generators don't know config at configure time)
add_compile_definitions(REXGLUE_BUILD_CONFIG="$<CONFIG>")

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/rex_pch.cmake)

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/rex_version.cmake)
rex_resolve_version(REXGLUE_FULL_VERSION
    FLOOR_MAJOR ${PROJECT_VERSION_MAJOR}
    FLOOR_MINOR ${PROJECT_VERSION_MINOR})

# Strip the -id trailer (if any) for the numeric-only version.
string(REGEX REPLACE "-.*$" "" REXGLUE_NUMERIC_VERSION "${REXGLUE_FULL_VERSION}")

# Parse up to 4 numeric components for consumers that want integer access.
string(REGEX MATCH "^([0-9]+)\\.([0-9]+)(\\.([0-9]+))?(\\.([0-9]+))?" _ "${REXGLUE_NUMERIC_VERSION}")
set(REXGLUE_DERIVED_MAJOR "${CMAKE_MATCH_1}")
set(REXGLUE_DERIVED_MINOR "${CMAKE_MATCH_2}")
if(CMAKE_MATCH_4)
    set(REXGLUE_DERIVED_PATCH "${CMAKE_MATCH_4}")
else()
    set(REXGLUE_DERIVED_PATCH "0")
endif()
if(CMAKE_MATCH_6)
    set(REXGLUE_DERIVED_TWEAK "${CMAKE_MATCH_6}")
else()
    set(REXGLUE_DERIVED_TWEAK "0")
endif()

set(REXGLUE_FLOOR_VERSION
    "${REXGLUE_DERIVED_MAJOR}.${REXGLUE_DERIVED_MINOR}.${REXGLUE_DERIVED_PATCH}")

rex_version_channel(REXGLUE_VERSION_CHANNEL VERSION "${REXGLUE_FULL_VERSION}")

# Generate version header -- must run after REX_PLATFORM is set
# Timestamp is set at configure time -- intentionally not updated on every rebuild
string(TIMESTAMP REXGLUE_BUILD_TIMESTAMP "%Y%m%d_%H%M")
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/include/rex/version.h.in
    ${CMAKE_CURRENT_BINARY_DIR}/include/rex/version.h
    @ONLY
)

# Keep Switch artifacts in the consumer's build tree when this SDK is a submodule.
# Desktop retains its existing source-tree layout for compatibility.
if(REXGLUE_PLATFORM_SWITCH)
    set(_rexglue_output_root "${CMAKE_CURRENT_BINARY_DIR}/out/${REX_PLATFORM}")
else()
    set(_rexglue_output_root "${REXGLUE_ROOT}/out/${REX_PLATFORM}")
endif()
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${_rexglue_output_root}")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${_rexglue_output_root}")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${_rexglue_output_root}")

# Sanitizer support for debugging memory corruption and undefined behavior
if(REXGLUE_ENABLE_SANITIZERS)
    message(STATUS "Enabling UndefinedBehaviorSanitizer (UBSan only - ASan conflicts with custom memory mapping)")
    # Note: ASan doesn't work well with the custom mmap at 0x100000000, so we only use UBSan
    add_compile_options(-fsanitize=undefined -fno-omit-frame-pointer -g)
    add_link_options(-fsanitize=undefined)
endif()

if(REXGLUE_BUILD_TESTS)
    list(APPEND CMAKE_MODULE_PATH "${REXGLUE_ROOT}/cmake")
    list(APPEND CMAKE_MODULE_PATH "${REXGLUE_ROOT}/thirdparty/catch2/extras")
endif()

# glslang generates headers with a host Python interpreter while CMake is
# otherwise cross-compiling. Look outside the target sysroot first. devkitPro
# MSYS2 on Windows may omit Windows Python from PATH, so check its standard
# per-user install directory without baking a developer path into this repo.
if(REXGLUE_PLATFORM_SWITCH AND NOT PYTHON_EXECUTABLE)
    find_program(_rexglue_host_python NAMES python3 python python.exe
        NO_CMAKE_FIND_ROOT_PATH)
    if(NOT _rexglue_host_python AND DEFINED ENV{LOCALAPPDATA})
        string(REPLACE "\\" "/" _rexglue_local_app_data "$ENV{LOCALAPPDATA}")
        if(_rexglue_local_app_data MATCHES "^[A-Za-z]:/")
            # MSYS paths use /c/... while LOCALAPPDATA is a Windows C:\ path.
            string(SUBSTRING "${_rexglue_local_app_data}" 0 1 _rexglue_drive)
            string(TOLOWER "${_rexglue_drive}" _rexglue_drive)
            string(SUBSTRING "${_rexglue_local_app_data}" 2 -1 _rexglue_path_tail)
            set(_rexglue_local_app_data "/${_rexglue_drive}${_rexglue_path_tail}")
        endif()
        file(GLOB _rexglue_windows_python
            "${_rexglue_local_app_data}/Programs/Python/Python*/python.exe")
        if(_rexglue_windows_python)
            list(SORT _rexglue_windows_python COMPARE NATURAL ORDER DESCENDING)
            list(GET _rexglue_windows_python 0 _rexglue_host_python)
        endif()
    endif()
    if(NOT _rexglue_host_python)
        message(FATAL_ERROR
            "Switch build needs host Python 3 for glslang. Install it or pass -DPYTHON_EXECUTABLE=<host python>.")
    endif()
    set(PYTHON_EXECUTABLE "${_rexglue_host_python}" CACHE FILEPATH
        "Host Python for build-time code generation")
endif()

# Third-party dependencies (vendored sources only)
add_subdirectory(thirdparty)

# Enable warnings after thirdparty
add_compile_options(
    -Wall
    -Wextra
)

include_directories(${REXGLUE_ROOT}/include)

add_subdirectory(src/core)
add_subdirectory(src/filesystem)
add_subdirectory(src/ui)
add_subdirectory(src/input)
add_subdirectory(src/audio)
add_subdirectory(src/graphics)
add_subdirectory(src/system)
add_subdirectory(src/kernel)
if(REXGLUE_PLATFORM_SWITCH AND REXGLUE_BUILD_SWITCH_LINK_PROBE AND PROJECT_IS_TOP_LEVEL)
    add_subdirectory(switch/tests/link-probe)
endif()
if(REXGLUE_PLATFORM_SWITCH AND REXGLUE_BUILD_SWITCH_THREAD_SMOKE AND PROJECT_IS_TOP_LEVEL)
    add_subdirectory(switch/tests/thread-smoke)
endif()
if(NOT REXGLUE_PLATFORM_SWITCH)
    # Code generation runs on the developer's PC. Never build those tools as
    # AArch64 NRO code or pull their dependencies into a title's cross build.
    add_subdirectory(src/codegen)
    add_subdirectory(src/rexglue)
endif()

# Add tests subdirectory if tests are enabled
if(REXGLUE_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

include(cmake/rexglue_link_audit.cmake)

# Print configuration summary
message(STATUS "===========================================")
message(STATUS "ReXGlue Configuration Summary:")
message(STATUS "  Version: ${REXGLUE_FULL_VERSION} (${REXGLUE_VERSION_CHANNEL})")
message(STATUS "  Platform: ${REX_PLATFORM}")
message(STATUS "  Compiler: ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
message(STATUS "  Configurations: ${CMAKE_CONFIGURATION_TYPES}")
message(STATUS "  Output Dir: ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
message(STATUS "  C++ Standard: C++${CMAKE_CXX_STANDARD}")
message(STATUS "  Graphics: D3D12=${REXGLUE_USE_D3D12} Vulkan=${REXGLUE_USE_VULKAN}")
message(STATUS "  FidelityFX: ${REXGLUE_ENABLE_FIDELITYFX}")
message(STATUS "  Tracy: ${REXGLUE_ENABLE_TRACY}")
message(STATUS "  Perf Counters: ${REXGLUE_ENABLE_PERF_COUNTERS}")
message(STATUS "===========================================")

# SDK install/export rules (skipped when consumed as a subdirectory)
if(PROJECT_IS_TOP_LEVEL)
    if(NOT REXGLUE_PLATFORM_SWITCH)
        include(cmake/rexglue_devenv.cmake)
        include(cmake/rexglue_install.cmake)
    endif()
else()
    # When consumed via add_subdirectory(), provide the same interface as find_package().
    # This sets REXGLUE_SHARE_DIR and makes rexglue_configure_target() available.
    set(REXGLUE_SHARE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/ui" PARENT_SCOPE)
    set(REXGLUE_SHARE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/ui")
    include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/rexglue_helpers.cmake)
endif()
