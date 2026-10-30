-- A card's window kept to its part of the file: Nvim's window range
-- (|nvim_win_set_range()|) does it (the cursor stays in the part, an
-- operator works only on its text, the range follows the edits); here the
-- view is also kept from scrolling past the part's last line, and nothing
-- in it folds.

local M = {}

--- Window `win` kept to rows `srow..erow` (from 0) of its buffer.
---@param win integer
---@param srow integer
---@param erow integer
function M.set(win, srow, erow)
  vim.api.nvim_win_set_range(win, srow, erow)
  if vim.wo[win].foldenable then
    vim.wo[win].foldenable = false
  end
end

--- The rows (from 0) window `win` is kept to, if it is.
---@param win integer
---@return integer?, integer?
function M.rows(win)
  local r = vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_range(win) or {}
  return r[1], r[2]
end

--- The view back on the range: from its first line, never past its last.
---@param win integer
function M.clamp_view(win)
  local s, e = M.rows(win)
  if not s then
    return
  end
  vim.api.nvim_win_call(win, function()
    local view = vim.fn.winsaveview()
    local height = vim.api.nvim_win_get_height(win)
    local top = math.max(s + 1, math.min(view.topline, e + 2 - height))
    -- Not part way into its first line either (a line wrapped in rows).
    if top ~= view.topline or (top == s + 1 and (view.skipcol or 0) > 0) then
      vim.fn.winrestview({ topline = top, skipcol = 0 })
    end
  end)
end

vim.api.nvim_create_autocmd("WinScrolled", {
  group = vim.api.nvim_create_augroup("biscide_narrow", { clear = true }),
  callback = function()
    for key in pairs(vim.v.event) do
      local win = tonumber(key)
      if win then
        M.clamp_view(win)
      end
    end
  end,
})

return M
