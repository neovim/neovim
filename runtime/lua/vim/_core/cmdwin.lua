--- @brief Command-line window (q:, q/, q?, c_CTRL-F).
---
--- Implements cmdwin as a normal window+buffer, instead of the legacy nested `state_enter` loop.
--- - On confirm, curline is fed back through the cmdline via |nvim_feedkeys()|.
--- - On cancel, curline is pre-filled in the ":" cmdline.
---
--- `M.host()` is a variant that runs as the *entire* UI of a child Nvim (see `run_in_terminal`), used
--- to host a cmdwin for blocking prompts like |input()|; there confirm returns the line to the parent
--- over RPC instead of acting on a host window.

local M = {}

--- @class vim._core.cmdwin.State
--- @field type string   ':', '/', '?', '='
--- @field win integer   cmdwin window id
--- @field buf integer   cmdwin buffer id
--- @field caller_win integer  Window to return-to on close
--- @field caller_cursor integer[]  (1,0)-cursor of caller_win (for '=': where to insert the result)

--- @type vim._core.cmdwin.State?
local state = nil

-- '=' is the expr register (i_CTRL-R =); on confirm its line is evaluated and inserted. #40407
local cmdwin_types = { [':'] = true, ['/'] = true, ['?'] = true, ['='] = true }

--- Maps a cmdwin type char to its history name.
local function type_histname(type)
  return type == ':' and 'cmd'
    or (type == '/' or type == '?') and 'search'
    or type == '=' and 'expr'
    or nil
end

--- Prepends cmdline history (one entry per line) above the buffer's existing (editable) content,
--- then puts the cursor on the last line. The caller seeds the editable line(s) first.
--- @param buf integer
--- @param win integer
--- @param histname string?  'cmd'/'search'/'expr'/'input'; nil/empty for none.
--- @param col? integer  1-based cursor column in the last line.
local function fill_history(buf, win, histname, col)
  if histname and histname ~= '' then
    local lines = {} --- @type string[]
    for i = 1, vim.fn.histnr(histname) do
      local h = vim.fn.histget(histname, i)
      if h ~= '' then
        -- One cmdwin line = one entry. Entry may have embedded newlines (feedkeys or :execute).
        lines[#lines + 1] = (h:gsub('\n', '\0'))
      end
    end
    if #lines > 0 then
      vim.api.nvim_buf_set_lines(buf, 0, 0, false, lines) -- prepend above the editable line(s)
    end
  end
  local last = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_win_set_cursor(win, { last, math.max(0, (col or 1) - 1) })
end

--- Open the command-line window.
---
--- @param type? string  ':', '/', '?', '='. Default ':'.
--- @param init_line? string  Pre-fill the last line (the "live" cmdline).
--- @param init_col? integer  1-based cursor column in the last line.
--- @param host_lnum? integer  For '=': caller cursor line where the result is inserted on confirm.
--- @param host_col? integer  For '=': caller cursor column (0-based byte).
function M.open(type, init_line, init_col, host_lnum, host_col)
  type = type or ':'
  assert(cmdwin_types[type], 'cmdwin: unknown type: ' .. tostring(type))
  if state ~= nil then
    vim.api.nvim_echo(
      { { 'E1292: Command-line window is already open', 'ErrorMsg' } },
      true,
      { err = true }
    )
    return
  end

  local caller = vim.api.nvim_get_current_win()

  -- Split a horizontal window at the bottom, sized by 'cmdwinheight'.
  local ok, err = pcall(function()
    vim.cmd(('botright %dnew'):format(vim.o.cmdwinheight))
  end)
  if not ok then
    vim.api.nvim_echo({ { tostring(err), 'ErrorMsg' } }, true, { err = true })
    return
  end
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()

  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = true -- #40431
  vim.wo[win][0].winfixbuf = true
  vim.wo[win][0].foldenable = false
  vim.wo[win][0].scrollbind = false
  -- Show cmdwin-char via 'statuscolumn'.
  vim.wo[win][0].statuscolumn = '%#NonText#' .. type

  init_line = init_line and init_line:gsub('\n', '\0') or ''

  -- Seed the in-flight cmdline as the editable line, then prepend history above it.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { init_line or '' })
  fill_history(buf, win, type_histname(type), init_col)

  pcall(vim.api.nvim_buf_set_name, buf, '[Command Line]')
  if type == ':' then
    vim.bo[buf].filetype = 'vim'
  end

  if vim.o.wildchar == ('\t'):byte() then
    vim.keymap.set('i', '<Tab>', '<C-X><C-V>', { buf = buf })
    vim.keymap.set('n', '<Tab>', 'a<C-X><C-V>', { buf = buf })
  end

  vim.api.nvim__cmdwin_set(type, buf) -- Update the C-side globals.

  state = {
    type = type,
    win = win,
    buf = buf,
    caller_win = caller,
    -- For '=', use the exact Insert-mode cursor (host_lnum/col); the post-<C-\><C-N> Normal-mode
    -- cursor would be off by one at end-of-line. 1-based row, 0-based col.
    caller_cursor = (type == '=' and host_lnum and host_lnum > 0) and { host_lnum, host_col }
      or vim.api.nvim_win_get_cursor(caller),
  }

  -- Clean up when the (last-visible) cmdwin is closed by other means (`:q`, `:close`, etc.).
  vim.api.nvim_create_autocmd({ 'WinClosed' }, {
    buffer = buf,
    nested = true,
    callback = function(ev)
      if state == nil then
        return
      end
      local closing = tonumber(ev.match)
      for _, w in ipairs(vim.fn.win_findbuf(buf)) do
        if w ~= closing then
          return -- Still visible elsewhere; keep cmdwin (and this autocmd) active.
        end
      end
      M._cleanup()
      return true -- Last cmdwin window gone; delete this autocmd.
    end,
  })

  vim.api.nvim_exec_autocmds('CmdwinEnter', { pattern = type, modeline = false })
end

--- @private
function M._cleanup()
  if state == nil then
    return
  end
  local s = state
  state = nil
  pcall(vim.api.nvim__cmdwin_set, '', 0) -- Clear the C-side globals.
  pcall(vim.api.nvim_exec_autocmds, 'CmdwinLeave', { pattern = s.type, modeline = false })
  if vim.api.nvim_buf_is_valid(s.buf) then
    pcall(vim.api.nvim_buf_delete, s.buf, { force = true })
  end
  if vim.api.nvim_win_is_valid(s.caller_win) then
    pcall(vim.api.nvim_set_current_win, s.caller_win)
  end
end

--- Closes the cmdwin and returns its current line and type.
--- @return string line, string type
local function _close()
  local line = vim.api.nvim_get_current_line()
  local type = assert(state).type
  M._cleanup()
  return line, type
end

--- Confirm: execute the current line (':' / '/' / '?') or, for the expr register ('='), evaluate
--- it and insert the result at the caller's cursor (like i_CTRL-R =). #40407
function M.confirm()
  if state == nil then -- Not in cmdwin (closed already?).
    return
  end
  local caller_win = state.caller_win
  local caller_cursor = state.caller_cursor
  local line, type = _close() -- Closes the cmdwin; switches back to caller_win.
  line = line:gsub('%z', '\n'):gsub('(%c)', '\022%1') -- Escape control characters.
  if type == '=' then
    local ok, result = pcall(vim.fn.eval, line == '' and '@=' or line)
    if not ok then
      vim.api.nvim_echo({ { tostring(result), 'ErrorMsg' } }, true, { err = true })
      return
    end
    if vim.api.nvim_win_is_valid(caller_win) then
      vim.api.nvim_set_current_win(caller_win)
      -- Insert the result at the host cursor (like i_CTRL-R =), then resume Insert mode after it.
      local buf = vim.api.nvim_win_get_buf(caller_win)
      local row, col = caller_cursor[1] - 1, caller_cursor[2]
      local lines = vim.split(tostring(result), '\n', { plain = true })
      vim.api.nvim_buf_set_text(buf, row, col, row, col, lines)
      -- Resume Insert mode just after the inserted text.
      local end_row = row + #lines - 1
      local end_col = (#lines == 1 and col or 0) + #lines[#lines]
      local linelen = #vim.api.nvim_buf_get_lines(buf, end_row, end_row + 1, false)[1]
      if end_col >= linelen then
        pcall(vim.api.nvim_win_set_cursor, caller_win, { end_row + 1, math.max(0, linelen - 1) })
        vim.cmd('startinsert!')
      else
        pcall(vim.api.nvim_win_set_cursor, caller_win, { end_row + 1, end_col })
        vim.cmd('startinsert')
      end
    end
    return
  end
  vim.api.nvim_feedkeys(type .. line .. vim.keycode('<CR>'), 'nt', false)
end

--- Cancel: close the cmdwin and re-enter cmdline mode with the line pre-filled (no execute).
function M.cancel()
  if state == nil then -- Not in cmdwin (closed already?).
    return
  end
  local caller_win = state.caller_win
  local line, type = _close()
  line = line:gsub('%z', '\n'):gsub('(%c)', '\022%1') -- Escape control characters.

  if type == '=' then
    -- Expr register: nothing to execute. Resume Insert mode in the caller (the '=' was aborted).
    if vim.api.nvim_win_is_valid(caller_win) then
      vim.api.nvim_set_current_win(caller_win)
      vim.api.nvim_feedkeys('a', 'n', false)
    end
    return
  end
  vim.api.nvim_feedkeys(type .. line, 'nt', false)
end

--- cmdwin host: runs as the entire UI of a child Nvim spawned by `run_in_terminal.run_nvim()` to host
--- a cmdwin for a blocking prompt (e.g. |input()|). Lays out history (from the ShaDa shared via `-i`)
--- like `M.open`, with the seeded file as the editable last line; on confirm hands the *current* line
--- back to the parent over its |$NVIM| RPC channel (instead of acting on a host window). #40407
--- @param histname? string  History to show ('input'/'cmd'/'search'/'expr'); empty/nil for none.
function M.host(histname)
  vim.o.laststatus = 0
  vim.o.ruler = false
  vim.o.showmode = false
  vim.bo.bufhidden = 'wipe'

  fill_history(0, 0, histname) -- the seed (file contents) is already the buffer; prepend history above

  local opts = { buffer = true, silent = true }
  -- Confirm on <CR>/<NL> (the command-line submits on both; a pty may deliver Enter as <NL>): hand
  -- the *current* line (the user may have moved onto a history entry) back to the parent over its
  -- $NVIM RPC channel, flush history to the shared ShaDa, then exit.
  local function confirm()
    local line = vim.api.nvim_get_current_line()
    if vim.env.NVIM then -- parent's RPC address (set by |terminal|/|jobstart()|)
      local chan = vim.fn.sockconnect('pipe', vim.env.NVIM, { rpc = true })
      vim.rpcrequest(chan, 'nvim_exec_lua', "require('vim._core.run_in_terminal')._confirm(...)", {
        line,
      })
    end
    vim.cmd('silent rshada') -- `silent` so messages don't trip the |more-prompt| in this tiny UI
    vim.cmd('silent wshada')
    vim.cmd('qall!')
  end
  for _, k in ipairs({ '<CR>', '<NL>' }) do
    vim.keymap.set({ 'n', 'i' }, k, confirm, opts)
  end
  vim.keymap.set({ 'n', 'i' }, '<C-c>', '<Cmd>cquit<CR>', opts)

  vim.cmd('startinsert!') -- append at end of the line, like a cmdline
end

return M
