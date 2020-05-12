#
# Functions to help checking for a Lua interpreter
#

# Check if a module is available in Lua
function(check_lua_module LUA_PRG_PATH MODULE RESULT_VAR)
  execute_process(COMMAND ${LUA_PRG_PATH} -l "${MODULE}" -e ""
    RESULT_VARIABLE module_missing)
  if(module_missing)
    set(${RESULT_VAR} False PARENT_SCOPE)
  else()
    set(${RESULT_VAR} True PARENT_SCOPE)
  endif()
endfunction()

# Check Lua interpreter for dependencies
function(check_lua_deps LUA_PRG_PATH MODULES RESULT_VAR)
  # Check if the lua interpreter at the given path
  # satisfies all Neovim dependencies
  message(STATUS "Checking Lua interpreter: ${LUA_PRG_PATH}")
  if(NOT EXISTS ${LUA_PRG_PATH})
    message(STATUS
      "[${LUA_PRG_PATH}] file not found")
  endif()

  foreach(module ${MODULES})
    check_lua_module(${LUA_PRG_PATH} ${module} has_module)
    if(NOT has_module)
      message(STATUS
        "[${LUA_PRG_PATH}] The '${module}' lua package is required for building Neovim")
      set(${RESULT_VAR} False PARENT_SCOPE)
      return()
    endif()
  endforeach()

  set(${RESULT_VAR} True PARENT_SCOPE)
endfunction()
