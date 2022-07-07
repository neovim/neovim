-- prevents luacheck from making lints for setting things on vim
local vim = assert(vim)

local a = vim.api
local validate = vim.validate

local SET_TYPES = setmetatable({
  SET = 0,
  LOCAL = 1,
  GLOBAL = 2,
}, { __index = error })

local options_info = nil
local buf_options = nil
local glb_options = nil
local win_options = nil

local function _setup()
  if options_info ~= nil then
    return
  end
  options_info = {}
  for _, v in pairs(a.nvim_get_all_options_info()) do
    options_info[v.name] = v
    if v.shortname ~= '' then
      options_info[v.shortname] = v
    end
  end

  local function get_scoped_options(scope)
    local result = {}
    for name, option_info in pairs(options_info) do
      if option_info.scope == scope then
        result[name] = true
      end
    end

    return result
  end

  buf_options = get_scoped_options('buf')
  glb_options = get_scoped_options('global')
  win_options = get_scoped_options('win')
end

local function make_meta_accessor(get, set, del, validator)
  validator = validator or function()
    return true
  end

  validate({
    get = { get, 'f' },
    set = { set, 'f' },
    del = { del, 'f', true },
    validator = { validator, 'f' },
  })

  local mt = {}
  function mt:__newindex(k, v)
    if not validator(k) then
      return
    end

    if del and v == nil then
      return del(k)
    end
    return set(k, v)
  end
  function mt:__index(k)
    if not validator(k) then
      return
    end

    return get(k)
  end
  return setmetatable({}, mt)
end

vim.env = make_meta_accessor(function(k)
  local v = vim.fn.getenv(k)
  if v == vim.NIL then
    return nil
  end
  return v
end, vim.fn.setenv)

do -- buffer option accessor
  local function new_buf_opt_accessor(bufnr)
    local function get(k)
      if bufnr == nil and type(k) == 'number' then
        return new_buf_opt_accessor(k)
      end

      return a.nvim_get_option_value(k, { buf = bufnr or 0 })
    end

    local function set(k, v)
      return a.nvim_set_option_value(k, v, { buf = bufnr or 0 })
    end

    return make_meta_accessor(get, set, nil, function(k)
      if type(k) == 'string' then
        _setup()
        if win_options[k] then
          error(
            string.format([['%s' is a window option, not a buffer option. See ":help %s"]], k, k)
          )
        elseif glb_options[k] then
          error(
            string.format([['%s' is a global option, not a buffer option. See ":help %s"]], k, k)
          )
        end
      end

      return true
    end)
  end

  vim.bo = new_buf_opt_accessor(nil)
end

do -- window option accessor
  local function new_win_opt_accessor(winnr)
    local function get(k)
      if winnr == nil and type(k) == 'number' then
        return new_win_opt_accessor(k)
      end
      return a.nvim_get_option_value(k, { win = winnr or 0 })
    end

    local function set(k, v)
      return a.nvim_set_option_value(k, v, { win = winnr or 0 })
    end

    return make_meta_accessor(get, set, nil, function(k)
      if type(k) == 'string' then
        _setup()
        if buf_options[k] then
          error(
            string.format([['%s' is a buffer option, not a window option. See ":help %s"]], k, k)
          )
        elseif glb_options[k] then
          error(
            string.format([['%s' is a global option, not a window option. See ":help %s"]], k, k)
          )
        end
      end

      return true
    end)
  end

  vim.wo = new_win_opt_accessor(nil)
end

-- vim global option
--  this ONLY sets the global option. like `setglobal`
vim.go = make_meta_accessor(function(k)
  return a.nvim_get_option_value(k, { scope = 'global' })
end, function(k, v)
  return a.nvim_set_option_value(k, v, { scope = 'global' })
end)

-- vim `set` style options.
--  it has no additional metamethod magic.
vim.o = make_meta_accessor(function(k)
  return a.nvim_get_option_value(k, {})
end, function(k, v)
  return a.nvim_set_option_value(k, v, {})
end)

---@brief [[
--- vim.opt, vim.opt_local and vim.opt_global implementation
---
--- To be used as helpers for working with options within neovim.
--- For information on how to use, see :help vim.opt
---
---@brief ]]

--- Preserves the order and does not mutate the original list
local remove_duplicate_values = function(t)
  local result, seen = {}, {}
  if type(t) == 'function' then
    error(debug.traceback('asdf'))
  end
  for _, v in ipairs(t) do
    if not seen[v] then
      table.insert(result, v)
    end

    seen[v] = true
  end

  return result
end

-- TODO(tjdevries): Improve option metadata so that this doesn't have to be hardcoded.
--                  Can be done in a separate PR.
local key_value_options = {
  fillchars = true,
  listchars = true,
  winhl = true,
}

---@class OptionTypes
--- Option Type Enum
local OptionTypes = setmetatable({
  BOOLEAN = 0,
  NUMBER = 1,
  STRING = 2,
  ARRAY = 3,
  MAP = 4,
  SET = 5,
}, {
  __index = function(_, k)
    error('Not a valid OptionType: ' .. k)
  end,
  __newindex = function(_, k)
    error('Cannot set a new OptionType: ' .. k)
  end,
})

--- Convert a vimoption_T style dictionary to the correct OptionType associated with it.
---@return OptionType
local get_option_type = function(name, info)
  if info.type == 'boolean' then
    return OptionTypes.BOOLEAN
  elseif info.type == 'number' then
    return OptionTypes.NUMBER
  elseif info.type == 'string' then
    if not info.commalist and not info.flaglist then
      return OptionTypes.STRING
    end

    if key_value_options[name] then
      assert(info.commalist, 'Must be a comma list to use key:value style')
      return OptionTypes.MAP
    end

    if info.flaglist then
      return OptionTypes.SET
    elseif info.commalist then
      return OptionTypes.ARRAY
    end

    error('Fallthrough in OptionTypes')
  else
    error('Not a known info.type:' .. info.type)
  end
end

-- Check whether the OptionTypes is allowed for vim.opt
-- If it does not match, throw an error which indicates which option causes the error.
local function assert_valid_value(name, value, types)
  local type_of_value = type(value)
  for _, valid_type in ipairs(types) do
    if valid_type == type_of_value then
      return
    end
  end

  error(
    string.format(
      "Invalid option type '%s' for '%s', should be %s",
      type_of_value,
      name,
      table.concat(types, ' or ')
    )
  )
end

local valid_types = {
  [OptionTypes.BOOLEAN] = { 'boolean' },
  [OptionTypes.NUMBER] = { 'number' },
  [OptionTypes.STRING] = { 'string' },
  [OptionTypes.SET] = { 'string', 'table' },
  [OptionTypes.ARRAY] = { 'string', 'table' },
  [OptionTypes.MAP] = { 'string', 'table' },
}

--- Convert a lua value to a vimoption_T value
local convert_value_to_vim = (function()
  -- Map of functions to take a Lua style value and convert to vimoption_T style value.
  -- Each function takes (info, lua_value) -> vim_value
  local to_vim_value = {
    [OptionTypes.BOOLEAN] = function(_, value)
      return value
    end,
    [OptionTypes.NUMBER] = function(_, value)
      return value
    end,
    [OptionTypes.STRING] = function(_, value)
      return value
    end,

    [OptionTypes.SET] = function(info, value)
      if type(value) == 'string' then
        return value
      end

      if info.flaglist and info.commalist then
        local keys = {}
        for k, v in pairs(value) do
          if v then
            table.insert(keys, k)
          end
        end

        table.sort(keys)
        return table.concat(keys, ',')
      else
        local result = ''
        for k, v in pairs(value) do
          if v then
            result = result .. k
          end
        end

        return result
      end
    end,

    [OptionTypes.ARRAY] = function(info, value)
      if type(value) == 'string' then
        return value
      end
      if not info.allows_duplicates then
        value = remove_duplicate_values(value)
      end
      return table.concat(value, ',')
    end,

    [OptionTypes.MAP] = function(_, value)
      if type(value) == 'string' then
        return value
      end

      local result = {}
      for opt_key, opt_value in pairs(value) do
        table.insert(result, string.format('%s:%s', opt_key, opt_value))
      end

      table.sort(result)
      return table.concat(result, ',')
    end,
  }

  return function(name, info, value)
    if value == nil then
      return vim.NIL
    end

    local option_type = get_option_type(name, info)
    assert_valid_value(name, value, valid_types[option_type])

    return to_vim_value[option_type](info, value)
  end
end)()

--- Converts a vimoption_T style value to a Lua value
local convert_value_to_lua = (function()
  -- Map of OptionType to functions that take vimoption_T values and convert to lua values.
  -- Each function takes (info, vim_value) -> lua_value
  local to_lua_value = {
    [OptionTypes.BOOLEAN] = function(_, value)
      return value
    end,
    [OptionTypes.NUMBER] = function(_, value)
      return value
    end,
    [OptionTypes.STRING] = function(_, value)
      return value
    end,

    [OptionTypes.ARRAY] = function(info, value)
      if type(value) == 'table' then
        if not info.allows_duplicates then
          value = remove_duplicate_values(value)
        end

        return value
      end

      -- Empty strings mean that there is nothing there,
      -- so empty table should be returned.
      if value == '' then
        return {}
      end

      -- Handles unescaped commas in a list.
      if string.find(value, ',,,') then
        local comma_split = vim.split(value, ',,,')
        local left = comma_split[1]
        local right = comma_split[2]

        local result = {}
        vim.list_extend(result, vim.split(left, ','))
        table.insert(result, ',')
        vim.list_extend(result, vim.split(right, ','))

        table.sort(result)

        return result
      end

      if string.find(value, ',^,,', 1, true) then
        local comma_split = vim.split(value, ',^,,', true)
        local left = comma_split[1]
        local right = comma_split[2]

        local result = {}
        vim.list_extend(result, vim.split(left, ','))
        table.insert(result, '^,')
        vim.list_extend(result, vim.split(right, ','))

        table.sort(result)

        return result
      end

      return vim.split(value, ',')
    end,

    [OptionTypes.SET] = function(info, value)
      if type(value) == 'table' then
        return value
      end

      -- Empty strings mean that there is nothing there,
      -- so empty table should be returned.
      if value == '' then
        return {}
      end

      assert(info.flaglist, 'That is the only one I know how to handle')

      if info.flaglist and info.commalist then
        local split_value = vim.split(value, ',')
        local result = {}
        for _, v in ipairs(split_value) do
          result[v] = true
        end

        return result
      else
        local result = {}
        for i = 1, #value do
          result[value:sub(i, i)] = true
        end

        return result
      end
    end,

    [OptionTypes.MAP] = function(info, raw_value)
      if type(raw_value) == 'table' then
        return raw_value
      end

      assert(info.commalist, 'Only commas are supported currently')

      local result = {}

      local comma_split = vim.split(raw_value, ',')
      for _, key_value_str in ipairs(comma_split) do
        local key, value = unpack(vim.split(key_value_str, ':'))
        key = vim.trim(key)

        result[key] = value
      end

      return result
    end,
  }

  return function(name, info, option_value)
    return to_lua_value[get_option_type(name, info)](info, option_value)
  end
end)()

--- Handles the mutation of various different values.
local value_mutator = function(name, info, current, new, mutator)
  return mutator[get_option_type(name, info)](current, new)
end

--- Handles the '^' operator
local prepend_value = (function()
  local methods = {
    [OptionTypes.NUMBER] = function()
      error("The '^' operator is not currently supported for")
    end,

    [OptionTypes.STRING] = function(left, right)
      return right .. left
    end,

    [OptionTypes.ARRAY] = function(left, right)
      for i = #right, 1, -1 do
        table.insert(left, 1, right[i])
      end

      return left
    end,

    [OptionTypes.MAP] = function(left, right)
      return vim.tbl_extend('force', left, right)
    end,

    [OptionTypes.SET] = function(left, right)
      return vim.tbl_extend('force', left, right)
    end,
  }

  return function(name, info, current, new)
    return value_mutator(
      name,
      info,
      convert_value_to_lua(name, info, current),
      convert_value_to_lua(name, info, new),
      methods
    )
  end
end)()

--- Handles the '+' operator
local add_value = (function()
  local methods = {
    [OptionTypes.NUMBER] = function(left, right)
      return left + right
    end,

    [OptionTypes.STRING] = function(left, right)
      return left .. right
    end,

    [OptionTypes.ARRAY] = function(left, right)
      for _, v in ipairs(right) do
        table.insert(left, v)
      end

      return left
    end,

    [OptionTypes.MAP] = function(left, right)
      return vim.tbl_extend('force', left, right)
    end,

    [OptionTypes.SET] = function(left, right)
      return vim.tbl_extend('force', left, right)
    end,
  }

  return function(name, info, current, new)
    return value_mutator(
      name,
      info,
      convert_value_to_lua(name, info, current),
      convert_value_to_lua(name, info, new),
      methods
    )
  end
end)()

--- Handles the '-' operator
local remove_value = (function()
  local remove_one_item = function(t, val)
    if vim.tbl_islist(t) then
      local remove_index = nil
      for i, v in ipairs(t) do
        if v == val then
          remove_index = i
        end
      end

      if remove_index then
        table.remove(t, remove_index)
      end
    else
      t[val] = nil
    end
  end

  local methods = {
    [OptionTypes.NUMBER] = function(left, right)
      return left - right
    end,

    [OptionTypes.STRING] = function()
      error('Subtraction not supported for strings.')
    end,

    [OptionTypes.ARRAY] = function(left, right)
      if type(right) == 'string' then
        remove_one_item(left, right)
      else
        for _, v in ipairs(right) do
          remove_one_item(left, v)
        end
      end

      return left
    end,

    [OptionTypes.MAP] = function(left, right)
      if type(right) == 'string' then
        left[right] = nil
      else
        for _, v in ipairs(right) do
          left[v] = nil
        end
      end

      return left
    end,

    [OptionTypes.SET] = function(left, right)
      if type(right) == 'string' then
        left[right] = nil
      else
        for _, v in ipairs(right) do
          left[v] = nil
        end
      end

      return left
    end,
  }

  return function(name, info, current, new)
    return value_mutator(name, info, convert_value_to_lua(name, info, current), new, methods)
  end
end)()

local create_option_metatable = function(set_type)
  local set_mt, option_mt

  local make_option = function(name, value)
    _setup()
    local info = assert(options_info[name], 'Not a valid option name: ' .. name)

    if type(value) == 'table' and getmetatable(value) == option_mt then
      assert(name == value._name, "must be the same value, otherwise that's weird.")

      value = value._value
    end

    return setmetatable({
      _name = name,
      _value = value,
      _info = info,
    }, option_mt)
  end

  local scope
  if set_type == SET_TYPES.GLOBAL then
    scope = 'global'
  elseif set_type == SET_TYPES.LOCAL then
    scope = 'local'
  end

  option_mt = {
    -- To set a value, instead use:
    --  opt[my_option] = value
    _set = function(self)
      local value = convert_value_to_vim(self._name, self._info, self._value)
      a.nvim_set_option_value(self._name, value, { scope = scope })

      return self
    end,

    get = function(self)
      return convert_value_to_lua(self._name, self._info, self._value)
    end,

    append = function(self, right)
      return self:__add(right):_set()
    end,

    __add = function(self, right)
      return make_option(self._name, add_value(self._name, self._info, self._value, right))
    end,

    prepend = function(self, right)
      return self:__pow(right):_set()
    end,

    __pow = function(self, right)
      return make_option(self._name, prepend_value(self._name, self._info, self._value, right))
    end,

    remove = function(self, right)
      return self:__sub(right):_set()
    end,

    __sub = function(self, right)
      return make_option(self._name, remove_value(self._name, self._info, self._value, right))
    end,
  }
  option_mt.__index = option_mt

  set_mt = {
    __index = function(_, k)
      return make_option(k, a.nvim_get_option_value(k, { scope = scope }))
    end,

    __newindex = function(_, k, v)
      local opt = make_option(k, v)
      opt:_set()
    end,
  }

  return set_mt
end

vim.opt = setmetatable({}, create_option_metatable(SET_TYPES.SET))
vim.opt_local = setmetatable({}, create_option_metatable(SET_TYPES.LOCAL))
vim.opt_global = setmetatable({}, create_option_metatable(SET_TYPES.GLOBAL))
