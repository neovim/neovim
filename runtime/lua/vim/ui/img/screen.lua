---@class vim.ui.img.ScreenSize
---@field width integer in pixels
---@field height integer in pixels
---@field columns integer
---@field rows integer
---@field cell_width integer in pixels
---@field cell_height integer in pixels
---@field scale number dpi

---@type vim.ui.img.ScreenSize|nil
local cached_screen_size = nil
vim.api.nvim_create_autocmd('VimResized', {
  callback = function()
    cached_screen_size = nil
  end
})

---@type integer
local DEFAULT_CELL_WIDTH_PX = 9
---@type integer
local DEFAULT_CELL_HEIGHT_PX = 18

---@return {width:number, height:number}|nil
local function screen_width_height_pixels()
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
      result = vim.trim(result)
      if result == '' then
        return nil
      end
      return result
    end
  end

  -- Attempt to calculate the width & height by finding the terminal's
  -- pixel width and height using (CSI 14 t). We need to fork a process
  -- so we can capture raw stdin (the response) since neovim eats CSI
  -- codes without giving us a response via TermResponse.
  local tty = get_tty_name()
  if not tty or tty == '' then
    return
  end

  local fd = assert(vim.uv.fs_open(tty, 'r+', 0))

  local msg = '\027[14t'
  while string.len(msg) > 0 do
    local bytes = assert(vim.uv.fs_write(fd, msg))
    msg = string.sub(msg, bytes + 1)
  end

  ---@type string, string
  local height, width
  local data = ''
  local looking = true

  local function try_read()
    vim.uv.fs_read(fd, 512, nil, function(err, chunk)
      if err then
        return
      end

      if not chunk or chunk == '' then
        return
      end

      data = data .. chunk
      height, width = string.match(data, '\027%[4;(%d+);(%d+)t')
      if height and width then
        looking = false
      end

      if looking then
        vim.defer_fn(try_read, 100)
      end
    end)
  end

  vim.schedule(try_read)
  vim.wait(1000, function()
    return not looking
  end, 200)
  looking = false

  if height and width then
    return {
      width = tonumber(width),
      height = tonumber(height),
    }
  end
end

---@return vim.ui.img.ScreenSize
local function default_screen_size()
  return {
    width = vim.o.columns * DEFAULT_CELL_WIDTH_PX,
    height = vim.o.lines * DEFAULT_CELL_HEIGHT_PX,
    columns = vim.o.columns,
    rows = vim.o.lines,
    cell_width = DEFAULT_CELL_WIDTH_PX,
    cell_height = DEFAULT_CELL_HEIGHT_PX,
    scale = DEFAULT_CELL_WIDTH_PX / 8,
  }
end

---@param force? boolean
---@return vim.ui.img.ScreenSize
local function screen_size(force)
  if cached_screen_size and not force then
    return cached_screen_size
  end

  local size = default_screen_size()
  local screen = screen_width_height_pixels()
  if not screen then
    return size
  end

  return {
    width = screen.width,
    height = screen.height,
    columns = size.columns,
    rows = size.rows,
    cell_width = screen.width / size.columns,
    cell_height = screen.height / size.rows,
    scale = screen.width / size.columns / 8,
  }
end

return {
  size = screen_size,
}
