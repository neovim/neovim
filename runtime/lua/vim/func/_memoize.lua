--- Module for private utility functions

--- @param argc integer?
--- @return fun(...): any
local function concat_hash(argc)
  return function(...)
    return table.concat({ ... }, '%%', 1, argc)
  end
end

--- @param idx integer
--- @return fun(...): any
local function idx_hash(idx)
  return function(...)
    return select(idx, ...)
  end
end

--- @param hash integer|string|fun(...): any
--- @return fun(...): any
local function resolve_hash(hash)
  if type(hash) == 'number' then
    hash = idx_hash(hash)
  elseif type(hash) == 'string' then
    local c = hash == 'concat' or hash:match('^concat%-(%d+)')
    if c then
      hash = concat_hash(tonumber(c))
    else
      error('invalid value for hash: ' .. hash)
    end
  end
  --- @cast hash -integer
  return hash
end

---@return table<any,table<any,any>>
local function get_weak_table()
  return setmetatable({}, { __mode = 'kv' })
end

--- @alias vim.func.Hash integer|string|fun(...): any

--- @class vim.func.MemoizeTable
--- @field clear fun(self, ...)

--- @generic F: function
--- @param hash vim.func.Hash
--- @param fn F
--- @return F
--- @overload fun(hash: vim.func.Hash, fn: fun(...): any): vim.func.MemoizeTable
return function(hash, fn)
  vim.validate({
    hash = { hash, { 'number', 'string', 'function' } },
    fn = { fn, 'function' },
  })

  local cache = get_weak_table()

  hash = resolve_hash(hash)

  local mt = {
    __call = function(_, ...)
      local key = hash(...)
      if cache[key] == nil then
        cache[key] = vim.F.pack_len(fn(...))
      end

      return vim.F.unpack_len(cache[key])
    end,
  }

  return setmetatable({
    clear = function(_, ...)
      if vim.tbl_count(cache) == 0 then
        return
      end

      if #{ ... } == 0 then
        cache = get_weak_table()
      else
        local key = hash(...)
        cache[key] = nil
      end
    end,
  }, mt)
end
