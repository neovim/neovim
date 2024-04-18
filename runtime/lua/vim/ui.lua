local M = {}

--- Prompts the user to pick from a list of items, allowing arbitrary (potentially asynchronous)
--- work until `on_choice`.
---
--- Example:
---
--- ```lua
--- vim.ui.select({ 'tabs', 'spaces' }, {
---     prompt = 'Select tabs or spaces:',
---     format_item = function(item)
---         return "I'd like to choose " .. item
---     end,
--- }, function(choice)
---     if choice == 'spaces' then
---         vim.o.expandtab = true
---     else
---         vim.o.expandtab = false
---     end
--- end)
--- ```
---
---@param items any[] Arbitrary items
---@param opts table Additional options
---     - prompt (string|nil)
---               Text of the prompt. Defaults to `Select one of:`
---     - format_item (function item -> text)
---               Function to format an
---               individual item from `items`. Defaults to `tostring`.
---     - kind (string|nil)
---               Arbitrary hint string indicating the item shape.
---               Plugins reimplementing `vim.ui.select` may wish to
---               use this to infer the structure or semantics of
---               `items`, or the context in which select() was called.
---@param on_choice fun(item: any|nil, idx: integer|nil)
---               Called once the user made a choice.
---               `idx` is the 1-based index of `item` within `items`.
---               `nil` if the user aborted the dialog.
function M.select(items, opts, on_choice)
  vim.validate({
    items = { items, 'table', false },
    on_choice = { on_choice, 'function', false },
  })
  opts = opts or {}
  local choices = { opts.prompt or 'Select one of:' }
  local format_item = opts.format_item or tostring
  for i, item in ipairs(items) do
    table.insert(choices, string.format('%d: %s', i, format_item(item)))
  end
  local choice = vim.fn.inputlist(choices)
  if choice < 1 or choice > #items then
    on_choice(nil, nil)
  else
    on_choice(items[choice], choice)
  end
end

--- Prompts the user for input, allowing arbitrary (potentially asynchronous) work until
--- `on_confirm`.
---
--- Example:
---
--- ```lua
--- vim.ui.input({ prompt = 'Enter value for shiftwidth: ' }, function(input)
---     vim.o.shiftwidth = tonumber(input)
--- end)
--- ```
---
---@param opts table? Additional options. See |input()|
---     - prompt (string|nil)
---               Text of the prompt
---     - default (string|nil)
---               Default reply to the input
---     - completion (string|nil)
---               Specifies type of completion supported
---               for input. Supported types are the same
---               that can be supplied to a user-defined
---               command using the "-complete=" argument.
---               See |:command-completion|
---     - highlight (function)
---               Function that will be used for highlighting
---               user inputs.
---@param on_confirm function ((input|nil) -> ())
---               Called once the user confirms or abort the input.
---               `input` is what the user typed (it might be
---               an empty string if nothing was entered), or
---               `nil` if the user aborted the dialog.
function M.input(opts, on_confirm)
  vim.validate({
    opts = { opts, 'table', true },
    on_confirm = { on_confirm, 'function', false },
  })

  opts = (opts and not vim.tbl_isempty(opts)) and opts or vim.empty_dict()

  -- Note that vim.fn.input({}) returns an empty string when cancelled.
  -- vim.ui.input() should distinguish aborting from entering an empty string.
  local _canceled = vim.NIL
  opts = vim.tbl_extend('keep', opts, { cancelreturn = _canceled })

  local ok, input = pcall(vim.fn.input, opts)
  if not ok or input == _canceled then
    on_confirm(nil)
  else
    on_confirm(input)
  end
end

--- Opens `path` with the system default handler (macOS `open`, Windows `explorer.exe`, Linux
--- `xdg-open`, …), or returns (but does not show) an error message on failure.
---
--- Expands "~/" and environment variables in filesystem paths.
---
--- Examples:
---
--- ```lua
--- -- Asynchronous.
--- vim.ui.open("https://neovim.io/")
--- vim.ui.open("~/path/to/file")
--- -- Synchronous (wait until the process exits).
--- local cmd, err = vim.ui.open("$VIMRUNTIME")
--- if cmd then
---   cmd:wait()
--- end
--- ```
---
---@param path string Path or URL to open
---
---@return vim.SystemObj|nil # Command object, or nil if not found.
---@return string|nil # Error message on failure
---
---@see |vim.system()|
function M.open(path)
  vim.validate({
    path = { path, 'string' },
  })
  local is_uri = path:match('%w+:')
  if not is_uri then
    path = vim.fn.expand(path)
  end

  local cmd --- @type string[]

  if vim.fn.has('mac') == 1 then
    cmd = { 'open', path }
  elseif vim.fn.has('win32') == 1 then
    if vim.fn.executable('rundll32') == 1 then
      cmd = { 'rundll32', 'url.dll,FileProtocolHandler', path }
    else
      return nil, 'vim.ui.open: rundll32 not found'
    end
  elseif vim.fn.executable('explorer.exe') == 1 then
    cmd = { 'explorer.exe', path }
  elseif vim.fn.executable('xdg-open') == 1 then
    cmd = { 'xdg-open', path }
  else
    return nil, 'vim.ui.open: no handler found (tried: explorer.exe, xdg-open)'
  end

  return vim.system(cmd, { text = true, detach = true }), nil
end

return M
