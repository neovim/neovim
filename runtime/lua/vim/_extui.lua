local api = vim.api
local ext = require('vim._extui.shared')
ext.msg = require('vim._extui.messages')
ext.cmd = require('vim._extui.cmdline')
local M = {}
local lsauid = -1 -- Autocommand id for 'laststatus' WinOpen/Closed handler.

local function ui_callback(event, ...)
  local handler = event:find('msg_') and assert(ext.msg[event]) or assert(ext.cmd[event])
  ext.tab_check_wins()
  handler(...)
  vim.api.nvim__redraw({
    flush = true,
    cursor = handler == ext.cmd[event] and true or nil,
    win = handler == ext.cmd[event] and ext.wins[ext.tab].cmd or nil,
  })
end
local scheduled_ui_callback = vim.schedule_wrap(ui_callback)

M.enable = function(enable)
  if not enable then
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

  api.nvim_create_autocmd('UIEnter', {
    group = ext.augroup,
    callback = function()
      for _, ui in ipairs(api.nvim_list_uis()) do
        if ui.ext_messages then
          vim.ui_detach(ext.ns)
        end
      end
    end,
    desc = 'Detach when another ext_messages UI attaches.',
  })

  api.nvim_create_autocmd('VimResized', {
    group = ext.augroup,
    callback = function()
      ext.msg.set_pos(ext.cmdheight, 0)
    end,
    desc = 'Manipulate cmdline and message window dimensions after shell resize.',
  })

  api.nvim_create_autocmd('OptionSet', {
    group = ext.augroup,
    pattern = { 'cmdheight', 'laststatus', 'termguicolors' },
    callback = function(ev)
      if ev.match == 'cmdheight' then
        ext.cmdheight = vim.v.option_new
        local cfg = { height = math.max(ext.cmdheight, 1), hide = ext.cmdheight == 0 }
        pcall(api.nvim_win_set_config, ext.wins[ext.tab].cmd, cfg)
      elseif ev.match == 'termguicolors' then
        for _, tab in ipairs(api.nvim_list_tabpages()) do
          local win = ext.wins[tab].msg
          api.nvim_win_set_config(win, { border = vim.v.option_new == 0 and 'single' or 'none' })
          vim.wo[win].winbl = vim.v.option_new and 30 or 0
        end
      elseif vim.v.option_new == 1 and lsauid == -1 then -- 'laststatus' == 1
        lsauid = api.nvim_create_autocmd({ 'WinNew', 'WinClosed' }, {
          group = ext.augroup,
          callback = function(evt)
            ext.msg.set_pos(ext.cmdheight, assert(tonumber(evt.match)))
          end,
          desc = 'Manipulate message window dimensions after number of windows changes.',
        })
      elseif lsauid > 0 then -- 'laststatus' ~= 1
        api.nvim_del_autocmd(lsauid)
        ext.lsauid = -1
      end
      ext.msg.set_pos(ext.cmdheight, 0)
    end,
    desc = 'Manipulate cmdline and message window dimensions after changing option values.',
  })
end

return M
