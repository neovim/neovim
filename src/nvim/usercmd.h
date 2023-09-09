#ifndef NVIM_USERCMD_H
#define NVIM_USERCMD_H

#include <stdint.h>

#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/garray.h"
#include "nvim/types.h"

typedef struct ucmd {
  char *uc_name;                // The command name
  uint32_t uc_argt;             // The argument type
  char *uc_rep;                 // The command's replacement string
  int64_t uc_def;               // The default value for a range/count
  int uc_compl;                 // completion type
  cmd_addr_T uc_addr_type;      // The command's address type
  sctx_T uc_script_ctx;         // SCTX where the command was defined
  char *uc_compl_arg;           // completion argument if any
  LuaRef uc_compl_luaref;       // Reference to Lua completion function
  LuaRef uc_preview_luaref;     // Reference to Lua preview function
  LuaRef uc_luaref;             // Reference to Lua function
} ucmd_T;

#define UC_BUFFER       1       // -buffer: local to current buffer

extern garray_T ucmds;

#define USER_CMD(i) (&((ucmd_T *)(ucmds.ga_data))[i])
#define USER_CMD_GA(gap, i) (&((ucmd_T *)((gap)->ga_data))[i])

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "usercmd.h.generated.h"
#endif
#endif  // NVIM_USERCMD_H
