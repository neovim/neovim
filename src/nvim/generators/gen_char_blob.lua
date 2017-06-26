if arg[1] == '--help' then
  print('Usage:')
  print('  gencharblob.lua source target varname')
  print('')
  print('Generates C file with big uint8_t blob.')
  print('Blob will be stored in a static const array named varname.')
  os.exit()
end

assert(#arg == 3)

local source_file = arg[1]
local target_file = arg[2]
local varname = arg[3]

source = io.open(source_file, 'r')
target = io.open(target_file, 'w')

target:write('#include <stdint.h>\n\n')
target:write(('static const uint8_t %s[] = {\n'):format(varname))

num_bytes = 0
MAX_NUM_BYTES = 15  -- 78 / 5: maximum number of bytes on one line
target:write(' ')

increase_num_bytes = function()
  num_bytes = num_bytes + 1
  if num_bytes == MAX_NUM_BYTES then
    num_bytes = 0
    target:write('\n ')
  end
end

for line in source:lines() do
  for i = 1,string.len(line) do
    byte = string.byte(line, i)
    assert(byte ~= 0)
    target:write(string.format(' %3u,', byte))
    increase_num_bytes()
  end
  target:write(string.format(' %3u,', string.byte('\n', 1)))
  increase_num_bytes()
end

target:write('   0};\n')

source:close()
target:close()
