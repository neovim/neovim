local M = {}

--- Wait for |vim.ui.select()| and return the selected index. The default vim.ui.select impl
--- (inputlist()) is synchronous, but this also handles async pickers (fzf-lua, telescope, …).
---
--- @param items table Items to choose from.
--- @param opts table Forwarded to |vim.ui.select()|.
--- @return integer? # 1-based index of the chosen item, or nil if cancelled/interrupted.
function M.select_blocking(items, opts)
  local choice ---@type integer?
  local done = false
  vim.ui.select(items, opts or {}, function(_, idx)
    choice = idx
    done = true
  end)
  -- vim.wait returns false on timeout (math.huge means never) or interrupt (-2).
  vim.wait(math.huge, function()
    return done
  end)
  return choice
end

return M
