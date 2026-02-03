local api = vim.api
local M = {
  msg = nil, ---@type vim._extui.messages
  cmd = nil, ---@type vim._extui.cmdline
  ns = api.nvim_create_namespace('nvim._ext_ui'),
  augroup = api.nvim_create_augroup('nvim._ext_ui', {}),
  cmdheight = vim.o.cmdheight, -- 'cmdheight' option value set by user.
  redrawing = false, -- True when redrawing to display UI event.
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
--- @type vim.api.keyset.win_config
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
---Ensure target buffers and windows are still valid.
function M.check_targets()
  local curtab = api.nvim_get_current_tabpage()
  for i, type in ipairs({ 'cmd', 'dialog', 'msg', 'pager' }) do
    local setopt = not api.nvim_buf_is_valid(M.bufs[type])
    if setopt then
      M.bufs[type] = api.nvim_create_buf(false, false)
    end

    if
      tab ~= curtab
      or not api.nvim_win_is_valid(M.wins[type])
      or not api.nvim_win_get_config(M.wins[type]).zindex -- no longer floating
    then
      local cfg = vim.tbl_deep_extend('force', wincfg, {
        focusable = type == 'pager',
        mouse = type ~= 'cmd' and true or nil,
        anchor = type ~= 'cmd' and 'SE' or nil,
        hide = type ~= 'cmd' or M.cmdheight == 0 or nil,
        border = type ~= 'msg' and 'none' or nil,
        -- kZIndexMessages < cmd zindex < kZIndexCmdlinePopupMenu (grid_defs.h), pager below others.
        zindex = 201 - i,
        _cmdline_offset = type == 'cmd' and 0 or nil,
      })
      if tab ~= curtab and api.nvim_win_is_valid(M.wins[type]) then
        cfg = api.nvim_win_get_config(M.wins[type])
        api.nvim_win_close(M.wins[type], true)
      end
      M.wins[type] = api.nvim_open_win(M.bufs[type], false, cfg)
      setopt = true
    elseif api.nvim_win_get_buf(M.wins[type]) ~= M.bufs[type] then
      api.nvim_win_set_buf(M.wins[type], M.bufs[type])
      setopt = true
    end

    if setopt then
      -- Set options without firing OptionSet and BufFilePost.
      vim._with({ win = M.wins[type], noautocmd = true }, function()
        local ignore = 'all,-FileType' .. (type == 'pager' and ',-TextYankPost' or '')
        api.nvim_set_option_value('eventignorewin', ignore, { scope = 'local' })
        api.nvim_set_option_value('wrap', true, { scope = 'local' })
        api.nvim_set_option_value('linebreak', false, { scope = 'local' })
        api.nvim_set_option_value('smoothscroll', true, { scope = 'local' })
        api.nvim_set_option_value('breakindent', false, { scope = 'local' })
        api.nvim_set_option_value('foldenable', false, { scope = 'local' })
        api.nvim_set_option_value('showbreak', '', { scope = 'local' })
        api.nvim_set_option_value('spell', false, { scope = 'local' })
        api.nvim_set_option_value('swapfile', false, { scope = 'local' })
        api.nvim_set_option_value('modifiable', true, { scope = 'local' })
        api.nvim_set_option_value('bufhidden', 'hide', { scope = 'local' })
        api.nvim_set_option_value('buftype', 'nofile', { scope = 'local' })
        -- Use MsgArea except in the msg window. Hide Search highlighting except in the pager.
        local search_hide = 'Search:,CurSearch:,IncSearch:'
        local hl = 'Normal:MsgArea,' .. search_hide
        if type == 'pager' then
          hl = 'Normal:MsgArea'
        elseif type == 'msg' then
          hl = search_hide
        end
        api.nvim_set_option_value('winhighlight', hl, { scope = 'local' })
      end)
      api.nvim_buf_set_name(M.bufs[type], ('[%s]'):format(type:sub(1, 1):upper() .. type:sub(2)))
      -- Fire FileType with window context to let the user reconfigure local options.
      vim._with({ win = M.wins[type] }, function()
        api.nvim_set_option_value('filetype', type, { scope = 'local' })
      end)

      if type == 'pager' then
        -- Close pager with `q`, same as `checkhealth`
        api.nvim_buf_set_keymap(M.bufs.pager, 'n', 'q', '<Cmd>wincmd c<CR>', {})
      elseif type == M.cfg.msg.target then
        M.msg.prev_msg = '' -- Will no longer be visible.
      end
    end
  end
  tab = curtab
end

return M
