--- @brief
---
---WARNING: This is an experimental interface intended to replace the message
---grid in the TUI.
---
---To enable the experimental UI (default opts shown):
---```lua
---require('vim._extui').enable({
---  enable = true, -- Whether to enable or disable the UI.
---  msg = { -- Options related to the message module.
---    ---@type 'box'|'cmd' Type of window used to place messages, either in the
---    ---cmdline or in a separate message box window with ephemeral messages.
---    pos = 'cmd',
---    box = { -- Options related to the message box window.
---      timeout = 4000, -- Time a message is visible.
---    },
---  },
---})
---```

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

---@nodoc
function M.enable(opts)
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

  vim.ui_attach(ext.ns, { ext_messages = true, set_cmdheight = false }, function(event, ...)
    if vim.in_fast_event() then
      scheduled_ui_callback(event, ...)
    else
      ui_callback(event, ...)
    end
  end)

  -- Use MsgArea and hide search highlighting in the cmdline window.
  -- TODO: Add new highlight group/namespaces for other windows? It is
  -- not clear if MsgArea is wanted in the box, more and prompt windows.
  api.nvim_set_hl(ext.ns, 'Normal', { link = 'MsgArea' })
  api.nvim_set_hl(ext.ns, 'Search', { link = 'MsgArea' })
  api.nvim_set_hl(ext.ns, 'CurSearch', { link = 'MsgArea' })
  api.nvim_set_hl(ext.ns, 'IncSearch', { link = 'MsgArea' })

  -- The visibility and appearance of the cmdline and message box window is
  -- dependent on some option values. Reconfigure windows when option value
  -- has changed and after VimEnter when the user configured value is known.
  -- TODO: Reconsider what is needed when this module is enabled by default early in startup.
  local function check_opt(name, value)
    if name == 'cmdheight' then
      -- 'cmdheight' set; (un)hide cmdline window and set its height.
      ext.cmdheight = value
      ext.cfg.msg.pos = ext.cmdheight == 0 and 'box' or ext.cfg.msg.pos
      local cfg = { height = math.max(ext.cmdheight, 1), hide = ext.cmdheight == 0 }
      api.nvim_win_set_config(ext.wins[ext.tab].cmd, cfg)
    elseif name == 'termguicolors' then
      -- 'termguicolors' toggled; add or remove border and set 'winblend' for box windows.
      for _, tab in ipairs(api.nvim_list_tabpages()) do
        api.nvim_win_set_config(ext.wins[tab].box, { border = value and 'none' or 'single' })
        vim.wo[ext.wins[tab].box].winblend = value and 30 or 0
      end
    end
  end

  if vim.v.vim_did_enter == 1 then
    ext.tab_check_wins()
    check_opt('cmdheight', vim.o.cmdheight)
    check_opt('termguicolors', vim.o.termguicolors)
  end

  api.nvim_create_autocmd('OptionSet', {
    group = ext.augroup,
    pattern = { 'cmdheight', 'termguicolors' },
    callback = function(ev)
      ext.tab_check_wins()
      check_opt(ev.match, vim.v.option_new)
      ext.msg.set_pos()
    end,
    desc = 'Set cmdline and message window dimensions for changed option values.',
  })

  api.nvim_create_autocmd({ 'VimEnter', 'VimResized' }, {
    group = ext.augroup,
    callback = function(ev)
      ext.tab_check_wins()
      if ev.event == 'VimEnter' then
        check_opt('cmdheight', vim.o.cmdheight)
        check_opt('termguicolors', vim.o.termguicolors)
      end
      ext.msg.set_pos()
    end,
    desc = 'Set cmdline and message window dimensions after startup and shell resize.',
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
