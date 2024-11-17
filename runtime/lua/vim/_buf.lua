local M = {}

--- Adds one or more blank lines above or below the cursor.
-- TODO: move to _defaults.lua once it is possible to assign a Lua function to options #25672
--- @param above? boolean Place blank line(s) above the cursor
local function add_blank(above)
  local offset = above and 1 or 0
  local repeated = vim.fn['repeat']({ '' }, vim.v.count1)
  local linenr = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, linenr - offset, linenr - offset, true, repeated)
end

-- TODO: move to _defaults.lua once it is possible to assign a Lua function to options #25672
function M.space_above()
  add_blank(true)
end

-- TODO: move to _defaults.lua once it is possible to assign a Lua function to options #25672
function M.space_below()
  add_blank()
end

return M
