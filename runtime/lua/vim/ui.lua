local M = {}

--- Prompts the user to pick a single item from a collection of entries
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
--- <pre>
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
  vim.validate {
    items = { items, 'table', false },
    on_choice = { on_choice, 'function', false },
  }
  opts = opts or {}
  local choices = {opts.prompt or 'Select one of:'}
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

--- Prompts the user to select one or more items from a collection of entries
---
---@param items table Arbitrary items
---@param opts table Additional options
---     - prompt (string|nil)
---               Text of the prompt. Defaults to `Select from list or <Enter> to confirm: `
---     - format_item (function item -> text)
---               Function to format an individual item from `items`. Defaults to `tostring`.
---     - kind (string|nil)
---               Arbitrary hint string indicating the item shape.
---               Plugins reimplementing `vim.ui.select_many` may wish to
---               use this to infer the structure or semantics of
---               `items`, or the context in which select_many() was called.
---@param on_choices function ((chosen_items|nil, indexes|nil) -> ())
---               Called once the user made a choice.
---               `indexes` is a list of 1-based indexes of `chosen_items` within `items`.
---               `nil` if the user aborted the dialog without selecting any items.
---
---
--- Example:
--- <pre>
--- vim.ui.select_many({ 'menu', 'menuone', 'longest', 'preview', 'noinsert', 'noselect' }, {
---     prompt = "Select values for 'completeopt':",
--- }, function(choices)
---     if choices and #choices > 0 then
---         vim.opt.completeopt = choices
---     end
--- end)
--- </pre>
function M.select_many(items, opts, on_choices)
  vim.validate {
    items = { items, 'table', false },
    on_choices = { on_choices, 'function', false },
  }
  opts = opts or {}
  local selected = {}
  local selected_indexes = {}
  local choices = {opts.prompt or 'Select from list or <Enter> to confirm: '}
  local format_item = opts.format_item or tostring
  for i, item in pairs(items) do
    table.insert(choices, string.format('%d: %s', i, format_item(item)))
  end
  while true do
    local chosen = vim.fn.inputlist(choices)
    if chosen == 0 then
      break
    else
      if vim.tbl_contains(selected, items[chosen]) then
        selected[chosen] = nil
        selected_indexes[chosen] = nil

        choices[chosen+1] = choices[chosen+1]:sub(3, #choices[chosen+1])
      else
        selected[chosen] = items[chosen]
        selected_indexes[chosen] = chosen
        choices[chosen+1] = '* ' .. choices[chosen+1]
      end
      vim.cmd('redraw')
    end
  end
  if #selected > 0 then
    -- Reconstruct tables with table.insert to ensure a list-like table,
    -- e.g. selected could end up like { [1] = 'choice 1', [3] = 'choice 3' }
    -- and this fixes that.
    --
    -- TODO(smolck): There's probably a better way to do this?
    local s2 = {}
    local s2_indexes = {}
    for i, item in pairs(selected) do
      table.insert(s2, item)
      table.insert(s2_indexes, selected_indexes[i])
    end
    on_choices(s2, s2_indexes)
  else
    on_choices(nil, nil)
  end
end

--- Prompts the user for input
---
---@param opts table Additional options. See |input()|
---     - prompt (string|nil)
---               Text of the prompt. Defaults to `Input: `.
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
---               `input` is what the user typed.
---               `nil` if the user aborted the dialog.
---
--- Example:
--- <pre>
--- vim.ui.input({ prompt = 'Enter value for shiftwidth: ' }, function(input)
---     vim.o.shiftwidth = tonumber(input)
--- end)
--- </pre>
function M.input(opts, on_confirm)
  vim.validate {
    on_confirm = { on_confirm, 'function', false },
  }

  opts = opts or {}
  local input = vim.fn.input(opts)
  if #input > 0 then
    on_confirm(input)
  else
    on_confirm(nil)
  end
end

return M
