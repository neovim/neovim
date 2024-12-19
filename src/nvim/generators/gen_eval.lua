local mpack = vim.mpack

local autodir = arg[1]
local metadata_file = arg[2]
local funcs_file = arg[3]

local funcsfname = autodir .. '/funcs.generated.h'

--Will generate funcs.generated.h with definition of functions static const array.

local hashy = require 'generators.hashy'

local hashpipe = assert(io.open(funcsfname, 'wb'))

hashpipe:write([[
#include "nvim/arglist.h"
#include "nvim/cmdexpand.h"
#include "nvim/cmdhist.h"
#include "nvim/digraph.h"
#include "nvim/eval.h"
#include "nvim/eval/buffer.h"
#include "nvim/eval/deprecated.h"
#include "nvim/eval/fs.h"
#include "nvim/eval/funcs.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/vars.h"
#include "nvim/eval/window.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/fold.h"
#include "nvim/getchar.h"
#include "nvim/insexpand.h"
#include "nvim/mapping.h"
#include "nvim/match.h"
#include "nvim/mbyte.h"
#include "nvim/menu.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/quickfix.h"
#include "nvim/runtime.h"
#include "nvim/search.h"
#include "nvim/state.h"
#include "nvim/strings.h"
#include "nvim/sign.h"
#include "nvim/testing.h"
#include "nvim/undo.h"

]])

local funcs = require('eval').funcs
for _, func in pairs(funcs) do
  if func.float_func then
    func.func = 'float_op_wrapper'
    func.data = '{ .float_func = &' .. func.float_func .. ' }'
  end
end

local metadata = mpack.decode(io.open(metadata_file, 'rb'):read('*all'))
for _, fun in ipairs(metadata) do
  if fun.eval then
    funcs[fun.name] = {
      args = #fun.parameters,
      func = 'api_wrapper',
      data = '{ .api_handler = &method_handlers[' .. fun.handler_id .. '] }',
    }
  end
end

local func_names = vim.tbl_filter(function(name)
  return name:match('__%d*$') == nil
end, vim.tbl_keys(funcs))

table.sort(func_names)

local funcsdata = assert(io.open(funcs_file, 'w'))
funcsdata:write(mpack.encode(func_names))
funcsdata:close()

local neworder, hashfun = hashy.hashy_hash('find_internal_func', func_names, function(idx)
  return 'functions[' .. idx .. '].name'
end)

hashpipe:write('static const EvalFuncDef functions[] = {\n')

for _, name in ipairs(neworder) do
  local def = funcs[name]
  local args = def.args or 0
  if type(args) == 'number' then
    args = { args, args }
  elseif #args == 1 then
    args[2] = 'MAX_FUNC_ARGS'
  end
  local base = def.base or 'BASE_NONE'
  local func = def.func or ('f_' .. name)
  local data = def.data or '{ .null = NULL }'
  local fast = def.fast and 'true' or 'false'
  hashpipe:write(
    ('  { "%s", %s, %s, %s, %s, &%s, %s },\n'):format(
      name,
      args[1],
      args[2],
      base,
      fast,
      func,
      data
    )
  )
end
hashpipe:write('  { NULL, 0, 0, BASE_NONE, false, NULL, { .null = NULL } },\n')
hashpipe:write('};\n\n')
hashpipe:write(hashfun)
hashpipe:close()
