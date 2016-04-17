assert(#arg == 2)

module_file = arg[1]
target_file = arg[2]

module = io.open(module_file, 'r')
target = io.open(target_file, 'w')

target:write('#include <stdint.h>\n\n')
target:write('static const uint8_t vim_module[] = {\n')

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

for line in module:lines() do
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

module:close()
target:close()
