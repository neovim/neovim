local api = vim.api
local ext = require('vim._extui.shared')
ext.msg = require('vim._extui.messages')
ext.cmd = require('vim._extui.cmdline')
local M = {}

local function ui_callback(event, ...)
  local handler = ext.msg[event] or ext.cmd[event]
  if not handler then
    return
  end
  vim.opt_global.eventignore:append('all')
  ext.tab_check_wins()
  handler(...)
  vim.api.nvim__redraw({
    flush = true,
    cursor = handler == ext.cmd[event] and true or nil,
    win = handler == ext.cmd[event] and ext.wins[ext.tab].cmd or nil,
  })
  vim.opt_global.eventignore:remove('all')
end
local scheduled_ui_callback = vim.schedule_wrap(ui_callback)

M.enable = function(opts)
  ext.cfg = vim.tbl_deep_extend('keep', opts, ext.cfg)
  if ext.cfg.enable == false then
    -- Detach and cleanup windows, buffers and autocommands.
    for _, tab in ipairs(api.nvim_list_tabpages()) do
      for _, win in pairs(ext.wins[tab] or {}) do
        api.nvim_win_close(win, true)
      end
    end
    for _, buf in pairs(ext.bufs) do
      api.nvim_buf_delete(buf, {})
    end
    api.nvim_clear_autocmds({ group = ext.augroup })
    vim.ui_detach(ext.ns)
    return
  end

  ext.cmdheight = vim.o.cmdheight
  vim.ui_attach(ext.ns, { ext_cmdline = true, ext_messages = true }, function(event, ...)
    if vim.in_fast_event() then
      scheduled_ui_callback(event, ...)
    else
      ui_callback(event, ...)
    end
  end)
  vim.o.cmdheight = ext.cmdheight

  api.nvim_set_hl(ext.ns, 'Normal', { link = 'MsgArea' })
  api.nvim_set_hl(ext.ns, 'Search', { link = 'MsgArea' })
  api.nvim_set_hl(ext.ns, 'CurSearch', { link = 'MsgArea' })
  api.nvim_set_hl(ext.ns, 'IncSearch', { link = 'MsgArea' })

  api.nvim_create_autocmd('VimResized', {
    group = ext.augroup,
    callback = function()
      ext.msg.set_pos()
    end,
    desc = 'Manipulate cmdline and message window dimensions after shell resize.',
  })

  api.nvim_create_autocmd('OptionSet', {
    group = ext.augroup,
    pattern = { 'cmdheight', 'termguicolors' },
    callback = function(ev)
      ext.tab_check_wins()
      if ev.match == 'cmdheight' then
        -- 'cmdheight' set; (un)hide cmdline window and set its height.
        ext.cmdheight = vim.v.option_new
        local cfg = { height = math.max(ext.cmdheight, 1), hide = ext.cmdheight == 0 }
        api.nvim_win_set_config(ext.wins[ext.tab].cmd, cfg)
        if ext.cmdheight == 0 then
          ext.cfg.messages.pos = 'box'
        end
      elseif ev.match == 'termguicolors' then
        -- 'termguicolors' toggled; add or remove border and set 'winblend' for message windows.
        for _, tab in ipairs(api.nvim_list_tabpages()) do
          local win = ext.wins[tab].box
          api.nvim_win_set_config(win, { border = vim.v.option_new and 'none' or 'single' })
          api.nvim_set_option_value('winblend', vim.v.option_new and 30 or 0, { win = win })
        end
      end
      ext.msg.set_pos()
    end,
    desc = 'Manipulate cmdline and message window dimensions after changing option values.',
  })

  api.nvim_create_autocmd('WinEnter', {
    callback = function()
      local win = api.nvim_get_current_win()
      local wins = { ext.wins[ext.tab].cmd, ext.wins[ext.tab].box, ext.wins[ext.tab].more }
      if vim.tbl_contains(wins, win) and api.nvim_win_get_config(win).hide then
        vim.cmd.wincmd('p')
      end
    end,
    desc = 'Make sure hidden extui window is never current.',
  })
end

return M
