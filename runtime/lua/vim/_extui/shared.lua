local api, o = vim.api, vim.o
local M = {
  msg = nil, ---@type vim._extui.messages
  cmd = nil, ---@type vim._extui.cmdline
  ns = api.nvim_create_namespace('nvim._ext_ui'),
  augroup = api.nvim_create_augroup('nvim._ext_ui', {}),
  cmdheight = -1, -- 'cmdheight' option value set by user.
  -- Map of tabpage ID to box/cmd/more/prompt window IDs.
  wins = {}, ---@type { ['box'|'cmd'|'more'|'prompt']: integer }[]
  bufs = { box = -1, cmd = -1, more = -1, prompt = -1 },
  tab = 0, -- Current tabpage.
  cfg = {
    enable = true,
    msg = { -- Options related to the message module.
      ---@type 'box'|'cmd' Type of window used to place messages, either in the
      ---cmdline or in a separate ephemeral message box window.
      pos = 'cmd',
      box = { -- Options related to the message box window.
        timeout = 4000, -- Time a message is visible.
      },
    },
  },
}
local wincfg = { -- Default cfg for nvim_open_win().
  relative = 'laststatus',
  style = 'minimal',
  col = 0,
  row = 1,
  width = 10000,
  height = 1,
  noautocmd = true,
}

--- Ensure the various buffers and windows have not been deleted.
function M.tab_check_wins()
  M.tab = api.nvim_get_current_tabpage()
  if not M.wins[M.tab] then
    M.wins[M.tab] = { box = -1, cmd = -1, more = -1, prompt = -1 }
  end

  for _, type in ipairs({ 'box', 'cmd', 'more', 'prompt' }) do
    local setopt = not api.nvim_buf_is_valid(M.bufs[type])
    if setopt then
      M.bufs[type] = api.nvim_create_buf(false, true)
      if type == 'cmd' then
        -- Attach highlighter to the cmdline buffer.
        local parser = assert(vim.treesitter.get_parser(M.bufs.cmd, 'vim', {}))
        M.cmd.highlighter = vim.treesitter.highlighter.new(parser)
      end
    end

    if
      not api.nvim_win_is_valid(M.wins[M.tab][type])
      or not api.nvim_win_get_config(M.wins[M.tab][type]).zindex -- no longer floating
    then
      local top = { vim.opt.fcs:get().horiz or o.ambw == 'single' and '─' or '-', 'WinSeparator' }
      local border = (type == 'more' or type == 'prompt') and { '', top, '', '', '', '', '', '' }
      local cfg = vim.tbl_deep_extend('force', wincfg, {
        focusable = type == 'more',
        mouse = type ~= 'cmd' and true or nil,
        anchor = type ~= 'cmd' and 'SE' or nil,
        hide = type ~= 'cmd' or M.cmdheight == 0 or nil,
        title = type == 'more' and 'Messages' or nil,
        border = type == 'box' and 'single' or border or 'none',
        -- kZIndexMessages < zindex < kZIndexCmdlinePopupMenu (grid_defs.h), 'more' below others.
        zindex = 200 - (type == 'more' and 1 or 0),
        _cmdline_offset = type == 'cmd' and 0 or nil,
      })
      M.wins[M.tab][type] = api.nvim_open_win(M.bufs[type], false, cfg)
      if type == 'cmd' then
        api.nvim_win_set_hl_ns(M.wins[M.tab][type], M.ns)
      end
      setopt = true
    elseif api.nvim_win_get_buf(M.wins[M.tab][type]) ~= M.bufs[type] then
      api.nvim_win_set_buf(M.wins[M.tab][type], M.bufs[type])
      setopt = true
    end

    if setopt then
      api.nvim_buf_set_name(M.bufs[type], 'vim._extui.' .. type)
      if type == 'more' then
        -- Close more window with `q`, same as `checkhealth`
        api.nvim_buf_set_keymap(M.bufs.more, 'n', 'q', '<Cmd>wincmd c<CR>', {})
      end

      -- Fire a FileType autocommand with window context to let the user reconfigure local options.
      api.nvim_win_call(M.wins[M.tab][type], function()
        api.nvim_set_option_value('wrap', true, { scope = 'local' })
        api.nvim_set_option_value('linebreak', false, { scope = 'local' })
        api.nvim_set_option_value('smoothscroll', true, { scope = 'local' })
        local ft = type == 'cmd' and 'cmdline' or ('msg' .. type)
        api.nvim_set_option_value('filetype', ft, { scope = 'local' })
        local ignore = 'all' .. (type == 'more' and ',-TextYankPost' or '')
        api.nvim_set_option_value('eventignorewin', ignore, { scope = 'local' })
      end)
    end
  end
end

return M
