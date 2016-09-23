local helpers = require('test.unit.helpers')

local cimport = helpers.cimport
local to_cstr = helpers.to_cstr
local ffi = helpers.ffi
local eq = helpers.eq

local eval = cimport('./src/nvim/eval.h', './src/nvim/eval/typval.h')

local null_string = {[true]='NULL string'}
local null_list = {[true]='NULL list'}
local null_dict = {[true]='NULL dict'}
local type_key = {[true]='type key'}
local locks_key = {[true]='locks key'}
local list_type = {[true]='list type'}
local dict_type = {[true]='dict type'}
local func_type = {[true]='func type'}
local int_type = {[true]='int type'}
local flt_type = {[true]='flt type'}

local nil_value = {[true]='nil'}

local lua2typvalt

local function li_alloc(nogc)
  local gcfunc = eval.tv_list_item_free
  if nogc then gcfunc = nil end
  local li = ffi.gc(eval.tv_list_item_alloc(), gcfunc)
  li.li_next = nil
  li.li_prev = nil
  li.li_tv = {v_type=eval.VAR_UNKNOWN, v_lock=eval.VAR_UNLOCKED}
  return li
end

local function list(...)
  local ret = ffi.gc(eval.tv_list_alloc(), eval.tv_list_unref)
  eq(0, ret.lv_refcount)
  ret.lv_refcount = 1
  for i = 1, select('#', ...) do
    local val = select(i, ...)
    local li_tv = ffi.gc(lua2typvalt(val), nil)
    local li = li_alloc(true)
    li.li_tv = li_tv
    eval.tv_list_append(ret, li)
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
  [tonumber(eval.VAR_LIST)] = function(t, processed)
    return lst2tbl(t.vval.v_list, processed)
  end,
  [tonumber(eval.VAR_DICT)] = function(t, processed)
    return dct2tbl(t.vval.v_dict, processed)
  end,
  [tonumber(eval.VAR_FUNC)] = function(t)
    return {[type_key]=func_type, value=typvalt2lua_tab[eval.VAR_STRING](t)}
  end,
}

local typvalt2lua = function(t, processed)
  return ((typvalt2lua_tab[tonumber(t.v_type)] or function(t_inner)
    assert(false, 'Converting ' .. tonumber(t_inner.v_type) .. ' was not implemented yet')
  end)(t, processed))
end

lst2tbl = function(l, processed)
  if l == nil then
    return null_list
  end
  processed = processed or {}
  local p_key = tostring(l)
  if processed[p_key] then
    return processed[p_key]
  end
  local ret = {[type_key]=list_type}
  processed[p_key] = ret
  local li = l.lv_first
  -- (listitem_T *) NULL is equal to nil, but yet it is not false.
  while li ~= nil do
    ret[#ret + 1] = typvalt2lua(li.li_tv, processed)
    li = li.li_next
  end
  if ret[1] then
    ret[type_key] = nil
  end
  return ret
end

local function dict_iter(d)
  local init_s = {
    todo=d.dv_hashtab.ht_used,
    hi=d.dv_hashtab.ht_array,
  }
  local function f(s, _)
    if s.todo == 0 then return nil end
    while s.todo > 0 do
      if s.hi.hi_key ~= nil and s.hi ~= eval.hash_removed then
        local key = ffi.string(s.hi.hi_key)
        local di = ffi.cast('dictitem_T*',
                            s.hi.hi_key - ffi.offsetof('dictitem_T', 'di_key'))
        s.todo = s.todo - 1
        s.hi = s.hi + 1
        return key, di
      end
      s.hi = s.hi + 1
    end
  end
  return f, init_s, nil
end

local function first_di(d)
  for _, di in dict_iter(d) do
    return di
  end
end

dct2tbl = function(d, processed)
  if d == nil then
    return null_dict
  end
  processed = processed or {}
  local p_key = tostring(d)
  if processed[p_key] then
    return processed[p_key]
  end
  local ret = {}
  processed[p_key] = ret
  for k, di in dict_iter(d) do
    ret[k] = typvalt2lua(di.di_tv, processed)
  end
  return ret
end

local typvalt = function(typ, vval)
  if typ == nil then
    typ = eval.VAR_UNKNOWN
  elseif type(typ) == 'string' then
    typ = eval[typ]
  end
  return ffi.gc(ffi.new('typval_T', {v_type=typ, vval=vval}), eval.tv_clear)
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
    local lst = eval.tv_list_alloc()
    lst.lv_refcount = 1
    processed[l] = lst
    local ret = typvalt(eval.VAR_LIST, {v_list=lst})
    for i = 1, #l do
      local item_tv = ffi.gc(lua2typvalt(l[i], processed), nil)
      eval.tv_list_append_tv(lst, item_tv)
      eval.tv_clear(item_tv)
    end
    return ret
  end,
  [dict_type] = function(l, processed)
    if processed[l] then
      processed[l].dv_refcount = processed[l].dv_refcount + 1
      return typvalt(eval.VAR_DICT, {v_dict=processed[l]})
    end
    local dct = eval.tv_dict_alloc()
    dct.dv_refcount = 1
    processed[l] = dct
    local ret = typvalt(eval.VAR_DICT, {v_dict=dct})
    for k, v in pairs(l) do
      if type(k) == 'string' then
        local di = eval.tv_dict_item_alloc(to_cstr(k))
        local val_tv = ffi.gc(lua2typvalt(v, processed), nil)
        eval.tv_copy(val_tv, di.di_tv)
        eval.tv_clear(val_tv)
        eval.tv_dict_add(dct, di)
      end
    end
    return ret
  end,
}

local special_vals = {
  [null_string] = typvalt(eval.VAR_STRING, {v_string=ffi.cast('char_u*', nil)}),
  [null_list] = typvalt(eval.VAR_LIST, {v_list=ffi.cast('list_T*', nil)}),
  [null_dict] = typvalt(eval.VAR_DICT, {v_dict=ffi.cast('dict_T*', nil)}),
  [nil_value] = typvalt(eval.VAR_SPECIAL, {v_special=eval.kSpecialVarNull}),
  [true] = typvalt(eval.VAR_SPECIAL, {v_special=eval.kSpecialVarTrue}),
  [false] = typvalt(eval.VAR_SPECIAL, {v_special=eval.kSpecialVarFalse}),
}

lua2typvalt = function(l, processed)
  processed = processed or {}
  if l == nil then
    return special_vals[nil_value]
  elseif special_vals[l] then
    return special_vals[l]
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
  elseif type(l) == 'string' then
    return typvalt(eval.VAR_STRING, {v_string=eval.xmemdupz(to_cstr(l), #l)})
  elseif type(l) == 'cdata' then
    local tv = typvalt(eval.VAR_UNKNOWN)
    eval.tv_copy(l, tv)
    return tv
  end
end

return {
  null_string=null_string,
  null_list=null_list,
  null_dict=null_dict,
  list_type=list_type,
  dict_type=dict_type,
  func_type=func_type,
  int_type=int_type,
  flt_type=flt_type,

  nil_value=nil_value,

  type_key=type_key,
  locks_key=locks_key,

  list=list,
  lst2tbl=lst2tbl,
  dct2tbl=dct2tbl,

  lua2typvalt=lua2typvalt,
  typvalt2lua=typvalt2lua,

  typvalt=typvalt,

  li_alloc=li_alloc,

  dict_iter=dict_iter,
  first_di=first_di,

  empty_list = {[type_key]=list_type},
}
