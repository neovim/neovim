// Lua bindings for vim.op (Cancelable Operations)

#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
#include <string.h>

#include "nvim/api/ops.h"
#include "nvim/memory.h"

#define OPS_USERDATA_NAME "nvim_operation"

static Operation *op_lua_get(lua_State *lstate, int idx)
{
  return *(Operation **)luaL_checkudata(lstate, idx, OPS_USERDATA_NAME);
}

static int op_lua_gc(lua_State *lstate)
{
  Operation *op = op_lua_get(lstate, 1);
  if (op) {
    op_release(op);
  }
  return 0;
}

static int op_lua_title(lua_State *lstate)
{
  Operation *op = op_lua_get(lstate, 1);
  lua_pushstring(lstate, op_title(op));
  return 1;
}

static int op_lua_state(lua_State *lstate)
{
  Operation *op = op_lua_get(lstate, 1);
  const char *state_name = NULL;

  switch (op_state(op)) {
  case OP_RUNNING:
    state_name = "running";
    break;
  case OP_FINISHED:
    state_name = "finished";
    break;
  case OP_CANCELED:
    state_name = "canceled";
    break;
  case OP_FAILED:
    state_name = "failed";
    break;
  }

  lua_pushstring(lstate, state_name);
  return 1;
}

static int op_lua_cancel(lua_State *lstate)
{
  Operation *op = op_lua_get(lstate, 1);
  op_cancel(op);
  return 0;
}

static int op_lua_finish(lua_State *lstate)
{
  Operation *op = op_lua_get(lstate, 1);
  op_finish(op, (Object)OBJECT_INIT);
  return 0;
}

static int op_lua_fail(lua_State *lstate)
{
  Operation *op = op_lua_get(lstate, 1);
  op_fail(op, (Object)OBJECT_INIT);
  return 0;
}

static int op_lua_progress(lua_State *lstate)
{
  Operation *op = op_lua_get(lstate, 1);

  if (lua_gettop(lstate) >= 2) {
    // Set progress
    lua_Number progress = luaL_checknumber(lstate, 2);
    op_set_progress(op, (float)progress);
    return 0;
  }

  // Get progress
  if (!op_has_progress(op)) {
    lua_pushnil(lstate);
  } else {
    lua_pushnumber(lstate, (lua_Number)op_progress(op));
  }
  return 1;
}

static int op_lua_result(lua_State *lstate)
{
  Operation *op = op_lua_get(lstate, 1);
  lua_pushnil(lstate);
  return 1;
}

static int op_lua_error(lua_State *lstate)
{
  Operation *op = op_lua_get(lstate, 1);
  lua_pushnil(lstate);
  return 1;
}

static int op_lua_is_canceled(lua_State *lstate)
{
  Operation *op = op_lua_get(lstate, 1);
  lua_pushboolean(lstate, op_is_canceled(op) ? 1 : 0);
  return 1;
}

static void op_lua_push_userdata(lua_State *lstate, Operation *op)
{
  if (!op) {
    lua_pushnil(lstate);
    return;
  }

  Operation **ud = (Operation **)lua_newuserdata(lstate, sizeof(Operation *));
  *ud = op;
  op_retain(op);

  luaL_getmetatable(lstate, OPS_USERDATA_NAME);
  lua_setmetatable(lstate, -2);
}

static int ops_lua_start(lua_State *lstate)
{
  luaL_checktype(lstate, 1, LUA_TTABLE);
  lua_getfield(lstate, 1, "title");
  const char *title = luaL_checkstring(lstate, -1);
  lua_pop(lstate, 1);

  Operation *op = op_create(title);
  op_lua_push_userdata(lstate, op);
  op_release(op);

  return 1;
}

static int ops_lua_list(lua_State *lstate)
{
  Operation **ops = NULL;
  size_t count = op_list(&ops);

  lua_createtable(lstate, (int)count, 0);

  for (size_t i = 0; i < count; i++) {
    op_lua_push_userdata(lstate, ops[i]);
    lua_rawseti(lstate, -2, (int)(i + 1));
    op_release(ops[i]);
  }

  xfree(ops);
  return 1;
}

static const luaL_Reg op_lua_methods[] = {
  { "title", op_lua_title },
  { "state", op_lua_state },
  { "cancel", op_lua_cancel },
  { "finish", op_lua_finish },
  { "fail", op_lua_fail },
  { "progress", op_lua_progress },
  { "result", op_lua_result },
  { "error", op_lua_error },
  { "is_canceled", op_lua_is_canceled },
  { "__gc", op_lua_gc },
  { NULL, NULL },
};

static const luaL_Reg ops_lua_module[] = {
  { "start", ops_lua_start },
  { "list", ops_lua_list },
  { NULL, NULL },
};

int luaopen_vim_op(lua_State *lstate)
{
  luaL_newmetatable(lstate, OPS_USERDATA_NAME);
  lua_pushstring(lstate, "__index");
  lua_pushvalue(lstate, -2);
  lua_settable(lstate, -3);
  luaL_setfuncs(lstate, op_lua_methods, 0);
  lua_pop(lstate, 1);

  lua_newtable(lstate);
  luaL_setfuncs(lstate, ops_lua_module, 0);

  return 1;
}
