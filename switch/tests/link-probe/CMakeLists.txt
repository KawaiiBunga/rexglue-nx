# Builds the real SDK host link graph without proprietary title code.
# This target is not a runnable game: the creator deliberately returns null.
add_executable(rexglue_switch_link_probe main.cpp)
target_link_libraries(rexglue_switch_link_probe PRIVATE rex::runtime)
rexglue_configure_target(rexglue_switch_link_probe GPU_PLUGINS xenos)
