--- Multicursor:
--- - Display: kitty cursors if supported (`detect()`), else "highlight" cursors (hl-MCursor).
---   https://github.com/kovidgoyal/kitty/blob/master/docs/multiple-cursors-protocol.rst
--- - Commands: `[count]Q`, `{Visual}Q`, `gQ`, `]C`, `g CTRL-A`.
--- - Script API: `active()`.

local M = {}

--- Extmarks tracking multicursor positions.
local ns = vim.api.nvim_create_namespace('nvim.multicursor')
--- Selection-end cursors, during a Visual selection.
local vcur_ns = vim.api.nvim_create_namespace('nvim.multicursor.cursor')
--- Kitty cursors protocol: host terminal supports the protocol.
local tty_cursors = false
local last_seq = '' ---@type string
local pending = false

--- Gets the operative mcursors namespace, depending on the current state.
--- @param buf integer
local function display_ns(buf)
  if #vim.api.nvim_buf_get_extmarks(buf, vcur_ns, 0, -1, { limit = 1 }) > 0 then
    return vcur_ns
  end
  return ns
end

--- Absolute (screen) coordinates ("2:row:col", 1-indexed) of mcursors in each visible window.
--- Off-screen cursors are omitted.
--- @return string[]
local function coords()
  local r = {} ---@type string[]
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    -- Visible cursors only: constrain to the viewport, for performance.
    local top, bot = vim.fn.line('w0', win) - 1, vim.fn.line('w$', win) - 1
    local marks = vim.api.nvim_buf_get_extmarks(buf, display_ns(buf), { top, 0 }, { bot, -1 }, {})
    local last = vim.api.nvim_buf_line_count(buf)
    for _, m in ipairs(marks) do
      -- Marks can be stale by the time the (scheduled) refresh runs.
      if m[2] < last then
        local pos = vim.fn.screenpos(win, m[2] + 1, m[3] + 1)
        if pos.row > 0 and pos.col > 0 then
          r[#r + 1] = ('2:%d:%d'):format(pos.row, pos.col)
        end
      end
    end
  end
  return r
end

--- Kitty cursors protocol: Sends a term sequence. Empty string ('') means clear.
local function send(seq)
  if seq == last_seq then -- Skip redundant sequences.
    return
  end
  last_seq = seq
  vim.api.nvim_ui_send(seq == '' and '\027[>0;4 q' or seq)
end

--- Kitty cursors protocol: Updates the cursors.
local function refresh()
  local c = coords()
  -- Clear all extra cursors ("no cursor" over the full-screen rectangle), then set shape 29 (mimic
  -- primary) at each position.
  send(#c == 0 and '' or ('\027[>0;4 q\027[>29;%s q'):format(table.concat(c, ';')))
end

--- Displays the mcursors. Invoked per-redraw while cursors exist.
--- - Kitty cursors protocol: deferred to end of redraw cycle (display_end).
--- - Else: highlight cells (the tracking extmarks only carry positions).
---
--- NOTE: The fake Visual selections ("nvim.multicursor.visual") are self-painting extmarks.
--- TODO(justimk): could also do that for "nvim.multicursor" after #41576.
local function display_win(_, _, bufnr, topline, botline)
  if tty_cursors then -- Terminal draws the cursors; emit once per redraw (on_end).
    pending = true
    return
  end
  local marks = vim.api.nvim_buf_get_extmarks(
    bufnr,
    display_ns(bufnr),
    { topline, 0 },
    { botline + 1, 0 },
    {}
  )
  local lastrow = vim.api.nvim_buf_line_count(bufnr)
  for _, m in ipairs(marks) do
    local row, col = m[2], m[3]
    -- Marks may be stale (undo/redo).
    if row < lastrow then
      -- TODO(justinmk): eliminate this text-vs-virtual handling. #41576
      local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1]
      if col >= #line then
        -- Past EOL (e.g. insert-mode "A"): overlay a virtual-space cell. #41576
        vim.api.nvim_buf_set_extmark(bufnr, ns, row, col, {
          ephemeral = true,
          virt_text = { { ' ', 'MCursor' } },
          virt_text_pos = 'overlay',
          priority = 4097, -- Cover the selection highlight.
        })
      else
        vim.api.nvim_buf_set_extmark(bufnr, ns, row, col, {
          ephemeral = true,
          end_col = col + 1,
          hl_group = 'MCursor',
          priority = 4097, -- Cover the selection highlight.
        })
      end
    end
  end
end

--- Render cursors in one "frame" at redraw edge (on_end), when screen positions are final.
local function display_end()
  if pending then
    pending = false
    refresh()
  end
end

--- Enables/disables multicursor display handling.
--- @param enable boolean
function M.enable(enable)
  vim.api.nvim_set_decoration_provider(ns, enable and {
    on_win = display_win,
    on_end = display_end,
  } or {})
  if not enable then
    send('') -- Kitty cursors protocol: clear the UI-side cursors.
  end
end

--- ]C/[C: Jumps to the [count]'th next/previous cursor.
--- @param forward boolean
--- @param count integer?
--- @return boolean moved
function M.jump(forward, count)
  local last = vim.api.nvim_buf_line_count(0)
  local positions = {} ---@type vim.Pos[]
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})) do
    if m[2] < last then
      positions[#positions + 1] = vim.pos(0, m[2], m[3])
    end
  end
  local n = #positions
  if n == 0 then
    return false
  end
  table.sort(positions)
  local curpos = vim.pos.cursor(0)
  local steps = ((count or 1) - 1) % n
  local idx ---@type integer
  if forward then
    local i = 1 -- First cursor after current position. (n+1: none)
    while i <= n and positions[i] <= curpos do
      i = i + 1
    end
    idx = (i - 1 + steps) % n + 1
  else
    local i = n -- Last cursor before current position. (0: none)
    while i >= 1 and not (positions[i] < curpos) do
      i = i - 1
    end
    idx = (i - 1 - steps) % n + 1
  end
  vim.cmd [[normal! m']]
  vim.api.nvim_win_set_cursor(0, positions[idx]:to_cursor())
  return true
end

--- Restores the previous multicursors.
function M.restore()
  local last_ns = vim.api.nvim_create_namespace('nvim.multicursor.last')
  local lastrow = vim.api.nvim_buf_line_count(0)
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, last_ns, 0, -1, {})) do
    if m[2] < lastrow then
      vim.api.nvim_mcursor(0, { m[2] + 1, m[3] })
    end
  end
end

--- Places a cursor on each line of the Visual selection. Enables "follow mode" (q=).
function M.visual()
  local vline = vim.fn.line('v') --[[@as integer]]
  local cline = vim.fn.line('.') --[[@as integer]]
  local first, last = math.min(vline, cline), math.max(vline, cline)
  local vcol = vim.fn.virtcol('.', true)[1] --[[@as integer]]
  vim.cmd.normal({ vim.keycode('<Esc>'), bang = true }) -- End Visual mode.
  --- Screen column (per-line: multibyte chars/tabs shift the byte<->screen mapping), or the
  --- past-EOL insertion point on shorter lines.
  --- @param lnum integer
  local function bytecol(lnum)
    if vim.fn.virtcol({ lnum, '$' }) <= vcol then
      return vim.fn.col({ lnum, '$' }) - 1
    end
    return vim.fn.virtcol2col(0, lnum, vcol) - 1
  end
  vim.api.nvim_win_set_cursor(0, { first, bytecol(first) })
  for lnum = first, last do
    vim.api.nvim_mcursor(0, { lnum, bytecol(lnum) })
  end
  vim.cmd('norm! 1q=') -- "Follow" mode.
end

--- "[count]Q": Places a multicursor at every match of the last search pattern.
function M.matches()
  if vim.fn.getreg('/') == '' then
    require('vim._core.util').echo_err('E35: No previous regular expression')
    return
  end
  local view = vim.fn.winsaveview()
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local pos = vim.fn.searchpos('', 'cW')
  while pos[1] ~= 0 do
    vim.api.nvim_mcursor(0, { pos[1], pos[2] - 1 })
    pos = vim.fn.searchpos('', 'W')
  end
  vim.fn.winrestview(view)
end

--- Inserts an ascending number at each cursor (Emacs F3-counter): 1, 2, 3, ….
--- Numbers ascend in cursor order (top-to-bottom, left-to-right); the primary counts too.
--- @param start? integer First number (default 1)
--- @param step? integer Increment (default 1)
--- @param format? string %d-style format for each number (default "%d")
function M.number(start, step, format)
  start = start or 1
  step = step or 1
  format = format or '%d'
  local pts = { vim.pos.cursor(0) } ---@type vim.Pos[]
  local lastrow = vim.api.nvim_buf_line_count(0)
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})) do
    if m[2] < lastrow then
      pts[#pts + 1] = vim.pos(0, m[2], m[3])
    end
  end
  table.sort(pts)
  -- Coincident cursors (e.g. primary sitting on a cursor) share a number slot.
  vim.list.unique(pts, function(p)
    return ('%d:%d'):format(p.row, p.col)
  end)
  -- Number in position order, but INSERT bottom-up in case of text shifting.
  for i = #pts, 1, -1 do
    local p = pts[i]
    vim.api.nvim_buf_set_text(
      0,
      p.row,
      p.col,
      p.row,
      p.col,
      { format:format(start + (i - 1) * step) }
    )
  end
end

--- Kitty cursors protocol: enables terminal-driven cursor display.
--- @param enable boolean
function M.tty_cursors(enable)
  if tty_cursors == enable then
    return
  end
  tty_cursors = enable
  vim.api.nvim__redraw({ valid = false, flush = false })
  if not enable then
    send('') -- Clear the displayed terminal cursors.
  end
end

--- Kitty cursors protocol: Queries the host terminal for protocol support, and enables it.
--- @param ui table Id of the attached nvim_list_uis() TTY UI.
function M.detect(ui)
  -- Query: "CSI > SP q"
  vim.tty.request('\027[> q', { chan = ui.chan }, function(resp)
    --- Response is a list of cursor shapes, e.g. "CSI > 1;2;3;29;30;40;100;101 SP q".
    local shapes = resp:match('^\027%[>([%d;]*) q$') ---@type string?
    if not shapes then
      return -- Not a reply to our query, keep listening.
    end
    -- Shape 29: cursors follow the primary cursor's shape.
    if vim.list_contains(vim.split(shapes, ';', { plain = true }), '29') then
      M.tty_cursors(true)
    end
    return true
  end)
end

--- True if multicursor is active in the current buffer.
--- @return boolean
function M.active()
  return #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { limit = 1 }) > 0
end

return M
