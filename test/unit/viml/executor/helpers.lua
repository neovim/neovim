return function(it)
local cimport, internalize, eq, ffi, lib, cstr, to_cstr
do
  local _obj_0 = require('test.unit.helpers')
  cimport, internalize, eq, ffi, lib, cstr, to_cstr = _obj_0.cimport, _obj_0.internalize, _obj_0.eq, _obj_0.ffi, _obj_0.lib, _obj_0.cstr, _obj_0.to_cstr
end

local libnvim = cimport('./src/nvim/viml/testhelpers/executor.h')

local execute_viml_test = function(str)
  local s = to_cstr(str)
  local result = libnvim.execute_viml_test(s)
  if result == nil then
    error('execute_viml_test returned nil')
  end
  return ffi.string(result)
end

local array_repr, obj_repr

array_repr = function(obj, indent)
  local ret = indent .. 'array: {{{\n'
  for _, v in ipairs(obj) do
    ret = ret .. obj_repr(v, indent .. '  ')
  end
  ret = ret .. indent .. '}}}\n'
  return ret
end

obj_repr = function(obj, indent)
  local typ = type(obj)
  if typ == 'number' then
    return indent .. 'number: ' .. tostring(obj) .. '\n'
  elseif typ == 'string' then
    return indent .. 'string: ' .. tostring(#obj) .. ': ' .. obj .. '\n'
  elseif typ == 'table' then
    if obj._t == 'float' then
      return string.format('%sfloat: %+.2e\n', indent, obj._v)
    elseif obj[1] or obj._t == 'list' then
      return array_repr(obj, indent)
    end
    error('Not implemented')
  end
  error('Invalid type')
end

local to_obj_repr = function(obj)
  return array_repr(obj, '')
end

local eqo = function(str, exp)
  local act = execute_viml_test(str)
  exp = to_obj_repr(exp)
  return eq(exp, act)
end

local ito = function(msg, str, exp)
  it(msg, function()
    eqo(str, exp)
  end)
end

local itoe = function(msg, strs, exp)
  local str = ''
  for _, v in ipairs(strs) do
    str = str .. 'try\n' .. v .. '\ncatch\necho v:exception\nendtry\n'
  end
  return ito(msg, str, exp)
end

local f = function(v)
  return {_t='float', _v=v}
end

return {
  eqo=eqo,
  ito=ito,
  itoe=itoe,
  f=f,
}
end
