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
  ext.tab_check_wins()
  handler(...)
  api.nvim__redraw({
    flush = true,
    cursor = handler == ext.cmd[event] and true or nil,
    win = handler == ext.cmd[event] and ext.wins[ext.tab].cmd or nil,
  })
end
local scheduled_ui_callback = vim.schedule_wrap(ui_callback)

M.enable = function(opts)
  vim.validate('opts', opts, 'table', true)
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

  api.nvim_set_hl(ext.ns, 'Normal', { link = 'MsgArea' })
  api.nvim_set_hl(ext.ns, 'Search', { link = 'MsgArea' })
  api.nvim_set_hl(ext.ns, 'CurSearch', { link = 'MsgArea' })
  api.nvim_set_hl(ext.ns, 'IncSearch', { link = 'MsgArea' })

  -- Enable after startup, so that user option values can be checked.
  api.nvim_create_autocmd('VimEnter', {
    group = ext.augroup,
    callback = function()
      ext.cmdheight = vim.o.cmdheight
      ext.cfg.msg.pos = ext.cmdheight == 0 and 'box' or ext.cfg.msg.pos
      vim.ui_attach(ext.ns, { ext_cmdline = true, ext_messages = true }, function(event, ...)
        if vim.in_fast_event() then
          scheduled_ui_callback(event, ...)
        else
          ui_callback(event, ...)
        end
      end)
      -- ui_attach() sets 'cmdheight' to 0 for BWC, reset it to the user configured value.
      vim.o.cmdheight = ext.cmdheight
    end,
  })

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
        ext.cfg.msg.pos = ext.cmdheight == 0 and 'box' or ext.cfg.msg.pos
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
      if vim.tbl_contains(ext.wins[ext.tab] or {}, win) and api.nvim_win_get_config(win).hide then
        vim.cmd.wincmd('p')
      end
    end,
    desc = 'Make sure hidden extui window is never current.',
  })
end

return M
