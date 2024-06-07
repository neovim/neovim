--- @brief Nvim Lua provides an interface or "bridge" to Vimscript variables and
--- functions, and editor commands and options.
---
--- Objects passed over this bridge are COPIED (marshalled): there are no
--- "references". |lua-guide-variables| For example, using `vim.fn.remove()` on
--- a Lua list copies the list object to Vimscript and does NOT modify the Lua
--- list:
---
--- ```lua
--- local list = { 1, 2, 3 }
--- vim.fn.remove(list, 0)
--- vim.print(list)  --> "{ 1, 2, 3 }"
--- ```

--- @brief <pre>help
--- vim.call({func}, {...})                                           *vim.call()*
---     Invokes |vim-function| or |user-function| {func} with arguments {...}.
---     See also |vim.fn|.
---     Equivalent to: >lua
---         vim.fn[func]({...})
--- <
--- vim.cmd({command})
---     See |vim.cmd()|.
---
--- vim.fn.{func}({...})                                                  *vim.fn*
---     Invokes |vim-function| or |user-function| {func} with arguments {...}.
---     To call autoload functions, use the syntax: >lua
---         vim.fn['some#function']({...})
--- <
---     Unlike vim.api.|nvim_call_function()| this converts directly between Vim
---     objects and Lua objects. If the Vim function returns a float, it will be
---     represented directly as a Lua number. Empty lists and dictionaries both
---     are represented by an empty table.
---
---     Note: |v:null| values as part of the return value is represented as
---     |vim.NIL| special value
---
---     Note: vim.fn keys are generated lazily, thus `pairs(vim.fn)` only
---     enumerates functions that were called at least once.
---
---     Note: The majority of functions cannot run in |api-fast| callbacks with some
---     undocumented exceptions which are allowed.
---
---                                                            *lua-vim-variables*
--- The Vim editor global dictionaries |g:| |w:| |b:| |t:| |v:| can be accessed
--- from Lua conveniently and idiomatically by referencing the `vim.*` Lua tables
--- described below. In this way you can easily read and modify global Vimscript
--- variables from Lua.
---
--- Example: >lua
---
---     vim.g.foo = 5     -- Set the g:foo Vimscript variable.
---     print(vim.g.foo)  -- Get and print the g:foo Vimscript variable.
---     vim.g.foo = nil   -- Delete (:unlet) the Vimscript variable.
---     vim.b[2].foo = 6  -- Set b:foo for buffer 2
--- <
---
--- Note that setting dictionary fields directly will not write them back into
--- Nvim. This is because the index into the namespace simply returns a copy.
--- Instead the whole dictionary must be written as one. This can be achieved by
--- creating a short-lived temporary.
---
--- Example: >lua
---
---     vim.g.my_dict.field1 = 'value'  -- Does not work
---
---     local my_dict = vim.g.my_dict   --
---     my_dict.field1 = 'value'        -- Instead do
---     vim.g.my_dict = my_dict         --
---
--- vim.g                                                                  *vim.g*
---     Global (|g:|) editor variables.
---     Key with no value returns `nil`.
---
--- vim.b                                                                  *vim.b*
---     Buffer-scoped (|b:|) variables for the current buffer.
---     Invalid or unset key returns `nil`. Can be indexed with
---     an integer to access variables for a specific buffer.
---
--- vim.w                                                                  *vim.w*
---     Window-scoped (|w:|) variables for the current window.
---     Invalid or unset key returns `nil`. Can be indexed with
---     an integer to access variables for a specific window.
---
--- vim.t                                                                  *vim.t*
---     Tabpage-scoped (|t:|) variables for the current tabpage.
---     Invalid or unset key returns `nil`. Can be indexed with
---     an integer to access variables for a specific tabpage.
---
--- vim.v                                                                  *vim.v*
---     |v:| variables.
---     Invalid or unset key returns `nil`.
--- </pre>

local api = vim.api

-- TODO(tjdevries): Improve option metadata so that this doesn't have to be hardcoded.
local key_value_options = {
  fillchars = true,
  fcs = true,
  listchars = true,
  lcs = true,
  winhighlight = true,
  winhl = true,
}

--- @nodoc
--- @class vim._option.Info : vim.api.keyset.get_option_info
--- @field metatype 'boolean'|'string'|'number'|'map'|'array'|'set'

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

--- @param name string
--- @return vim._option.Info
local function get_options_info(name)
  local info = api.nvim_get_option_info2(name, {})
  --- @cast info vim._option.Info
  info.metatype = get_option_metatype(name, info)
  return info
end

--- Environment variables defined in the editor session.
--- See |expand-env| and |:let-environment| for the Vimscript behavior.
--- Invalid or unset key returns `nil`.
---
--- Example:
---
--- ```lua
--- vim.env.FOO = 'bar'
--- print(vim.env.TERM)
--- ```
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

local function new_buf_opt_accessor(bufnr)
  return setmetatable({}, {
    __index = function(_, k)
      if bufnr == nil and type(k) == 'number' then
        return new_buf_opt_accessor(k)
      end
      return api.nvim_get_option_value(k, { buf = bufnr or 0 })
    end,

    __newindex = function(_, k, v)
      return api.nvim_set_option_value(k, v, { buf = bufnr or 0 })
    end,
  })
end

local function new_win_opt_accessor(winid, bufnr)
  return setmetatable({}, {
    __index = function(_, k)
      if bufnr == nil and type(k) == 'number' then
        if winid == nil then
          return new_win_opt_accessor(k)
        else
          return new_win_opt_accessor(winid, k)
        end
      end

      if bufnr ~= nil and bufnr ~= 0 then
        error('only bufnr=0 is supported')
      end

      -- TODO(lewis6991): allow passing both buf and win to nvim_get_option_value
      return api.nvim_get_option_value(k, {
        scope = bufnr and 'local' or nil,
        win = winid or 0,
      })
    end,

    __newindex = function(_, k, v)
      -- TODO(lewis6991): allow passing both buf and win to nvim_set_option_value
      return api.nvim_set_option_value(k, v, {
        scope = bufnr and 'local' or nil,
        win = winid or 0,
      })
    end,
  })
end

--- @brief <pre>help
---                                                                  *lua-options*
---                                                              *lua-vim-options*
---                                                                  *lua-vim-set*
---                                                             *lua-vim-setlocal*
---
--- Vim options can be accessed through |vim.o|, which behaves like Vimscript
--- |:set|.
---
---     Examples: ~
---
---     To set a boolean toggle:
---         Vimscript: `set number`
---         Lua:       `vim.o.number = true`
---
---     To set a string value:
---         Vimscript: `set wildignore=*.o,*.a,__pycache__`
---         Lua:       `vim.o.wildignore = '*.o,*.a,__pycache__'`
---
--- Similarly, there is |vim.bo| and |vim.wo| for setting buffer-scoped and
--- window-scoped options. Note that this must NOT be confused with
--- |local-options| and |:setlocal|. There is also |vim.go| that only accesses the
--- global value of a |global-local| option, see |:setglobal|.
--- </pre>

--- Get or set |options|. Like `:set`. Invalid key is an error.
---
--- Note: this works on both buffer-scoped and window-scoped options using the
--- current buffer and window.
---
--- Example:
---
--- ```lua
--- vim.o.cmdheight = 4
--- print(vim.o.columns)
--- print(vim.o.foo)     -- error: invalid key
--- ```
vim.o = setmetatable({}, {
  __index = function(_, k)
    return api.nvim_get_option_value(k, {})
  end,
  __newindex = function(_, k, v)
    return api.nvim_set_option_value(k, v, {})
  end,
})

--- Get or set global |options|. Like `:setglobal`. Invalid key is
--- an error.
---
--- Note: this is different from |vim.o| because this accesses the global
--- option value and thus is mostly useful for use with |global-local|
--- options.
---
--- Example:
---
--- ```lua
--- vim.go.cmdheight = 4
--- print(vim.go.columns)
--- print(vim.go.bar)     -- error: invalid key
--- ```
vim.go = setmetatable({}, {
  __index = function(_, k)
    return api.nvim_get_option_value(k, { scope = 'global' })
  end,
  __newindex = function(_, k, v)
    return api.nvim_set_option_value(k, v, { scope = 'global' })
  end,
})

--- Get or set buffer-scoped |options| for the buffer with number {bufnr}.
--- If {bufnr} is omitted then the current buffer is used.
--- Invalid {bufnr} or key is an error.
---
--- Note: this is equivalent to `:setlocal` for |global-local| options and `:set` otherwise.
---
--- Example:
---
--- ```lua
--- local bufnr = vim.api.nvim_get_current_buf()
--- vim.bo[bufnr].buflisted = true    -- same as vim.bo.buflisted = true
--- print(vim.bo.comments)
--- print(vim.bo.baz)                 -- error: invalid key
--- ```
vim.bo = new_buf_opt_accessor()

--- Get or set window-scoped |options| for the window with handle {winid} and
--- buffer with number {bufnr}. Like `:setlocal` if setting a |global-local| option
--- or if {bufnr} is provided, like `:set` otherwise. If {winid} is omitted then
--- the current window is used. Invalid {winid}, {bufnr} or key is an error.
---
--- Note: only {bufnr} with value `0` (the current buffer in the window) is
--- supported.
---
--- Example:
---
--- ```lua
--- local winid = vim.api.nvim_get_current_win()
--- vim.wo[winid].number = true    -- same as vim.wo.number = true
--- print(vim.wo.foldmarker)
--- print(vim.wo.quux)             -- error: invalid key
--- vim.wo[winid][0].spell = false -- like ':setlocal nospell'
--- ```
vim.wo = new_win_opt_accessor()

--- vim.opt, vim.opt_local and vim.opt_global implementation
---
--- To be used as helpers for working with options within neovim.
--- For information on how to use, see :help vim.opt

--- Preserves the order and does not mutate the original list
--- @generic T
--- @param t T[]
--- @return T[]
local function remove_duplicate_values(t)
  --- @type table, table<any,true>
  local result, seen = {}, {}
  for _, v in
    ipairs(t --[[@as any[] ]])
  do
    if not seen[v] then
      table.insert(result, v)
    end

    seen[v] = true
  end

  return result
end

--- Check whether the OptionTypes is allowed for vim.opt
--- If it does not match, throw an error which indicates which option causes the error.
--- @param name any
--- @param value any
--- @param types string[]
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

--- @param t table<any,any>
--- @param value any|any[]
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

  --- @param info vim._option.Info
  --- @param value string|table<string,true>
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

  --- @param info vim._option.Info
  --- @param value string|string[]
  array = function(info, value)
    if type(value) == 'string' then
      return value
    end
    if not info.allows_duplicates then
      value = remove_duplicate_values(value)
    end
    return table.concat(value, ',')
  end,

  --- @param value string|table<string,string>
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
    if value:find(',,,') then
      --- @type string, string
      local left, right = unpack(vim.split(value, ',,,'))

      local result = {}
      vim.list_extend(result, vim.split(left, ','))
      table.insert(result, ',')
      vim.list_extend(result, vim.split(right, ','))

      table.sort(result)

      return result
    end

    if value:find(',^,,', 1, true) then
      --- @type string, string
      local left, right = unpack(vim.split(value, ',^,,', { plain = true }))

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

    local result = {} --- @type table<string,true>

    if info.flaglist and info.commalist then
      local split_value = vim.split(value, ',')
      for _, v in ipairs(split_value) do
        result[v] = true
      end
    else
      for i = 1, #value do
        result[value:sub(i, i)] = true
      end
    end

    return result
  end,

  map = function(info, raw_value)
    if type(raw_value) == 'table' then
      return raw_value
    end

    assert(info.commalist, 'Only commas are supported currently')

    local result = {} --- @type table<string,string>

    local comma_split = vim.split(raw_value, ',')
    for _, key_value_str in ipairs(comma_split) do
      --- @type string, string
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
  --- @param left integer
  --- @param right integer
  number = function(left, right)
    return left + right
  end,

  --- @param left string
  --- @param right string
  string = function(left, right)
    return left .. right
  end,

  --- @param left string[]
  --- @param right string[]
  --- @return string[]
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

--- @param t table<any,any>
--- @param val any
local function remove_one_item(t, val)
  if vim.islist(t) then
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
  --- @param left integer
  --- @param right integer
  number = function(left, right)
    return left - right
  end,

  string = function()
    error('Subtraction not supported for strings.')
  end,

  --- @param left string[]
  --- @param right string[]
  --- @return string[]
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
    local info = assert(get_options_info(name), 'Not a valid option name: ' .. name)

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
      -- vim.opt_global must get global value only
      -- vim.opt_local may fall back to global value like vim.opt
      local opts = { scope = scope == 'global' and 'global' or nil }
      return make_option(k, api.nvim_get_option_value(k, opts))
    end,

    __newindex = function(_, k, v)
      make_option(k, v):_set()
    end,
  })
end

--- @brief <pre>help
---                                                                           *vim.opt_local*
---                                                                        *vim.opt_global*
---                                                                               *vim.opt*
---
---
--- A special interface |vim.opt| exists for conveniently interacting with list-
--- and map-style option from Lua: It allows accessing them as Lua tables and
--- offers object-oriented method for adding and removing entries.
---
---     Examples: ~
---
---     The following methods of setting a list-style option are equivalent:
---         In Vimscript: >vim
---             set wildignore=*.o,*.a,__pycache__
--- <
---         In Lua using `vim.o`: >lua
---             vim.o.wildignore = '*.o,*.a,__pycache__'
--- <
---         In Lua using `vim.opt`: >lua
---             vim.opt.wildignore = { '*.o', '*.a', '__pycache__' }
--- <
---     To replicate the behavior of |:set+=|, use: >lua
---
---         vim.opt.wildignore:append { "*.pyc", "node_modules" }
--- <
---     To replicate the behavior of |:set^=|, use: >lua
---
---         vim.opt.wildignore:prepend { "new_first_value" }
--- <
---     To replicate the behavior of |:set-=|, use: >lua
---
---         vim.opt.wildignore:remove { "node_modules" }
--- <
---     The following methods of setting a map-style option are equivalent:
---         In Vimscript: >vim
---             set listchars=space:_,tab:>~
--- <
---         In Lua using `vim.o`: >lua
---             vim.o.listchars = 'space:_,tab:>~'
--- <
---         In Lua using `vim.opt`: >lua
---             vim.opt.listchars = { space = '_', tab = '>~' }
--- <
---
--- Note that |vim.opt| returns an `Option` object, not the value of the option,
--- which is accessed through |vim.opt:get()|:
---
---     Examples: ~
---
---     The following methods of getting a list-style option are equivalent:
---         In Vimscript: >vim
---             echo wildignore
--- <
---         In Lua using `vim.o`: >lua
---             print(vim.o.wildignore)
--- <
---         In Lua using `vim.opt`: >lua
---             vim.print(vim.opt.wildignore:get())
--- <
---
--- In any of the above examples, to replicate the behavior |:setlocal|, use
--- `vim.opt_local`. Additionally, to replicate the behavior of |:setglobal|, use
--- `vim.opt_global`.
--- </pre>

--- @nodoc
--- @class vim.Option
local Option = {} -- luacheck: no unused

--- Returns a Lua-representation of the option. Boolean, number and string
--- values will be returned in exactly the same fashion.
---
--- For values that are comma-separated lists, an array will be returned with
--- the values as entries in the array:
---
--- ```lua
--- vim.cmd [[set wildignore=*.pyc,*.o]]
---
--- vim.print(vim.opt.wildignore:get())
--- -- { "*.pyc", "*.o", }
---
--- for _, ignore_pattern in ipairs(vim.opt.wildignore:get()) do
---     print("Will ignore:", ignore_pattern)
--- end
--- -- Will ignore: *.pyc
--- -- Will ignore: *.o
--- ```
---
--- For values that are comma-separated maps, a table will be returned with
--- the names as keys and the values as entries:
---
--- ```lua
--- vim.cmd [[set listchars=space:_,tab:>~]]
---
--- vim.print(vim.opt.listchars:get())
--- --  { space = "_", tab = ">~", }
---
--- for char, representation in pairs(vim.opt.listchars:get()) do
---     print(char, "=>", representation)
--- end
--- ```
---
--- For values that are lists of flags, a set will be returned with the flags
--- as keys and `true` as entries.
---
--- ```lua
--- vim.cmd [[set formatoptions=njtcroql]]
---
--- vim.print(vim.opt.formatoptions:get())
--- -- { n = true, j = true, c = true, ... }
---
--- local format_opts = vim.opt.formatoptions:get()
--- if format_opts.j then
---     print("J is enabled!")
--- end
--- ```
---@return string|integer|boolean|nil value of option
function Option:get() end

--- Append a value to string-style options. See |:set+=|
---
--- These are equivalent:
---
--- ```lua
--- vim.opt.formatoptions:append('j')
--- vim.opt.formatoptions = vim.opt.formatoptions + 'j'
--- ```
---@param value string Value to append
---@diagnostic disable-next-line:unused-local used for gen_vimdoc
function Option:append(value) end -- luacheck: no unused

--- Prepend a value to string-style options. See |:set^=|
---
--- These are equivalent:
---
--- ```lua
--- vim.opt.wildignore:prepend('*.o')
--- vim.opt.wildignore = vim.opt.wildignore ^ '*.o'
--- ```
---@param value string Value to prepend
---@diagnostic disable-next-line:unused-local used for gen_vimdoc
function Option:prepend(value) end -- luacheck: no unused

--- Remove a value from string-style options. See |:set-=|
---
--- These are equivalent:
---
--- ```lua
--- vim.opt.wildignore:remove('*.pyc')
--- vim.opt.wildignore = vim.opt.wildignore - '*.pyc'
--- ```
---@param value string Value to remove
---@diagnostic disable-next-line:unused-local used for gen_vimdoc
function Option:remove(value) end -- luacheck: no unused

---@private
vim.opt = create_option_accessor()

---@private
vim.opt_local = create_option_accessor('local')

---@private
vim.opt_global = create_option_accessor('global')
