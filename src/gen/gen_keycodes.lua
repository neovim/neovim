local names_file = arg[1]

local keycodes = require('nvim.keycodes')
local keycode_names = keycodes.names

local names_tgt = assert(io.open(names_file, 'w'))

names_tgt:write([[
static const struct key_name_entry {
  int key;           ///< Special key code or ascii value
  const char *name;  ///< Name of key
} key_names_table[] = {]])

for _, keycode in ipairs(keycode_names) do
  names_tgt:write(('\n  {%s, "%s"},'):format(keycode[1], keycode[2]))
end

names_tgt:write('\n  {0, NULL},\n};\n')
names_tgt:close()
