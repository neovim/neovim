local helpers = require('test.unit.helpers')

local cimport = helpers.cimport
local to_cstr = helpers.to_cstr
local ffi = helpers.ffi
local eq = helpers.eq

local eval = cimport('./src/nvim/eval.h', './src/nvim/eval_defs.h')

local null_string = {[true]='NULL string'}
local null_list = {[true]='NULL list'}
local type_key = {[true]='type key'}
local list_type = {[true]='list type'}

local function list(...)
  local ret = ffi.gc(eval.list_alloc(), eval.list_unref)
  eq(0, ret.lv_refcount)
  ret.lv_refcount = 1
  for i = 1, select('#', ...) do
    local val = select(i, ...)
    local typ = type(val)
    if typ == 'string' then
      eval.list_append_string(ret, to_cstr(val))
    elseif typ == 'table' and val == null_string then
      eval.list_append_string(ret, nil)
    elseif typ == 'table' and val == null_list then
      eval.list_append_list(ret, nil)
    elseif typ == 'table' and val[type_key] == list_type then
      local itemlist = ffi.gc(list(table.unpack(val)), nil)
      eq(1, itemlist.lv_refcount)
      itemlist.lv_refcount = 0
      eval.list_append_list(ret, itemlist)
    else
      assert(false, 'Not implemented yet')
    end
  end
  return ret
end

local lst2tbl = function(l)
  local ret = {[type_key]=list_type}
  if l == nil then
    return ret
  end
  local li = l.lv_first
  -- (listitem_T *) NULL is equal to nil, but yet it is not false.
  while li ~= nil do
    local typ = li.li_tv.v_type
    if typ == eval.VAR_STRING then
      local str = li.li_tv.vval.v_string
      if str == nil then
        ret[#ret + 1] = null_string
      else
        ret[#ret + 1] = ffi.string(str)
      end
    else
      assert(false, 'Not implemented yet')
    end
    li = li.li_next
  end
  return ret
end

return {
  null_string=null_string,
  null_list=null_list,
  list_type=list_type,
  type_key=type_key,

  list=list,
  lst2tbl=lst2tbl,
}
