--- @brief Run a process in a `:terminal` buffer, blocking (interactively, UI live) until it exits.
---
--- Single-threaded: the parent stays suspended in `nvim__terminal_enter()` (a nested event-loop
--- pump) which renders the terminal and forwards input to the child. A buffer-local |TermClose|
--- closes the buffer on exit, which ends the modal loop without a keypress. The reusable primitive
--- behind cmdwin-in-a-terminal and (future) interactive `:!`. #40407

local M = {}

--- Runs `argv` in a terminal buffer, blocking (interactively) until the process exits.
--- @param argv string[]  Command and arguments.
--- @param opts? table  Extra |jobstart()| options (cwd, env, ...). `term` is forced on. The extra
---                     key `feed` (string) is written to the child's stdin via a separate pipe
---                     (`stdin='fd'`), so the child reads it on fd 0 while the terminal stays the
---                     tty — no tempfile. #40407
--- @return integer? code  Process exit status, or nil if the job failed to start.
function M.run(argv, opts)
  local jobopts = vim.tbl_extend('force', opts or {}, { term = true }) --[[@as table<string, any>]]
  local feed = jobopts.feed --[[@as string?]]
  jobopts.feed = nil
  if feed ~= nil then
    jobopts.stdin = 'fd' -- child stdin is a pipe (the fed data), not the tty
  end

  local caller_win = vim.api.nvim_get_current_win()
  vim.cmd('botright new') -- empty host buffer for the terminal
  local buf = vim.api.nvim_get_current_buf()

  local code --- @type integer?
  vim.api.nvim_create_autocmd('TermClose', {
    buffer = buf,
    once = true,
    callback = function(ev)
      code = vim.v.event.status --[[@as integer]]
      -- Wiping the buffer ends nvim__terminal_enter() without a keypress.
      vim.api.nvim_buf_delete(ev.buf, { force = true })
    end,
  })

  local job = vim.fn.jobstart(argv, jobopts)
  if job <= 0 then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    return nil
  end

  if feed ~= nil then
    vim.fn.chansend(job, feed)
    vim.fn.chanclose(job, 'stdin') -- EOF on fd 0
  end

  -- Block in Terminal-mode until the process exits (skip if it already did).
  if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == 'terminal' then
    vim.api.nvim__terminal_enter()
  end

  if vim.api.nvim_win_is_valid(caller_win) then
    pcall(vim.api.nvim_set_current_win, caller_win)
  end
  return code
end

--- Edits `text` in a child Nvim hosted in a terminal (the cmdwin for blocking prompts like
--- |input()|). Returns the edited text, or nil if cancelled.
--- @param text string
--- @param histname? string  History to show in the cmdwin (e.g. 'input'); nil for none.
--- @return string?
function M.run_nvim(text, histname)
  local tmp = vim.fn.tempname()
  vim.fn.writefile(vim.split(text, '\n', { plain = true }), tmp)

  -- Share history (command/search/input) with the child via the ShaDa file: materialize this
  -- Nvim's history to an explicit file (so it exists, regardless of 'shada'/`--clean`), pass it as
  -- the child's `-i`, and merge back what the child writes on exit. #40407
  local shada = vim.fn.tempname()
  vim.cmd('wshada ' .. vim.fn.fnameescape(shada))

  local argv = {
    vim.v.progpath,
    '--clean',
    '-i',
    shada,
    '-c',
    ("lua require('vim._core.cmdwin').host(%q)"):format(histname or ''),
    tmp,
  }
  -- The child hands its result back over this Nvim's `$NVIM` RPC channel (see `M._confirm`), so the
  -- result is collected here rather than read from a file.
  M._result = nil
  M.run(argv, {
    -- jobstart() unsets $VIMRUNTIME (see :help jobstart-env); restore it so the child can
    -- `require('vim._core.cmdwin')` from the same runtime as this Nvim.
    env = {
      VIMRUNTIME = vim.env.VIMRUNTIME --[[@as string]],
    },
  })
  vim.cmd('rshada ' .. vim.fn.fnameescape(shada)) -- merge back history the child added

  local result = M._result
  M._result = nil
  vim.fn.delete(tmp)
  vim.fn.delete(shada)
  return result
end

--- Runs a shell command line in an interactive terminal (blocking), for a terminal-based `:!`. The
--- command runs in a real pty in *this* Nvim, so interactive programs (pagers, editors, prompts) work
--- — unlike legacy `:!`, which dumps output to the message area. #40407
--- @param cmd string  The (already-expanded) shell command line.
--- @param feed? string  Written to the command's stdin (fd 0) via a pipe (see `M.run`'s `feed`).
--- @return integer? code  Exit status, or nil if the shell failed to start.
function M.run_shell(cmd, feed)
  -- Build the shell argv: 'shell' (may itself contain args) + 'shellcmdflag' + the command.
  local argv = vim.split(vim.o.shell, ' ', { plain = true, trimempty = true })
  argv[#argv + 1] = vim.o.shellcmdflag
  argv[#argv + 1] = cmd
  return M.run(argv, feed ~= nil and { feed = feed } or nil)
end

--- Pipes buffer lines [line1, line2] (1-based, inclusive) into a shell command's stdin, run in an
--- interactive terminal — for `:[range]w !cmd` (e.g. the `:w !sudo tee %` trick). The lines go to
--- the command's stdin via a pipe (`stdin='fd'`), while the *tty* stays the terminal: it can still
--- prompt (sudo reads /dev/tty, not stdin) and show output. No tempfile, no shell redirect. #40407
--- @param cmd string  @param line1 integer  @param line2 integer
--- @return integer? code  Exit status, or nil if the shell failed to start.
function M.write_shell(cmd, line1, line2)
  local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
  return M.run_shell(cmd, table.concat(lines, '\n') .. '\n')
end

--- Runs a shell command in an interactive terminal, capturing its stdout (`stdout='fd'`) and
--- inserting it into the current buffer after `line2` on exit — for `:[range]r :term cmd` (e.g. an
--- interactive picker: TUI on the tty, selection on stdout). Non-blocking. #40407
--- @param cmd string  @param _line1 integer  @param line2 integer  Insert after this 1-based line.
function M.read_shell(cmd, _line1, line2)
  local buf = vim.api.nvim_get_current_buf()
  local caller_win = vim.api.nvim_get_current_win()

  vim.cmd('botright new') -- throwaway terminal window
  local termbuf = vim.api.nvim_get_current_buf()

  local argv = vim.split(vim.o.shell, ' ', { plain = true, trimempty = true })
  argv[#argv + 1] = vim.o.shellcmdflag
  argv[#argv + 1] = cmd
  vim.fn.jobstart(argv, {
    term = true,
    stdout = 'fd', -- capture the clean stdout; the tty (display) stays separate
    stdout_buffered = true, -- deliver all of stdout once, at EOF
    --- @param data string[]
    on_stdout = function(_, data)
      if vim.api.nvim_buf_is_valid(buf) then
        -- Insert after line2 (captured when :read was invoked); clamp in case the buffer shrank.
        local at = math.min(line2, vim.api.nvim_buf_line_count(buf))
        if #data > 0 and data[#data] == '' then -- drop the trailing newline's empty element
          data[#data] = nil
        end
        vim.api.nvim_buf_set_lines(buf, at, at, false, data)
      end
      if vim.api.nvim_buf_is_valid(termbuf) then
        pcall(vim.api.nvim_buf_delete, termbuf, { force = true })
      end
      if vim.api.nvim_win_is_valid(caller_win) then
        pcall(vim.api.nvim_set_current_win, caller_win)
      end
    end,
  })
  vim.cmd('startinsert') -- enter Terminal-mode so an interactive picker is usable immediately
end

--- Result line handed back by the hosted cmdwin child via `$NVIM` RPC on confirm; nil if cancelled.
--- One slot suffices: run_nvim is blocking and non-reentrant. #40407
--- @type string?
M._result = nil

--- Called by the hosted cmdwin child over this Nvim's `$NVIM` RPC channel (see |$NVIM| and
--- `vim._core.cmdwin.host`) when the user confirms, with the chosen line.
--- @param line string
function M._confirm(line)
  M._result = line
end

return M
