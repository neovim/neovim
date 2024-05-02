local ext = require('vim._extui.shared')
local api = vim.api
---@class vim._extui.cmdline
local M = {
  active = false, -- Whether the cmdline is currently active (false after cmdline_hide).
  shown = false, -- Whether the last entered command is still visible (false after msg_showmode).
  prompt = false, -- Whether a prompt is active; messages are placed in the 'prompt' buffer/window.
}

local row = 0 -- Current row in the cmdline buffer, > 0 for "cmdline_block".
--- Concatenate content chunks and set the text for the current row in the cmdline buffer.
---
---@alias CmdChunk [integer, string]
---@alias CmdContent CmdChunk[]
---@param content CmdContent
---@param prompt string
local function set_text(content, prompt)
  for _, chunk in ipairs(content) do
    prompt = prompt .. chunk[2]
  end
  api.nvim_buf_set_lines(ext.bufs.cmd, row, -1, false, { prompt .. ' ' })
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
  M.active, M.shown, M.prompt = true, true, #prompt > 0
  ext.cmdhl.active[ext.bufs.cmd] = firstc == ':' and ext.cmdhl or nil
  prompt = firstc .. prompt .. (' '):rep(indent)
  promptlen = #prompt
  set_text(content, prompt)

  -- Accommodate 'cmdheight' and cmdline window height to command text length.
  local height = math.max(ext.cmdheight, api.nvim_win_text_height(ext.wins[ext.tab].cmd, {}).all)
  if vim.o.cmdheight ~= height then
    vim.opt.eventignore:append('OptionSet')
    vim.o.cmdheight = height
    vim.opt.eventignore:remove('OptionSet')
  end
  if ext.cmdheight == 0 and api.nvim_win_get_config(ext.wins[ext.tab].cmd).hide == true then
    api.nvim_win_set_config(ext.wins[ext.tab].cmd, { hide = false, height = height })
    ext.msg.set_pos()
  elseif api.nvim_win_get_height(ext.wins[ext.tab].cmd) ~= height then
    api.nvim_win_set_height(ext.wins[ext.tab].cmd, height)
    ext.msg.set_pos()
  end
  M.cmdline_pos(pos)
  if ext.cfg.messages.pos == 'cmd' then
    ext.msg.dupe, ext.msg.prev_msg = 0, ''
  end
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

local col = 0 -- Current cursor column (promptlen + pos).
--- Set the cmdline cursor position.
---
---@param pos integer
--@param level integer
M.cmdline_pos = function(pos)
  if col ~= promptlen + pos then
    col = promptlen + pos
    api.nvim_win_set_cursor(ext.wins[ext.tab].cmd, { row + 1, col })
  end
end

local in_block = false -- Whether currently in "cmdline_block".
--- Leaving the cmdline, restore 'cmdheight' and 'ruler'.
---
--@param level integer
---@param abort boolean
M.cmdline_hide = function(_, abort)
  if in_block then
    return -- No need to hide when still in "cmdline_block".
  end
  if abort then
    api.nvim_buf_set_lines(ext.bufs.cmd, 0, -1, false, {})
  end
  -- Avoid clearing prompt window when it is re-entered before the next event
  -- loop iteration. E.g. when a non-choice confirm button is pressed.
  if M.prompt then
    vim.schedule(function()
      if not M.prompt then
        api.nvim_buf_set_lines(ext.bufs.cmd, 0, -1, false, {})
        api.nvim_win_set_config(ext.wins[ext.tab].prompt, { hide = true })
      end
    end)
  end

  M.active, M.prompt, col = false, false, 0
  if vim.o.cmdheight ~= ext.cmdheight then
    vim.o.cmdheight = ext.cmdheight
    if ext.cmdheight == 0 then
      api.nvim_win_set_config(ext.wins[ext.tab].cmd, { hide = true })
    else
      api.nvim_win_set_height(ext.wins[ext.tab].cmd, ext.cmdheight)
    end
    ext.msg.set_pos()
  end
end

--- Set multi-line cmdline buffer text.
---
---@param lines CmdContent[]
M.cmdline_block_show = function(lines)
  in_block = true
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
  api.nvim_buf_set_lines(ext.bufs.cmd, 0, row + 1, false, { '' })
  in_block, row = false, 0
  M.cmdline_hide(nil, false)
end

return M
