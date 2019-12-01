if arg[1] == '--help' then
  print('Usage:')
  print('  '..arg[0]..' target source varname [source varname]...')
  print('')
  print('Generates C file with big uint8_t blob.')
  print('Blob will be stored in a static const array named varname.')
  os.exit()
end

assert(#arg >= 3 and (#arg - 1) % 2 == 0)

local target_file = arg[1] or error('Need a target file')
local target = io.open(target_file, 'w')

target:write('#include <stdint.h>\n\n')

local varnames = {}
for argi = 2, #arg, 2 do
  local source_file = arg[argi]
  local varname = arg[argi + 1]
  if varnames[varname] then
    error(string.format("varname %q is already specified for file %q", varname, varnames[varname]))
  end
  varnames[varname] = source_file

  local source = io.open(source_file, 'r')
      or error(string.format("source_file %q doesn't exist", source_file))

  target:write(('static const uint8_t %s[] = {\n'):format(varname))

  local num_bytes = 0
  local MAX_NUM_BYTES = 15  -- 78 / 5: maximum number of bytes on one line
  target:write(' ')

  local increase_num_bytes
  increase_num_bytes = function()
    num_bytes = num_bytes + 1
    if num_bytes == MAX_NUM_BYTES then
      num_bytes = 0
      target:write('\n ')
    end
  end

  for line in source:lines() do
    for i = 1, string.len(line) do
      local byte = line:byte(i)
      assert(byte ~= 0)
      target:write(string.format(' %3u,', byte))
      increase_num_bytes()
    end
    target:write(string.format(' %3u,', string.byte('\n', 1)))
    increase_num_bytes()
  end

  target:write('   0};\n')
  source:close()
end

target:close()
