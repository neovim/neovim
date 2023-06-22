local api = vim.api

-- TODO(tjdevries): Improve option metadata so that this doesn't have to be hardcoded.
--                  Can be done in a separate PR.
local key_value_options = {
  fillchars = true,
  fcs = true,
  listchars = true,
  lcs = true,
  winhighlight = true,
  winhl = true,
}

--- Convert a vimoption_T style dictionary to the correct OptionType associated with it.
---@return string
local function get_option_metatype(name, info)
  if info.type == 'string' then
    if info.flaglist then
      return 'set'
    elseif info.commalist then
      if key_value_options[name] then
        return 'map'
      end
      return 'array'
    end
    return 'string'
  end
  return info.type
end

local options_info = setmetatable({}, {
  __index = function(t, k)
    local info = api.nvim_get_option_info(k)
    info.metatype = get_option_metatype(k, info)
    rawset(t, k, info)
    return rawget(t, k)
  end,
})

vim.env = setmetatable({}, {
  __index = function(_, k)
    local v = vim.fn.getenv(k)
    if v == vim.NIL then
      return nil
    end
    return v
  end,

  __newindex = function(_, k, v)
    vim.fn.setenv(k, v)
  end,
})

local function opt_validate(option_name, target_scope)
  local scope = options_info[option_name].scope
  if scope ~= target_scope then
    local scope_to_string = { buf = 'buffer', win = 'window' }
    error(
      string.format(
        [['%s' is a %s option, not a %s option. See ":help %s"]],
        option_name,
        scope_to_string[scope] or scope,
        scope_to_string[target_scope] or target_scope,
        option_name
      )
    )
  end
end

local function new_opt_accessor(handle, scope)
  return setmetatable({}, {
    __index = function(_, k)
      if handle == nil and type(k) == 'number' then
        return new_opt_accessor(k, scope)
      end
      opt_validate(k, scope)
      return api.nvim_get_option_value(k, { [scope] = handle or 0 })
    end,

    __newindex = function(_, k, v)
      opt_validate(k, scope)
      return api.nvim_set_option_value(k, v, { [scope] = handle or 0 })
    end,
  })
end

vim.bo = new_opt_accessor(nil, 'buf')
vim.wo = new_opt_accessor(nil, 'win')

-- vim global option
--  this ONLY sets the global option. like `setglobal`
vim.go = setmetatable({}, {
  __index = function(_, k)
    return api.nvim_get_option_value(k, { scope = 'global' })
  end,
  __newindex = function(_, k, v)
    return api.nvim_set_option_value(k, v, { scope = 'global' })
  end,
})

-- vim `set` style options.
--  it has no additional metamethod magic.
vim.o = setmetatable({}, {
  __index = function(_, k)
    return api.nvim_get_option_value(k, {})
  end,
  __newindex = function(_, k, v)
    return api.nvim_set_option_value(k, v, {})
  end,
})

---@brief [[
--- vim.opt, vim.opt_local and vim.opt_global implementation
---
--- To be used as helpers for working with options within neovim.
--- For information on how to use, see :help vim.opt
---
---@brief ]]

--- Preserves the order and does not mutate the original list
local function remove_duplicate_values(t)
  local result, seen = {}, {}
  for _, v in ipairs(t) do
    if not seen[v] then
      table.insert(result, v)
    end

    seen[v] = true
  end

  return result
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

local function passthrough(_, x)
  return x
end

local function tbl_merge(left, right)
  return vim.tbl_extend('force', left, right)
end

local function tbl_remove(t, value)
  if type(value) == 'string' then
    t[value] = nil
  else
    for _, v in ipairs(value) do
      t[v] = nil
    end
  end

  return t
end

local valid_types = {
  boolean = { 'boolean' },
  number = { 'number' },
  string = { 'string' },
  set = { 'string', 'table' },
  array = { 'string', 'table' },
  map = { 'string', 'table' },
}

-- Map of functions to take a Lua style value and convert to vimoption_T style value.
-- Each function takes (info, lua_value) -> vim_value
local to_vim_value = {
  boolean = passthrough,
  number = passthrough,
  string = passthrough,

  set = function(info, value)
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

  array = function(info, value)
    if type(value) == 'string' then
      return value
    end
    if not info.allows_duplicates then
      value = remove_duplicate_values(value)
    end
    return table.concat(value, ',')
  end,

  map = function(_, value)
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

--- Convert a Lua value to a vimoption_T value
local function convert_value_to_vim(name, info, value)
  if value == nil then
    return vim.NIL
  end

  assert_valid_value(name, value, valid_types[info.metatype])

  return to_vim_value[info.metatype](info, value)
end

-- Map of OptionType to functions that take vimoption_T values and convert to Lua values.
-- Each function takes (info, vim_value) -> lua_value
local to_lua_value = {
  boolean = passthrough,
  number = passthrough,
  string = passthrough,

  array = function(info, value)
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
      local left, right = unpack(vim.split(value, ',,,'))

      local result = {}
      vim.list_extend(result, vim.split(left, ','))
      table.insert(result, ',')
      vim.list_extend(result, vim.split(right, ','))

      table.sort(result)

      return result
    end

    if string.find(value, ',^,,', 1, true) then
      local left, right = unpack(vim.split(value, ',^,,', true))

      local result = {}
      vim.list_extend(result, vim.split(left, ','))
      table.insert(result, '^,')
      vim.list_extend(result, vim.split(right, ','))

      table.sort(result)

      return result
    end

    return vim.split(value, ',')
  end,

  set = function(info, value)
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

  map = function(info, raw_value)
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

--- Converts a vimoption_T style value to a Lua value
local function convert_value_to_lua(info, option_value)
  return to_lua_value[info.metatype](info, option_value)
end

local prepend_methods = {
  number = function()
    error("The '^' operator is not currently supported for")
  end,

  string = function(left, right)
    return right .. left
  end,

  array = function(left, right)
    for i = #right, 1, -1 do
      table.insert(left, 1, right[i])
    end

    return left
  end,

  map = tbl_merge,
  set = tbl_merge,
}

--- Handles the '^' operator
local function prepend_value(info, current, new)
  return prepend_methods[info.metatype](
    convert_value_to_lua(info, current),
    convert_value_to_lua(info, new)
  )
end

local add_methods = {
  number = function(left, right)
    return left + right
  end,

  string = function(left, right)
    return left .. right
  end,

  array = function(left, right)
    for _, v in ipairs(right) do
      table.insert(left, v)
    end

    return left
  end,

  map = tbl_merge,
  set = tbl_merge,
}

--- Handles the '+' operator
local function add_value(info, current, new)
  return add_methods[info.metatype](
    convert_value_to_lua(info, current),
    convert_value_to_lua(info, new)
  )
end

local function remove_one_item(t, val)
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

local remove_methods = {
  number = function(left, right)
    return left - right
  end,

  string = function()
    error('Subtraction not supported for strings.')
  end,

  array = function(left, right)
    if type(right) == 'string' then
      remove_one_item(left, right)
    else
      for _, v in ipairs(right) do
        remove_one_item(left, v)
      end
    end

    return left
  end,

  map = tbl_remove,
  set = tbl_remove,
}

--- Handles the '-' operator
local function remove_value(info, current, new)
  return remove_methods[info.metatype](convert_value_to_lua(info, current), new)
end

local function create_option_accessor(scope)
  local option_mt

  local function make_option(name, value)
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

  option_mt = {
    -- To set a value, instead use:
    --  opt[my_option] = value
    _set = function(self)
      local value = convert_value_to_vim(self._name, self._info, self._value)
      api.nvim_set_option_value(self._name, value, { scope = scope })
    end,

    get = function(self)
      return convert_value_to_lua(self._info, self._value)
    end,

    append = function(self, right)
      self._value = add_value(self._info, self._value, right)
      self:_set()
    end,

    __add = function(self, right)
      return make_option(self._name, add_value(self._info, self._value, right))
    end,

    prepend = function(self, right)
      self._value = prepend_value(self._info, self._value, right)
      self:_set()
    end,

    __pow = function(self, right)
      return make_option(self._name, prepend_value(self._info, self._value, right))
    end,

    remove = function(self, right)
      self._value = remove_value(self._info, self._value, right)
      self:_set()
    end,

    __sub = function(self, right)
      return make_option(self._name, remove_value(self._info, self._value, right))
    end,
  }
  option_mt.__index = option_mt

  return setmetatable({}, {
    __index = function(_, k)
      return make_option(k, api.nvim_get_option_value(k, {}))
    end,

    __newindex = function(_, k, v)
      make_option(k, v):_set()
    end,
  })
end

vim.opt = create_option_accessor()
vim.opt_local = create_option_accessor('local')
vim.opt_global = create_option_accessor('global')
