--- @brief Command-line window (q:, q/, q?, c_CTRL-F).
---
--- Implements cmdwin as a normal window+buffer, instead of the legacy nested `state_enter` loop.
--- - On confirm, curline is fed back through the cmdline via |nvim_feedkeys()|.
--- - On cancel, curline is pre-filled in the ":" cmdline.

local M = {}

--- @class vim._core.cmdwin.State
--- @field type string   ':', '/', '?'
--- @field win integer   cmdwin window id
--- @field buf integer   cmdwin buffer id
--- @field caller_win integer  Window to return-to on close

--- @type vim._core.cmdwin.State?
local state = nil

local cmdwin_types = { [':'] = true, ['/'] = true, ['?'] = true }

--- Fills the cmdwin buffer with the cmdline history.
--- @return boolean filled  Whether any lines were written.
local function fill_history(buf, type)
  local histname = type == ':' and 'cmd' or (type == '/' or type == '?') and 'search' or nil
  assert(histname, 'cmdwin: unknown type: ' .. tostring(type))
  local n = vim.fn.histnr(histname)
  if n <= 0 then -- May be -1 if history is empty.
    return false
  end
  local lines = {} --- @type string[]
  for i = 1, n do
    local h = vim.fn.histget(histname, i)
    if h ~= '' then
      -- One cmdwin line = one cmdline. Entry may have embedded newlines (e.g. via feedkeys or :execute).
      lines[#lines + 1] = (h:gsub('\n', '\0'))
    end
  end
  if #lines == 0 then
    return false
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return true
end

--- Open the command-line window.
---
--- @param type? string  ':', '/', '?'. Default ':'.
--- @param init_line? string  Pre-fill the last line (the "live" cmdline).
--- @param init_col? integer  1-based cursor column in the last line.
function M.open(type, init_line, init_col)
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

  local filled = fill_history(buf, type)
  init_line = init_line and init_line:gsub('\n', '\0') or ''

  -- Append the in-flight cmdline as the last line (or only line if history is empty).
  vim.api.nvim_buf_set_lines(buf, filled and -1 or 0, -1, false, { init_line })
  local last = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_win_set_cursor(win, { last, math.max(0, (init_col or 1) - 1) })

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

--- Confirm and execute the current line as a cmdline.
function M.confirm()
  if state == nil then -- Not in cmdwin (closed already?).
    return
  end
  local line, type = _close()
  line = line:gsub('%z', '\n'):gsub('(%c)', '\022%1') -- Escape control characters.
  vim.api.nvim_feedkeys(type .. line .. vim.keycode('<CR>'), 'nt', false)
end

--- Cancel: close the cmdwin and re-enter cmdline mode with the line pre-filled (no execute).
function M.cancel()
  if state == nil then -- Not in cmdwin (closed already?).
    return
  end
  local line, type = _close()
  line = line:gsub('%z', '\n'):gsub('(%c)', '\022%1') -- Escape control characters.
  vim.api.nvim_feedkeys(type .. line, 'nt', false)
end

return M
