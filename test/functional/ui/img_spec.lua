local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local tt = require('test.functional.testterm')

local eq = t.eq
local retry = t.retry

local feed, clear = n.feed, n.clear
local fn = n.fn
local testprg = n.testprg
local exec_lua = n.exec_lua
local eval = n.eval

---4x4 PNG image that can be written to disk.
---@type string
local PNG_IMG_BYTES = string.char(unpack({
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 4, 0, 0,
  0, 4, 8, 6, 0, 0, 0, 169, 241, 158, 126, 0, 0, 0, 1, 115, 82, 71, 66, 0, 174,
  206, 28, 233, 0, 0, 0, 39, 73, 68, 65, 84, 8, 153, 99, 252, 207, 192, 240, 159,
  129, 129, 129, 193, 226, 63, 3, 3, 3, 3, 3, 3, 19, 3, 26, 96, 97, 156, 1, 145,
  250, 207, 184, 12, 187, 10, 0, 36, 189, 6, 125, 75, 9, 40, 46, 0, 0, 0, 0, 73,
  69, 78, 68, 174, 66, 96, 130,
}))

---@param s string
---@return integer[]
local function str_to_bytes(s)
  ---@type integer[]
  local bytes = {}
  for i = 1, string.len(s) do
    bytes[i] = string.byte(s, i, i)
  end
  return bytes
end

---@param s string
---@return string
local function escape_ansi(s)
  return (string.gsub(s, '.', function(c)
    local byte = string.byte(c)
    if byte < 32 or byte == 127 then
      return string.format('\\%03d', byte)
    else
      return c
    end
  end))
end

---@param s string
---@return string
local function base64_encode(s)
  return exec_lua(function()
    return vim.base64.encode(s)
  end)
end

describe('ui/img', function()
  ---@type test.functional.ui.screen
  local screen

  ---@type string
  local img_filename

  before_each(function()
    clear()

    -- Configure a screen for all of our image-based tests
    -- screen = Screen.new(25, 5)
    screen = tt.setup_screen()

    -- Create the image on disk in a temporary location
    img_filename = t.tmpname(true)
    t.write_file(img_filename, PNG_IMG_BYTES, true, false)

    -- Set up a default provider that is a test that we can examine
    exec_lua([[
      vim.ui.img.providers['test'] = vim.ui.img.providers.new({
        show = function(_self, opts)
        end,
        hide = function(_self, ids)
        end,
      })

      vim.o.imgprovider = 'test'
    ]])
  end)

  describe('iterm2 provider', function()
    it('can display an image in neovim', function()
      ---@type string, string
      local esc_codes, img_bytes = exec_lua(function()
        local data = {}
        vim.o.imgprovider = 'iterm2'

        -- Eagerly load the provider so we can inject a function
        -- to capture the output being written
        vim.ui.img.providers.load('iterm2', {
          debug_write = function(...)
            vim.list_extend(data, { ... })
          end,
        })

        -- Load image including data into memory as iterm sends it all
        local img = vim.ui.img.load(img_filename)

        -- Should trigger image data to be sent
        img:show({
          pos = { x = 1, y = 2, unit = 'cell' },
          size = { width = 3, height = 4, unit = 'cell' },
        })

        -- Need to wait a bit for the image to be shown
        vim.wait(100)

        return table.concat(data), img.bytes
      end)

      local expected = table.concat({
        -- Hide cursor so it doesn't move around
        '\027[?25l',
        -- Start terminal sync mode
        '\027[?2026h',
        -- Move cursor to top-left of image position
        '\027[2;1H',
        -- iterm2 image file display escape sequence
        string.format(
          '\027]1337;File=%s:%s\007',
          string.format(
            'name=%s;size=%s;preserveAspectRatio=0;inline=1;width=3;height=4',
            base64_encode(fn.fnamemodify(img_filename, ':t:r')),
            string.len(img_bytes)
          ),
          base64_encode(img_bytes)
        ),
        -- End terminal sync mode
        '\027[?2026l',
        -- Show cursor again
        '\027[?25h',
      })

      eq(escape_ansi(expected), escape_ansi(esc_codes))
    end)

    it('can hide an image in neovim', function()
      error('todo: implement')
    end)

    it('can update an image in neovim', function()
      error('todo: implement')
    end)
  end)

  describe('kitty provider', function()
    it('can display an image in neovim', function()
      error('todo: implement')
    end)

    it('can hide an image in neovim', function()
      error('todo: implement')
    end)

    it('can update an image in neovim', function()
      error('todo: implement')
    end)
  end)

  describe('sixel provider', function()
    it('can display an image in neovim', function()
      ---@type string, string
      local esc_codes, img_bytes = exec_lua(function()
        local data = {}
        vim.o.imgprovider = 'sixel'

        -- Eagerly load the provider so we can inject a function
        -- to capture the output being written
        vim.ui.img.providers.load('sixel', {
          debug_write = function(...)
            vim.list_extend(data, { ... })
          end,
        })

        -- Load image including data into memory as iterm sends it all
        local img = vim.ui.img.load(img_filename)

        -- Should trigger image data to be sent
        img:show({
          -- X 1, Y 2, Width 2, height 1
          crop = {
            pos1 = { x = 1, y = 2, unit = 'pixel' },
            pos2 = { x = 3, y = 3, unit = 'pixel' },
          },
          pos = { x = 1, y = 2, unit = 'cell' },
          size = { width = 8, height = 8, unit = 'pixel' },
        })

        -- Need to wait a bit for the image to be shown
        vim.wait(100)

        return table.concat(data), img.bytes
      end)

      local expected = table.concat({
        -- Hide cursor so it doesn't move around
        '\027[?25l',
        -- Start terminal sync mode
        '\027[?2026h',
        -- Move cursor to top-left of image position
        '\027[2;1H',
        -- sixel image file display escape sequence
        table.concat({
          '\027P',                   -- Begin sixel
          '0;0;0q',                  -- Macro parameter for aspect ratio (0;0 = use default)
          '"1;1;8;4',                -- Set raster attributes
          '#0;2;37;38;87',           -- Color register 0; 2 = rgb mode; r=37%, g=38%, b=87%
          '#1;2;86;8;70',            -- Color register 1; ...
          '#2;2;100;0;63',           -- Color register 2; ...
          '#3;2;63;22;78',           -- Color register 3; ...
          '#4;2;1;59;100',           -- Color register 4; ...
          '#5;2;14;51;95',           -- Color register 5; ...
          '#6;2;0;63;100',           -- Color register 6; ...
          '#6N#4N#5N#0N#3N#1N#2NN-', -- Image data
          '\027\\',                  -- End sixel
        }),
        -- End terminal sync mode
        '\027[?2026l',
        -- Show cursor again
        '\027[?25h',
      })

      eq(escape_ansi(expected), escape_ansi(esc_codes))
    end)

    it('can hide an image in neovim', function()
      error('todo: implement')
    end)

    it('can update an image in neovim', function()
      error('todo: implement')
    end)
  end)
end)
