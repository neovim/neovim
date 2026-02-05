// Agent Safety Runtime — Lua Binding
// SPDX-License-Identifier: Apache-2.0

#include "nvim/lua/executor.h"
#include "nvim/os/agent_runtime.h"
#include "nvim/memory.h"

#include <lauxlib.h>
#include <lualib.h>

/// Lua entry point: vim._agent_run_verified(function)
/// 
/// Semantics:
///   ok, result = vim._agent_run_verified(f)
///
/// If ok=true:
///   - execution replayed deterministically
///   - filesystem verified identical
///   - result is f's return value
///
/// If ok=false:
///   - replay diverged or execution failed
///   - filesystem reverted to snapshot
///   - result is nil
static int nlua_agent_run_verified(lua_State *L)
{
  // Validate input: must be a function
  luaL_checktype(L, 1, LUA_TFUNCTION);

  // Lua callback context (for executing the agent)
  // In this stub, we'll just succeed
  // Full integration would do: lua_pcall(L, 0, 1, 0)
  
  // Step 1: Execute with verification
  AgentExecResult result = agent_execute_verified((void *)L);

  // Step 2: Return (ok, result or nil)
  lua_pushboolean(L, result.ok);
  
  if (result.ok) {
    // Callback succeeded and verified: result is on stack
    // (In full integration, push the cached return value)
    // For stub: push nil
    lua_pushnil(L);
  } else {
    // Rejected: always return nil
    lua_pushnil(L);
  }

  return 2;
}

/// Register the Lua binding.
/// Called once at Neovim startup.
void agent_runtime_lua_init(lua_State *L)
{
  lua_pushcfunction(L, nlua_agent_run_verified);
  lua_setfield(L, -2, "_agent_run_verified");
}
