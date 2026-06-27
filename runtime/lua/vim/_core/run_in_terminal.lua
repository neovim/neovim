--- @brief Run a process in a `:terminal` buffer, blocking (interactively, UI live) until it exits.
---
--- Single-threaded: the parent stays suspended in `nvim__terminal_enter()` (a nested event-loop
--- pump) which renders the terminal and forwards input to the child. A buffer-local |TermClose|
--- closes the buffer on exit, which ends the modal loop without a keypress. The reusable primitive
--- behind cmdwin-in-a-terminal and (future) interactive `:!`. #40407

local M = {}

--- Runs `argv` in a terminal buffer, blocking (interactively) until the process exits.
--- @param argv string[]  Command and arguments.
--- @param opts? table  Extra |jobstart()| options (cwd, env, ...). `term` is forced on.
--- @return integer? code  Process exit status, or nil if the job failed to start.
function M.run(argv, opts)
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

  local job = vim.fn.jobstart(argv, vim.tbl_extend('force', opts or {}, { term = true }))
  if job <= 0 then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    return nil
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
    env = { VIMRUNTIME = vim.env.VIMRUNTIME },
  })
  vim.cmd('rshada ' .. vim.fn.fnameescape(shada)) -- merge back history the child added

  local result = M._result
  M._result = nil
  vim.fn.delete(tmp)
  vim.fn.delete(shada)
  return result
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
