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
---@param on_choice function ((item|nil, idx|nil) -> ())
---               Called once the user made a choice.
---               `idx` is the 1-based index of `item` within `item`.
---               `nil` if the user aborted the dialog.
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


return M
