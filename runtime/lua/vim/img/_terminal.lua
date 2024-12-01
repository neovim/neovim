---@class vim.img.terminal
---@field private __tty_name string
local M = {}

local TERM_CODE = {
  BEL = '\x07', -- aka ^G
  ESC = '\x1B', -- aka ^[ aka \033
}

---Retrieve the tty name used by the editor.
---
---E.g. /dev/ttys008
---@return string|nil
local function get_tty_name()
  if vim.fn.has('win32') == 1 then
    -- On windows, we use \\.\CON for reading and writing
    return '\\\\.\\CON'
  else
    -- Linux/Mac: Use `tty` command, which reads the terminal name
    --            in the form of something like /dev/ttys008
    local handle = io.popen('tty 2>/dev/null')
    if not handle then
      return nil
    end
    local result = handle:read('*a')
    handle:close()
    result = vim.fn.trim(result)
    if result == '' then
      return nil
    end
    return result
  end
end

---Returns the name of the tty associated with the terminal.
---@return string
function M.tty_name()
  if not M.__tty_name then
    M.__tty_name = assert(get_tty_name(), 'failed to read editor tty name')
  end

  return M.__tty_name
end

---Writes data to the editor tty.
---@param ... string|number
function M.write(...)
  local handle = assert(io.open(M.tty_name(), 'w'))
  handle:write(...)
  handle:close()
end

---@class vim.img.terminal.cursor
M.cursor = {}

---@param x integer
---@param y integer
---@param save? boolean
function M.cursor.move(x, y, save)
  if save then
    M.cursor.save()
  end
  M.write(TERM_CODE.ESC .. '[' .. y .. ';' .. x .. 'H')
  vim.uv.sleep(1)
end

function M.cursor.save()
  M.write(TERM_CODE.ESC .. '[s')
end

function M.cursor.restore()
  M.write(TERM_CODE.ESC .. '[u')
end

---Terminal escape codes.
M.code = TERM_CODE

---@param opts {query:string, handler:(fun(buffer:string):string|nil), timeout?:integer}
---@return string|nil result, string|nil err
function M.query(opts)
  local uv = vim.uv

  opts = opts or {}
  local query = opts.query
  local handler = opts.handler
  local timeout = opts.timeout or 250

  local tty_fd, err
  local function cleanup()
    if tty_fd then
      uv.fs_close(tty_fd)
      tty_fd = nil
    end
  end

  -- Identify the path to the editor's tty
  -- NOTE: This only works on Unix-like systems!
  local ok, tty_path = pcall(M.tty_name)
  if not ok then
    return nil, tty_path
  end

  -- Open the tty so we can write our query
  tty_fd, err = uv.fs_open(tty_path, 'r+', 438)
  if not tty_fd then
    return nil, err
  end

  -- Write query to terminal.
  local success, write_err = uv.fs_write(tty_fd, query, -1)
  if not success then
    cleanup()
    return nil, write_err
  end

  -- Read response with timeout.
  local buffer = ''
  local start_time = uv.now()

  while uv.now() - start_time < timeout do
    local data, read_err = uv.fs_read(tty_fd, 512, -1)
    if data then
      buffer = buffer .. data
      local result = handler(buffer)
      if result then
        cleanup()
        return result
      end
    elseif read_err ~= 'EAGAIN' then
      cleanup()
      return nil, read_err
    end
    uv.sleep(1)
  end

  cleanup()
  return nil, 'Timeout'
end

return M
