local N_ = vim.fn.gettext

local M = {}

--- Saves a terminal buffer's rendered state and metadata as a msgpack file.
---
--- Called as a BufWriteCmd handler for `term://*` buffers.
---
---@param args table autocmd args (buf, file, match)
---@param opts? { silent?: boolean }
function M.save(args, opts)
  opts = opts or {}
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
  -- `:write` on a terminal buffer overwrites its own state file like a normal buffer
  if is_uri and stat and vim.v.cmdbang == 0 and fname ~= vim.api.nvim_buf_get_name(bufnr) then
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
  if not opts.silent then
    vim.api.nvim_echo({ { msg } }, false, {})
  end
end

--- Saves the state of all running terminal buffers
function M.save_running()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[bufnr].buftype == 'terminal' then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if vim.startswith(name, 'term://') or name:sub(-6) == '.mpack' then
        local chan = vim.bo[bufnr].channel
        -- Skip exited jobs: session restore falls back to restarting the command
        if chan ~= 0 and vim.fn.jobwait({ chan }, 0)[1] == -1 then
          M.save({ buf = bufnr, file = name }, { silent = true })
        end
      end
    end
  end
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

--- Finds state files matching a `term://` URI in `stdpath('state')/term/`
---
---@param uri string
---@param cwd string?
---@param cmd string
---@return { path: string, state: vim._core.terminal.State }[]
local function find_states(uri, cwd, cmd)
  local term_path = vim.fs.joinpath(vim.fn.stdpath('state'), 'term')
  if vim.fn.isdirectory(term_path) == 0 then
    return {}
  end

  -- URIs recorded by sessions/marks is complete
  local fname = vim.fs.joinpath(term_path, vim.fs.slug(uri) .. '.mpack')
  local exact_state = read_state(fname)
  if exact_state then
    return { { path = fname, state = exact_state } }
  end

  -- local uri_cwd = cwd and vim.fs.normalize(cwd) or nil
  ---@param state vim._core.terminal.State
  local function matches(state)
    -- Note: the dir in a `term://` URI is the directory the terminal was spawned in,
    --       not the save-time cwd which may have been changed via `:bcd`/OSC 7.
    --       So, dir is matched by filename only, and state.cwd is deliberately not compared.
    -- if uri_cwd and (type(state.cwd) ~= 'string' or vim.fs.normalize(state.cwd) ~= uri_cwd) then
    --   return false
    -- end
    return type(state.argv) == 'table' and table.concat(state.argv, ' '):find(cmd, 1, true) ~= nil
  end

  -- how dir and cmd appear in filenames
  local dir_frag = cwd and cwd:gsub('[%c%s/\\:*?"<>|]', '-') or nil
  local cmd_frag = cmd:gsub('[%c%s/\\:*?"<>|]', '-')
  -- Verified matches
  local cands = {} ---@type { path: string, state: vim._core.terminal.State }[]
  -- Frag misses, rechecked only when `cands` is empty
  local unchecked = {} ---@type string[]
  for name, typ in vim.fs.dir(term_path) do
    if typ == 'file' and name:sub(-6) == '.mpack' then
      local path = vim.fs.joinpath(term_path, name)
      if (dir_frag and name:find(dir_frag, 1, true)) and name:find(cmd_frag, 1, true) then
        local state = read_state(path)
        if state and matches(state) then
          cands[#cands + 1] = { path = path, state = state }
        end
      else
        unchecked[#unchecked + 1] = path
      end
    end
  end
  if #cands == 0 then
    for _, path in ipairs(unchecked) do
      local state = read_state(path)
      if state and matches(state) then
        cands[#cands + 1] = { path = path, state = state }
      end
    end
  end
  table.sort(cands, function(a, b)
    return (a.state.timestamp or 0) > (b.state.timestamp or 0)
  end)
  return cands
end

--- Opens a `term://` URI as a live terminal buffer
---
--- Called as a BufReadCmd handler for `term://*` buffers. When state files match the URI,
--- the chosen one is restored via `M.load`; otherwise the URI's command is started fresh.
---
---@param args table autocmd args (buf, file, match)
function M.open(args)
  local bufnr = args.buf ---@type integer
  local uri = args.match ---@type string
  if vim.b[bufnr].term_title ~= nil then
    return
  end
  -- `term://{cwd}//{pid}:{cmd}`; cwd and the pid prefix are optional
  local rest = uri:sub(#'term://' + 1)
  local cwd, cmd = rest:match('^(.-)//(.*)$') ---@type string?, string?
  if cmd then
    -- Strip the PID prefix
    cmd = cmd:match('^%d+:(.*)$') or cmd
    cwd = cwd ~= '' and cwd or nil
  else
    cmd = rest
  end

  -- Only a URI with both dir and cmd participates in matching
  local cands = {} ---@type { path: string, state: vim._core.terminal.State }[]
  if cwd and cmd ~= '' then
    cands = find_states(uri, cwd, cmd)
  end

  if #cands == 1 then
    M.load({ buf = bufnr, file = cands[1].path })
  elseif #cands > 1 then
    vim.ui.select(cands, {
      prompt = N_('Select a terminal state to restore:'),
      kind = 'termstate',
      ---@param cand { path: string, state: vim._core.terminal.State }
      format_item = function(cand)
        local t = type(cand.state.timestamp) == 'number'
            and vim.fn.strftime('%Y-%m-%d %H:%M', cand.state.timestamp)
          or '?'
        return ('%s  %s  %s'):format(
          t,
          cand.state.cwd or '',
          table.concat(cand.state.argv or {}, ' ')
        )
      end,
    }, function(_, idx)
      -- Buffer wiped while an async picker was open: nothing to restore into
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      vim.api.nvim_set_current_buf(bufnr)
      if idx then
        M.load({ buf = bufnr, file = cands[idx].path })
      else
        -- Cancelled: abandon the restore and fall back to a fresh terminal
        vim.fn.jobstart(cmd, { term = true, cwd = vim.fn.expand(cwd or '') })
      end
    end)
  else
    vim.fn.jobstart(cmd, { term = true, cwd = vim.fn.expand(cwd or '') })
  end
end

--- Redirects a `terms://` buffer to the state directory listing
---
---@param args table autocmd args (buf, file, match)
function M.list(args)
  -- Deferred: `:edit` inside BufReadCmd would nest the read flow
  vim.schedule(function()
    local dir = vim.fs.joinpath(vim.fn.stdpath('state'), 'term')
    vim.fn.mkdir(dir, 'p') -- may not exist yet
    local win = vim.fn.bufwinid(args.buf)
    if win ~= -1 then
      vim.api.nvim_set_current_win(win)
    end
    vim.api.nvim_cmd({ cmd = 'edit', args = { dir }, magic = { file = false, bar = false } }, {})
    if vim.api.nvim_buf_is_valid(args.buf) then
      vim.api.nvim_buf_delete(args.buf, { force = true })
    end
  end)
end

return M
