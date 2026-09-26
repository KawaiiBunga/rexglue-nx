include_guard(GLOBAL)

# Package a linked Switch game target. Keep the unstripped ELF for symbols;
# only the copy passed to elf2nro is stripped.
function(rexglue_add_switch_nro target_name)
    if(NOT REXGLUE_PLATFORM_SWITCH)
        message(FATAL_ERROR "rexglue_add_switch_nro requires REXGLUE_PLATFORM_SWITCH")
    endif()
    if(NOT TARGET ${target_name})
        message(FATAL_ERROR "Unknown Switch game target: ${target_name}")
    endif()

    cmake_parse_arguments(ARG "" "TITLE;AUTHOR;VERSION;ROMFS_DIR" "" ${ARGN})
    if(NOT ARG_TITLE OR NOT ARG_AUTHOR OR NOT ARG_VERSION)
        message(FATAL_ERROR
            "rexglue_add_switch_nro(${target_name}) requires TITLE, AUTHOR and VERSION")
    endif()

    find_program(_rex_nacptool NAMES nacptool REQUIRED
        HINTS "$ENV{DEVKITPRO}/tools/bin")
    find_program(_rex_elf2nro NAMES elf2nro REQUIRED
        HINTS "$ENV{DEVKITPRO}/tools/bin")
    if(NOT CMAKE_STRIP)
        message(FATAL_ERROR "The Switch toolchain must provide CMAKE_STRIP")
    endif()

    set(_nacp "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.nacp")
    set(_stripped "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.stripped.elf")
    set(_nro "$<TARGET_FILE_DIR:${target_name}>/${target_name}.nro")

    set(_romfs_args)
    if(ARG_ROMFS_DIR)
        if(NOT IS_DIRECTORY "${ARG_ROMFS_DIR}")
            message(FATAL_ERROR "ROMFS_DIR does not exist: ${ARG_ROMFS_DIR}")
        endif()
        list(APPEND _romfs_args "--romfsdir=${ARG_ROMFS_DIR}")
    endif()

    add_custom_command(TARGET ${target_name} POST_BUILD
        COMMAND "${_rex_nacptool}" --create
            "${ARG_TITLE}" "${ARG_AUTHOR}" "${ARG_VERSION}" "${_nacp}"
        COMMAND "${CMAKE_STRIP}" --strip-all -o "${_stripped}" "$<TARGET_FILE:${target_name}>"
        COMMAND "${_rex_elf2nro}" "${_stripped}" "${_nro}"
            "--nacp=${_nacp}" ${_romfs_args}
        BYPRODUCTS "${_nacp}" "${_stripped}"
        COMMENT "Packaging ${target_name}.nro"
        VERBATIM)
endfunction()
