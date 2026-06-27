local M = {}

--- Convert a "term://" URI into a filename (PID is discarded).
---
--- e.g. "term://~/project//12345:bash" -> "~-project-bash"
---
---@param uri string
---@return string
local function uri2fname(uri)
  local s = uri:gsub('^term://', '')
  local sep = s:find('//')
  if not sep then
    return 'terminal'
  end
  local cwd = s:sub(1, sep - 1):gsub('[^%w._~-]', '-')
  local pid_cmd = s:sub(sep + 2)
  local colon = pid_cmd:find(':')
  local cmd = (colon and pid_cmd:sub(colon + 1) or pid_cmd):gsub('[^%w._~-]', '-')
  local name ---@type string
  if cwd ~= '' and cmd ~= '' then
    name = cwd .. '-' .. cmd
  elseif cwd ~= '' then
    name = cwd
  else
    name = cmd
  end
  return name ~= '' and name or 'terminal'
end

--- Saves a terminal buffer's rendered state and metadata as a msgpack file.
---
---@param buf_handle integer terminal buffer handle (source of argv).
---@param ansi       string ANSI escape sequences of the terminal state/scrollback content.
---@param cwd        string current working directory of the shell.
---@param fname      string "term://" URI or user-specified path/name.
---@param force      boolean overwrite an existing destination (`:write!`).
---@param mkdir_p    boolean create missing parent directories for explicit paths (`++p`).
---@return table     result { true, msg } / { false, err, path }
function M.save(buf_handle, ansi, cwd, fname, force, mkdir_p)
  if fname == '' then
    -- `:write` without args: get the "term://" URI from the buffer.
    fname = vim.api.nvim_buf_get_name(buf_handle)
  end
  local des ---@type string
  local is_uri = vim.startswith(fname, 'term://')
  if is_uri then
    local name = uri2fname(fname)
    des = vim.fs.joinpath(vim.fn.stdpath('state'), 'term', name .. '.mpack')
    vim.fn.mkdir(vim.fs.dirname(des), 'p')
  else
    if fname:sub(-6) ~= '.mpack' then
      fname = fname .. '.mpack' --[[@as string]]
    end
    des = vim.fn.fnamemodify(vim.fs.normalize(fname), ':p')
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
    cwd = cwd or '',
    argv = info.argv,
    timestamp = vim.fn.localtime(),
    content = ansi,
  })

  if not is_uri and mkdir_p then
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
