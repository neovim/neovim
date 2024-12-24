local api = vim.api
local M = {
  msg = nil, ---@type vim._extui.messages
  cmd = nil, ---@type vim._extui.cmdline
  ns = api.nvim_create_namespace('nvim_ext_ui'),
  augroup = api.nvim_create_augroup('nvim_ext_ui', {}),
  cmdheight = 0, -- 'cmdheight' option value set by user.
  wins = {}, ---@type { [string]: integer }[] Map of tabpages to cmdline/message/more window.
  bufs = { cmd = -1, msg = -1, more = -1 }, -- Buffers used in cmdline/message/more window.
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
    M.wins[M.tab] = { cmd = -1, msg = -1, more = -1 }
  end

  for _, type in ipairs({ 'cmd', 'msg', 'more' }) do
    if not api.nvim_buf_is_valid(M.bufs[type]) then
      M.bufs[type] = api.nvim_create_buf(false, true)
      -- Attach highlighter to the cmdline buffer.
      if has_ts and type == 'cmd' then
        M.cmdhl = ts.highlighter.new(assert(ts.get_parser(M.bufs.cmd, 'vim', {}), {}))
      end
    end

    if not api.nvim_win_is_valid(M.wins[M.tab][type]) then
      local tgc = vim.o.termguicolors
      local cfg = vim.tbl_deep_extend('force', M.wincfg, {
        border = type == 'msg' and not tgc and 'single' or nil,
        hide = type ~= 'cmd' or M.cmdheight == 0 or nil,
      })
      M.wins[M.tab][type] = api.nvim_open_win(M.bufs[type], false, cfg)
      api.nvim_win_set_hl_ns(M.wins[M.tab][type], M.ns)
      if type == 'msg' and tgc then
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
