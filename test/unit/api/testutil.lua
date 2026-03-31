local t = require('test.unit.testutil')
local t_eval = require('test.unit.eval.testutil')

local cimport = t.cimport
local to_cstr = t.to_cstr
local ffi = t.ffi

local list_type = t_eval.list_type
local dict_type = t_eval.dict_type
local func_type = t_eval.func_type
local nil_value = t_eval.nil_value
local int_type = t_eval.int_type
local flt_type = t_eval.flt_type
local type_key = t_eval.type_key

local api = cimport(
  './src/nvim/api/private/defs.h',
  './src/nvim/api/private/helpers.h',
  './src/nvim/memory.h'
)

local obj2lua

local obj2lua_tab = nil

local function init_obj2lua_tab()
  if obj2lua_tab then
    return
  end
  obj2lua_tab = {
    [tonumber(api.kObjectTypeArray)] = function(obj)
      local ret = { [type_key] = list_type }
      for i = 1, tonumber(obj.data.array.size) do
        ret[i] = obj2lua(obj.data.array.items[i - 1])
      end
      if ret[1] then
        ret[type_key] = nil
      end
      return ret
    end,
    [tonumber(api.kObjectTypeDict)] = function(obj)
      local ret = {}
      for i = 1, tonumber(obj.data.dict.size) do
        local kv_pair = obj.data.dict.items[i - 1]
        ret[ffi.string(kv_pair.key.data, kv_pair.key.size)] = obj2lua(kv_pair.value)
      end
      return ret
    end,
    [tonumber(api.kObjectTypeBoolean)] = function(obj)
      if obj.data.boolean == false then
        return false
      else
        return true
      end
    end,
    [tonumber(api.kObjectTypeNil)] = function(_)
      return nil_value
    end,
    [tonumber(api.kObjectTypeFloat)] = function(obj)
      return tonumber(obj.data.floating)
    end,
    [tonumber(api.kObjectTypeInteger)] = function(obj)
      return { [type_key] = int_type, value = tonumber(obj.data.integer) }
    end,
    [tonumber(api.kObjectTypeString)] = function(obj)
      return ffi.string(obj.data.string.data, obj.data.string.size)
    end,
  }
end

obj2lua = function(obj)
  init_obj2lua_tab()
  return (
    (obj2lua_tab[tonumber(obj['type'])] or function(obj_inner)
      assert(
        false,
        'Converting ' .. tostring(tonumber(obj_inner['type'])) .. ' is not implementing yet'
      )
    end)(obj)
  )
end

local obj = function(typ, data)
  return ffi.gc(ffi.new('Object', { ['type'] = typ, data = data }), api.api_free_object)
end

local lua2obj

local lua2obj_type_tab = {
  [int_type] = function(l)
    return obj(api.kObjectTypeInteger, { integer = l.value })
  end,
  [flt_type] = function(l)
    return obj(api.kObjectTypeFloat, { floating = l })
  end,
  [list_type] = function(l)
    local len = #l
    local arr = obj(api.kObjectTypeArray, {
      array = {
        size = len,
        capacity = len,
        items = ffi.cast('Object *', api.xmalloc(len * ffi.sizeof('Object'))),
      },
    })
    for i = 1, len do
      arr.data.array.items[i - 1] = ffi.gc(lua2obj(l[i]), nil)
    end
    return arr
  end,
  [dict_type] = function(l)
    local kvs = {}
    for k, v in pairs(l) do
      if type(k) == 'string' then
        kvs[#kvs + 1] = { k, v }
      end
    end
    local len = #kvs
    local dct = obj(api.kObjectTypeDict, {
      dict = {
        size = len,
        capacity = len,
        items = ffi.cast('KeyValuePair *', api.xmalloc(len * ffi.sizeof('KeyValuePair'))),
      },
    })
    for i = 1, len do
      local key, val = unpack(kvs[i])
      dct.data.dict.items[i - 1] = ffi.new(
        'KeyValuePair',
        { key = ffi.gc(lua2obj(key), nil).data.string, value = ffi.gc(lua2obj(val), nil) }
      )
    end
    return dct
  end,
}

lua2obj = function(l)
  if type(l) == 'table' then
    if l[type_key] then
      return lua2obj_type_tab[l[type_key]](l)
    else
      if l[1] then
        return lua2obj_type_tab[list_type](l)
      else
        return lua2obj_type_tab[dict_type](l)
      end
    end
  elseif type(l) == 'number' then
    return lua2obj_type_tab[flt_type](l)
  elseif type(l) == 'boolean' then
    return obj(api.kObjectTypeBoolean, { boolean = l })
  elseif type(l) == 'string' then
    return obj(
      api.kObjectTypeString,
      { string = {
        size = #l,
        data = api.xmemdupz(to_cstr(l), #l),
      } }
    )
  elseif l == nil or l == nil_value then
    return obj(api.kObjectTypeNil, { integer = 0 })
  end
end

return {
  list_type = list_type,
  dict_type = dict_type,
  func_type = func_type,
  int_type = int_type,
  flt_type = flt_type,

  nil_value = nil_value,

  type_key = type_key,

  obj2lua = obj2lua,
  lua2obj = lua2obj,
}
