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

local M = {}
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

--- Gets or sets environment variables in the current editor process. See |expand-env| and
--- |:let-environment| for the Vimscript behavior. Invalid or unset key returns `nil`.
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
      api.nvim_set_option_value(k, v, { buf = bufnr or 0 })
    end,
  })
end

local function new_win_opt_accessor(winid, bufnr)
  -- TODO(lewis6991): allow passing both buf and win to nvim_get_option_value
  if bufnr ~= nil and bufnr ~= 0 then
    error('only bufnr=0 is supported')
  end

  return setmetatable({}, {
    __index = function(_, k)
      if bufnr == nil and type(k) == 'number' then
        if winid == nil then
          return new_win_opt_accessor(k)
        else
          return new_win_opt_accessor(winid, k)
        end
      end

      return api.nvim_get_option_value(k, {
        scope = bufnr and 'local' or nil,
        win = winid or 0,
      })
    end,

    __newindex = function(_, k, v)
      api.nvim_set_option_value(k, v, {
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
---         Lua (alt): `vim.o.wildignore = { '*.o', '*.a', '__pycache__' }`
---
---     To set a key:value type option:
---         Vimscript: `set listchars=eol:~,space:-`
---         Lua:       `vim.o.listchars = 'eol:~,space:-'`
---         Lua (alt): `vim.o.listchars = { eol = '~', space = '-' }`
---
--- Similarly, there is |vim.bo| and |vim.wo| for setting buffer-scoped and
--- window-scoped options. Note that this must NOT be confused with
--- |local-options| and |:setlocal|. There is also |vim.go| that only accesses the
--- global value of a |global-local| option, see |:setglobal|.
--- </pre>

--- Gets or sets |options|. Works like `:set`, so buffer/window-scoped options target the current
--- buffer/window. Invalid key is an error.
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
    api.nvim_set_option_value(k, v, {})
  end,
})

--- Gets or sets global |options|. Like `:setglobal`. Invalid key is an error.
---
--- Note: unlike |vim.o|, this accesses the global option value and thus is mostly useful
--- with |global-local| options.
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
    api.nvim_set_option_value(k, v, { scope = 'global' })
  end,
})

--- Gets or sets buffer-scoped |options| on buffer {bufnr} (or "current buffer" if 0 or omitted). Like
--- `:setlocal`. Invalid {bufnr} or key is an error.
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

--- Gets or sets window-scoped |options| on window {winid} (or "current window" if 0 or omitted) and
--- buffer {bufnr} (0 for current buffer). Like `:setlocal` if setting a |global-local| option or if
--- {bufnr} is specified, like `:set` otherwise. Invalid {winid}, {bufnr}, or key is an error.
---
--- Note: only bufnr=0 (current window-buffer) is supported, currently.
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

local function passthrough(_, x)
  return x
end

-- Map of OptionType to functions that take vimoption_T values and convert to Lua values.
-- Each function takes (info, vim_value) -> lua_value
local to_lua_value = {
  boolean = passthrough,
  number = passthrough,
  string = passthrough,

  array = function(_, value)
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
function M.convert_value_to_lua(name, option_value)
  local info = get_options_info(name) or error('Not a valid option name: ' .. name)
  return to_lua_value[info.metatype](info, option_value)
end

local function create_option_accessor(scope)
  --- @diagnostic disable-next-line: no-unknown
  local option_mt

  local function make_option(name, value, op_count)
    if type(value) == 'table' and getmetatable(value) == option_mt then
      assert(name == value._name, "must be the same value, otherwise that's weird.")

      --- @diagnostic disable-next-line: no-unknown
      value = value._value
    end

    return setmetatable({
      _name = name,
      _value = value,
      _op_count = op_count,
    }, option_mt)
  end

  option_mt = {
    get = function(self)
      return M.convert_value_to_lua(self._name, self._value)
    end,

    append = function(self, right)
      vim.api.nvim_set_option_value(self._name, right, { operation = 'append', scope = scope })
    end,

    __infix = function(self, right, operation)
      -- TODO(kylesower): support multiple infix operations. Right now this
      -- doesn't work because nvim_set_option_value uses get_option_newval to
      -- merge the values, and that always expects a varp pointer that points
      -- to the existing option value. Thus, when a new value is computed with
      -- an infix op, but the option isn't updated, subsequent infix ops still
      -- use the outdated option value.
      -- This could be resolved by updating the option value when computing
      -- the infix ops; however, this would then turn the infix ops into
      -- assignments. The full solution to the problem requires computing the
      -- infix op of two arbitrary values (not just one value compared to an
      -- existing option).
      if self._op_count > 0 then
        error('Multiple vim.opt infix operations unsupported')
      end
      return make_option(
        self._name,
        vim.api.nvim_set_option_value(
          self._name,
          right,
          { operation = operation, scope = scope, dry_run = true }
        ),
        self._op_count + 1
      )
    end,

    __add = function(self, right)
      return self:__infix(right, 'append')
    end,

    prepend = function(self, right)
      vim.api.nvim_set_option_value(self._name, right, { operation = 'prepend', scope = scope })
    end,

    __pow = function(self, right)
      return self:__infix(right, 'prepend')
    end,

    remove = function(self, right)
      vim.api.nvim_set_option_value(self._name, right, { operation = 'remove', scope = scope })
    end,

    __sub = function(self, right)
      return self:__infix(right, 'remove')
    end,
  }
  option_mt.__index = option_mt

  return setmetatable({}, {
    __index = function(_, k)
      -- vim.opt_global must get global value only
      -- vim.opt_local may fall back to global value like vim.opt
      local opts = { scope = scope == 'global' and 'global' or nil }
      return make_option(k, api.nvim_get_option_value(k, opts), 0)
    end,

    __newindex = function(_, k, v)
      local option = make_option(k, v, 0)
      api.nvim_set_option_value(option._name, option._value, { scope = scope })
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
--- and map-style options from Lua: It allows accessing them as Lua tables and
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

--- @nodoc
vim.opt = create_option_accessor()

--- @nodoc
vim.opt_local = create_option_accessor('local')

--- @nodoc
vim.opt_global = create_option_accessor('global')

return M
