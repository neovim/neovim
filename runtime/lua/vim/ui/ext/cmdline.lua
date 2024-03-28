local M = {}
local ext = require('vim.ui.ext')
local row = 0 -- Current row in the cmdline buffer, > 0 for "cmdline_block".

--- Concatenate content chunks and set the text for the current row in the cmdline buffer.
---
---@alias CmdChunk table<integer,string>
---@alias CmdContent CmdChunk[]
---@param content CmdContent
---@param str string
---@param highlight boolean
local function set_text(content, str, highlight)
  for _, chunk in ipairs(content) do
    str = str .. chunk[2]
  end
  vim.api.nvim_buf_set_lines(ext.cmdbuf, row, -1, false, { str .. ' ' })

  ext.set_win_height(false)
  if highlight then
    -- Highlight the cmdline text with treesitter Vimscript parser.
    local ok, ts = pcall(require, 'vim.treesitter')
    if ok and not ext.cmdhl then
      ext.cmdhl = ts.highlighter.new(ts.get_parser(ext.cmdbuf, 'vim', {}), {})
    end
  end
end

local promptlen = 0 -- Current length of the prompt, stored for use in "cmdline_pos"

---@param content CmdContent
---@param pos string
---@param firstc string
---@param prompt string
---@param indent integer
--@param level integer
M.cmdline_show = function(
  content,
  pos,
  firstc,
  prompt,
  indent --[[,level]]
)
  local win = ext.wins[ext.tab]
  if not ext.cmdline then
    vim.api.nvim_win_set_config(win, { hide = false, height = math.max(ext.cmdheight, 1) })
    ext.set_cmdheight(ext.cmdheight)
  end

  ext.cmdline = true
  prompt = firstc .. prompt .. (' '):rep(indent)
  promptlen = prompt:len()
  set_text(content, prompt, firstc == ':')
  vim.api.nvim_win_set_cursor(win, { row + 1, promptlen + pos })
end

---@param c string
---@param shift boolean
--@param level integer
M.cmdline_special_char = function(
  c,
  shift --[[,level]]
)
  vim.api.nvim_put({ c }, shift and '' or 'c', false, false)
end

---@param pos integer
--@param level integer
M.cmdline_pos = function(
  pos --[[,level]]
)
  vim.api.nvim_win_set_cursor(ext.wins[ext.tab], { row + 1, promptlen + pos })
end

local block_show = false -- Whether currently in "cmdline_block".

M.cmdline_hide = function()
  if block_show then
    return -- No need to hide when still in "cmdline_block".
  end

  if not ext.hstwin then
    ext.set_win_height(false)
    ext.msg.msg_ruler(ext.last_ruler)
  end
end

--- @param lines CmdContent[]
M.cmdline_block_show = function(lines)
  block_show = true
  for _, content in ipairs(lines) do
    set_text(content, ':', true)
    row = row + 1
  end
end

--- @param line CmdContent
M.cmdline_block_append = function(line)
  set_text(line, ':', true)
  row = row + 1
end

M.cmdline_block_hide = function()
  vim.api.nvim_buf_set_lines(ext.cmdbuf, 0, row + 1, false, { '' })
  block_show = false
  M.cmdline_hide()
  row = 0
end

return M
