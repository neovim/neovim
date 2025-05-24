---@class vim.ui.img._codes
local M = {
  ---Hides the cursor from being shown in terminal.
  cursor_hide = '\027[?25l',
  ---Restore cursor position based on last save.
  cursor_restore = '\0278',
  ---Save cursor position to be restored later.
  cursor_save = '\0277',
  ---Shows the cursor if it was hidden in terminal.
  cursor_show = '\027[?25h',
  ---Queries the terminal for its background color.
  query_background_color = '\027]11;?',
  ---Disable synchronized output mode.
  sync_mode_disable = '\027[?2026l',
  ---Enable synchronized output mode.
  sync_mode_enable = '\027[?2026h',
}

---Generates the escape code to move the cursor.
---Rounds down the column and row values.
---@param opts {row:number, col:number}
---@return string
function M.move_cursor(opts)
  return string.format('\027[%s;%sH', math.floor(opts.row), math.floor(opts.col))
end

---Wraps one or more escape sequences for use with tmux passthrough.
---@param s string
---@return string
function M.escape_tmux_passthrough(s)
  return ('\027Ptmux;' .. string.gsub(s, '\027', '\027\027')) .. '\027\\'
end

return M
