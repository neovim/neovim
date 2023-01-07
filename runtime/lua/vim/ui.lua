local M = {}

--- Prompts the user to pick from a list of items, allowing arbitrary (potentially asynchronous)
--- work until `on_choice`.
---
---@param items table Arbitrary items
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
---@param on_choice function ((item|nil, idx|nil) -> ())
---               Called once the user made a choice.
---               `idx` is the 1-based index of `item` within `items`.
---               `nil` if the user aborted the dialog.
---
---
--- Example:
--- <pre>lua
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
--- </pre>
function M.select(items, opts, on_choice)
  vim.validate({
    items = { items, 'table', false },
    on_choice = { on_choice, 'function', false },
  })
  opts = opts or {}
  local choices = { opts.prompt or 'Select one of:' }
  local format_item = opts.format_item or tostring
  for i, item in pairs(items) do
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
---@param opts table Additional options. See |input()|
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
---
--- Example:
--- <pre>lua
--- vim.ui.input({ prompt = 'Enter value for shiftwidth: ' }, function(input)
---     vim.o.shiftwidth = tonumber(input)
--- end)
--- </pre>
function M.input(opts, on_confirm)
  vim.validate({
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

--- Prompts the user to pick an option from a list of choices
---
---@param msg string prompt displayed to the user
---@param opts table
---     - choices (string[]|nil)
---               List of choices. The shortcut key for each choice
---               is designated with a "&" character. If "&" is not present
---               in the choice, the first letter of the choice is used.
---     - default (number|nil)
---               Default choice selected when user presses <Enter>
---@param on_choice fun(idx:number|nil,choice:string|nil)
---               Called once the user chooses or cancel the input.
---               `idx` is the 1-based index of the 'choice' in `opts.choices` table,
---               (it might be `0` if none of the choices is picked, or
---               `nil` if the user aborted the dialog.)
---		  `choice` is what the user chose (`nil` on abortion or
---		  if user did not choose any option)
---
--- Example:
--- <pre>lua
--- vim.ui.confirm("Favorite fruit?", {
---     choices = {'Apple', 'Banana', 'Cranberry', 'El&derberry' },
---     default = 2,
--- }, function(idx, choice)
---     print(idx, choice)
--- end)
--- </pre>
function M.confirm(msg, opts, on_choice)
  vim.validate({
    msg = { msg, 'string' },
    opts = { opts, 'table', true },
    on_choice = { on_choice, 'function' },
  })

  opts = opts or {}
  opts.choices = opts.choices or {}

  local ok, res = pcall(vim.fn.confirm, msg, table.concat(opts.choices, '\n'), opts.default)

  if (ok and res == 0) or (not ok and res == 'Keyboard interrupt') then
    on_choice(nil, nil)
  elseif ok then
    local selected_choice = nil
    if vim.tbl_isempty(opts.choices) == false then
      selected_choice = (opts.choices[res]:gsub('&', ''))
    end
    on_choice(res, selected_choice)
  else
    error(res)
  end
end

return M
