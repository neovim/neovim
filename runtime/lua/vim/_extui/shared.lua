local api = vim.api
local o = vim.o
local M = {
  msg = nil, ---@type vim._extui.messages
  cmd = nil, ---@type vim._extui.cmdline
  ns = api.nvim_create_namespace('nvim_ext_ui'),
  augroup = api.nvim_create_augroup('nvim_ext_ui', {}),
  cmdheight = 0, -- 'cmdheight' option value set by user.
  wins = {}, ---@type { [string]: integer }[] Map of tabpage to cmdline/message/more/list window.
  bufs = { cmd = -1, msg = -1, more = -1, list = -1 },
  tab = 0, -- Current tabpage.
  wincfg = { -- Default cfg for nvim_open_win().
    relative = 'editor',
    style = 'minimal',
    col = 0,
    row = 10000,
    width = 10000,
    height = 1,
    focusable = false,
    noautocmd = true,
    zindex = 300,
  },
}

local has_ts, ts = pcall(require, 'vim.treesitter')
--- Ensure the various buffers and windows have not been deleted.
M.tab_check_wins = function()
  M.tab = api.nvim_get_current_tabpage()
  if not M.wins[M.tab] then
    M.wins[M.tab] = { cmd = -1, msg = -1, more = -1, list = -1 }
  end

  for _, type in ipairs({ 'cmd', 'msg', 'more', 'list' }) do
    if not api.nvim_buf_is_valid(M.bufs[type]) then
      M.bufs[type] = api.nvim_create_buf(false, true)
      -- Attach highlighter to the cmdline buffer.
      if has_ts and type == 'cmd' then
        M.cmdhl = ts.highlighter.new(assert(ts.get_parser(M.bufs.cmd, 'vim', {}), {}))
      end
    end

    if not api.nvim_win_is_valid(M.wins[M.tab][type]) then
      local top = { vim.opt.fcs:get().horiz or o.ambw == 'single' and '─' or '-', 'WinSeparator' }
      local border = (type == 'more' or type == 'list') and { '', top, '', '', '', '', '', '' } or nil
      local cfg = vim.tbl_deep_extend('force', M.wincfg, {
        hide = type ~= 'cmd' or M.cmdheight == 0 or nil,
        title = type == 'more' and 'Messages' or nil,
        border = type == 'msg' and not o.termguicolors and 'single' or border,
      })
      M.wins[M.tab][type] = api.nvim_open_win(M.bufs[type], false, cfg)
      api.nvim_win_set_hl_ns(M.wins[M.tab][type], M.ns)
      if type == 'msg' and o.termguicolors then
        vim.wo[M.wins[M.tab][type]].winblend = 30
      end
      if type ~= 'cmd' then
        vim.wo[M.wins[M.tab][type]].linebreak = false
        vim.wo[M.wins[M.tab][type]].smoothscroll = true
      end
    elseif api.nvim_win_get_buf(M.wins[M.tab][type]) ~= M.bufs[type] then
      api.nvim_win_set_buf(M.wins[M.tab][type], M.bufs[type])
    end
  end
end

return M
