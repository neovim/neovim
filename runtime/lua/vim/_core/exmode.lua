--- Ex mode.
--- - `run()`: non-interactive (`nvim -es`): executes stdin as Ex commands.
--- - `open()`: interactive (`[count]q:`, `nvim -e`), a keep-open "cmdwin" REPL.

local api = vim.api
local N_ = vim.fn.gettext
local util = require('vim._core.util')

local M = {}

--- Commands that end Ex mode before executing (in the caller window).
local exit_cmds = {
  cquit = true,
  exit = true,
  quit = true,
  quitall = true,
  restart = true,
  view = true,
  visual = true,
  wq = true,
  wqall = true,
  xall = true,
  xit = true,
}

--- Continuation lines (of a multiline cmd), for the statuscolumn.
--- @type table<integer, true>
local cont_lines = {}

--- Non-interactive "script mode" ("nvim -es", fka "Ex-mode", but POSIX behavior was dropped):
--- Executes stdin as Ex commands, until EOF.
---
--- Stdin is not consumed as typeahead: fd 0 is read directly (`io.lines()`), so `:lua` script lines
--- can also read stdin as data via `io.read()`.
function M.run()
  local lines = io.lines()
  local getline = function()
    local line = lines()
    -- Strip trailing CR so CRLF input (e.g. Windows pipes) works like LF.
    return line and (line:gsub('\r$', '')) or nil
  end
  -- Instead of per-line `nvim_exec2`, this runs one `do_cmdline` per logical command with
  -- `getline` as the line-getter, in order to preserve these behaviors:
  -- - :append/:function/:if/heredocs pull continuation lines from stdin. #7679
  -- - Errors are emitted, not thrown (nvim_exec2 turns the first error into an exception):
  --   execution continues with the next command, `ex_exitval` still sets the exit code, and
  --   "-V1" shows errors on stderr.
  -- - Output (:print, :set, …) to stdout as each command executes.
  --
  -- TODO: could enhance nvim_exec2 instead?
  while vim._core.ex_docmd(getline) do
    vim.wait(0) -- Run pending events (vim.schedule() callbacks, RPC).
  end
end

--- Whether `lines` form a complete command block: no `:append` text, `:function` body, heredoc, or
--- :if/:while/:for/:try block is awaiting continuation lines. Feeds the lines to do_cmdline(),
--- which groups multiline constructs even when skipping (false `:if`), without executing anything.
--- If the construct is still open it consumes the sentinel "endif" and asks the getter for more.
--- @param lines string[]
--- @return boolean
local function block_complete(lines)
  -- :append/etc. not grouped by the skipped-:if below: collect until the "." terminator.
  local ok, p = pcall(api.nvim_parse_cmd, lines[1], {})
  if ok and (p.cmd == 'append' or p.cmd == 'insert' or p.cmd == 'change') then
    return vim.list_contains({ unpack(lines, 2) }, '.')
  end

  local feed = { 'if v:false' }
  vim.list_extend(feed, lines)
  feed[#feed + 1] = 'endif'
  local i = 0
  local complete = true
  -- Silenced: probing an incomplete block emits e.g. E126/E990 when the reader hits EOF.
  vim._with({ silent = true, emsg_silent = true }, function()
    vim._core.ex_docmd(function()
      i = i + 1
      if i > #feed then
        complete = false
        return nil
      end
      return feed[i]
    end)
  end)
  return complete
end

--- Ex-mode 'statuscolumn': ":", or blank for continuation lines (`:func` body, `:append` text, …).
function M._statuscolumn()
  return cont_lines[vim.v.lnum] and ' ' or ':'
end

--- Interactive Ex-mode: keep-open cmdwin REPL. `<CR>` executes the current line against the caller
--- window and keeps the cmdwin open; command output is presented as comment ('"') lines. Multiline
--- commands (`:append`, etc.) are collected until the block is complete.
function M.open()
  local cmdwin = require('vim._core.cmdwin')
  local caller = api.nvim_get_current_win()
  cmdwin.open(':')
  if api.nvim_get_current_win() == caller then
    return -- cmdwin failed to open (E1292 already echoed).
  end
  local buf = api.nvim_get_current_buf()
  api.nvim_buf_set_name(buf, N_('[Ex mode]'))
  local block_start = api.nvim_buf_line_count(buf)
  cont_lines = {}
  vim.wo[0][0].statuscolumn = '%#NonText#%{v:lua.require("vim._core.exmode")._statuscolumn()}'

  --- Formats `text` (possibly multiline) as transcript comment lines.
  --- @param out string[]
  --- @param text string
  local function put(out, text)
    for _, l in ipairs(vim.split(text, '\n', { trimempty = true })) do
      out[#out + 1] = '" ' .. l
    end
  end

  api.nvim_echo({ { N_('Entering Ex mode.  Type "visual" to go to Normal mode.') } }, true, {})

  local function run()
    if not api.nvim_win_is_valid(caller) then
      cmdwin._cleanup() -- Caller window is gone: end Ex mode.
      return
    end
    local line = api.nvim_get_current_line()
    local lnum = api.nvim_win_get_cursor(0)[1]
    if lnum >= block_start then
      -- Multiline commands: collect continuation lines until the block is complete.
      local block = api.nvim_buf_get_lines(buf, block_start - 1, lnum, false)
      if not block_complete(block) then
        cont_lines[lnum + 1] = true -- Mark the continuation line.
        api.nvim_buf_set_lines(buf, lnum, lnum, false, { '' })
        api.nvim_win_set_cursor(0, { lnum + 1, 0 })
        return
      end
      line = table.concat(block, '\n')
    end
    local parse_ok, parsed = pcall(api.nvim_parse_cmd, line:match('^[^\n]*'), {})
    if parse_ok and not line:find('\n') and exit_cmds[parsed.cmd] then
      vim.fn.histadd('cmd', line)
      cmdwin._cleanup() -- Focuses the caller window.
      vim.cmd.stopinsert()
      if parsed.cmd ~= 'visual' and parsed.cmd ~= 'view' or #parsed.args > 0 then
        --- @type boolean, string?
        local ok, err = pcall(vim.cmd --[[@as function]], line) -- May exit Nvim.
        if not ok then
          util.echo_err(util.cmd_errmsg(tostring(err)))
        end
      end
      return
    end

    local out = {} --- @type string[]
    local prev_lnum = api.nvim_win_get_cursor(caller)[1]
    local prev_tick = vim.b[api.nvim_win_get_buf(caller)].changedtick
    if line == '' then
      -- Empty line: advance one line (POSIX ex "+"); auto-print below shows it.
      if prev_lnum >= api.nvim_buf_line_count(api.nvim_win_get_buf(caller)) then
        put(out, N_('E501: At end-of-file'))
      else
        api.nvim_win_set_cursor(caller, { prev_lnum + 1, 0 })
      end
    else
      local ok, res = pcall(api.nvim_win_call, caller, function()
        return api.nvim_exec2(line, { output = true })
      end)
      if ok then
        put(out, res.output)
      else
        put(out, util.cmd_errmsg(tostring(res)))
      end
      vim.fn.histadd('cmd', line)
    end

    if not api.nvim_win_is_valid(caller) then
      -- The command closed the caller window (e.g. ":close"): continue Ex mode against a
      -- remaining window, or end it.
      local wins = vim.tbl_filter(
        --- @param w integer
        function(w)
          return api.nvim_win_get_buf(w) ~= buf
        end,
        api.nvim_list_wins()
      )
      if #wins == 0 then
        vim.cmd.quit() -- Only the cmdwin is left: exit.
        return
      end
      caller = wins[1]
    end

    -- Ex-mode feature: auto-print the current line after a cursor move or buffer change, unless the
    -- cmd already printed something (e.g. ":5,6print" should not redundantly auto-print).
    local typed_text = parse_ok
      and (parsed.cmd == 'append' or parsed.cmd == 'insert' or parsed.cmd == 'change')
    local cbuf = api.nvim_win_get_buf(caller)
    local cur = api.nvim_win_get_cursor(caller)[1]
    if
      #out == 0
      and not typed_text
      -- Bare range (":1") prints even when the cursor is already on line 1.
      and (
        (parse_ok and parsed.cmd == '')
        or cur ~= prev_lnum
        or vim.b[cbuf].changedtick ~= prev_tick
      )
    then
      put(out, api.nvim_buf_get_lines(cbuf, cur - 1, cur, false)[1] or '')
    end

    -- Keep-open: record the transcript and park the cursor on a fresh last line.
    out[#out + 1] = ''
    api.nvim_buf_set_lines(buf, -1, -1, false, out)
    block_start = api.nvim_buf_line_count(buf)
    api.nvim_win_set_cursor(0, { block_start, 0 })
  end

  vim.keymap.set({ 'n', 'i' }, '<CR>', run, { buffer = buf })
  vim.keymap.set({ 'n', 'i' }, '<NL>', run, { buffer = buf })
  -- Enter Insert mode before any already-typed keys, so `1q:cmd<CR>` types "cmd" into the REPL.
  api.nvim_feedkeys('i', 'ni', false)
end

return M
