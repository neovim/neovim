local mpack = require('mpack')

local nvimsrcdir = arg[1]
local autodir = arg[2]
local metadata_file = arg[3]
local funcs_file = arg[4]

if nvimsrcdir == '--help' then
  print([[
Usage:
  lua gen_eval.lua src/nvim build/src/nvim/auto

Will generate build/src/nvim/auto/funcs.generated.h with definition of functions
static const array.
]])
  os.exit(0)
end

package.path = nvimsrcdir .. '/?.lua;' .. package.path

local funcs = require('eval').funcs
local metadata = mpack.unpack(io.open(metadata_file, 'rb'):read("*all"))
for _,fun in ipairs(metadata) do
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

local funcs_list = io.open(autodir .. '/funcs.generated.h', 'w')

funcs_list:write([[
#ifdef _MSC_VER
// This prevents MSVC from replacing the functions with intrinsics,
// and causing errors when trying to get their addresses
#pragma function(ceil)
#pragma function(floor)
#endif

static const VimLFuncDef functions[] = {
]])

-- Sort the functions by their name
local names = {}
for n in pairs(funcs) do table.insert(names, n) end
table.sort(names)

for _, name in ipairs(names) do
  local def = funcs[name]
  local args = def.args or 0
  if type(args) == 'number' then
    args = {args, args}
  elseif #args == 1 then
    args[2] = 'MAX_FUNC_ARGS'
  end
  local func = def.func or ('f_' .. name)
  local data = def.data or "NULL"
  funcs_list:write(('  {"%s", %s, %s, &%s, (FunPtr)%s},\n')
                  :format(name, args[1], args[2], func, data))
end

funcs_list:write('};\n')
funcs_list:close()
