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
