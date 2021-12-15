if arg[1] == '--help' then
  print('Usage:')
  print('  '..arg[0]..' [-c] target source varname [source varname]...')
  print('')
  print('Generates C file with big uint8_t blob.')
  print('Blob will be stored in a static const array named varname.')
  os.exit()
end

-- Recognized options:
--   -c   compile Lua bytecode
local options = {}

while true do
  local opt = string.match(arg[1], "^-(%w)")
  if not opt then
    break
  end

  options[opt] = true
  table.remove(arg, 1)
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

  target:write(('static const uint8_t %s[] = {\n'):format(varname))

  local output
  if options.c then
    local luac = os.getenv("LUAC_PRG")
    if luac then
      output = io.popen(luac:format(source_file), "r"):read("*a")
    else
      print("LUAC_PRG is undefined")
    end
  end

  if not output then
    local source = io.open(source_file, "r")
        or error(string.format("source_file %q doesn't exist", source_file))
    output = source:read("*a")
    source:close()
  end

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

  for i = 1, string.len(output) do
    local byte = output:byte(i)
    target:write(string.format(' %3u,', byte))
    increase_num_bytes()
  end

  target:write('  0};\n')
end

target:close()
