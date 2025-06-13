local api, o = vim.api, vim.o
local M = {
  msg = nil, ---@type vim._extui.messages
  cmd = nil, ---@type vim._extui.cmdline
  ns = api.nvim_create_namespace('nvim._ext_ui'),
  augroup = api.nvim_create_augroup('nvim._ext_ui', {}),
  cmdheight = -1, -- 'cmdheight' option value set by user.
  wins = { cmd = -1, dialog = -1, msg = -1, pager = -1 },
  bufs = { cmd = -1, dialog = -1, msg = -1, pager = -1 },
  cfg = {
    enable = true,
    msg = { -- Options related to the message module.
      ---@type 'cmd'|'msg' Where to place regular messages, either in the
      ---cmdline or in a separate ephemeral message window.
      target = 'cmd',
      timeout = 4000, -- Time a message is visible in the message window.
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

local tab = 0
--- Ensure the various buffers and windows have not been deleted.
function M.tab_check_wins()
  local curtab = api.nvim_get_current_tabpage()
  for _, type in ipairs({ 'cmd', 'dialog', 'msg', 'pager' }) do
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
      tab ~= curtab
      or not api.nvim_win_is_valid(M.wins[type])
      or not api.nvim_win_get_config(M.wins[type]).zindex -- no longer floating
    then
      local top = { vim.opt.fcs:get().horiz or o.ambw == 'single' and '─' or '-', 'WinSeparator' }
      local border = (type == 'pager' or type == 'dialog') and { '', top, '', '', '', '', '', '' }
      local cfg = vim.tbl_deep_extend('force', wincfg, {
        focusable = type == 'pager',
        mouse = type ~= 'cmd' and true or nil,
        anchor = type ~= 'cmd' and 'SE' or nil,
        hide = type ~= 'cmd' or M.cmdheight == 0 or nil,
        title = type == 'pager' and 'Pager' or nil,
        border = type == 'msg' and 'single' or border or 'none',
        -- kZIndexMessages < zindex < kZIndexCmdlinePopupMenu (grid_defs.h), pager below others.
        zindex = 200 - (type == 'pager' and 1 or 0),
        _cmdline_offset = type == 'cmd' and 0 or nil,
      })
      if tab ~= curtab and api.nvim_win_is_valid(M.wins[type]) then
        cfg = api.nvim_win_get_config(M.wins[type])
        api.nvim_win_close(M.wins[type], true)
      end
      M.wins[type] = api.nvim_open_win(M.bufs[type], false, cfg)
      if type == 'cmd' then
        api.nvim_win_set_hl_ns(M.wins[type], M.ns)
      end
      setopt = true
    elseif api.nvim_win_get_buf(M.wins[type]) ~= M.bufs[type] then
      api.nvim_win_set_buf(M.wins[type], M.bufs[type])
      setopt = true
    end

    if setopt then
      local name = { cmd = 'Cmd', dialog = 'Dialog', msg = 'Msg', pager = 'Pager' }
      api.nvim_buf_set_name(M.bufs[type], ('[%s]'):format(name[type]))
      if type == 'pager' then
        -- Close pager with `q`, same as `checkhealth`
        api.nvim_buf_set_keymap(M.bufs.pager, 'n', 'q', '<Cmd>wincmd c<CR>', {})
      end

      -- Fire a FileType autocommand with window context to let the user reconfigure local options.
      api.nvim_win_call(M.wins[type], function()
        api.nvim_set_option_value('wrap', true, { scope = 'local' })
        api.nvim_set_option_value('linebreak', false, { scope = 'local' })
        api.nvim_set_option_value('smoothscroll', true, { scope = 'local' })
        local ft = name[type]:sub(1, 1):lower() .. name[type]:sub(2)
        api.nvim_set_option_value('filetype', ft, { scope = 'local' })
        local ignore = 'all' .. (type == 'pager' and ',-TextYankPost' or '')
        api.nvim_set_option_value('eventignorewin', ignore, { scope = 'local' })
      end)
    end
  end
  tab = curtab
end

return M
