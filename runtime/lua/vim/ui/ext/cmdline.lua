local ext = require('vim.ui.ext')
local api = vim.api
local M = {}

local row = 0 -- Current row in the cmdline buffer, > 0 for "cmdline_block".
--- Concatenate content chunks and set the text for the current row in the cmdline buffer.
---
---@alias CmdChunk table<integer,string>
---@alias CmdContent CmdChunk[]
---@param content CmdContent
---@param prompt string
local function set_text(content, prompt)
  for _, chunk in ipairs(content) do
    prompt = prompt .. chunk[2]
  end
  api.nvim_buf_set_lines(ext.cmdbuf, row, -1, false, { prompt .. ' ' })
end

local promptlen = 0 -- Current length of the prompt, stored for use in "cmdline_pos"
--- Set the cmdline buffer text and cursor position.
---
---@param content CmdContent
---@param pos integer
---@param firstc string
---@param prompt string
---@param indent integer
--@param level integer
M.cmdline_show = function(content, pos, firstc, prompt, indent)
  prompt = firstc .. prompt .. (' '):rep(indent)
  promptlen = prompt:len()
  set_text(content, prompt)

  -- Accommodate 'cmdheight' and cmdline window height to command text length.
  local height = math.max(ext.cmdheight, api.nvim_win_text_height(ext.wins[ext.tab].cmd, {}).all)
  if vim.o.cmdheight ~= height then
    vim.opt.eventignore:append('OptionSet')
    vim.o.cmdheight = height
    vim.opt.eventignore:remove('OptionSet')
    api.nvim_win_set_height(ext.wins[ext.tab].cmd, height)
    ext.msg_set_pos(false, height, 0)
  end
  M.cmdline_pos(pos)

  -- Enable/disable treesitter highlighter based on firstc.
  ext.cmdhl.active[ext.cmdbuf] = firstc == ':' and ext.cmdhl or nil
  ext.cmdline = true
end

--- Insert special character at cursor position.
---
---@param c string
---@param shift boolean
--@param level integer
M.cmdline_special_char = function(c, shift)
  api.nvim_win_call(ext.wins[ext.tab].cmd, function()
    api.nvim_put({ c }, shift and '' or 'c', false, false)
  end)
end

--- Set the cmdline cursor position.
---
---@param pos integer
--@param level integer
M.cmdline_pos = function(pos)
  api.nvim_win_set_cursor(ext.wins[ext.tab].cmd, { row + 1, promptlen + pos })
  -- api.nvim_redraw({ win = ext.wins[ext.tab].cmd, cursor = true })
end

local block_show = false -- Whether currently in "cmdline_block".
--- Leaving the cmdline, restore 'cmdheight' and 'ruler'.
M.cmdline_hide = function()
  if block_show then
    return -- No need to hide when still in "cmdline_block".
  end

  if vim.o.cmdheight ~= ext.cmdheight then
    vim.o.cmdheight = ext.cmdheight
    api.nvim_win_set_height(ext.wins[ext.tab].cmd, ext.cmdheight)
    ext.msg_set_pos(false, ext.cmdheight, 0)
  end

  -- Re-emit the last ruler message
  ext.msg.msg_ruler(ext.last_ruler)
end

--- Set multi-line cmdline buffer text.
---
---@param lines CmdContent[]
M.cmdline_block_show = function(lines)
  block_show = true
  for _, content in ipairs(lines) do
    set_text(content, ':')
    row = row + 1
  end
end

--- Append line to a multiline cmdline.
---
---@param line CmdContent
M.cmdline_block_append = function(line)
  set_text(line, ':')
  row = row + 1
end

--- Event handler for "block_hide". Clear cmdline buffer and leave the cmdline.
M.cmdline_block_hide = function()
  api.nvim_buf_set_lines(ext.cmdbuf, 0, row + 1, false, { '' })
  block_show = false
  M.cmdline_hide()
  row = 0
end

return M
