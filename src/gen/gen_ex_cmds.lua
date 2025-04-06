local includedir = arg[1]
local autodir = arg[2]

-- Will generate files ex_cmds_enum.generated.h with cmdidx_T enum
-- and ex_cmds_defs.generated.h with main Ex commands definitions.

local enumfname = includedir .. '/ex_cmds_enum.generated.h'
local defsfname = autodir .. '/ex_cmds_defs.generated.h'

local enumfile = io.open(enumfname, 'w')
local defsfile = io.open(defsfname, 'w')

local bit = require 'bit'
local ex_cmds = require('nvim.ex_cmds')
local defs = ex_cmds.cmds
local flags = ex_cmds.flags

local byte_a = string.byte('a')
local byte_z = string.byte('z')
local a_to_z = byte_z - byte_a + 1

-- Table giving the index of the first command in cmdnames[] to lookup
-- based on the first letter of a command.
local cmdidxs1_out = string.format(
  [[
static const uint16_t cmdidxs1[%u] = {
]],
  a_to_z
)
-- Table giving the index of the first command in cmdnames[] to lookup
-- based on the first 2 letters of a command.
-- Values in cmdidxs2[c1][c2] are relative to cmdidxs1[c1] so that they
-- fit in a byte.
local cmdidxs2_out = string.format(
  [[
static const uint8_t cmdidxs2[%u][%u] = {
  /*           a   b   c   d   e   f   g   h   i   j   k   l   m   n   o   p   q   r   s   t   u   v   w   x   y   z */
]],
  a_to_z,
  a_to_z
)

enumfile:write([[
// IWYU pragma: private, include "nvim/ex_cmds_defs.h"

typedef enum CMD_index {
]])
defsfile:write(string.format(
  [[
#include "nvim/arglist.h"
#include "nvim/autocmd.h"
#include "nvim/buffer.h"
#include "nvim/cmdhist.h"
#include "nvim/debugger.h"
#include "nvim/diff.h"
#include "nvim/digraph.h"
#include "nvim/eval.h"
#include "nvim/eval/userfunc.h"
#include "nvim/eval/vars.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_session.h"
#include "nvim/help.h"
#include "nvim/indent.h"
#include "nvim/lua/executor.h"
#include "nvim/lua/secure.h"
#include "nvim/mapping.h"
#include "nvim/mark.h"
#include "nvim/match.h"
#include "nvim/menu.h"
#include "nvim/message.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/os/lang.h"
#include "nvim/profile.h"
#include "nvim/quickfix.h"
#include "nvim/runtime.h"
#include "nvim/sign.h"
#include "nvim/spell.h"
#include "nvim/spellfile.h"
#include "nvim/syntax.h"
#include "nvim/undo.h"
#include "nvim/usercmd.h"
#include "nvim/version.h"

static const int command_count = %u;
static CommandDefinition cmdnames[%u] = {
]],
  #defs,
  #defs
))
local cmds, cmdidxs1, cmdidxs2 = {}, {}, {}
for _, cmd in ipairs(defs) do
  if bit.band(cmd.flags, flags.RANGE) == flags.RANGE then
    assert(
      cmd.addr_type ~= 'ADDR_NONE',
      string.format('ex_cmds.lua:%s: Using RANGE with ADDR_NONE\n', cmd.command)
    )
  else
    assert(
      cmd.addr_type == 'ADDR_NONE',
      string.format('ex_cmds.lua:%s: Missing ADDR_NONE\n', cmd.command)
    )
  end
  if bit.band(cmd.flags, flags.DFLALL) == flags.DFLALL then
    assert(
      cmd.addr_type ~= 'ADDR_OTHER' and cmd.addr_type ~= 'ADDR_NONE',
      string.format('ex_cmds.lua:%s: Missing misplaced DFLALL\n', cmd.command)
    )
  end
  if bit.band(cmd.flags, flags.PREVIEW) == flags.PREVIEW then
    assert(
      cmd.preview_func ~= nil,
      string.format('ex_cmds.lua:%s: Missing preview_func\n', cmd.command)
    )
  end
  local enumname = cmd.enum or ('CMD_' .. cmd.command)
  local byte_cmd = cmd.command:sub(1, 1):byte()
  if byte_a <= byte_cmd and byte_cmd <= byte_z then
    table.insert(cmds, cmd.command)
  end
  local preview_func
  if cmd.preview_func then
    preview_func = string.format('&%s', cmd.preview_func)
  else
    preview_func = 'NULL'
  end
  enumfile:write('  ' .. enumname .. ',\n')
  defsfile:write(string.format(
    [[
  [%s] = {
    .cmd_name = "%s",
    .cmd_func = (ex_func_T)&%s,
    .cmd_preview_func = %s,
    .cmd_argt = %uL,
    .cmd_addr_type = %s
  },
]],
    enumname,
    cmd.command,
    cmd.func,
    preview_func,
    cmd.flags,
    cmd.addr_type
  ))
end
for i = #cmds, 1, -1 do
  local cmd = cmds[i]
  -- First and second characters of the command
  local c1 = cmd:sub(1, 1)
  cmdidxs1[c1] = i - 1
  if cmd:len() >= 2 then
    local c2 = cmd:sub(2, 2)
    local byte_c2 = string.byte(c2)
    if byte_a <= byte_c2 and byte_c2 <= byte_z then
      if not cmdidxs2[c1] then
        cmdidxs2[c1] = {}
      end
      cmdidxs2[c1][c2] = i - 1
    end
  end
end
for i = byte_a, byte_z do
  local c1 = string.char(i)
  cmdidxs1_out = cmdidxs1_out .. '  /*  ' .. c1 .. '  */ ' .. cmdidxs1[c1] .. ',\n'
  cmdidxs2_out = cmdidxs2_out .. '  /*  ' .. c1 .. '  */ {'
  for j = byte_a, byte_z do
    local c2 = string.char(j)
    cmdidxs2_out = cmdidxs2_out
      .. ((cmdidxs2[c1] and cmdidxs2[c1][c2]) and string.format(
        '%3d',
        cmdidxs2[c1][c2] - cmdidxs1[c1]
      ) or '  0')
      .. ','
  end
  cmdidxs2_out = cmdidxs2_out .. ' },\n'
end
enumfile:write([[
  CMD_SIZE,
  CMD_USER = -1,
  CMD_USER_BUF = -2
} cmdidx_T;
]])
defsfile:write(string.format(
  [[
};
%s};
%s};
]],
  cmdidxs1_out,
  cmdidxs2_out
))
