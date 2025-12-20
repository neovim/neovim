#pragma once

#include <stddef.h>  // IWYU pragma: keep
#include <stdint.h>

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/cmdexpand_defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/garray_defs.h"
#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"

typedef struct {
  char *uc_name;             ///< The command name
  uint32_t uc_argt;          ///< The argument type
  char *uc_rep;              ///< The command's replacement string
  int64_t uc_def;            ///< The default value for a range/count
  int uc_compl;              ///< completion type
  cmd_addr_T uc_addr_type;   ///< The command's address type
  addr_mode_T uc_addr_mode;  ///< operation mode if address is a ADDR_POSITION
  sctx_T uc_script_ctx;      ///< SCTX where the command was defined
  char *uc_compl_arg;        ///< completion argument if any
  LuaRef uc_compl_luaref;    ///< Reference to Lua completion function
  LuaRef uc_preview_luaref;  ///< Reference to Lua preview function
  LuaRef uc_luaref;          ///< Reference to Lua function
} ucmd_T;

enum { UC_BUFFER = 1, };  ///< -buffer: local to current buffer

extern garray_T ucmds;

#define USER_CMD(i) (&((ucmd_T *)(ucmds.ga_data))[i])
#define USER_CMD_GA(gap, i) (&((ucmd_T *)((gap)->ga_data))[i])

#include "usercmd.h.generated.h"
