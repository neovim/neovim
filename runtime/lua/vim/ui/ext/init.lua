local api = vim.api
local M = {
  ns = api.nvim_create_namespace('nvim_ext_ui'),
  augroup = api.nvim_create_augroup('nvim_ext_ui', {}),
  lsauid = -1, -- Autocommand id for 'laststatus' WinOpen/Closed handler.
  cmdline = false, -- Whether the last written text to cmdbuf was cmdline text.
  cmdheight = 1, -- 'cmdheight' value set by user.
  cmdbuf = -1, -- Buffer handle used in cmdline window.
  msgbuf = -1, -- Buffer handle used in message window.
  wins = {}, ---@type { [string]: integer }[] Map of tabpages to cmdline/message window.
  tab = 0, -- Current tabpage.
}

api.nvim_set_hl(M.ns, 'Normal', { link = 'MsgArea' })
api.nvim_set_hl(M.ns, 'Search', { link = 'MsgArea' })
api.nvim_set_hl(M.ns, 'CurSearch', { link = 'MsgArea' })
api.nvim_set_hl(M.ns, 'IncSearch', { link = 'MsgArea' })
api.nvim_create_autocmd('OptionSet', {
  group = M.augroup,
  pattern = { 'cmdheight', 'laststatus' },
  callback = function(ev)
    if ev.match == 'cmdheight' then
      M.cmdheight = vim.v.option_new
      api.nvim_win_set_height(M.wins[M.tab].cmd, math.max(1, M.cmdheight))
    elseif vim.v.option_new == 1 and M.lsauid == -1 then -- 'laststatus' == 1
      M.lsauid = api.nvim_create_autocmd({ 'WinNew', 'WinClosed' }, {
        group = M.augroup,
        callback = function(evt)
          M.msg_set_pos(false, M.cmdheight, evt.match)
        end,
        desc = 'Manipulate message window dimensions after number of windows changes.',
      })
    elseif M.lsauid > 0 then -- 'laststatus' ~= 1
      api.nvim_del_autocmd(M.lsauid)
      M.lsauid = -1
    end
    M.msg_set_pos(false, M.cmdheight, 0)
  end,
  desc = 'Manipulate cmdline and message window dimensions after changing option values.',
})

--- Ensure the buffers have not been deleted, and the cmdline/message window
--- in the current tabpage have not been closed.
M.tab_check_wins = function()
  if not api.nvim_buf_is_valid(M.cmdbuf) then
    M.cmdbuf = api.nvim_create_buf(false, true)
    -- Attach highlighter to the cmdbuf.
    local ok, ts = pcall(require, 'vim.treesitter')
    if ok then
      M.cmdhl = ts.highlighter.new(ts.get_parser(M.cmdbuf, 'vim', {}), {})
    end
  end

  if not api.nvim_buf_is_valid(M.msgbuf) then
    M.msgbuf = api.nvim_create_buf(false, true)
  end

  M.tab = api.nvim_get_current_tabpage()
  if not M.wins[M.tab] then
    M.wins[M.tab] = { cmd = -1, msg = -1 }
  end

  local style = {
    relative = 'editor',
    col = 0,
    row = 10000,
    width = 10000,
    height = 1,
    style = 'minimal',
    focusable = false,
    noautocmd = true,
    zindex = 300,
  }

  if not api.nvim_win_is_valid(M.wins[M.tab].cmd) then
    M.wins[M.tab].cmd = api.nvim_open_win(M.cmdbuf, false, style)
    api.nvim_win_set_hl_ns(M.wins[M.tab].cmd, M.ns)
  elseif api.nvim_win_get_buf(M.wins[M.tab].cmd) ~= M.cmdbuf then
    api.nvim_win_set_buf(M.wins[M.tab].cmd, M.cmdbuf)
  end

  if not api.nvim_win_is_valid(M.wins[M.tab].msg) then
    style.hide = true
    M.wins[M.tab].msg = api.nvim_open_win(M.msgbuf, false, style)
    api.nvim_win_set_hl_ns(M.wins[M.tab].msg, M.ns)
    api.nvim_set_option_value('winblend', 30, { win = M.wins[M.tab].msg })
    api.nvim_set_option_value('statusline', 'Messages', { win = M.wins[M.tab].msg })
  elseif api.nvim_win_get_buf(M.wins[M.tab].msg) ~= M.msgbuf then
    api.nvim_win_set_buf(M.wins[M.tab].msg, M.msgbuf)
  end
end

---@param closedid integer #ID of window that will be closed.
---@return integer #Height of the 'laststatus' status line.
local function ls_height(closedid)
  local ls = vim.o.laststatus
  if ls == 1 then
    local win, wins, winlist = 1, 0, api.nvim_tabpage_list_wins(0)
    while wins < 2 and win <= #winlist do
      local id = winlist[win]
      wins = wins + ((id == tonumber(closedid) or api.nvim_win_get_config(id).zindex) and 0 or 1)
      win = win + 1
    end
    return (wins > 1 and 1 or 0)
  end
  return (ls == 0 and 0 or 1)
end

--- Adjust the message window dimensions after certain events.
---
---@param newheight boolean #Whether to calculate a new height based on message text height.
---@param cmdheight integer #Current 'cmdheight'.
---@param closedid integer #ID of the to be closed window in a WinClosed event.
M.msg_set_pos = function(newheight, cmdheight, closedid)
  local win = M.wins[M.tab].msg
  local h = newheight and api.nvim_win_text_height(win, {}).all or api.nvim_win_get_height(win)
  if h <= math.ceil(vim.o.lines * 0.5) then
    local width = api.nvim_win_get_width(win)
    api.nvim_win_set_config(win, {
      hide = false,
      relative = 'editor',
      height = newheight and h or nil,
      row = vim.o.lines - cmdheight - h - ls_height(closedid),
      col = vim.o.columns - width,
    })
  else
    M.msg.msg_to_split()
  end
end

return M
