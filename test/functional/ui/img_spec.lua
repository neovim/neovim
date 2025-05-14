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
  end)

  it('should be able to load an image from disk', function()
    -- Synchronous loading from disk
    ---@type vim.ui.Image
    local sync_img = exec_lua(function()
      return vim.ui.img.load(img_filename)
    end)

    eq(img_filename, sync_img.filename)
    eq(PNG_IMG_BYTES, sync_img.bytes)

    -- Asynchronous loading from disk
    ---@type vim.ui.Image
    local async_img = exec_lua(function()
      ---@type vim.ui.Image|nil
      local img = nil
      vim.ui.img.load(img_filename, function(_, image)
        img = image
      end)

      if vim.wait(1000, function() return img ~= nil end) then
        return img
      else
        error('could not load image asynchronously')
      end
    end)

    eq(img_filename, async_img.filename)
    eq(PNG_IMG_BYTES, async_img.bytes)
  end)

  it('should unload the old provider when vim.o.imgprovider changes', function()
    ---@type boolean
    local was_unloaded = exec_lua(function()
      local was_unloaded = false
      vim.ui.img.providers['test'] = vim.ui.img.providers.new({
        on_show = function()
          return 0
        end,
        on_hide = function() end,
        on_unload = function()
          was_unloaded = true
        end,
      })

      -- Ensure the provider is loaded, as otherwise it won't unload
      vim.ui.img.providers.load('test')

      -- Force a change away from our test provider
      vim.o.imgprovider = 'test'
      vim.o.imgprovider = 'kitty'

      return was_unloaded
    end)

    eq(true, was_unloaded, 'test provider unloaded')
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
        -- Start terminal sync mode
        '\027[?2026h',
        -- Hide cursor so it doesn't move around
        '\027[?25l',
        -- Save cursor position so it can be restored later
        '\0277',
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
        -- Restore original cursor position
        '\0278',
        -- Show cursor again
        '\027[?25h',
        -- End terminal sync mode
        '\027[?2026l',
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
    ---@param esc string actual escape sequence
    ---
    ---@return {i:integer, j:integer, control:table<string, string>, data:string|nil}
    local function parse_kitty_seq(esc)
      local i, j, c, d = string.find(esc, '\027_G([^;\027]+)([^\027]*)\027\\')
      assert(c, 'invalid kitty escape sequence: ' .. escape_ansi(esc))

      ---@type table<string, string>, integer|nil
      local control, idx = {}, 0
      while true do
        local k, v, _
        idx, _, k, v = string.find(c, '(%a+)=([^,]+),?', idx + 1)
        if idx == nil then
          break
        end
        if k and v then
          control[k] = v
        end
      end

      -- Strip leading ; if we got data
      ---@type string|nil
      local data
      if d and d ~= '' then
        data = string.sub(d, 2)
      end

      return { i = i, j = j, control = control, data = data }
    end

    it('can display an image in neovim', function()
      ---@type string, integer
      local esc_codes, img_placement_id = exec_lua(function()
        local data = {}
        vim.o.imgprovider = 'kitty'

        -- Eagerly load the provider so we can inject a function
        -- to capture the output being written
        vim.ui.img.providers.load('kitty', {
          debug_write = function(...)
            vim.list_extend(data, { ... })
          end,
        })

        -- Load image including data into memory as iterm sends it all
        local img = vim.ui.img.load(img_filename)

        -- Should trigger image data to be sent
        local img_placement_id = img:show({
          crop = { x = 5, y = 6, width = 7, height = 8, unit = 'pixel' },
          pos = { x = 1, y = 2, unit = 'cell' },
          size = { width = 3, height = 4, unit = 'cell' },
          z = 123,
        })

        -- Need to wait a bit for the image to be shown
        vim.wait(100)

        return table.concat(data), img_placement_id
      end)

      -- First, we upload an image and assign it an id
      local seq = parse_kitty_seq(esc_codes)
      assert(seq.i == 1, 'not starting with kitty graphics sequence: ' .. escape_ansi(esc_codes))
      local image_id = seq.control.i
      eq({
        f = '100',
        a = 't',
        t = 'f',
        i = image_id,
        q = '2',
      }, seq.control, 'transmit image control data')
      eq(base64_encode(img_filename), seq.data)
      esc_codes = string.sub(esc_codes, seq.j + 1)

      -- Second, we save the current cursor position to restore it later
      eq(escape_ansi('\0277'), escape_ansi(string.sub(esc_codes, 1, 2)), 'cursor save')
      esc_codes = string.sub(esc_codes, 3)

      -- Third, we hide the cursor so it doesn't jump around on screeen
      eq(escape_ansi('\027[?25l'), escape_ansi(string.sub(esc_codes, 1, 6)), 'cursor hide')
      esc_codes = string.sub(esc_codes, 7)

      -- Fourth, we move the cursor to the top-left of image position
      eq(escape_ansi('\027[2;1H'), escape_ansi(string.sub(esc_codes, 1, 6)), 'cursor movement')
      esc_codes = string.sub(esc_codes, 7)

      -- Fifth, we display the image using its id and a placement id
      seq = parse_kitty_seq(esc_codes)
      assert(seq.i == 1, 'not starting with kitty graphics sequence: ' .. escape_ansi(esc_codes))
      eq({
        a = 'p',
        i = image_id,
        p = tostring(img_placement_id),
        C = '1',
        q = '2',
        x = '5',
        y = '6',
        w = '7',
        h = '8',
        c = '3',
        r = '4',
        z = '123',
      }, seq.control, 'display image control data')
      esc_codes = string.sub(esc_codes, seq.j + 1)

      -- Sixth, we restore the cursor position to where it was before displaying images
      eq(escape_ansi('\0278'), escape_ansi(string.sub(esc_codes, 1, 2)), 'cursor restore')
      esc_codes = string.sub(esc_codes, 3)

      -- Seventh, we show the cursor again
      eq(escape_ansi('\027[?25h'), escape_ansi(string.sub(esc_codes, 1, 6)), 'cursor show')
      esc_codes = string.sub(esc_codes, 7)
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
      local esc_codes = exec_lua(function()
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
          -- X = 1, Y = 2, Width = 2, Height = 1
          crop = { x = 1, y = 2, width = 2, height = 1, unit = 'pixel' },
          pos = { x = 1, y = 2, unit = 'cell' },
          size = { width = 8, height = 8, unit = 'pixel' },
        })

        -- Need to wait a bit for the image to be shown
        vim.wait(100)

        return table.concat(data)
      end)

      -- https://vt100.net/docs/vt3xx-gp/chapter14.html
      -- TODO: Disable sixel scrolling
      local expected = table.concat({
        -- Start terminal sync mode
        '\027[?2026h',
        -- Disable sixel scrolling mode
        '\027[?80l',
        -- Hide cursor so it doesn't move around
        '\027[?25l',
        -- Save cursor position so it can be restored later
        '\0277',
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
        -- Restore original cursor position
        '\0278',
        -- Show cursor again
        '\027[?25h',
        -- End terminal sync mode
        '\027[?2026l',
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
