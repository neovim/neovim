local autodir = arg[1]

local deffname = autodir .. '/normal_cmds.generated.h'
local defsfile = io.open(deffname, 'w')

defsfile:write [[
#include "nvim/normal_defs.h"

/// Function to be called for a Normal or Visual mode command.
/// The argument is a cmdarg_T.
typedef void (*nv_func_T)(cmdarg_T *cap);

/// This table contains one entry for every Normal or Visual mode command.
/// The order doesn't matter, init_normal_cmds() will create a sorted index.
/// It is faster when all keys from zero to '~' are present.
static const struct nv_cmd {
  int cmd_char;                 ///< (first) command character
  nv_func_T cmd_func;           ///< function for this command
  uint16_t cmd_flags;           ///< NV_ flags
  int16_t cmd_arg;              ///< value for ca.arg
} nv_cmds[] = {
]]

local normal = require('normal_cmds')
for i, item in vim.spairs(normal.nv_cmds) do
  defsfile:write(('  { %s, %s, %s, %s },\n'):format(item.char, item.func, item.flags, item.arg))
  if i == #normal.nv_cmds then
    defsfile:write('};\n\n')
  end
end

defsfile:close()
