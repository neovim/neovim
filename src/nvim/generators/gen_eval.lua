mpack = require('mpack')

local nvimsrcdir = arg[1]
local autodir = arg[2]
local metadata_file = arg[3]
local funcs_file = arg[4]

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

local gperf = require('generators.gperf')

local funcs = require('eval').funcs
local metadata = mpack.unpack(io.open(arg[3], 'rb'):read("*all"))
for i,fun in ipairs(metadata) do
  if not fun.remote_only then
    funcs[fun.name] = {
      args=#fun.parameters,
      func='api_wrapper',
      data='&handle_'..fun.name,
    }
  end
end

local funcsdata = io.open(funcs_file, 'w')
funcsdata:write(mpack.pack(funcs))
funcsdata:close()

gperf.generate({
  outputf_base = autodir .. '/funcs.generated.h',
  word_array_name = 'functions',
  lookup_function_name = 'find_internal_func_gperf',
  struct_type = 'VimLFuncDef',
  initializer_suffix = ',0,0,NULL,NULL',
  item_callback = function(self, name, def)
    args = def.args or 0
    if type(args) == 'number' then
      args = {args, args}
    elseif #args == 1 then
      args[2] = 'MAX_FUNC_ARGS'
    end
    func = def.func or ('f_' .. name)
    data = def.data or 'NULL'
    return (('%s, %s, %s, &%s, (FunPtr)%s'):format(
      name, args[1], args[2], func, data))
  end,
  data = funcs,
})
