--- Module for private utility functions

--- @alias vim.func.MemoObj { _hash: (fun(...): any), _weak: boolean?, _cache: table<any> }

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

--- @param weak boolean?
--- @return table
local create_cache = function(weak)
  return setmetatable({}, {
    __mode = weak ~= false and 'kv',
  })
end

--- @generic F: function
--- @param hash integer|string|fun(...): any
--- @param fn F
--- @param weak? boolean
--- @return F
return function(hash, fn, weak)
  vim.validate('hash', hash, { 'number', 'string', 'function' })
  vim.validate('fn', fn, 'function')
  vim.validate('weak', weak, 'boolean', true)

  --- @type vim.func.MemoObj
  local obj = {
    _cache = create_cache(weak),
    _hash = resolve_hash(hash),
    _weak = weak,
    --- @param self vim.func.MemoObj
    clear = function(self, ...)
      if select('#', ...) == 0 then
        self._cache = create_cache(self._weak)
        return
      end
      local key = self._hash(...)
      self._cache[key] = nil
    end,
  }

  return setmetatable(obj, {
    --- @param self vim.func.MemoObj
    __call = function(self, ...)
      local key = self._hash(...)
      local cache = self._cache
      if cache[key] == nil then
        cache[key] = vim.F.pack_len(fn(...))
      end
      return vim.F.unpack_len(cache[key])
    end,
  })
end
