local usercommand = {}

--- Table of options for creating |user-commands|
--- with scoped subcommands.
---
--- @class vim.usercommand.SubcommandOpts
---
--- The implementation of the subcommand.
--- @field command fun(opts: vim.usercommand.Opts)
---
--- Provides completions for this subcommand.
--- `arg_lead` is the text that has been typed
--- after the subcommand name.
--- `cmdline` is the whole command line text.
--- @field complete? fun(arg_lead: string, cmdline: string): string[]
---
--- Whether this subcommand supports being called with a bang `!`,
--- for example `:Foo! subcmd`
--- Subcommands that do not support a bang will not
--- show up in completions for a command that is called with one.
--- @field bang? boolean

--- A table of subcommands, where the keys are the
--- subcommand names.
--- The first element can be a function, which is invoked
--- if the |user-commands| is called without a subcommand.
---
--- Examples:
--- ```lua
--- -- Two local subcommands:
--- {
---   subcmd1 = {
---     command = function(opts) print('real lua function') end,
---     complete = function(arg_lead, fargs) return { 'list', 'of', 'completions' } end,
---   },
---   subcmd2 = {
---     command = function(opts) print('real lua function') end,
---   },
--- }
--- -- Main command and a subcommand:
--- {
---   function(opts) print('main command') end,
---   subcmd = {
---     command = function(opts) print('this is a subcommand') end,
---   },
--- }
--- ```
---
--- @alias vim.usercommand.CmdTable { [1]: fun(opts: vim.usercommand.Opts) | nil, [string]: vim.usercommand.SubcommandOpts }

--- @class vim.usercommand.create.Opts : vim.api.keyset.user_command
--- @inlinedoc
---
--- Creates a buffer-local user command, `0` or `true` for current buffer.
--- @field buffer? integer|true
---
--- Implements completions for a user command.
--- @field complete? fun(arg_lead: string, cmdline: string): string[]


--- @class vim.usercommand.Opts
---
--- Command name
--- @field name string
---
--- The args passed to the command, if any
--- @field args string
---
--- The args split by unescaped whitespace
--- (when more than one argument is allowed), if any
--- @field fargs string[]
---
--- Number of arguments `:command-nargs`
--- @field nargs string
---
--- `true` if the command was executed with a ! modifier
--- @field bang boolean
---
--- The starting line of the command range
--- @field line1 number
---
--- The final line of the command range
--- @field line2 number
---
--- The number of items in the command range: 0, 1, or 2
--- @field range number
---
--- Any count supplied
--- @field count number
---
--- The optional register, if specified
--- @field reg string
---
--- Command modifiers, if any
--- @field mods string
---
--- Command modifiers in a structured format.
--- Has the same structure as the "mods" key of `nvim_parse_cmd()`.
--- @field smods table

--- @generic K, V
--- @param predicate fun(v: V):boolean
--- @param tbl table<K, V>
--- @return K[]
local function filter_keys_by_value(predicate, tbl)
  local ret = {}
  ---@diagnostic disable-next-line:no-unknown
  for k, v in pairs(tbl) do
    if predicate(v) then
      table.insert(ret, k)
    end
  end
  return ret
end

--- Adds a new |user-commands|.
---
--- Examples:
---
--- ```lua
--- -- Creating a simple user command:
--- vim.usercommand.create('Foo', function print('foo') end)
--- -- Creating a simple user command that accepts bang `!` modifiers:
--- vim.usercommand.create('Foo', function print('foo') end, { bang = true })
--- -- Creating a user command with scoped subcommands
--- vim.usercommand.create('Foo', {
---   function print('foo') end,
---   bar = {
---     command = function(opts) print('bar') end,
---     complete = function(arg_lead, cmdline) return { 'a', 'b', 'c' } end,
---     bang = true,
---   },
---   baz = {
---     command = function(opts) print('baz') end,
---   },
--- })
--- ```
---
--- @param name string The name of the command
--- @param command function | string | vim.usercommand.CmdTable The command or subcommand table
---                    If `command` is a subcommand table, this function automatically creates
---                    completions for the subcommands.
--- @param opts? vim.usercommand.create.Opts
--- @see |nvim_create_user_command()|
--- @see |nvim_buf_create_user_command()|
function usercommand.create(name, command, opts)
  vim.validate({
    name = { name, 's' },
    command = { command, { 'f', 's', 't' } },
    opts = { opts, 't', true },
  })

  opts = vim.deepcopy(opts or {}, true)

  if type(command) == 'function' or type(command) == 'string' then
    if opts.buffer then
      opts.buffer = nil
      local bufnr = opts.buffer == true and 0 or opts.buffer --[[@as integer]]
      vim.api.nvim_buf_create_user_command(bufnr, name, command, opts)
    else
      opts.buffer = nil
      vim.api.nvim_create_user_command(name, command, opts)
    end
    return
  end

  --- @cast command vim.usercommand.CmdTable

  local fallback_complete = opts.complete

  --- @param arg_lead string
  --- @param cmdline string
  --- @return string[]
  opts.complete = function(arg_lead, cmdline)
    local subcommand_names = cmdline:match('^' .. name .. '!') ~= nil
      --- @param subcommand fun(opts: vim.usercommand.Opts) | vim.usercommand.SubcommandOpts
      and filter_keys_by_value(function(subcommand)
        return subcommand.bang == true
      end, command)
      or vim.tbl_keys(command)
    --- @type string, string
    local subcmd_name, subcmd_arg_lead = cmdline:match('^' .. name .. '[!]*%s(%S+)%s(.*)$')
    if subcmd_name and subcmd_arg_lead and command[subcmd_name] and command[subcmd_name].complete then
      return command[subcmd_name].complete(subcmd_arg_lead, cmdline)
    end
    if cmdline:match('^' .. name .. '[!]*%s+%w*$') then
      return vim.iter(subcommand_names):filter(function(sub_name)
        return type(sub_name) == 'string' and sub_name:find(arg_lead) ~= nil
      end):totable()
    end
    if type(fallback_complete) == 'function' then
      -- Fall back to origin
      return fallback_complete(arg_lead, cmdline)
    end
    return {}
  end

  if vim.iter(command):any(function(sub_command)
    return sub_command.bang
  end) then
    opts.bang = true
  end

  ---@param cmd_opts vim.usercommand.Opts
  local function scoped_command(cmd_opts)
    cmd_opts = vim.deepcopy(cmd_opts or {}, true)
    local fargs = cmd_opts.fargs
    local subcmd_name = table.remove(fargs, 1)
    local subcommand = command[subcmd_name]
    if subcommand and type(subcommand.command) == 'function' then
      cmd_opts.name = subcmd_name
      cmd_opts.fargs = #fargs > 1 and vim.list_slice(fargs, 2, #fargs) or {}
      subcommand.command(cmd_opts)
    else
      local main_command = type(command[1]) == 'function' and command[1]
      if main_command then
        main_command(cmd_opts)
      else
        vim.notify('Command ' .. name .. ' called without any subcommands', vim.log.levels.ERROR)
      end
    end
  end

  if opts.buffer then
    opts.buffer = nil
    local bufnr = opts.buffer == true and 0 or opts.buffer --[[@as integer]]
    vim.api.nvim_buf_create_user_command(bufnr, name, scoped_command, opts)
  else
    opts.buffer = nil
    vim.api.nvim_create_user_command(name, scoped_command, opts)
  end
end

--- @class vim.usercommand.del.Opts
--- @inlinedoc
---
--- Remove a |user-commands| from the given buffer.
--- When `0` or `true`, use the current buffer.
--- @field buffer? integer|true

--- Remove an existing user command.
--- Examples:
---
--- ```lua
--- vim.usercommand.del('Foo')
---
--- vim.usercommand.del('Foo', { buffer = 5 })
--- ```
---
---@param name string
---@param opts? vim.usercommand.del.Opts
---@see |vim.usercommand.create()|
--- @see |nvim_del_user_command()|
--- @see |nvim_buf_del_user_command()|
function usercommand.del(name, opts)
  vim.validate({
    name = { name, 's' },
    opts = { opts, 't', true },
  })

  opts = opts or {}

  local buffer = false ---@type false|integer
  if opts.buffer ~= nil then
    buffer = opts.buffer == true and 0 or opts.buffer --[[@as integer]]
  end

  if buffer == false then
    vim.api.nvim_del_user_command(name)
  else
    vim.api.nvim_buf_del_user_command(buffer, name)
  end
end

return usercommand
