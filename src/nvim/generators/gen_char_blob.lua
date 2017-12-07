if arg[1] == '--help' then
  print('Usage:')
  print('  gencharblob.lua src/nvim source target varname')
  print('')
  print('Generates C file with big uint8_t blob.')
  print('Blob will be stored in a static const array named varname.')
  os.exit()
end

assert(#arg == 4)

local nvimdir = arg[1]
local source_file = arg[2]
local target_file = arg[3]
local varname = arg[4]

package.path = nvimdir .. '/?/init.lua;' .. nvimdir .. '/?.lua;' .. package.path

local dump_bin_array = require("generators.dump_bin_array")

source = io.open(source_file, 'r')
target = io.open(target_file, 'w')

target:write('#include <stdint.h>\n\n')

dump_bin_array(target, varname, source:read('*a') .. '\0')

source:close()
target:close()
