local nvimsrcdir = arg[1]
local autodir = arg[2]

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
local funcsfile = io.open(funcsfname, 'w')

local funcs = require('eval')

local sorted_funcs = {}
for name, def in pairs(funcs.funcs) do
  def.name = name
  def.args = def.args or 0
  if type(def.args) == 'number' then
    def.args = {def.args, def.args}
  elseif #def.args == 1 then
    def.args[2] = 'MAX_FUNC_ARGS'
  end
  def.func = def.func or ('f_' .. def.name)
  sorted_funcs[#sorted_funcs + 1] = def
end
table.sort(sorted_funcs, function(a, b) return a.name < b.name end)

funcsfile:write('static const VimLFuncDef functions[] = {\n')
for _, def in ipairs(sorted_funcs) do
  funcsfile:write(('  { "%s", %s, %s, &%s },\n'):format(
      def.name, def.args[1], def.args[2], def.func
  ))
end
funcsfile:write('};\n')
