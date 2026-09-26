include_guard(GLOBAL)

function(rexglue_prepare_switch_ffmpeg output_var)
    if(NOT DEFINED ENV{DEVKITPRO})
        message(FATAL_ERROR "Switch FFmpeg needs DEVKITPRO set to the devkitPro root")
    endif()

    set(_source "${REXGLUE_ROOT}/thirdparty/FFmpeg")
    find_program(_git git REQUIRED)
    find_program(_bash bash REQUIRED)
    find_program(_make make REQUIRED)
    execute_process(COMMAND "${_git}" -C "${_source}" rev-parse HEAD
        OUTPUT_VARIABLE _revision OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE _git_result)
    if(NOT _git_result EQUAL 0)
        message(FATAL_ERROR "Switch FFmpeg requires the initialized FFmpeg submodule")
    endif()

    string(SHA256 _identity "switch-ffmpeg-none-v1:${_revision}:${CMAKE_C_COMPILER_VERSION}")
    string(SUBSTRING "${_identity}" 0 12 _short_identity)
    set(_destination "${CMAKE_CURRENT_BINARY_DIR}/switch-ffmpeg-${_short_identity}")
    set(_stamp "${_destination}/.rexglue-switch-ffmpeg-stamp")
    set(_archive "${CMAKE_CURRENT_BINARY_DIR}/switch-ffmpeg-${_short_identity}.tar")
    set(_devkitpro "$ENV{DEVKITPRO}")
    get_filename_component(_compiler_dir "${CMAKE_C_COMPILER}" DIRECTORY)
    set(_cross_prefix "${_compiler_dir}/aarch64-none-elf-")

    if(NOT EXISTS "${_stamp}")
        # Only remove the generated copy directly beneath this binary directory.
        file(REMOVE_RECURSE "${_destination}")
        file(MAKE_DIRECTORY "${_destination}")
        execute_process(COMMAND "${_git}" -C "${_source}" archive --format=tar
                "--output=${_archive}" HEAD
            RESULT_VARIABLE _archive_result)
        if(NOT _archive_result EQUAL 0)
            message(FATAL_ERROR "Could not archive the pinned FFmpeg source")
        endif()
        file(ARCHIVE_EXTRACT INPUT "${_archive}" DESTINATION "${_destination}")
        execute_process(
            COMMAND "${_bash}" ./configure
                --enable-cross-compile
                "--cross-prefix=${_cross_prefix}"
                --arch=aarch64 --cpu=cortex-a57 --target-os=none
                --enable-pic --enable-static --disable-shared
                --disable-programs --disable-doc --disable-autodetect
                --disable-network --disable-debug --disable-everything
                --enable-avcodec --enable-avutil --enable-decoder=xmaframes
                "--extra-cflags=-D__SWITCH__ -I${_devkitpro}/libnx/include -I${_devkitpro}/portlibs/switch/include"
                "--extra-ldflags=-L${_devkitpro}/libnx/lib -L${_devkitpro}/portlibs/switch/lib -specs=${_devkitpro}/libnx/switch.specs"
            WORKING_DIRECTORY "${_destination}"
            RESULT_VARIABLE _configure_result
            OUTPUT_FILE "${_destination}/rexglue-configure.log"
            ERROR_FILE "${_destination}/rexglue-configure.err")
        if(NOT _configure_result EQUAL 0)
            message(FATAL_ERROR
                "Switch FFmpeg configure failed; see ${_destination}/rexglue-configure.err")
        endif()
        file(WRITE "${_stamp}" "${_identity}\n")
        file(REMOVE "${_archive}")
    endif()

    set(_util "${_destination}/libavutil/libavutil.a")
    set(_codec "${_destination}/libavcodec/libavcodec.a")
    add_custom_command(OUTPUT "${_util}" "${_codec}"
        COMMAND "${_make}" -j4 libavutil/libavutil.a libavcodec/libavcodec.a
        WORKING_DIRECTORY "${_destination}"
        COMMENT "Building minimal Switch FFmpeg XMA decoder"
        VERBATIM)
    add_custom_target(rexglue_switch_ffmpeg_build DEPENDS "${_util}" "${_codec}")

    add_library(libavutil STATIC IMPORTED GLOBAL)
    set_target_properties(libavutil PROPERTIES
        IMPORTED_LOCATION "${_util}"
        INTERFACE_INCLUDE_DIRECTORIES "${_destination}")
    add_dependencies(libavutil rexglue_switch_ffmpeg_build)

    add_library(libavcodec STATIC IMPORTED GLOBAL)
    set_target_properties(libavcodec PROPERTIES
        IMPORTED_LOCATION "${_codec}"
        INTERFACE_INCLUDE_DIRECTORIES "${_destination}")
    target_link_libraries(libavcodec INTERFACE libavutil)
    add_dependencies(libavcodec rexglue_switch_ffmpeg_build)
    set(${output_var} "${_destination}" PARENT_SCOPE)
endfunction()
