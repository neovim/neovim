local M = {}

--- Saves a terminal buffer's rendered state and metadata as a msgpack file.
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

  local des = vim.fn.fnamemodify(vim.fs.normalize(fname), ':p')

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
    cwd = cwd or '',
    argv = info.argv,
    timestamp = vim.fn.localtime(),
    content = ansi,
  })

  if mkdir_p then
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
