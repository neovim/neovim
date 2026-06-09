local M = {}

--- Saves a terminal buffer's rendered state and metadata as a msgpack file.
---
--- The destination is based on `fname`:
---   - a bare name is stored under stdpath('state')/term/<name>.mpack;
---   - a name containing a path separator is written to that path.
---
---@param buf_handle integer terminal buffer handle (source of argv).
---@param ansi       string ANSI escape sequences of the terminal state/scrollback content.
---@param cwd        string current working directory of the shell.
---@param fname      string user-specified name.
---@param force      boolean overwrite an existing destination (`:write!`).
---@param mkdir_p    boolean create missing parent directories for explicit paths (`++p`).
---@return table     result { true, msg } / { false, err, path }
function M.save(buf_handle, ansi, cwd, fname, force, mkdir_p)
  if fname:sub(-6) ~= '.mpack' then
    fname = fname .. '.mpack' --[[@as string]]
  end

  -- Classify the user-specified name:
  --   - contains a path separator:
  --     treat as a real path and write there directly.
  --     (e.g. `:write ./foo.mpack`, `:write /tmp/foo.mpack`).
  --   - is a bare name:
  --     store under stdpath('state')/term/<name>.mpack.
  local des ---@type string
  local explicit_path = fname:find('[/\\]') ~= nil
  if explicit_path then
    des = vim.fn.fnamemodify(vim.fs.normalize(fname), ':p')
  else
    des = vim.fs.joinpath(vim.fn.stdpath('state'), 'term', fname)
  end

  local stat = vim.uv.fs_stat(des)
  if stat and stat.type == 'directory' then
    return { ok = false, err = 17, path = des }
  end
  -- Overwrite policy.
  local existed = stat ~= nil
  if existed and not force then
    return { ok = false, err = 13, path = des }
  end

  local chan = vim.bo[buf_handle].channel
  local info = vim.api.nvim_get_chan_info(chan)

  local packed = vim.mpack.encode({
    cwd = cwd,
    argv = info.argv,
    timestamp = vim.fn.localtime(),
    content = ansi,
  })

  if not explicit_path or mkdir_p then
    vim.fn.mkdir(vim.fs.dirname(des), 'p')
  end

  local tmp = des .. '.tmp'
  local f = io.open(tmp, 'wb')
  if not f then
    return { ok = false, err = 212, path = des }
  end
  local ok = (f:write(packed) ~= nil)
  if not f:close() then
    ok = false
  end
  if ok and not vim.uv.fs_rename(tmp, des) then
    ok = false
  end
  if not ok then
    os.remove(tmp)
    return { ok = false, err = 212, path = des }
  end

  -- Get message
  local lines = select(2, ansi:gsub('\n', ''))
  local msg = ('"%s"%s %dL, %dB written'):format(des, existed and '' or ' [New]', lines, #packed)
  return { ok = true, msg = msg }
end

return M
