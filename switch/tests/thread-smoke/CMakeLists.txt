add_executable(rexglue_switch_thread_smoke
    main.cpp
    ${REXGLUE_ROOT}/src/core/threading_switch.cpp)
target_include_directories(rexglue_switch_thread_smoke PRIVATE ${REXGLUE_ROOT}/include)
target_link_libraries(rexglue_switch_thread_smoke PRIVATE
    fmt::fmt spdlog::spdlog simde tomlplusplus)
target_compile_features(rexglue_switch_thread_smoke PRIVATE cxx_std_23)
rexglue_add_switch_nro(rexglue_switch_thread_smoke
    TITLE "ReXGlue NX Thread Test"
    AUTHOR "ReXGlue NX"
    VERSION "0.1.0")
