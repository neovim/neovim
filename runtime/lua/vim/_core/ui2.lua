--- @brief
---
---WARNING: This is an experimental interface intended to replace the message
---grid in the TUI.
---
---To enable the experimental UI (default opts shown):
---```lua
---require('vim._core.ui2').enable({
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
local M = {
  ns = api.nvim_create_namespace('nvim.ui2'),
  augroup = api.nvim_create_augroup('nvim.ui2', {}),
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

local function ui_callback(redraw_msg, event, ...)
  local handler = M.msg[event] or M.cmd[event] --[[@as function]]
  M.check_targets()
  handler(...)
  -- Cmdline mode, non-fast message and non-empty showcmd require an immediate redraw.
  if M.cmd[event] or redraw_msg or (event == 'msg_showcmd' and select(1, ...)[1]) then
    M.redrawing = true
    api.nvim__redraw({
      flush = handler ~= M.cmd.cmdline_hide or nil,
      cursor = handler == M.cmd[event] and true or nil,
      win = handler == M.cmd[event] and M.wins.cmd or nil,
    })
    M.redrawing = false
  end
end
local scheduled_ui_callback = vim.schedule_wrap(ui_callback)

---@nodoc
function M.enable(opts)
  vim.validate('opts', opts, 'table', true)
  M.cfg = vim.tbl_deep_extend('keep', opts, M.cfg)
  M.cmd = require('vim._core.ui2.cmdline')
  M.msg = require('vim._core.ui2.messages')

  if M.cfg.enable == false then
    -- Detach and cleanup windows, buffers and autocommands.
    for _, win in pairs(M.wins) do
      if api.nvim_win_is_valid(win) then
        api.nvim_win_close(win, true)
      end
    end
    for _, buf in pairs(M.bufs) do
      if api.nvim_buf_is_valid(buf) then
        api.nvim_buf_delete(buf, {})
      end
    end
    api.nvim_clear_autocmds({ group = M.augroup })
    vim.ui_detach(M.ns)
    return
  end

  vim.ui_attach(M.ns, { ext_messages = true, set_cmdheight = false }, function(event, ...)
    if not (M.msg[event] or M.cmd[event]) then
      return
    end
    -- Ensure cmdline is placed after a scheduled message in block mode.
    if vim.in_fast_event() or (event == 'cmdline_show' and M.cmd.srow > 0) then
      scheduled_ui_callback(false, event, ...)
    else
      ui_callback(event == 'msg_show', event, ...)
    end
    return true
  end)

  -- The visibility and appearance of the cmdline and message window is
  -- dependent on some option values. Reconfigure windows when option value
  -- has changed and after VimEnter when the user configured value is known.
  -- TODO: Reconsider what is needed when this module is enabled by default early in startup.
  local function check_cmdheight(value)
    M.check_targets()
    -- 'cmdheight' set; (un)hide cmdline window and set its height.
    local cfg = { height = math.max(value, 1), hide = value == 0 }
    api.nvim_win_set_config(M.wins.cmd, cfg)
    M.cmdheight = value
  end

  if vim.v.vim_did_enter == 0 then
    vim.schedule(function()
      check_cmdheight(vim.o.cmdheight)
    end)
  end

  api.nvim_create_autocmd('OptionSet', {
    group = M.augroup,
    pattern = { 'cmdheight', 'laststatus' },
    callback = function(ev)
      if ev.match == 'cmdheight' then
        check_cmdheight(vim.v.option_new)
      end
      M.msg.set_pos()
    end,
    desc = 'Set cmdline and message window dimensions for changed option values.',
  })

  api.nvim_create_autocmd({ 'VimResized', 'TabEnter' }, {
    group = M.augroup,
    callback = function()
      M.msg.set_pos()
    end,
    desc = 'Set cmdline and message window dimensions after shell resize or tabpage change.',
  })

  api.nvim_create_autocmd('WinEnter', {
    callback = function()
      local win = api.nvim_get_current_win()
      if vim.tbl_contains(M.wins, win) and api.nvim_win_get_config(win).hide then
        vim.cmd.wincmd('p')
      end
    end,
    desc = 'Make sure hidden UI window is never current.',
  })
end

return M
