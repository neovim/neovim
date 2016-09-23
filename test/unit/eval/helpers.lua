local helpers = require('test.unit.helpers')(nil)

local cimport = helpers.cimport
local to_cstr = helpers.to_cstr
local ffi = helpers.ffi
local eq = helpers.eq

local eval = cimport('./src/nvim/eval.h', './src/nvim/eval/typval.h',
                     './src/nvim/hashtab.h')

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

local ptr2key = function(ptr)
  return tostring(ptr)
end

local lst2tbl
local dct2tbl

local typvalt2lua
local typvalt2lua_tab = nil

local function typvalt2lua_tab_init()
  if typvalt2lua_tab then
    return
  end
  typvalt2lua_tab = {
    [tonumber(eval.VAR_SPECIAL)] = function(t)
      return ({
        [eval.kSpecialVarFalse] = false,
        [eval.kSpecialVarNull] = nil_value,
        [eval.kSpecialVarTrue] = true,
      })[t.vval.v_special]
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
    [tonumber(eval.VAR_FUNC)] = function(t, processed)
      return {[type_key]=func_type, value=typvalt2lua_tab[eval.VAR_STRING](t, processed or {})}
    end,
    [tonumber(eval.VAR_PARTIAL)] = function(t, processed)
      local p_key = ptr2key(t)
      if processed[p_key] then
        return processed[p_key]
      end
      local pt = t.vval.v_partial
      local value, auto, dict, argv = nil, nil, nil, nil
      if pt ~= nil then
        value = ffi.string(pt.pt_name)
        auto = pt.pt_auto and true or nil
        argv = {}
        for i = 1, pt.pt_argc do
          argv[i] = typvalt2lua(pt.pt_argv[i - 1], processed)
        end
        if pt.pt_dict ~= nil then
          dict = dct2tbl(pt.pt_dict)
        end
      end
      return {
        [type_key]=func_type,
        value=value,
        auto=auto,
        args=argv,
        dict=dict,
      }
    end,
  }
end

typvalt2lua = function(t, processed)
  typvalt2lua_tab_init()
  return ((typvalt2lua_tab[tonumber(t.v_type)] or function(t_inner)
    assert(false, 'Converting ' .. tonumber(t_inner.v_type) .. ' was not implemented yet')
  end)(t, processed or {}))
end

local function list_iter(l)
  local init_s = {
    idx=0,
    li=l.lv_first,
  }
  local function f(s, _)
    -- (listitem_T *) NULL is equal to nil, but yet it is not false.
    if s.li == nil then
      return nil
    end
    local ret_li = s.li
    s.li = s.li.li_next
    s.idx = s.idx + 1
    return s.idx, ret_li
  end
  return f, init_s, nil
end

local function list_items(l)
  local ret = {}
  for i, li in list_iter(l) do
    ret[i] = li
  end
  return ret
end

lst2tbl = function(l, processed)
  if l == nil then
    return null_list
  end
  processed = processed or {}
  local p_key = ptr2key(l)
  if processed[p_key] then
    return processed[p_key]
  end
  local ret = {[type_key]=list_type}
  processed[p_key] = ret
  for i, li in list_iter(l) do
    ret[i] = typvalt2lua(li.li_tv, processed)
  end
  if ret[1] then
    ret[type_key] = nil
  end
  return ret
end

local hi_key_removed = nil

local function dict_iter(d, return_hi)
  hi_key_removed = hi_key_removed or eval._hash_key_removed()
  local init_s = {
    todo=d.dv_hashtab.ht_used,
    hi=d.dv_hashtab.ht_array,
  }
  local function f(s, _)
    if s.todo == 0 then return nil end
    while s.todo > 0 do
      if s.hi.hi_key ~= nil and s.hi.hi_key ~= hi_key_removed then
        local key = ffi.string(s.hi.hi_key)
        local ret
        if return_hi then
          ret = s.hi
        else
          ret = ffi.cast('dictitem_T*',
                         s.hi.hi_key - ffi.offsetof('dictitem_T', 'di_key'))
        end
        s.todo = s.todo - 1
        s.hi = s.hi + 1
        return key, ret
      end
      s.hi = s.hi + 1
    end
  end
  return f, init_s, nil
end

local function first_di(d)
  local f, init_s, v = dict_iter(d)
  return select(2, f(init_s, v))
end

local function dict_items(d)
  local ret = {[0]=0}
  for k, hi in dict_iter(d) do
    ret[k] = hi
    ret[0] = ret[0] + 1
    ret[ret[0]] = hi
  end
  return ret
end

dct2tbl = function(d, processed)
  if d == nil then
    return null_dict
  end
  processed = processed or {}
  local p_key = ptr2key(d)
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
  [func_type] = function(l, processed)
    if processed[l] then
      processed[l].pt_refcount = processed[l].pt_refcount + 1
      return typvalt(eval.VAR_PARTIAL, {v_partial=processed[l]})
    end
    if l.args or l.dict then
      local pt = ffi.gc(ffi.cast('partial_T*', eval.xmalloc(ffi.sizeof('partial_T'))), nil)
      processed[l] = pt
      local argv = nil
      if l.args and #l.args > 0 then
        argv = ffi.gc(ffi.cast('typval_T*', eval.xmalloc(ffi.sizeof('typval_T') * #l.args)), nil)
        for i, arg in ipairs(l.args) do
          local arg_tv = ffi.gc(lua2typvalt(arg, processed), nil)
          eval.tv_copy(arg_tv, argv[i - 1])
          eval.tv_clear(arg_tv)
        end
      end
      local dict = nil
      if l.dict then
        local dict_tv = ffi.gc(lua2typvalt(l.dict, processed), nil)
        assert(dict_tv.v_type == eval.VAR_DICT)
        dict = dict_tv.vval.v_dict
      end
      pt.pt_refcount = 1
      pt.pt_name = eval.xmemdupz(to_cstr(l.value), #l.value)
      pt.pt_auto = not not l.auto
      pt.pt_argc = l.args and #l.args or 0
      pt.pt_argv = argv
      pt.pt_dict = dict
      return typvalt(eval.VAR_PARTIAL, {v_partial=pt})
    else
      return typvalt(eval.VAR_FUNC, {
        v_string=eval.xmemdupz(to_cstr(l.value), #l.value)
      })
    end
  end,
}

local special_vals = nil

lua2typvalt = function(l, processed)
  if not special_vals then
    special_vals = {
      [null_string] = {'VAR_STRING', {v_string=ffi.cast('char_u*', nil)}},
      [null_list] = {'VAR_LIST', {v_list=ffi.cast('list_T*', nil)}},
      [null_dict] = {'VAR_DICT', {v_dict=ffi.cast('dict_T*', nil)}},
      [nil_value] = {'VAR_SPECIAL', {v_special=eval.kSpecialVarNull}},
      [true] = {'VAR_SPECIAL', {v_special=eval.kSpecialVarTrue}},
      [false] = {'VAR_SPECIAL', {v_special=eval.kSpecialVarFalse}},
    }

    for k, v in pairs(special_vals) do
      local tmp = function(typ, vval)
        special_vals[k] = function()
          return typvalt(eval[typ], vval)
        end
      end
      tmp(v[1], v[2])
    end
  end
  processed = processed or {}
  if l == nil or l == nil_value then
    return special_vals[nil_value]()
  elseif special_vals[l] then
    return special_vals[l]()
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

local void_ptr = ffi.typeof('void *')
local function void(ptr)
  return ffi.cast(void_ptr, ptr)
end

local function alloc_len(len, get_ptr)
  if type(len) == 'string' or type(len) == 'table' then
    return #len
  elseif len == nil then
    return eval.strlen(get_ptr())
  else
    return len
  end
end

local alloc_logging_helpers = {
  list = function(l) return {func='calloc', args={1, ffi.sizeof('list_T')}, ret=void(l)} end,
  li = function(li) return {func='malloc', args={ffi.sizeof('listitem_T')}, ret=void(li)} end,
  dict = function(d) return {func='malloc', args={ffi.sizeof('dict_T')}, ret=void(d)} end,
  di = function(di, size)
    size = alloc_len(size, function() return di.di_key end)
    return {func='malloc', args={ffi.offsetof('dictitem_T', 'di_key') + size + 1}, ret=void(di)}
  end,
  str = function(s, size)
    size = alloc_len(size, function() return s end)
    return {func='malloc', args={size + 1}, ret=void(s)}
  end,

  freed = function(p) return {func='free', args={type(p) == 'table' and p or void(p)}} end,
}

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
  list_iter=list_iter,
  first_di=first_di,

  alloc_logging_helpers=alloc_logging_helpers,

  list_items=list_items,
  dict_items=dict_items,

  empty_list = {[type_key]=list_type},
}
