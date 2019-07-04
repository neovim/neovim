local mpack = require('mpack')

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

local funcsfname = autodir .. '/funcs.generated.h'

local gperfpipe = io.open(funcsfname .. '.gperf', 'wb')

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

gperfpipe:write([[
%language=ANSI-C
%global-table
%readonly-tables
%define initializer-suffix ,0,0,NULL,NULL
%define word-array-name functions
%define hash-function-name hash_internal_func_gperf
%define lookup-function-name find_internal_func_gperf
%omit-struct-type
%struct-type
VimLFuncDef;
%%
]])

for name, def in pairs(funcs) do
  local args = def.args or 0
  if type(args) == 'number' then
    args = {args, args}
  elseif #args == 1 then
    args[2] = 'MAX_FUNC_ARGS'
  end
  local func = def.func or ('f_' .. name)
  local data = def.data or "NULL"
  gperfpipe:write(('%s,  %s, %s, &%s, (FunPtr)%s\n')
                  :format(name, args[1], args[2], func, data))
end
gperfpipe:close()
