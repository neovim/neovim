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
local dict_type = {[true]='dict type'}
local func_type = {[true]='func type'}
local int_type = {[true]='int type'}
local flt_type = {[true]='flt type'}

local nil_value = {[true]='nil'}

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

local special_tab = {
  [eval.kSpecialVarFalse] = false,
  [eval.kSpecialVarNull] = nil_value,
  [eval.kSpecialVarTrue] = true,
}

local lst2tbl
local dct2tbl

local typvalt2lua_tab

typvalt2lua_tab = {
  [tonumber(eval.VAR_SPECIAL)] = function(t)
    return special_tab[t.vval.v_special]
  end,
  [tonumber(eval.VAR_NUMBER)] = function(t)
    return {[type_key]=int_type, value=tonumber(t.vval.v_number)}
  end,
  [tonumber(eval.VAR_FLOAT)] = function(t)
    return tonumber(t.vval.v_float)
  end,
  [tonumber(eval.VAR_STRING)] = function(t)
    local str = t.vval.v_string
    if str == nil then
      return null_string
    else
      return ffi.string(str)
    end
  end,
  [tonumber(eval.VAR_LIST)] = function(t)
    return lst2tbl(t.vval.v_list)
  end,
  [tonumber(eval.VAR_DICT)] = function(t)
    return dct2tbl(t.vval.v_dict)
  end,
  [tonumber(eval.VAR_FUNC)] = function(t)
    return {[type_key]=func_type, value=typvalt2lua_tab[eval.VAR_STRING](t)}
  end,
}

local typvalt2lua = function(t)
  return ((typvalt2lua_tab[tonumber(t.v_type)] or function(t_inner)
    assert(false, 'Converting ' .. tonumber(t_inner.v_type) .. ' was not implemented yet')
  end)(t))
end

lst2tbl = function(l)
  local ret = {[type_key]=list_type}
  if l == nil then
    return ret
  end
  local li = l.lv_first
  -- (listitem_T *) NULL is equal to nil, but yet it is not false.
  while li ~= nil do
    ret[#ret + 1] = typvalt2lua(li.li_tv)
    li = li.li_next
  end
  if ret[1] then
    ret[type_key] = nil
  end
  return ret
end

dct2tbl = function(d)
  local ret = {d=d}
  assert(false, 'Converting dictionaries is not implemented yet')
  return ret
end

local lua2typvalt

local typvalt = function(typ, vval)
  if type(typ) == 'string' then
    typ = eval[typ]
  end
  return ffi.gc(ffi.new('typval_T', {v_type=typ, vval=vval}), eval.clear_tv)
end

local lua2typvalt_type_tab = {
  [int_type] = function(l, _)
    return typvalt(eval.VAR_NUMBER, {v_number=l.value})
  end,
  [flt_type] = function(l, processed)
    return lua2typvalt(l.value, processed)
  end,
  [list_type] = function(l, processed)
    if processed[l] then
      processed[l].lv_refcount = processed[l].lv_refcount + 1
      return typvalt(eval.VAR_LIST, {v_list=processed[l]})
    end
    local lst = eval.list_alloc()
    lst.lv_refcount = 1
    processed[l] = lst
    local ret = typvalt(eval.VAR_LIST, {v_list=lst})
    for i = 1, #l do
      local item_tv = ffi.gc(lua2typvalt(l[i], processed), nil)
      eval.list_append_tv(lst, item_tv)
      eval.clear_tv(item_tv)
    end
    return ret
  end,
  [dict_type] = function(l, processed)
    if processed[l] then
      processed[l].dv_refcount = processed[l].dv_refcount + 1
      return typvalt(eval.VAR_DICT, {v_dict=processed[l]})
    end
    local dct = eval.dict_alloc()
    dct.dv_refcount = 1
    processed[l] = dct
    local ret = typvalt(eval.VAR_DICT, {v_dict=dct})
    for k, v in pairs(l) do
      if type(k) == 'string' then
        local di = eval.dictitem_alloc(to_cstr(k))
        local val_tv = ffi.gc(lua2typvalt(v, processed), nil)
        eval.copy_tv(val_tv, di.di_tv)
        eval.clear_tv(val_tv)
        eval.dict_add(dct, di)
      end
    end
    return ret
  end,
}

lua2typvalt = function(l, processed)
  processed = processed or {}
  if l == nil or l == nil_value then
    return typvalt(eval.VAR_SPECIAL, {v_special=eval.kSpecialVarNull})
  elseif type(l) == 'table' then
    if l[type_key] then
      return lua2typvalt_type_tab[l[type_key]](l, processed)
    else
      if l[1] then
        return lua2typvalt_type_tab[list_type](l, processed)
      else
        return lua2typvalt_type_tab[dict_type](l, processed)
      end
    end
  elseif type(l) == 'number' then
    return typvalt(eval.VAR_FLOAT, {v_float=l})
  elseif type(l) == 'boolean' then
    return typvalt(eval.VAR_SPECIAL, {
      v_special=(l and eval.kSpecialVarTrue or eval.kSpecialVarFalse)
    })
  elseif type(l) == 'string' then
    return typvalt(eval.VAR_STRING, {v_string=eval.xmemdupz(to_cstr(l), #l)})
  end
end

return {
  null_string=null_string,
  null_list=null_list,
  list_type=list_type,
  dict_type=dict_type,
  func_type=func_type,
  int_type=int_type,
  flt_type=flt_type,

  nil_value=nil_value,

  type_key=type_key,

  list=list,
  lst2tbl=lst2tbl,
  dct2tbl=dct2tbl,

  lua2typvalt=lua2typvalt,
  typvalt2lua=typvalt2lua,

  typvalt=typvalt,
}
