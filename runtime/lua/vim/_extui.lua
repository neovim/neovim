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
---    ---@type 'cmd'|'msg' Where to place regular messages, either in the
---    ---cmdline or in a separate ephemeral message window.
---    target = 'cmd',
---    timeout = 4000, -- Time a message is visible in the message window.
---  },
---})
---```
---
---There are four separate window types used by this interface:
---- "cmd": The cmdline window; also used for 'showcmd', 'showmode', 'ruler', and
---  messages if 'cmdheight' > 0.
---- "msg": The message window; used for messages when 'cmdheight' == 0.
---- "pager": The pager window; used for |:messages| and certain messages
---   that should be shown in full.
---- "dialog": The dialog window; used for prompt messages that expect user input.
---
---These four windows are assigned the "cmd", "msg", "pager" and "dialog"
---'filetype' respectively. Use a |FileType| autocommand to configure any local
---options for these windows and their respective buffers.
---
---Rather than a |hit-enter-prompt|, messages shown in the cmdline area that do
---not fit are appended with a `[+x]` "spill" indicator, where `x` indicates the
---spilled lines. To see the full message, the |g<| command can be used.

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
    flush = handler ~= ext.cmd.cmdline_hide or nil,
    cursor = handler == ext.cmd[event] and true or nil,
    win = handler == ext.cmd[event] and ext.wins.cmd or nil,
  })
end
local scheduled_ui_callback = vim.schedule_wrap(ui_callback)

---@nodoc
function M.enable(opts)
  vim.validate('opts', opts, 'table', true)
  if opts.msg then
    vim.validate('opts.msg.pos', opts.msg.pos, 'nil', true, 'nil: "pos" moved to opts.target')
    vim.validate('opts.msg.box', opts.msg.box, 'nil', true, 'nil: "timeout" moved to opts.msg')
  end
  ext.cfg = vim.tbl_deep_extend('keep', opts, ext.cfg)

  if ext.cfg.enable == false then
    -- Detach and cleanup windows, buffers and autocommands.
    for _, win in pairs(ext.wins) do
      api.nvim_win_close(win, true)
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
  -- not clear if MsgArea is wanted in the msg, pager and dialog windows.
  api.nvim_set_hl(ext.ns, 'Normal', { link = 'MsgArea' })
  api.nvim_set_hl(ext.ns, 'Search', { link = 'MsgArea' })
  api.nvim_set_hl(ext.ns, 'CurSearch', { link = 'MsgArea' })
  api.nvim_set_hl(ext.ns, 'IncSearch', { link = 'MsgArea' })

  -- The visibility and appearance of the cmdline and message window is
  -- dependent on some option values. Reconfigure windows when option value
  -- has changed and after VimEnter when the user configured value is known.
  -- TODO: Reconsider what is needed when this module is enabled by default early in startup.
  local function check_opt(name, value)
    if name == 'cmdheight' then
      -- 'cmdheight' set; (un)hide cmdline window and set its height.
      local cfg = { height = math.max(value, 1), hide = value == 0 }
      api.nvim_win_set_config(ext.wins.cmd, cfg)
      -- Change message position when 'cmdheight' was or becomes 0.
      if value == 0 or ext.cmdheight == 0 then
        ext.cfg.msg.target = value == 0 and 'msg' or 'cmd'
        ext.msg.prev_msg = ''
      end
      ext.cmdheight = value
    end
  end

  ext.tab_check_wins()
  check_opt('cmdheight', vim.o.cmdheight)

  api.nvim_create_autocmd('OptionSet', {
    group = ext.augroup,
    pattern = { 'cmdheight' },
    callback = function(ev)
      ext.tab_check_wins()
      check_opt(ev.match, vim.v.option_new)
      ext.msg.set_pos()
    end,
    desc = 'Set cmdline and message window dimensions for changed option values.',
  })

  api.nvim_create_autocmd({ 'VimEnter', 'VimResized', 'TabEnter' }, {
    group = ext.augroup,
    callback = function(ev)
      ext.tab_check_wins()
      if ev.event == 'VimEnter' then
        check_opt('cmdheight', vim.o.cmdheight)
      end
      ext.msg.set_pos()
    end,
    desc = 'Set extui window dimensions after startup, shell resize or tabpage change.',
  })

  api.nvim_create_autocmd('WinEnter', {
    callback = function()
      local win = api.nvim_get_current_win()
      if vim.tbl_contains(ext.wins, win) and api.nvim_win_get_config(win).hide then
        vim.cmd.wincmd('p')
      end
    end,
    desc = 'Make sure hidden extui window is never current.',
  })
end

return M
