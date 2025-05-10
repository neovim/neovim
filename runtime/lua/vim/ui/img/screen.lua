---@class vim.ui.img.screen.Size
---@field width integer in pixels
---@field height integer in pixels
---@field columns integer
---@field rows integer
---@field cell_width number in pixels (may be fractional)
---@field cell_height number in pixels (may be fractional)
---@field scale number dpi

---@class vim.ui.img.Screen
---@field private __def boolean has created necessary cdefs
---@field private __size vim.ui.img.screen.Size|nil cached screen size
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

---Determines the size of the terminal screen.
---@return vim.ui.img.screen.Size
function M.size()
  local size = M.__size

  if size then
    return size
  end

  if vim.fn.has('win32') == 1 then
    size = M.__windows_size()
  elseif vim.fn.has('unix') == 1 then
    size = M.__posix_size()
  end

  M.__size = size or M.__default_size()

  return M.__size
end

---@private
---Determines the size of the terminal screen for Windows systems with pixel accuracy.
---@return vim.ui.img.screen.Size|nil
function M.__windows_size()
  -- For neovim spawned from within Windows Terminal, this should be set to
  -- some GUID; so, leverage CSI escape codes to query, which are supported
  -- by modern Windows Terminal instances
  if vim.env.WT_SESSION then
    return M.__csi_size()
  end

  local ffi = require('ffi')

  if not M.__def then
    ffi.cdef([[
      typedef unsigned long DWORD;
      typedef unsigned short WORD;
      typedef int BOOL;
      typedef void* HANDLE;
      typedef short SHORT;

      typedef struct _COORD {
        SHORT X;
        SHORT Y;
      } COORD;

      typedef struct _SMALL_RECT {
        SHORT Left;
        SHORT Top;
        SHORT Right;
        SHORT Bottom;
      } SMALL_RECT;

      typedef struct _CONSOLE_SCREEN_BUFFER_INFO {
        COORD dwSize;
        COORD dwCursorPosition;
        WORD wAttributes;
        SMALL_RECT srWindow;
        COORD dwMaximumWindowSize;
      } CONSOLE_SCREEN_BUFFER_INFO;

      typedef struct _CONSOLE_FONT_INFO {
        DWORD nFont;
        COORD dwFontSize;
      } CONSOLE_FONT_INFO;

      HANDLE GetStdHandle(DWORD nStdHandle);
      BOOL GetConsoleScreenBufferInfo(
        HANDLE hConsoleOutput,
        CONSOLE_SCREEN_BUFFER_INFO* lpConsoleScreenBufferInfo
      );
      BOOL GetCurrentConsoleFont(
        HANDLE hConsoleOutput,
        BOOL bMaximumWindow,
        CONSOLE_FONT_INFO* lpConsoleFontInfo
      );
    ]])
    M.__def = true
  end

  ---@type vim.ui.img.screen.Size|nil
  local size

  ---Retrieve the screen buffer info and font size to determine the cell width and height.
  ---NOTE: This does not work on Windows Terminal! We will fall back to CSI escape codes.
  ---@type boolean, string|nil
  local ok, err = pcall(function()
    -- Using -11 should retrieve STD_OUTPUT_HANDLE, which initially is the
    -- active console screen buffer (CONOUT$)
    ---@type ffi.cdata*
    local hStdOut = ffi.C.GetStdHandle(-11)

    -- If our handle is INVALID_HANDLE_VALUE (-1)
    if hStdOut == ffi.cast('HANDLE', -1) then
      error('failed to get STD_OUTPUT_HANDLE')
    end

    ---@type { srWindow: { Left:integer, Top:integer, Right:integer, Bottom:integer } }
    local csbi = ffi.new('CONSOLE_SCREEN_BUFFER_INFO')
    if ffi.C.GetConsoleScreenBufferInfo(hStdOut, csbi) == 0 then
      error('failed to retrieve screen buffer info')
    end

    ---@type { nFont:integer, dwFontSize: { X:integer, Y:integer } }
    local fontInfo = ffi.new('CONSOLE_FONT_INFO')
    if ffi.C.GetCurrentConsoleFont(hStdOut, false, fontInfo) == 0 then
      error('failed to retrieve current console font')
    end

    -- Use the visible window (srWindow) to figure out the rows and columns shown
    local cols = csbi.srWindow.Right - csbi.srWindow.Left + 1
    local rows = csbi.srWindow.Bottom - csbi.srWindow.Top + 1

    -- Use our font size as an approximation of the cell size
    local cell_width = fontInfo.dwFontSize.X
    local cell_height = fontInfo.dwFontSize.Y

    -- Verify that we have valid font size information
    -- NOTE: On Windows Terminal, this should result in the font width being 0,
    --       so in the case that WT_SESSION was not set, we need to try it here
    if cell_width == 0 or cell_height == 0 then
      size = M.__csi_size()
      if not size then
        error('no valid size information available')
      end
    end

    size = {
      width = cols * cell_width,
      height = rows * cell_height,
      columns = cols,
      rows = rows,
      cell_width = cell_width,
      cell_height = cell_height,
      scale = math.max(1, cell_width / 8),
    }
  end)

  if not ok then
    vim.notify(
      string.format('unable to retrieve screen size (windows): %s', err or '???'),
      vim.log.levels.WARN
    )
  end

  return size
end

---@private
---Determines the size of the terminal screen using CSI escape codes.
---@return vim.ui.img.screen.Size|nil
function M.__csi_size()
  -- TODO: Introduce support for querying CSI. Neovim eats the response right now.
  --
  --       CSI 14 t and CSI 16 t are both supported by Windows Terminal
  --
  --       CSI 14 t :: tells us the pixel dimensions of the view space
  --       CSI 16 t :: tells us the pixel dimensions of a terminal character
  vim.notify(
    'support querying CSI 14 t and/or CSI 16 t is not available',
    vim.log.levels.WARN
  )
  return nil
end

---@private
---Determines the size of the terminal screen for POSIX systems.
---@return vim.ui.img.screen.Size|nil
function M.__posix_size()
  ---@type vim.ui.img.screen.Size|nil
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
---@return vim.ui.img.screen.Size
function M.__default_size()
  local cell_width = 9
  local cell_height = 18

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
