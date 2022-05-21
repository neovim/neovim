add_subdirectory(includes)

# TODO:
# - specify *all* the luarocks requirements for tests (what about ffi?)
# - use impatient to make up for the (sizeable) overhead when running each test independently

#################################
########## test specs ###########
#################################

set(ENV{LC_ALL} "en_US.UTF-8")

if(POLICY CMP0012)
  # Handle CI=true, without dev warnings.
  cmake_policy(SET CMP0012 NEW)
endif()

set(NVIM_PRG $<TARGET_FILE:nvim>)

set(test_env)
list(
  APPEND test_env
  "LC_ALL=en_US.UTF-8"
  "NVIM_PRG=${NVIM_PRG}"
  "NEOVIM_BUILD_DIR=${PROJECT_BINARY_DIR}"
  "NEOVIM_SOURCE_DIR=${PROJECT_SOURCE_DIR}"
  "VIMRUNTIME=${PROJECT_SOURCE_DIR}/runtime"
  "NVIM_RPLUGIN_MANIFEST=${PROJECT_BINARY_DIR}/Xtest_rplugin_manifest"
  "LOG_DIR=${PROJECT_BINARY_DIR}/log"
  "TEST_SKIP_FRAGILE=ON"
  "SYSTEM_NAME=${CMAKE_HOST_SYSTEM_NAME}"
)

foreach(
  task
  api
  autocmd
  core
  editor
  exCmds
  lua
  options
  plugin
  provider
  shada
  terminal
  treesitter
  ui
  vimscript
)
  add_test(
    NAME ${task}_serial
    COMMAND ${BUSTED_PRG} --run=${task}
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
  )
  set_tests_properties(
    ${task}_serial
    PROPERTIES
    LABELS ${task}_serial
    ENVIRONMENT "${test_env}"
  )
endforeach()

# set_tests_properties(
#   terminal_serial
#   PROPERTIES
#   RUN_SERIAL ON
# )

if(NOT LUA_HAS_FFI)
  message(INFO "disabling test discovery: no Luajit FFI in ${LUA_PRG}")
  return()
endif()

# TODO: this currently doesn't work for test/unit because test/unit/helper.lua is loading all the tests instead
add_custom_target(
  generate-test-runners
  DEPENDS ${FUNCTIONALTEST_PREREQS}
  SOURCES ${PROJECT_SOURCE_DIR}/test/functional/api/autocmd_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/buffer_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/buffer_updates_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/command_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/extmark_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/highlight_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/keymap_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/menu_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/proc_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/server_notifications_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/server_requests_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/tabpage_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/ui_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/version_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/vim_spec.lua
  ${PROJECT_SOURCE_DIR}/test/functional/api/window_spec.lua
)

include(LuaBusted)

busted_discover_tests(
  generate-test-runners
  BUSTED_PRG ${BUSTED_PRG}
  WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
  LUA_PRG ${LUA_PRG}
  BUILD_DIR ${PROJECT_BINARY_DIR}
  EXTRA_ARGS -Xhelper IS_FUNCTIONAL_TEST --no-auto-insulate --no-lazy
  TEST_ENVIRONMENT ${test_env}
)
