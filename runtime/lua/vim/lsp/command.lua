local M = {}

local ERR_NO_COMMAND            = 'lsp: Not a command: %s'
local ERR_NO_CLIENT             = 'lsp: LSP client not attached to this buffer'
local ERR_NO_CAPABILITY         = 'lsp: No server with support for this capability found'
local ERR_ARGS_NOT_ALLOWED      = 'lsp: Arguments not allowed for this command'
local ERR_RANGE_NOT_ALLOWED     = 'lsp: Range not allowed for this command'
local ERR_OPT_INVALID           = 'lsp: Invalid option: %s'
local ERR_OPT_DUPLICATE         = 'lsp: Duplicate option: %s'
local ERR_OPT_VALUE_MISSING     = 'lsp: Expected value for option: %s'
local ERR_OPT_VALUE_INVALID     = 'lsp: Invalid value for option: %s'
local ERR_OPT_VALUE_NOT_ALLOWED = 'lsp: Value not allowed for option: %s'


---@private
local function echo(msg, history)
  if type(msg) == 'string' then
    msg = {{msg}}
  elseif type(msg) ~= 'table' then
    error('expected table')
  end
  vim.api.nvim_echo(msg, history and true or false, {})
end

---@private
local function echoerr(msg)
  echo({{msg, 'ErrorMsg'}}, true)
end

---@private
--- Find a command with name matching "s"
local function match_command(s)
  s = s:match('%S+')
  if s then
    for _, cmd in ipairs(M.commands) do
      if s == cmd.name:sub(1, #s) then
        return cmd
      end
    end
  end
end


--- Runs :lsp command.
---
---@param args (string) Command arguments
---@param ctx (table) Command context:
---     buf   (number)      Buffer handle
---     bang  (boolean)     Bang
---     line1 (number|nil)  Range starting line
---     line2 (number|nil)  Range final line
---     range (number|nil)  Number of items in the range
function M.run(args, ctx)
  local cmdname, cmdargs = args:match('(%S+)%s*(.-)%s*$')
  if cmdname then
    local cmd = match_command(cmdname)
    if not cmd then
      return echoerr(ERR_NO_COMMAND:format(cmdname))
    elseif cmd.run then
      ctx.args = cmdargs ~= '' and cmdargs or nil
      local err = cmd.check and cmd.check(ctx)
      if err then
        return echoerr(err)
      else
        cmd.run(ctx)
      end
    end
  else
    M.default_command(ctx)
  end
end

--- Completion for :lsp command.
---
---@param pat (string) Argument to complete
---@param ctx (table) Command context:
---     buf   (number)      Buffer handle
---     args  (string|nil)  Previous arguments
---     bang  (boolean)     Bang
---     line1 (true|nil)    Range starting line
---     line2 (true|nil)    Range final line
---     range (true|nil)    Number of items in the range
function M.expand(pat, ctx)
  if not ctx.args then
    local res = {}
    for _, cmd in ipairs(M.commands) do
      if pat == cmd.name:sub(1, #pat) and (not cmd.check or not cmd.check(ctx)) then
        table.insert(res, cmd.name)
      end
    end
    return res
  else
    local cmdname, args = ctx.args:match('(%S+)%s*(.-)%s*$')
    ctx.args = args ~= '' and args or nil
    local cmd = match_command(cmdname)
    if cmd and cmd.expand and (not cmd.check or not cmd.check(ctx)) then
      return cmd.expand(pat, ctx)
    end
  end
end


---@private
--- Checks if any client is attached to the buffer
local function is_attached(ctx)
  local lsp = rawget(vim, 'lsp') -- Do not load lsp module if not already loaded
  return lsp and next(lsp.buf_get_clients(ctx.buf)) ~= nil or false
end

---@private
--- Returns a lookup table of capabilities of servers attached to the buffer
local function get_capabilities(bufnr)
  local res = {}
  local lsp = rawget(vim, 'lsp') -- Do not load lsp module if not already loaded
  if lsp then
    for _, client in pairs(lsp.buf_get_clients(bufnr or 0)) do
      for k, v in pairs(client.server_capabilities) do
        if v then
          res[k] = true
        end
      end
    end
  end
  return res
end

---@private
--- Filters out items not matching the pattern
local function filter(pat, t)
  local res, n = {}, #pat
  for _, v in ipairs(t) do
    if pat == v:sub(1, n) then
      table.insert(res, v)
    end
  end
  table.sort(res)
  return res
end

---@private
--- Parses command options
local function parse_options(ctx)
  if not ctx.args then return {} end
  local args = vim.split(ctx.args, '%s+', { trimempty = true })

  local res = {}
  for _, arg in ipairs(args) do
    local k, v = arg:match('^(.+)=(.*)$')
    if k then
      table.insert(res, {
        key = k,
        value = vim.split(v, ',', { plain = true, trimempty = true }),
      })
    else
      table.insert(res, { key = arg })
    end
  end
  return res
end

---@private
local function make_range(ctx)
  return { ctx.line1, 1 }, { ctx.line2, #vim.fn.getline(ctx.line2) }
end

---@private
--- Checks for errors and returns error message
---
---@param ctx   (table) Context
---@param what  (table) Errors to check:
---     no_range    (true|nil)    Range not allowed
---     no_args     (true|nil)    Arguments not allowed
---     attached    (true|nil)    Requires attached client
---     capability  (string|nil)  Required server capability
---@returns Error message or nil on success
local function check_err(ctx, what)
  if what.no_range and ctx.line1 then
    return ERR_RANGE_NOT_ALLOWED
  elseif what.no_args and ctx.args then
    return ERR_ARGS_NOT_ALLOWED
  elseif what.attached and not is_attached(ctx) then
    return ERR_NO_CLIENT
  elseif what.capability and not get_capabilities(ctx.buf)[what.capability] then
    return ERR_NO_CAPABILITY
  else
    return nil
  end
end

---@private
local function make_check_function(what)
  return function(ctx)
    return check_err(ctx, what)
  end
end

--- :lsp without any arguments
function M.default_command(ctx)
  local _ = ctx -- silence, linter
  return echoerr('lsp: Argument required')
end

---@private
local function make_basic_command(name, func, capability)
  return {
    name = name,
    check = make_check_function {
      no_args = true,
      attached = true,
      no_range = true,
      capability = capability,
    },
    run = function(_)
      vim.lsp.buf[func]()
    end,
  }
end

--- List of :lsp subcommands
---
--- Parameters:
---     name    (string)    Command name.
---     check   (function)  Checks if command is available in current context.
---                         Receives a context as argument, returns error message
---                         or nil on success.
---     run     (function)  Runs the command. Receives context as argument.
---     expand  (function)  Completion. Receives argument to complete as the first
---                         argument, and context as the second argument. Returns
---                         a list of completions and completion offset (to expand
---                         only a part of completed argument).
M.commands = {

  make_basic_command('definition',     'definition',       'definitionProvider'),
  make_basic_command('declaration',    'declaration',      'declarationProvider'),
  make_basic_command('implementation', 'implementation',   'implementationProvider'),
  make_basic_command('typedefinition', 'type_definition',  'typeDefinitionProvider'),
  make_basic_command('references',     'references',       'referencesProvider'),
  make_basic_command('symbols',        'document_symbol',  'documentSymbolProvider'),
  make_basic_command('hover',          'hover',            'hoverProvider'),
  make_basic_command('signature',      'signature_help',   'signatureHelpProvider'),

  {
    name = 'rename',
    check = make_check_function {
      attached = true,
      no_range = true,
      capability = 'renameProvider',
    },
    run = function(ctx)
      vim.lsp.buf.rename(ctx.args)
    end,
  },

  {
    name = 'codeaction',
    check = make_check_function {
      attached = true,
      capability = 'codeActionProvider',
    },
    run = function(ctx)
      local only
      for _, opt in ipairs(parse_options(ctx)) do
        if opt.key == 'only' then
          if only then
            return echoerr(ERR_OPT_DUPLICATE:format(opt.key))
          elseif not opt.value or #opt.value == 0 then
            return echoerr(ERR_OPT_VALUE_MISSING:format(opt.key))
          else
            only = opt.value
          end
        else
          return echoerr(ERR_OPT_INVALID:format(opt.key))
        end
      end

      if not ctx.line1 then
        vim.lsp.buf.code_action({ only = only })
      else
        local line1, line2 = make_range(ctx)
        vim.lsp.buf.range_code_action({ only = only }, line1, line2)
      end
    end,
    expand = function(pat, ctx)
      if pat:match('^only=') then
        local rest, last = assert(pat:match('^only=(.-)([^,]*)$'))
        local pos = #pat - #last

        local seen = {}
        for _, kind in ipairs(vim.split(rest, ',', { plain = true, trimempty = true })) do
          seen[kind] = true
        end

        local kinds = {}
        for _, client in pairs(vim.lsp.buf_get_clients(ctx.buf)) do
          local code_action = client.server_capabilities.codeActionProvider
          if type(code_action) == 'table' then
            for _, kind in ipairs(code_action.codeActionKinds) do
              if not seen[kind] then
                kinds[kind] = true
              end
            end
          end
        end

        return filter(last, vim.tbl_keys(kinds)), pos
      else
        return filter(pat, {'only='})
      end
    end,
  },

  {
    name = 'format',
    check = function(ctx)
      local err = check_err(ctx, { attached = true })
      if err then return err end
      local caps = get_capabilities(ctx.buf)
      if not caps['documentFormattingProvider'] and not caps['documentRangeFormattingProvider'] then
        return ERR_NO_CAPABILITY
      end
    end,
    run = function(ctx)
      local async, timeout
      for _, opt in ipairs(parse_options(ctx)) do
        if opt.key == 'async' then
          if async then
            return echoerr(ERR_OPT_DUPLICATE:format(opt.key))
          elseif opt.value then
            return echoerr(ERR_OPT_VALUE_NOT_ALLOWED:format(opt.key))
          else
            async = true
          end
        elseif opt.key == 'timeout' then
          if timeout then
            return echoerr(ERR_OPT_DUPLICATE:format(opt.key))
          elseif not opt.value or #opt.value == 0 then
            return echoerr(ERR_OPT_VALUE_MISSING:format(opt.key))
          elseif #opt.value ~= 1 or not #opt.value[1]:match('^[1-9][0-9]*$') then
            return echoerr(ERR_OPT_VALUE_INVALID:format(opt.key))
          else
            async = tonumber(opt.value[1])
          end
        else
            return echoerr(ERR_OPT_INVALID:format(opt.key))
        end
      end

      if not ctx.line1 then
        if not get_capabilities(ctx.buf)['documentFormattingProvider'] then
          echoerr(ERR_NO_CAPABILITY)
        end
        vim.lsp.buf.format({
          timeout_ms = timeout,
          async = async,
        })
      else
        if async then
          return echoerr('lsp: "async" not allowed for range formatting')
        elseif timeout then
          return echoerr('lsp: "timeout" not allowed for range formatting')
        elseif not get_capabilities(ctx.buf)['documentRangeFormattingProvider'] then
          echoerr(ERR_NO_CAPABILITY)
        end
        local line1, line2 = make_range(ctx)
        vim.lsp.buf.range_formatting({}, line1, line2)
      end
    end,
    expand = function(pat, ctx)
      if not ctx.line1 then
        return filter(pat, {'async', 'timeout='})
      end
    end,
  },

  {
    name = 'find',
    check = make_check_function {
      attached = true,
      no_range = true,
      capability = 'workspaceSymbolProvider',
    },
    run = function(ctx)
      vim.lsp.buf.workspace_symbol(ctx.args or '')
    end,
  },

  make_basic_command('incomingcalls', 'incoming_calls', 'callHierarchyProvider'),
  make_basic_command('outgoingcalls', 'outgoing_calls', 'callHierarchyProvider'),

  -- {
  --   name = 'attach',
  --   check = make_check_function {
  --     no_range = true,
  --   },
  --   -- TODO: run
  --   -- TODO: expand
  -- },

  -- {
  --   name = 'detach',
  --   check = make_check_function {
  --     no_range = true,
  --   },
  --   -- TODO: run
  --   -- TODO: expand
  -- },

}

return M
