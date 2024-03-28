local ext = require('vim.ui.ext')
local row = 0 -- Row next message chunk will be written to.
local col = 0 -- Column next message chunk will be written to.
local prevwin = 0
local hlmap = setmetatable({}, {
  __index = function(hlmap, id)
    hlmap[id] = vim.fn.synIDattr(id, 'name')
    return hlmap[id]
  end,
})
local M = {}

local prompt = 'Press ENTER or type command to continue '
local function wait_return()
  vim.schedule(function()
    vim.api.nvim_win_set_cursor(ext.wins[ext.tab], { row + 2, #prompt })
    vim.fn.getchar()
    M.msg_clear()
    ext.cmd.cmdline_hide()
    vim.api.nvim_set_current_win(prevwin)
  end)
end

local last_kind = ''
local history_show = false
--@param kind string
---@alias MsgChunk table<integer,string>
---@alias MsgContent MsgChunk[]
---@param content MsgContent
---@param replace_last boolean
---@param setheight boolean

M.msg_show = function(kind, content, replace_last, setheight)
  if ext.cmdline or replace_last then
    -- When printing newline after cmdline, keep entered command in the buffer.
    col = ext.cmdline and content[1][2]:sub(1, 1) == '\n' and -1 or 0
    row = 0
    ext.cmdline = false
    -- Disable highlighter in the cmdbuf.
    if ext.cmdhl then
      ext.cmdhl = ext.cmdhl:destroy()
    end
  end
  last_kind = kind

  local buf = history_show and ext.hstbuf or ext.cmdbuf
  -- Loop over all chunks and split at newline
  for _, chunk in ipairs(content) do
    local start_col = col
    local start_row = row
    local sub_start = 1

    for i = 1, #chunk[2] do
      local newline = chunk[2]:sub(i, i) == '\n'
      -- Set buffer text at newline or end of chunk
      if newline or i == #chunk[2] then
        local empty = newline and i == sub_start and col == 0
        local str = empty and '' or chunk[2]:sub(sub_start, i - (newline and 1 or 0))

        if col == 0 then
          vim.api.nvim_buf_set_lines(buf, row, -1, false, { str })
        elseif col > 0 then
          vim.api.nvim_buf_set_text(buf, row, col, row, col, { str })
        end

        -- Increment row at newline and add empty line at end of chunk
        if newline then
          row = row + 1
          sub_start = i + 1
          if i == #chunk[2] then
            vim.api.nvim_buf_set_lines(buf, row, -1, false, { '' })
          end
        end
        col = newline and 0 or col + i - sub_start + 1
      end
    end

    -- Set highlight group for chunk
    vim.api.nvim_buf_set_extmark(buf, ext.ns, start_row, start_col, {
      end_row = row,
      end_col = col,
      hl_group = hlmap[chunk[1]],
      undo_restore = false,
      invalidate = true,
    })
  end

  if setheight ~= false then
    if ext.set_win_height(true) then
      vim.api.nvim_buf_set_lines(buf, row + 1, -1, false, { prompt })
      vim.api.nvim_buf_set_extmark(buf, ext.ns, row + 1, 0, {
        hl_group = 'Question',
        end_col = #prompt,
        undo_restore = false,
        invalidate = true,
      })
      prevwin = vim.api.nvim_get_current_win()
      wait_return()
    end
  end
end

M.msg_clear = function()
  if ext.cmdline then
    return
  end
  vim.api.nvim_buf_set_lines(ext.cmdbuf, 0, -1, false, { '' })
  vim.api.nvim_win_set_height(ext.wins[ext.tab], ext.cmdheight)
end

---@param content MsgContent
M.msg_showmode = function(content)
  if #content == 0 and last_kind == 'showmode' then
    M.msg_clear()
  elseif #content > 0 then
    M.msg_show('showmode', content, true, false)
  end
end

local scid ---@type integer
local ruid ---@type integer
local rucol ---@type integer

---@param content MsgContent
M.msg_showcmd = function(content)
  if scid and #content == 0 then
    vim.api.nvim_buf_del_extmark(ext.cmdbuf, ext.ns, scid)
  elseif #content > 0 and not content[1][2]:sub(0):match(':/?') then
    scid = vim.api.nvim_buf_set_extmark(ext.cmdbuf, ext.ns, 0, 0, {
      virt_text = { { content[1][2]:sub(-10), 'Normal' } },
      virt_text_win_col = (rucol or vim.o.columns) - 11,
      undo_restore = false,
      invalidate = true,
      id = scid,
    })
  end
end

---@param content MsgContent
M.msg_ruler = function(content)
  ext.last_ruler = content
  if ruid and content and #content == 0 then
    vim.api.nvim_buf_del_extmark(ext.cmdbuf, ext.ns, ruid)
  elseif content and #content > 0 then
    rucol = vim.o.columns - content[1][2]:len() - 1
    ruid = vim.api.nvim_buf_set_extmark(ext.cmdbuf, ext.ns, 0, 0, {
      virt_text = { { content[1][2], 'Normal' } },
      virt_text_win_col = rucol,
      undo_restore = false,
      invalidate = true,
      id = ruid,
    })
  end
end

---@alias MsgHistory table<string,MsgContent>
---@param entries MsgHistory[]
M.msg_history_show = function(entries)
  if #entries == 0 then
    return
  end

  prevwin = vim.api.nvim_get_current_win()
  ext.hstwin = vim.api.nvim_open_win(ext.hstbuf, true, {
    relative = 'editor',
    row = 0,
    col = 0,
    height = 1,
    width = 10000,
    style = 'minimal',
    zindex = 300,
  })
  vim.api.nvim_win_set_hl_ns(ext.hstwin, ext.ns)
  vim.api.nvim_create_autocmd('WinClosed', {
    group = ext.augroup,
    once = true,
    desc = 'Restore cmdheight when closing :messages window',
    callback = function()
      ext.hstwin = nil
      M.msg_clear()
      ext.cmd.cmdline_hide()
    end,
  })

  row = 0
  history_show = true
  for _, content in ipairs(entries) do
    col = 0
    M.msg_show(content[1], content[2], false, false)
    row = row + 1
  end
  history_show = false

  ext.set_win_height(false)
  vim.api.nvim_win_set_cursor(ext.hstwin, { row, col })
end

M.msg_history_clear = function() end

return M
