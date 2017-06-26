local nvimsrcdir = arg[1]
local includedir = arg[2]
local autodir = arg[3]

if nvimsrcdir == '--help' then
  print ([[
Usage:
  lua genex_cmds.lua src/nvim build/include build/src/nvim/auto

Will generate files build/include/ex_cmds_enum.generated.h with cmdidx_T 
enum and build/src/nvim/auto/ex_cmds_defs.generated.h with main Ex commands 
definitions.
]])
  os.exit(0)
end

package.path = nvimsrcdir .. '/?.lua;' .. package.path

local enumfname = includedir .. '/ex_cmds_enum.generated.h'
local defsfname = autodir .. '/ex_cmds_defs.generated.h'

local enumfile = io.open(enumfname, 'w')
local defsfile = io.open(defsfname, 'w')

local defs = require('ex_cmds')
local lastchar = nil

local i
local cmd
local first = true
local prevfirstchar = nil

local byte_a = string.byte('a')
local byte_z = string.byte('z')

local cmdidxs = string.format([[
static const cmdidx_T cmdidxs[%u] = {
]], byte_z - byte_a + 2)

enumfile:write([[
typedef enum CMD_index {
]])
defsfile:write(string.format([[
static CommandDefinition cmdnames[%u] = {
]], #defs))
for i, cmd in ipairs(defs) do
  local enumname = cmd.enum or ('CMD_' .. cmd.command)
  firstchar = string.byte(cmd.command)
  if firstchar ~= prevfirstchar then
    if (not prevfirstchar
        or (byte_a <= firstchar      and firstchar     <= byte_z)
        or (byte_a <= prevfirstchar  and prevfirstchar <= byte_z)) then
      if not first then
        cmdidxs = cmdidxs .. ',\n'
      end
      cmdidxs = cmdidxs .. '  ' .. enumname
    end
    prevfirstchar = firstchar
  end
  if first then
    first = false
  else
    defsfile:write(',\n')
  end
  enumfile:write('  ' .. enumname .. ',\n')
  defsfile:write(string.format([[
  [%s] = {
    .cmd_name = (char_u *) "%s",
    .cmd_func = (ex_func_T)&%s,
    .cmd_argt = %uL,
    .cmd_addr_type = %i
  }]], enumname, cmd.command, cmd.func, cmd.flags, cmd.addr_type))
end
defsfile:write([[

};
]])
enumfile:write([[
  CMD_SIZE,
  CMD_USER = -1,
  CMD_USER_BUF = -2
} cmdidx_T;
]])
cmdidxs = cmdidxs .. [[

};
]]
defsfile:write(cmdidxs)
