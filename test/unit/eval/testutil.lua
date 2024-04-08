local t = require('test.unit.testutil')(nil)

local ptr2key = t.ptr2key
local cimport = t.cimport
local to_cstr = t.to_cstr
local ffi = t.ffi
local eq = t.eq

local eval = cimport(
  './src/nvim/eval.h',
  './src/nvim/eval/typval.h',
  './src/nvim/hashtab.h',
  './src/nvim/memory.h'
)

local null_string = { [true] = 'NULL string' }
local null_list = { [true] = 'NULL list' }
local null_dict = { [true] = 'NULL dict' }
local type_key = { [true] = 'type key' }
local locks_key = { [true] = 'locks key' }
local list_type = { [true] = 'list type' }
local dict_type = { [true] = 'dict type' }
local func_type = { [true] = 'func type' }
local int_type = { [true] = 'int type' }
local flt_type = { [true] = 'flt type' }

local nil_value = { [true] = 'nil' }

local lua2typvalt

local function tv_list_item_alloc()
  return ffi.cast('listitem_T*', eval.xmalloc(ffi.sizeof('listitem_T')))
end

local function tv_list_item_free(li)
  eval.tv_clear(li.li_tv)
  eval.xfree(li)
end

local function li_alloc(nogc)
  local gcfunc = tv_list_item_free
  if nogc then
    gcfunc = nil
  end
  local li = ffi.gc(tv_list_item_alloc(), gcfunc)
  li.li_next = nil
  li.li_prev = nil
  li.li_tv = { v_type = eval.VAR_UNKNOWN, v_lock = eval.VAR_UNLOCKED }
  return li
end

local function populate_list(l, lua_l, processed)
  processed = processed or {}
  eq(0, l.lv_refcount)
  l.lv_refcount = 1
  processed[lua_l] = l
  for i = 1, #lua_l do
    local item_tv = ffi.gc(lua2typvalt(lua_l[i], processed), nil)
    local item_li = tv_list_item_alloc()
    item_li.li_tv = item_tv
    eval.tv_list_append(l, item_li)
  end
  return l
end

local function populate_dict(d, lua_d, processed)
  processed = processed or {}
  eq(0, d.dv_refcount)
  d.dv_refcount = 1
  processed[lua_d] = d
  for k, v in pairs(lua_d) do
    if type(k) == 'string' then
      local di = eval.tv_dict_item_alloc(to_cstr(k))
      local val_tv = ffi.gc(lua2typvalt(v, processed), nil)
      eval.tv_copy(val_tv, di.di_tv)
      eval.tv_clear(val_tv)
      eval.tv_dict_add(d, di)
    end
  end
  return d
end

local function populate_partial(pt, lua_pt, processed)
  processed = processed or {}
  eq(0, pt.pt_refcount)
  processed[lua_pt] = pt
  local argv = nil
  if lua_pt.args and #lua_pt.args > 0 then
    argv = ffi.gc(ffi.cast('typval_T*', eval.xmalloc(ffi.sizeof('typval_T') * #lua_pt.args)), nil)
    for i, arg in ipairs(lua_pt.args) do
      local arg_tv = ffi.gc(lua2typvalt(arg, processed), nil)
      argv[i - 1] = arg_tv
    end
  end
  local dict = nil
  if lua_pt.dict then
    local dict_tv = ffi.gc(lua2typvalt(lua_pt.dict, processed), nil)
    assert(dict_tv.v_type == eval.VAR_DICT)
    dict = dict_tv.vval.v_dict
  end
  pt.pt_refcount = 1
  pt.pt_name = eval.xmemdupz(to_cstr(lua_pt.value), #lua_pt.value)
  pt.pt_auto = not not lua_pt.auto
  pt.pt_argc = lua_pt.args and #lua_pt.args or 0
  pt.pt_argv = argv
  pt.pt_dict = dict
  return pt
end

local lst2tbl
local dct2tbl

local typvalt2lua

local function partial2lua(pt, processed)
  processed = processed or {}
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
    [type_key] = func_type,
    value = value,
    auto = auto,
    args = argv,
    dict = dict,
  }
end

local typvalt2lua_tab = nil

local function typvalt2lua_tab_init()
  if typvalt2lua_tab then
    return
  end
  typvalt2lua_tab = {
    [tonumber(eval.VAR_BOOL)] = function(q)
      return ({
        [tonumber(eval.kBoolVarFalse)] = false,
        [tonumber(eval.kBoolVarTrue)] = true,
      })[tonumber(q.vval.v_bool)]
    end,
    [tonumber(eval.VAR_SPECIAL)] = function(q)
      return ({
        [tonumber(eval.kSpecialVarNull)] = nil_value,
      })[tonumber(q.vval.v_special)]
    end,
    [tonumber(eval.VAR_NUMBER)] = function(q)
      return { [type_key] = int_type, value = tonumber(q.vval.v_number) }
    end,
    [tonumber(eval.VAR_FLOAT)] = function(q)
      return tonumber(q.vval.v_float)
    end,
    [tonumber(eval.VAR_STRING)] = function(q)
      local str = q.vval.v_string
      if str == nil then
        return null_string
      else
        return ffi.string(str)
      end
    end,
    [tonumber(eval.VAR_LIST)] = function(q, processed)
      return lst2tbl(q.vval.v_list, processed)
    end,
    [tonumber(eval.VAR_DICT)] = function(q, processed)
      return dct2tbl(q.vval.v_dict, processed)
    end,
    [tonumber(eval.VAR_FUNC)] = function(q, processed)
      return { [type_key] = func_type, value = typvalt2lua_tab[eval.VAR_STRING](q, processed or {}) }
    end,
    [tonumber(eval.VAR_PARTIAL)] = function(q, processed)
      local p_key = ptr2key(q)
      if processed[p_key] then
        return processed[p_key]
      end
      return partial2lua(q.vval.v_partial, processed)
    end,
  }
end

typvalt2lua = function(q, processed)
  typvalt2lua_tab_init()
  return (
    (typvalt2lua_tab[tonumber(q.v_type)] or function(t_inner)
      assert(false, 'Converting ' .. tonumber(t_inner.v_type) .. ' was not implemented yet')
    end)(q, processed or {})
  )
end

local function list_iter(l)
  local init_s = {
    idx = 0,
    li = l.lv_first,
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
  local ret = { [type_key] = list_type }
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
    todo = d.dv_hashtab.ht_used,
    hi = d.dv_hashtab.ht_array,
  }
  local function f(s, _)
    if s.todo == 0 then
      return nil
    end
    while s.todo > 0 do
      if s.hi.hi_key ~= nil and s.hi.hi_key ~= hi_key_removed then
        local key = ffi.string(s.hi.hi_key)
        local ret
        if return_hi then
          ret = s.hi
        else
          ret = ffi.cast('dictitem_T*', s.hi.hi_key - ffi.offsetof('dictitem_T', 'di_key'))
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
  local ret = { [0] = 0 }
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
  return ffi.gc(ffi.new('typval_T', { v_type = typ, vval = vval }), eval.tv_clear)
end

local lua2typvalt_type_tab = {
  [int_type] = function(l, _)
    return typvalt(eval.VAR_NUMBER, { v_number = l.value })
  end,
  [flt_type] = function(l, processed)
    return lua2typvalt(l.value, processed)
  end,
  [list_type] = function(l, processed)
    if processed[l] then
      processed[l].lv_refcount = processed[l].lv_refcount + 1
      return typvalt(eval.VAR_LIST, { v_list = processed[l] })
    end
    local lst = populate_list(eval.tv_list_alloc(#l), l, processed)
    return typvalt(eval.VAR_LIST, { v_list = lst })
  end,
  [dict_type] = function(l, processed)
    if processed[l] then
      processed[l].dv_refcount = processed[l].dv_refcount + 1
      return typvalt(eval.VAR_DICT, { v_dict = processed[l] })
    end
    local dct = populate_dict(eval.tv_dict_alloc(), l, processed)
    return typvalt(eval.VAR_DICT, { v_dict = dct })
  end,
  [func_type] = function(l, processed)
    if processed[l] then
      processed[l].pt_refcount = processed[l].pt_refcount + 1
      return typvalt(eval.VAR_PARTIAL, { v_partial = processed[l] })
    end
    if l.args or l.dict then
      local pt = populate_partial(
        ffi.gc(ffi.cast('partial_T*', eval.xcalloc(1, ffi.sizeof('partial_T'))), nil),
        l,
        processed
      )
      return typvalt(eval.VAR_PARTIAL, { v_partial = pt })
    else
      return typvalt(eval.VAR_FUNC, {
        v_string = eval.xmemdupz(to_cstr(l.value), #l.value),
      })
    end
  end,
}

local special_vals = nil

lua2typvalt = function(l, processed)
  if not special_vals then
    special_vals = {
      [null_string] = { 'VAR_STRING', { v_string = ffi.cast('char*', nil) } },
      [null_list] = { 'VAR_LIST', { v_list = ffi.cast('list_T*', nil) } },
      [null_dict] = { 'VAR_DICT', { v_dict = ffi.cast('dict_T*', nil) } },
      [nil_value] = { 'VAR_SPECIAL', { v_special = eval.kSpecialVarNull } },
      [true] = { 'VAR_BOOL', { v_bool = eval.kBoolVarTrue } },
      [false] = { 'VAR_BOOL', { v_bool = eval.kBoolVarFalse } },
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
    return typvalt(eval.VAR_FLOAT, { v_float = l })
  elseif type(l) == 'string' then
    return typvalt(eval.VAR_STRING, { v_string = eval.xmemdupz(to_cstr(l), #l) })
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

local alloc_logging_t = {
  list = function(l)
    return { func = 'calloc', args = { 1, ffi.sizeof('list_T') }, ret = void(l) }
  end,
  li = function(li)
    return { func = 'malloc', args = { ffi.sizeof('listitem_T') }, ret = void(li) }
  end,
  dict = function(d)
    return { func = 'calloc', args = { 1, ffi.sizeof('dict_T') }, ret = void(d) }
  end,
  di = function(di, size)
    size = alloc_len(size, function()
      return di.di_key
    end)
    return {
      func = 'malloc',
      args = { ffi.offsetof('dictitem_T', 'di_key') + size + 1 },
      ret = void(di),
    }
  end,
  str = function(s, size)
    size = alloc_len(size, function()
      return s
    end)
    return { func = 'malloc', args = { size + 1 }, ret = void(s) }
  end,

  dwatcher = function(w)
    return { func = 'malloc', args = { ffi.sizeof('DictWatcher') }, ret = void(w) }
  end,

  freed = function(p)
    return { func = 'free', args = { type(p) == 'table' and p or void(p) } }
  end,

  -- lua_…: allocated by this file, not by some Neovim function
  lua_pt = function(pt)
    return { func = 'calloc', args = { 1, ffi.sizeof('partial_T') }, ret = void(pt) }
  end,
  lua_tvs = function(argv, argc)
    argc = alloc_len(argc)
    return { func = 'malloc', args = { ffi.sizeof('typval_T') * argc }, ret = void(argv) }
  end,
}

local function int(n)
  return { [type_key] = int_type, value = n }
end

local function list(...)
  return populate_list(
    ffi.gc(eval.tv_list_alloc(select('#', ...)), eval.tv_list_unref),
    { ... },
    {}
  )
end

local function dict(d)
  return populate_dict(ffi.gc(eval.tv_dict_alloc(), eval.tv_dict_free), d or {}, {})
end

local callback2tbl_type_tab = nil

local function init_callback2tbl_type_tab()
  if callback2tbl_type_tab then
    return
  end
  callback2tbl_type_tab = {
    [tonumber(eval.kCallbackNone)] = function(_)
      return { type = 'none' }
    end,
    [tonumber(eval.kCallbackFuncref)] = function(cb)
      return { type = 'fref', fref = ffi.string(cb.data.funcref) }
    end,
    [tonumber(eval.kCallbackPartial)] = function(cb)
      local lua_pt = partial2lua(cb.data.partial)
      return { type = 'pt', fref = ffi.string(lua_pt.value), pt = lua_pt }
    end,
  }
end

local function callback2tbl(cb)
  init_callback2tbl_type_tab()
  return callback2tbl_type_tab[tonumber(cb.type)](cb)
end

local function tbl2callback(tbl)
  local ret = nil
  if tbl.type == 'none' then
    ret = ffi.new('Callback[1]', { { type = eval.kCallbackNone } })
  elseif tbl.type == 'fref' then
    ret = ffi.new(
      'Callback[1]',
      { { type = eval.kCallbackFuncref, data = { funcref = eval.xstrdup(tbl.fref) } } }
    )
  elseif tbl.type == 'pt' then
    local pt = ffi.gc(ffi.cast('partial_T*', eval.xcalloc(1, ffi.sizeof('partial_T'))), nil)
    ret = ffi.new(
      'Callback[1]',
      { { type = eval.kCallbackPartial, data = { partial = populate_partial(pt, tbl.pt, {}) } } }
    )
  else
    assert(false)
  end
  return ffi.gc(ffi.cast('Callback*', ret), t.callback_free)
end

local function dict_watchers(d)
  local ret = {}
  local h = d.watchers
  local q = h.next
  local qs = {}
  local key_patterns = {}
  while q ~= h do
    local qitem =
      ffi.cast('DictWatcher *', ffi.cast('char *', q) - ffi.offsetof('DictWatcher', 'node'))
    ret[#ret + 1] = {
      cb = callback2tbl(qitem.callback),
      pat = ffi.string(qitem.key_pattern, qitem.key_pattern_len),
      busy = qitem.busy,
    }
    qs[#qs + 1] = qitem
    key_patterns[#key_patterns + 1] = { qitem.key_pattern, qitem.key_pattern_len }
    q = q.next
  end
  return ret, qs, key_patterns
end

local function eval0(expr)
  local tv = ffi.gc(ffi.new('typval_T', { v_type = eval.VAR_UNKNOWN }), eval.tv_clear)
  local evalarg = ffi.new('evalarg_T', { eval_flags = eval.EVAL_EVALUATE })
  if eval.eval0(to_cstr(expr), tv, nil, evalarg) == 0 then
    return nil
  else
    return tv
  end
end

return {
  int = int,

  null_string = null_string,
  null_list = null_list,
  null_dict = null_dict,
  list_type = list_type,
  dict_type = dict_type,
  func_type = func_type,
  int_type = int_type,
  flt_type = flt_type,

  nil_value = nil_value,

  type_key = type_key,
  locks_key = locks_key,

  list = list,
  dict = dict,
  lst2tbl = lst2tbl,
  dct2tbl = dct2tbl,

  lua2typvalt = lua2typvalt,
  typvalt2lua = typvalt2lua,

  typvalt = typvalt,

  li_alloc = li_alloc,
  tv_list_item_free = tv_list_item_free,

  dict_iter = dict_iter,
  list_iter = list_iter,
  first_di = first_di,

  alloc_logging_t = alloc_logging_t,

  list_items = list_items,
  dict_items = dict_items,

  dict_watchers = dict_watchers,
  tbl2callback = tbl2callback,
  callback2tbl = callback2tbl,

  eval0 = eval0,

  empty_list = { [type_key] = list_type },
}
