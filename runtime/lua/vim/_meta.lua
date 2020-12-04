-- prevents luacheck from making lints for setting things on vim
local vim = assert(vim)

local a = vim.api
local validate = vim.validate

local nil_wrap = vim.F.nil_wrap

local SET_TYPES = {
  SET = 0,
  LOCAL = 1,
  GLOBAL = 2,
}

local function make_meta_accessor(get, set, del, validator)
  validator = validator or function() return true end

  validate {
    get = {get, 'f'};
    set = {set, 'f'};
    del = {del, 'f', true};
    validator = {validator, 'f'};
  }

  local mt = {}
  if del then
    function mt:__newindex(k, v)
      if not validator(k) then
        return
      end

      if v == nil then
        return del(k)
      end
      return set(k, v)
    end
  else
    function mt:__newindex(k, v)
      if not validator(k) then
        return
      end
      return set(k, v)
    end
  end
  function mt:__index(k)
    if not validator(k) then
      return
    end

    return get(k)
  end
  return setmetatable({}, mt)
end

vim.b = make_meta_accessor(
  nil_wrap(function(v) return a.nvim_buf_get_var(0, v) end),
  function(v, k) return a.nvim_buf_set_var(0, v, k) end,
  function(v) return a.nvim_buf_del_var(0, v) end
)
vim.w = make_meta_accessor(
  nil_wrap(function(v) return a.nvim_win_get_var(0, v) end),
  function(v, k) return a.nvim_win_set_var(0, v, k) end,
  function(v) return a.nvim_win_del_var(0, v) end
)
vim.t = make_meta_accessor(
  nil_wrap(function(v) return a.nvim_tabpage_get_var(0, v) end),
  function(v, k) return a.nvim_tabpage_set_var(0, v, k) end,
  function(v) return a.nvim_tabpage_del_var(0, v) end
)
vim.g = make_meta_accessor(nil_wrap(a.nvim_get_var), a.nvim_set_var, a.nvim_del_var)
vim.v = make_meta_accessor(nil_wrap(a.nvim_get_vvar), a.nvim_set_vvar)

vim.env = make_meta_accessor(function(k)
  local v = vim.fn.getenv(k)
  if v == vim.NIL then
    return nil
  end
  return v
end, vim.fn.setenv)

local options_info = a.nvim_get_all_options_info()
for _, v in pairs(options_info) do
  if v.shortname ~= "" then options_info[v.shortname] = v end
end

local is_global_option = function(info) return info.scope == "global" end
local is_buffer_option = function(info) return info.scope == "buf" end
local is_window_option = function(info) return info.scope == "win" end


local reduce = vim.tbl_reduce
local filter = vim.tbl_filter

local accumulate = function(reducer, t)
  return reduce({}, reducer, t)
end

local scope_filter = function(scope)
  return function(v) return v.scope == scope end
end

local filter_options_to_scope = function(scope)
  return filter(scope_filter(scope), options_info)
end

-- [ { name = 'filetype', shortname = 'ft' }, ... ]
-- -> { 'filetype' = true, 'ft' = true, ... }
local name_accumulator = function(acc, v)
  acc[v.name] = true
  if v.shortname ~= "" then acc[v.shortname] = true end
end

local buf_options = accumulate(name_accumulator, filter_options_to_scope("buf"))
local glb_options = accumulate(name_accumulator, filter_options_to_scope("global"))
local win_options = accumulate(name_accumulator, filter_options_to_scope("win"))

vim.go = make_meta_accessor(a.nvim_get_option, a.nvim_set_option)

local function new_buf_opt_accessor(bufnr)
  local function get(k)
    if bufnr == nil and type(k) == "number" then
      return new_buf_opt_accessor(k)
    end

    return a.nvim_buf_get_option(bufnr or 0, k)
  end

  local function set(k, v)
    return a.nvim_buf_set_option(bufnr or 0, k, v)
  end

  return make_meta_accessor(get, set, nil, function(k)
    if type(k) == 'string' then
      if win_options[k] then
        error(string.format([['%s' is a window option, not a buffer option. See ":help %s"]], k, k))
      elseif glb_options[k] then
        error(string.format([['%s' is a global option, not a buffer option. See ":help %s"]], k, k))
      end
    end

    return true
  end)
end
vim.bo = new_buf_opt_accessor(nil)

local function new_win_opt_accessor(winnr)
  local function get(k)
    if winnr == nil and type(k) == "number" then
      return new_win_opt_accessor(k)
    end
    return a.nvim_win_get_option(winnr or 0, k)
  end

  local function set(k, v)
    return a.nvim_win_set_option(winnr or 0, k, v)
  end

  return make_meta_accessor(get, set, nil, function(k)
    if type(k) == 'string' then
      if buf_options[k] then
        error(string.format([['%s' is a buffer option, not a window option. See ":help %s"]], k, k))
      elseif glb_options[k] then
        error(string.format([['%s' is a global option, not a window option. See ":help %s"]], k, k))
      end
    end

    return true
  end)
end
vim.wo = new_win_opt_accessor(nil)

--[[
# Local:

buffer options: does not get copied when split
  nvim_set_option(buf_opt, value) -> sets the default for NEW buffers
    this sets the hidden global default for buffer options

  nvim_buf_set_option(...) -> sets the local value for the buffer

  set opt=value, does BOTH global default AND buffer local value
  setlocal opt=value, does ONLY buffer local value

window options: gets copied
  does not need to call nvim_set_option because nobody knows what the heck this does⸮


    Command      global value       local value ~
      :set option=value      set        set
 :setlocal option=value       -         set
:setglobal option=value      set         -
--]]
local function set_scoped_option(k, v, set_type)
  local info = options_info[k]

  -- Don't let people do setlocal with global options.
  --    That is a feature that doesn't make sense.
  if set_type == SET_TYPES.LOCAL and is_global_option(info) then
    error(string.format("Unable to setlocal option:'%s', which is a global option.", k))
  end

  -- Only `setlocal` skips setting the default/global value
  --    This will more-or-less noop for window options, but that's OK
  if set_type ~= SET_TYPES.LOCAL then
    a.nvim_set_option(k, v)
  end

  -- TODO(bfredl): this matches init.vim behavior of :set but not always runtime behavior
  if set_type ~= SET_TYPES.GLOBAL then
    if is_window_option(info) then
      a.nvim_win_set_option(0, k, v)
    elseif is_buffer_option(info) then
      a.nvim_buf_set_option(0, k, v)
    end
  end
end

local function get_scoped_option(k)
  -- TODO: use curbuf/curwin for scoped options
  return a.nvim_get_option(k)
end

vim.o = make_meta_accessor(get_scoped_option, function(k, v) return set_scoped_option(k, v, SET_TYPES.SET) end)

---@brief [[
--- vim.opt, vim.opt_local and vim.opt_global implementation
---
--- To be used as helpers for working with options within neovim.
--- For information on how to use, see :help vim.opt
---
---@brief ]]

--- Used to make sure that we don't have any values that are same in an aray.
--- This is to prevent saving redundant keys in an option to vim.
---     For some reason this is allowed?
---         (like, why would you want wildignore to contain the same thing twice?)
---
--- Preserves the order and does not mutate the original list
local remove_duplicate_values = function(t)
  local result, seen = {}, {}
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
  winhl     = true,
}

---@class OptionType
--- Option Type Enum
local OptionTypes = setmetatable({
  boolean = 0,
  number  = 1,
  string  = 2,
  array   = 3,
  map     = 4,
  set     = 5,
}, {
  __index = function(_, k) error("Not a valid OptionType: " .. k) end,
  __newindex = function(_, k) error("Cannot set a new OptionType: " .. k) end,
})

--- Convert a vimoption_T style dictionary to the correct OptionType associated with it.
---@return OptionType
local get_option_type = function(name, info)
  if info.type == "boolean" then
    return OptionTypes.boolean
  elseif info.type == "number" then
    return OptionTypes.number
  elseif info.type == "string" then
    if not info.commalist and not info.flaglist then
      return OptionTypes.string
    end

    if key_value_options[name] then
      assert(info.commalist, "Must be a comma list to use key:value style")
      return OptionTypes.map
    end

    if info.flaglist then
      return OptionTypes.set
    elseif info.commalist then
      return OptionTypes.array
    end

    error("Fallthrough in OptionTypes")
  else
    error("Not a known info.type:" .. info.type)
  end
end


--- Map of functions to take a Lua style value and convert to vimoption_T style value.
--- Each function takes (info, lua_value) -> vim_value
local to_vim_value = {
  [OptionTypes.boolean] = function(_, value) return value end,
  [OptionTypes.number] = function(_, value) return value end,
  [OptionTypes.string] = function(_, value) return value end,

  [OptionTypes.set] = function(_, value)
    if type(value) == "string" then return value end
    local result = ''
    for k in pairs(value) do
      result = result .. k
    end

    return result
  end,

  [OptionTypes.array] = function(_, value)
    if type(value) == "string" then return value end
    return table.concat(remove_duplicate_values(value), ",")
  end,

  [OptionTypes.map] = function(_, value)
    if type(value) == "string" then return value end

    local result = {}
    for opt_key, opt_value in pairs(value) do
      table.insert(result, string.format("%s:%s", opt_key, opt_value))
    end

    table.sort(result)
    return table.concat(result, ",")
  end,
}

--- Convert a lua value to a vimoption_T value
local convert_value_to_vim = function(name, info, value)
  local option_type = get_option_type(name, info)
  return to_vim_value[option_type](info, value)
end

--- Map of OptionType to functions that take vimoption_T values and conver to lua values.
--- Each function takes (info, vim_value) -> lua_value
local to_lua_value = {
  [OptionTypes.boolean] = function(_, value) return value end,
  [OptionTypes.number] = function(_, value) return value end,
  [OptionTypes.string] = function(_, value) return value end,

  [OptionTypes.array] = function(_, value)
    if type(value) == "table" then
      value = remove_duplicate_values(value)
      return value
    end

    return vim.split(value, ",")
  end,

  [OptionTypes.set] = function(info, value)
    if type(value) == "table" then return value end

    assert(info.flaglist, "That is the only one I know how to handle")

    local result = {}
    for i = 1, #value do
      result[value:sub(i, i)] = true
    end

    return result
  end,

  [OptionTypes.map] = function(info, raw_value)
    if type(raw_value) == "table" then return raw_value end

    assert(info.commalist, "Only commas are supported currently")

    local result = {}

    local comma_split = vim.split(raw_value, ",")
    for _, key_value_str in ipairs(comma_split) do
      local key, value = unpack(vim.split(key_value_str, ":"))
      key = vim.trim(key)
      value = vim.trim(value)

      result[key] = value
    end

    return result
  end,
}

--- Converts a vimoption_T style value to a Lua value
local convert_value_to_lua = function(name, info, option_value)
  local option_type = get_option_type(name, info)
  return to_lua_value[option_type](info, option_value)
end

local value_mutator = function(name, info, current, new, mutator)
  local option_type = get_option_type(name, info)
  return mutator[option_type](current, new)
end

local prepend_value = function(name, info, current, new)
  return value_mutator(
    name, info,
    convert_value_to_lua(name, info, current),
    convert_value_to_lua(name, info, new), {
      [OptionTypes.number] = function()
        error("The '^' operator is not currently supported for: " .. name)
      end,

      [OptionTypes.string] = function(left, right)
        return right .. left
      end,

      [OptionTypes.array] = function(left, right)
        for i = #right, 1, -1 do
          table.insert(left, 1, right[i])
        end

        return left
      end,

      [OptionTypes.map] = function(left, right)
        return vim.tbl_extend("force", left, right)
      end,

      [OptionTypes.set] = function(left, right)
        return vim.tbl_extend("force", left, right)
      end,
  })
end

local add_value = function(name, info, current, new)
  return value_mutator(
    name, info,
    convert_value_to_lua(name, info, current),
    convert_value_to_lua(name, info, new), {
      [OptionTypes.number] = function(left, right)
        return left + right
      end,

      [OptionTypes.string] = function(left, right)
        return left .. right
      end,

      [OptionTypes.array] = function(left, right)
        for _, v in ipairs(right) do
          table.insert(left, v)
        end

        return left
      end,

      [OptionTypes.map] = function(left, right)
        return vim.tbl_extend("force", left, right)
      end,

      [OptionTypes.set] = function(left, right)
        return vim.tbl_extend("force", left, right)
      end,
  })
end

local remove_value = function(name, info, current, new)
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

  return value_mutator(
    name, info,
    convert_value_to_lua(name, info, current),
    new, {
      [OptionTypes.number] = function(left, right)
        return left - right
      end,

      [OptionTypes.string] = function()
        error("This seems dumb... please don't do it :)")
      end,

      [OptionTypes.array] = function(left, right)
        if type(right) == "string" then
          remove_one_item(left, right)
        else
          for _, v in ipairs(right) do
            remove_one_item(left, v)
          end
        end

        return left
      end,

      [OptionTypes.map] = function(left, right)
        if type(right) == "string" then
          left[right] = nil
        else
          for _, v in ipairs(right) do
            left[v] = nil
          end
        end

        return left
      end,

      [OptionTypes.set] = function(left, right)
        if type(right) == "string" then
          left[right] = nil
        else
          for _, v in ipairs(right) do
            left[v] = nil
          end
        end

        return left
      end,
  })
end

local create_option_metatable = function(set_type)
  local set_mt, option_mt

  local make_option = function(name, value)
    -- TODO: Do the type checking for values.

    local info = assert(options_info[name], "Not a valid option name: " .. name)

    if type(value) == "table" and getmetatable(value) == option_mt then
      assert(name == value._name, "must be the same value, otherwise that's weird.")

      value = value._value
    end

    return setmetatable({
      _name = name,
      -- _value = convert_value_to_vim(name, info, value),
      _value = value,
      _info = info,
    }, option_mt)
  end

  -- TODO(tjdevries): consider supporting `nil` for set to remove the local option.
  --                  vim.cmd [[set option<]]
  --                  do not implement weird setlocal option< thing.
  --                  that seems not great

  option_mt = {
    -- To set a value, instead use:
    --  opt[my_option] = value
    _set = function(self)
      local value = convert_value_to_vim(self._name, self._info, self._value)
      set_scoped_option(self._name, value, set_type)

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
    end
  }
  option_mt.__index = option_mt

  local get_option_value = function(name)
    local info = assert(options_info[name], "Must be a valid option: " .. tostring(name))

    -- Global options are always global. Just return it.
    if is_global_option(info) then
      return a.nvim_get_option(name)
    end

    if is_buffer_option(info) then
      local was_set, value = pcall(a.nvim_buf_get_option, 0, name)
      if was_set then return value end

      if info.global_local then
        return a.nvim_get_option(name)
      end

      error("buf_get: This should not be able to happen, given my understanding of options // " .. name)
    end

    if is_window_option(info) then
      --[[
      if win_get_option == default AND option_info.was_set then
        return a.nvim_get_option
      else
        return win_get_option
      --]]
      local was_set, value = pcall(a.nvim_win_get_option, 0, name)
      if was_set then return value end

      if info.global_local then
        return a.nvim_get_option(name)
      end

      error("win_get: This should not be able to happen, given my understanding of options // " .. name)
    end

    error("This fallback case should not be possible. " .. name)
  end

  set_mt = {
    __index = function(_, k)
      return make_option(k, get_option_value(k))
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
