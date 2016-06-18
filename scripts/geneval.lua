mpack = require('mpack')

local nvimsrcdir = arg[1]
local autodir = arg[2]
local metadata_file = arg[3]

if nvimsrcdir == '--help' then
  print([[
Usage:
  lua geneval.lua src/nvim build/src/nvim/auto

Will generate build/src/nvim/auto/funcs.generated.h with definition of functions 
static const array.
]])
  os.exit(0)
end

package.path = nvimsrcdir .. '/?.lua;' .. package.path

local funcsfname = autodir .. '/funcs.generated.h'

local funcspipe = io.open(funcsfname .. '.hsh', 'w')

local funcs = require('eval').funcs

local metadata = mpack.unpack(io.open(arg[3], 'rb'):read("*all"))

for i,fun in ipairs(metadata) do
  funcs['api_'..fun.name] = {
    args=#fun.parameters,
    func='api_wrapper',
    data='handle_'..fun.name,
  }
end


for name, def in pairs(funcs) do
  args = def.args or 0
  if type(args) == 'number' then
    args = {args, args}
  elseif #args == 1 then
    args[2] = 'MAX_FUNC_ARGS'
  end
  func = def.func or ('f_' .. name)
  data = def.data or "NULL"
  local val = ('{ %s, %s, &%s, %s }'):format(args[1], args[2], func, data)
  funcspipe:write(name .. '\n' .. val .. '\n')
end
funcspipe:close()
