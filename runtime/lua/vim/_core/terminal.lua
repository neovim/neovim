local N_ = vim.fn.gettext

local M = {}

--- Saves a terminal buffer's rendered state and metadata as a msgpack file.
---
--- Called as a BufWriteCmd handler for `term://*` buffers.
---
---@param args table autocmd args (buf, file, match)
function M.save(args)
  local bufnr = args.buf ---@type integer
  local fname = args.file ---@type string

  -- Resolve the destination path
  local des ---@type string
  local is_uri = vim.startswith(fname, 'term://')
  if is_uri then
    -- `:write` without args: slug() handles the URI ("term://" gets a "=uri-term-" prefix)
    local name = vim.fs.slug(fname)
    des = vim.fs.joinpath(vim.fn.stdpath('state'), 'term', name .. '.mpack')
    vim.fn.mkdir(vim.fs.dirname(des), 'p')
  else
    -- `:write {name}`: use the user-specified path
    des = vim.fn.fnamemodify(vim.fs.normalize(fname), ':p')
  end

  -- For URI-derived paths, check_overwrite() in do_write() checked URI,
  -- and check_overwrite's os_isdir check is UNIX-only,
  -- so we must check them here.
  local stat = vim.uv.fs_stat(des)
  if stat and stat.type == 'directory' then
    vim.api.nvim_echo(
      { { N_('E17: "%s" is a directory'):format(des), 'ErrorMsg' } },
      true,
      { err = true }
    )
    return
  end
  if is_uri and stat and vim.v.cmdbang == 0 then
    vim.api.nvim_echo(
      { { N_('E13: File exists (add ! to override)'), 'ErrorMsg' } },
      true,
      { err = true }
    )
    return
  end

  -- Export ANSI content from the terminal.
  -- Use '] and '[ marks (set by buf_write) to export the selected range.
  local start_mark = vim.api.nvim_buf_get_mark(bufnr, '[')
  local end_mark = vim.api.nvim_buf_get_mark(bufnr, ']')
  local ansi = vim.api.nvim__term_capture(bufnr, start_mark[1], end_mark[1])
  if ansi == '' then
    return
  end

  -- Get metadata
  local chan = vim.bo[bufnr].channel
  local info = vim.api.nvim_get_chan_info(chan)

  -- Prefer buffer-local directory (set via `:bcd` or OSC 7)
  local cwd ---@type string
  if vim.fn.haslocaldir(-1, -1, bufnr) == 1 then
    cwd = vim.fn.getcwd(-1, -1, bufnr)
  else
    -- Fallback to spawn-time cwd from the "term://" buffer name
    cwd = vim.api.nvim_buf_get_name(bufnr):match('^term://(.-)//') or ''
  end
  if cwd ~= '' then
    cwd = vim.fs.normalize(cwd)
  end

  -- Encode to msgpack
  local packed = vim.mpack.encode({
    cwd = cwd,
    argv = info.argv,
    timestamp = vim.fn.localtime(),
    content = ansi,
  })

  -- Perf: use a for-loop, don't use `select()`.
  local line_count = 0
  ---@type string
  for _ in ansi:gmatch('\n') do
    line_count = line_count + 1
  end

  -- Write atomically
  local tmp = des .. '.tmp'
  if vim.fn.writefile(packed, tmp, 'b') ~= 0 or not vim.uv.fs_rename(tmp, des) then
    os.remove(tmp)
    vim.api.nvim_echo(
      { { N_("E482: Can't create file %s"):format(des), 'ErrorMsg' } },
      true,
      { err = true }
    )
    return
  end

  vim.bo[bufnr].modified = false

  -- Report message
  local msg = ('"%s"%s %dL, %dB %s'):format(
    des,
    stat and '' or (' ' .. N_('[New]')),
    line_count,
    #packed,
    N_('written')
  )
  vim.api.nvim_echo({ { msg } }, false, {})
end

---@class vim._core.terminal.State
---@field content string ANSI escape sequences (scrollback + visible screen)
---@field argv? string[] Command the terminal was started with
---@field cwd? string Working directory
---@field timestamp? integer Save time

--- Reads and decodes a terminal state file
---
---@param path string Path to a terminal state file
---@return vim._core.terminal.State? state Decoded state, or nil on failure
---@return string? errmsg Error message on failure
local function read_state(path)
  if vim.fn.filereadable(path) == 0 then
    return nil, N_("E484: Can't open file %s"):format(path)
  end
  local ok, state = pcall(vim.mpack.decode, vim.fn.readblob(path))
  if not ok or type(state) ~= 'table' or type(state.content) ~= 'string' then
    return nil, N_('E5011: Invalid terminal state file: %s'):format(path)
  end
  return state
end

--- Loads a terminal state file as a live terminal buffer
---
--- Called as a BufReadCmd handler for `stdpath("state")/term/*.mpack` files.
--- Restarts the saved command and replays the saved content as history,
--- followed by a "[ Terminal history ]" banner. New job output appears below it.
---
---@param args table autocmd args (buf, file, match)
function M.load(args)
  local bufnr = args.buf ---@type integer
  local state, err = read_state(args.file)
  if not state then
    vim.api.nvim_echo({ { err, 'ErrorMsg' } }, true, { err = true })
    return
  end

  -- Restart the saved command, falling back to 'shell' if it is gone
  local argv = state.argv
  if type(argv) ~= 'table' or type(argv[1]) ~= 'string' or vim.fn.executable(argv[1]) == 0 then
    argv = { vim.o.shell }
  end

  local cwd = state.cwd
  if type(cwd) ~= 'string' or vim.fn.isdirectory(cwd) == 0 then
    cwd = nil
  end
  -- jobstart() will rename the buffer to the new "term://" URI
  vim.fn.jobstart(argv, { term = true, cwd = cwd })
  -- Take the state file's name back, so `:write` overwrites the file the state was restored from
  pcall(vim.api.nvim_buf_set_name, bufnr, vim.fn.fnamemodify(args.file, ':p'))

  local now = vim.fn.strftime('%Y-%m-%d %H:%M', vim.fn.localtime())
  local text ---@type string
  if type(state.timestamp) == 'number' then
    local saved = vim.fn.strftime('%Y-%m-%d %H:%M', state.timestamp)
    text = ('saved at %s, restored at %s'):format(saved, now)
  else
    text = ('restored at %s'):format(now)
  end
  local banner = ('\27[7m[ Terminal history %s ]\27[0m'):format(text)
  local pad = state.content:sub(-1) == '\n' and '' or '\n'
  vim.api.nvim__term_feed(bufnr, state.content .. pad .. banner .. '\n\n')
end

return M
