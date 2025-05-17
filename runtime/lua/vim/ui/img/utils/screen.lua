---@class vim.ui.img.utils.ScreenSize
---@field width number in pixels (may be fractional)
---@field height number in pixels (may be fractional)
---@field columns integer
---@field rows integer
---@field cell_width number in pixels (may be fractional)
---@field cell_height number in pixels (may be fractional)
---@field scale number dpi

---@class vim.ui.img.utils.Screen
---@field private __def boolean has created necessary cdefs
---@field private __size vim.ui.img.utils.ScreenSize|nil cached screen size
local M = {
  __def = false,
  __size = nil,
}

vim.api.nvim_create_autocmd('VimResized', {
  desc = 'Screen size has changed',
  callback = function()
    -- Clear our cache when the screen size changes
    M.__size = nil
  end,
})

---Convert an integer representing absolute pixels to a cell.
---Rounds to the nearest integer.
---@param x integer
---@param y integer
---@return integer x, integer y
function M.pixels_to_cells(x, y)
  local size = M.size()
  return math.floor((x / size.cell_width) + 0.5), math.floor((y / size.cell_height) + 0.5)
end

---Convert an integer representing a cell to absolute pixels.
---Rounds to the nearest integer.
---@param x integer
---@param y integer
---@return integer x, integer y
function M.cells_to_pixels(x, y)
  local size = M.size()
  return math.floor((x * size.cell_width) + 0.5), math.floor((y * size.cell_height) + 0.5)
end

---Determines the size of the terminal screen.
---@return vim.ui.img.utils.ScreenSize
function M.size()
  local size = M.__size

  if size then
    return size
  end

  if vim.fn.has('unix') == 1 then
    size = M.__posix_size()
  end

  M.__size = size or M.__default_size()

  return M.__size
end

---@private
---Determines the size of the terminal screen for POSIX systems.
---@return vim.ui.img.utils.ScreenSize|nil
function M.__posix_size()
  ---@type vim.ui.img.utils.ScreenSize|nil
  local size

  -- On Linux/Android, BSD, MacOS, and Solaris we use
  -- ioctl with TIOCGWINSZ to calculate the size.
  --
  -- Because of this, we define a structure to collect
  -- the size information and specify ioctl as available.
  local ffi = require('ffi')
  if not M.__def then
    ffi.cdef([[
      typedef struct {
        unsigned short row;
        unsigned short col;
        unsigned short xpixel;
        unsigned short ypixel;
      } winsize;
      int ioctl(int, int, ...);
    ]])
    M.__def = true
  end

  local TIOCGWINSZ = nil

  -- 1. For Linux, Android, GNU Hurd, and WSL
  -- 2. For MacOS and BSD like FreeBSD, OpenBSD, NetBSD, and DragonflyBSD
  -- 3. For Solaris
  if vim.fn.has('linux') == 1 then
    TIOCGWINSZ = 0x5413
  elseif vim.fn.has('mac') == 1 or vim.fn.has('bsd') == 1 then
    TIOCGWINSZ = 0x40087468
  elseif vim.fn.has('sun') == 1 then
    TIOCGWINSZ = 0x5468
  end

  ---@type boolean, string|nil
  local ok, err = pcall(function()
    ---@type { row: number, col: number, xpixel: number, ypixel: number }
    local sz = ffi.new('winsize')
    if ffi.C.ioctl(1, TIOCGWINSZ, sz) ~= 0 or sz.col == 0 or sz.row == 0 then
      return
    end
    size = {
      width = sz.xpixel,
      height = sz.ypixel,
      columns = sz.col,
      rows = sz.row,
      cell_width = sz.xpixel / sz.col,
      cell_height = sz.ypixel / sz.row,
      scale = math.max(1, sz.xpixel / sz.col / 8),
    }
  end)

  if not ok then
    vim.notify(
      string.format('unable to retrieve screen size (POSIX): %s', err or ''),
      vim.log.levels.WARN
    )
  end

  return size
end

---@private
---@return vim.ui.img.utils.ScreenSize
function M.__default_size()
  -- Size of the original VT240 and VT330/340 terminals
  local cell_width = 10
  local cell_height = 20

  return {
    width = vim.o.columns * cell_width,
    height = vim.o.lines * cell_height,
    columns = vim.o.columns,
    rows = vim.o.lines,
    cell_width = cell_width,
    cell_height = cell_height,
    scale = cell_width / 8,
  }
end

return M
