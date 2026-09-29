include_guard(GLOBAL)

function(rexglue_prepare_switch_sdl output_var)
    set(_source "${REXGLUE_ROOT}/thirdparty/sdl3")
    set(_base_patch "${REXGLUE_ROOT}/switch/patches/sdl-dusklight-switch.patch")
    set(_adapt_patch "${REXGLUE_ROOT}/switch/patches/sdl-dusklight-melee-nx.patch")
    set(_expected_revision "8e37db5e797b6167f3a00d697d816a684bd259c7")

    find_program(_git_executable git REQUIRED)
    execute_process(
        COMMAND "${_git_executable}" -C "${_source}" rev-parse HEAD
        OUTPUT_VARIABLE _revision OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE _git_result)
    if(NOT _git_result EQUAL 0 OR NOT _revision STREQUAL _expected_revision)
        message(FATAL_ERROR
            "Switch SDL requires the pinned release-3.4.10 submodule "
            "(${_expected_revision}). Run git submodule update --init.")
    endif()

    file(SHA256 "${_base_patch}" _base_hash)
    file(SHA256 "${_adapt_patch}" _adapt_hash)
    string(SHA256 _identity "sdl-build-copy-v2:${_revision}:${_base_hash}:${_adapt_hash}")
    string(SUBSTRING "${_identity}" 0 12 _short_identity)
    set(_destination "${CMAKE_CURRENT_BINARY_DIR}/switch-sdl-${_short_identity}")
    set(_stamp "${_destination}/.rexglue-switch-sdl-stamp")

    if(NOT EXISTS "${_stamp}")
        # This path is formed only under CMake's own binary directory.
        file(REMOVE_RECURSE "${_destination}")
        file(MAKE_DIRECTORY "${_destination}")
        set(_archive "${CMAKE_CURRENT_BINARY_DIR}/switch-sdl-${_short_identity}.tar")
        execute_process(
            COMMAND "${_git_executable}" -C "${_source}" archive --format=tar
                "--output=${_archive}" HEAD
            RESULT_VARIABLE _archive_result)
        if(NOT _archive_result EQUAL 0)
            message(FATAL_ERROR "Could not archive the pinned SDL source")
        endif()
        file(ARCHIVE_EXTRACT INPUT "${_archive}" DESTINATION "${_destination}")
        # Give git apply a repository rooted at the build copy. Without this,
        # git discovers the parent SDK repository and silently skips patch paths.
        execute_process(
            COMMAND "${_git_executable}" init --quiet
            WORKING_DIRECTORY "${_destination}"
            RESULT_VARIABLE _init_result)
        if(NOT _init_result EQUAL 0)
            message(FATAL_ERROR "Could not initialize the build-local SDL patch tree")
        endif()
        foreach(_patch IN ITEMS "${_base_patch}" "${_adapt_patch}")
            execute_process(
                COMMAND "${_git_executable}" apply --recount "${_patch}"
                WORKING_DIRECTORY "${_destination}"
                RESULT_VARIABLE _patch_result)
            if(NOT _patch_result EQUAL 0)
                message(FATAL_ERROR "Switch SDL patch failed: ${_patch}")
            endif()
        endforeach()
        if(NOT EXISTS "${_destination}/src/video/switch/SDL_switchvideo.c")
            message(FATAL_ERROR "Switch SDL patch stack did not create the video backend")
        endif()
        file(WRITE "${_stamp}" "${_identity}\n")
        file(REMOVE "${_archive}")
    endif()

    set(${output_var} "${_destination}" PARENT_SCOPE)
endfunction()
