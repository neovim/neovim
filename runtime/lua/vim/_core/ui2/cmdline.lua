local ui = require('vim._core.ui2')
local api, fn = vim.api, vim.fn
---@class vim._core.ui2.cmdline
local M = {
  highlighter = nil, ---@type vim.treesitter.highlighter?
  indent = 0, -- Current indent for block event.
  prompt = false, -- Whether a prompt is active; route to dialog regardless of ui.cfg.msg.target.
  dialog = false, -- Whether a dialog window was opened.
  srow = 0, -- Buffer row at which the current cmdline starts; > 0 in block mode.
  erow = 0, -- Buffer row at which the current cmdline ends; messages appended here in block mode.
  level = 0, -- Current cmdline level; 0 when inactive.
  wmnumode = 0, -- wildmenumode() when not using the pum, dialog position adjusted when toggled.
}

--- Set the 'cmdheight' and cmdline window height. Reposition message windows.
---
---@param win integer Cmdline window in the current tabpage.
---@param hide boolean Whether to hide or show the window.
---@param height integer (Text)height of the cmdline window.
local function win_config(win, hide, height)
  if ui.cmdheight == 0 and api.nvim_win_get_config(win).hide ~= hide then
    api.nvim_win_set_config(win, { hide = hide, height = not hide and height or nil })
  elseif api.nvim_win_get_height(win) ~= height then
    api.nvim_win_set_height(win, height)
  end
  if vim.o.cmdheight ~= height then
    -- Avoid moving the cursor with 'splitkeep' = "screen", and altering the user
    -- configured value with noautocmd.
    vim._with({ noautocmd = true, o = { splitkeep = 'screen' } }, function()
      vim.o.cmdheight = height
    end)
    ui.msg.set_pos()
  elseif M.wmnumode ~= (M.dialog and fn.pumvisible() == 0 and fn.wildmenumode() or 0) then
    M.wmnumode = (M.wmnumode == 1 and 0 or 1)
    ui.msg.set_pos()
  end
end

local cmdbuff = '' ---@type string Stored cmdline used to calculate translation offset.
local promptlen = 0 -- Current length of the last line in the prompt.
--- Concatenate content chunks and set the text for the current row in the cmdline buffer.
---
---@alias CmdChunk [integer, string]
---@alias CmdContent CmdChunk[]
---@param content CmdContent
---@param prompt string
local function set_text(content, prompt)
  local lines = {} ---@type string[]
  for line in (prompt .. '\n'):gmatch('(.-)\n') do
    lines[#lines + 1] = fn.strtrans(line)
  end
  cmdbuff, promptlen, M.erow = '', #lines[#lines], M.srow + #lines - 1
  for _, chunk in ipairs(content) do
    cmdbuff = cmdbuff .. chunk[2]
  end
  lines[#lines] = ('%s%s '):format(lines[#lines], fn.strtrans(cmdbuff))
  api.nvim_buf_set_lines(ui.bufs.cmd, M.srow, -1, false, lines)
end

--- Set the cmdline buffer text and cursor position.
---
---@param content CmdContent
---@param pos integer
---@param firstc string
---@param prompt string
---@param indent integer
---@param level integer
---@param hl_id integer
function M.cmdline_show(content, pos, firstc, prompt, indent, level, hl_id)
  M.level, M.indent, M.prompt = level, indent, #prompt > 0
  if M.highlighter == nil or M.highlighter.bufnr ~= ui.bufs.cmd then
    local parser = assert(vim.treesitter.get_parser(ui.bufs.cmd, 'vim', {}))
    M.highlighter = vim.treesitter.highlighter.new(parser)
  end
  -- Only enable TS highlighter for Ex commands (not search or filter commands).
  M.highlighter.active[ui.bufs.cmd] = firstc == ':' and M.highlighter or nil
  if ui.msg.cmd.msg_row ~= -1 then
    ui.msg.msg_clear()
  end
  ui.msg.virt.last = { {}, {}, {}, {} }

  set_text(content, ('%s%s%s'):format(firstc, prompt, (' '):rep(indent)))
  if promptlen > 0 and hl_id > 0 then
    api.nvim_buf_set_extmark(ui.bufs.cmd, ui.ns, 0, 0, { hl_group = hl_id, end_col = promptlen })
  end

  local height = math.max(ui.cmdheight, api.nvim_win_text_height(ui.wins.cmd, {}).all)
  win_config(ui.wins.cmd, false, height)
  M.cmdline_pos(pos)
end

--- Insert special character at cursor position.
---
---@param c string
---@param shift boolean
--@param level integer
function M.cmdline_special_char(c, shift)
  api.nvim_win_call(ui.wins.cmd, function()
    api.nvim_put({ c }, shift and '' or 'c', false, false)
  end)
end

local curpos = { 0, 0 } -- Last drawn cursor position.
--- Set the cmdline cursor position.
---
---@param pos integer
--@param level integer
function M.cmdline_pos(pos)
  pos = #fn.strtrans(cmdbuff:sub(1, pos))
  if curpos[1] ~= M.erow + 1 or curpos[2] ~= promptlen + pos then
    curpos[1], curpos[2] = M.erow + 1, promptlen + pos
    -- Add matchparen highlighting to non-prompt part of cmdline.
    if pos > 0 and fn.exists('#matchparen#CursorMoved') == 1 then
      api.nvim_win_set_cursor(ui.wins.cmd, { curpos[1], curpos[2] - 1 })
      vim._with({ win = ui.wins.cmd, wo = { eventignorewin = '' } }, function()
        api.nvim_exec_autocmds('CursorMoved', {})
      end)
    end
    api.nvim_win_set_cursor(ui.wins.cmd, curpos)
  end
end

--- Leaving the cmdline, restore 'cmdheight' and 'ruler'.
---
---@param level integer
---@param abort boolean
function M.cmdline_hide(level, abort)
  if M.srow > 0 or level > (fn.getcmdwintype() == '' and 1 or 2) then
    return -- No need to hide when still in nested cmdline or cmdline_block.
  end

  fn.clearmatches(ui.wins.cmd) -- Clear matchparen highlights.
  api.nvim_win_set_cursor(ui.wins.cmd, { 1, 0 })
  if M.prompt or abort then
    -- Clear cmd buffer prompt or aborted command (non-abort is left visible).
    api.nvim_buf_set_lines(ui.bufs.cmd, 0, -1, false, {})
  end

  vim.schedule(function()
    -- Avoid clearing prompt window when it is re-entered before the next event
    -- loop iteration. E.g. when a non-choice confirm button is pressed.
    if M.dialog and M.level == 0 then
      api.nvim_buf_set_lines(ui.bufs.dialog, 0, -1, false, {})
      api.nvim_win_set_config(ui.wins.dialog, { hide = true })
      vim.on_key(nil, ui.msg.dialog_on_key)
      M.dialog, ui.msg.dialog_on_key = false, nil
    end
  end)

  M.prompt, M.level, curpos[1], curpos[2] = false, 0, 0, 0
  win_config(ui.wins.cmd, true, ui.cmdheight)
end

--- Set multi-line cmdline buffer text.
---
---@param lines CmdContent[]
function M.cmdline_block_show(lines)
  for _, content in ipairs(lines) do
    set_text(content, ':')
    M.srow = M.srow + 1
  end
end

--- Append line to a multiline cmdline.
---
---@param line CmdContent
function M.cmdline_block_append(line)
  set_text(line, ':')
  M.srow = M.srow + 1
end

--- Clear cmdline buffer and leave the cmdline.
function M.cmdline_block_hide()
  M.srow = 0
  M.cmdline_hide(M.level, true)
end

return M
