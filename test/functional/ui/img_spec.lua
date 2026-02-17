local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq

local clear = n.clear
local exec_lua = n.exec_lua

---4x4 PNG image that can be written to disk.
---@type string
-- stylua: ignore
local PNG_IMG_BYTES = string.char(unpack({
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 4, 0,
  0, 0, 4, 8, 6, 0, 0, 0, 169, 241, 158, 126, 0, 0, 0, 1, 115, 82, 71, 66, 0,
  174, 206, 28, 233, 0, 0, 0, 39, 73, 68, 65, 84, 8, 153, 99, 252, 207, 192,
  240, 159, 129, 129, 129, 193, 226, 63, 3, 3, 3, 3, 3, 3, 19, 3, 26, 96, 97,
  156, 1, 145, 250, 207, 184, 12, 187, 10, 0, 36, 189, 6, 125, 75, 9, 40, 46,
  0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
}))

---@param s string
---@return string
local function escape_ansi(s)
  return (
    string.gsub(s, '.', function(c)
      local byte = string.byte(c)
      if byte < 32 or byte == 127 then
        return string.format('\\%03d', byte)
      else
        return c
      end
    end)
  )
end

---@param s string
---@return string
local function base64_encode(s)
  return exec_lua(function()
    return vim.base64.encode(s)
  end)
end

---Sets up the experimental image API to capture output data.
local function setup_img_api()
  exec_lua(function()
    _G.data = {}

    -- Mock nvim_chan_send to capture the output
    local original_ui_send = vim.api.nvim_ui_send
    vim.api.nvim_ui_send = function(data)
      table.insert(_G.data, data)
    end

    -- Store original for restoration if needed
    _G._original_ui_send = original_ui_send
  end)
end

describe('ui/img', function()
  ---@type string
  local img_file

  before_each(function()
    clear()

    -- Create the image on disk in a temporary location
    img_file = t.tmpname(true)
    t.write_file(img_file, PNG_IMG_BYTES, true, false)
  end)

  it('should be able to load an image from disk', function()
    local image_id = exec_lua(function()
      return vim.ui.img.load(img_file)
    end)

    ---@type vim.ui.img.ImgOpts
    local info = exec_lua(function()
      return vim.ui.img.get(image_id)
    end)

    eq(img_file, info.filename)
  end)

  describe('kitty protocol', function()
    before_each(function()
      setup_img_api()
    end)

    ---@param esc string actual escape sequence
    ---@param opts? {strict?:boolean}
    ---@return {i:integer, j:integer, control:table<string, string>, data:string|nil}
    local function parse_kitty_seq(esc, opts)
      opts = opts or {}
      local i, j, c, d = string.find(esc, '\027_G([^;\027]+)([^\027]*)\027\\')
      assert(c, 'invalid kitty escape sequence: ' .. escape_ansi(esc))

      if opts.strict then
        assert(i == 1, 'not starting with kitty graphics sequence: ' .. escape_ansi(esc))
      end

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
      local payload
      if d and d ~= '' then
        payload = string.sub(d, 2)
      end

      return { i = i, j = j, control = control, data = payload }
    end

    it('can display an image in neovim', function()
      local esc_codes = exec_lua(function()
        _G.data = {} -- Reset our data to make sure we start clean

        -- Preload our image and place it somewhere
        local id = vim.ui.img.load(img_file)
        vim.ui.img.place(id, {
          col = 1,
          row = 2,
          width = 3,
          height = 4,
          z = 123,
        })

        -- Return esc codes sent
        return table.concat(_G.data)
      end)

      -- First, we upload an image and assign it an id
      local seq = parse_kitty_seq(esc_codes, { strict = true })
      local image_id = seq.control.i
      eq({
        f = '100',
        a = 't',
        t = 'f',
        i = image_id,
        q = '2',
      }, seq.control, 'transmit image control data')
      eq(base64_encode(img_file), seq.data)
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

      -- Fifth, we display the image using its id and a image id
      seq = parse_kitty_seq(esc_codes, { strict = true })
      local img_image_id = seq.control.p
      eq({
        a = 'p',
        i = image_id,
        p = img_image_id,
        C = '1',
        q = '2',
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
    end)

    it('can hide an image in neovim', function()
      local esc_codes = exec_lua(function()
        -- Preload our image and place it somewhere
        local id = vim.ui.img.load(img_file)
        vim.ui.img.place(id)

        _G.data = {} -- Reset our data to make sure we start clean

        -- Hide the placement
        vim.ui.img.hide(id)

        -- Return esc codes sent
        return table.concat(_G.data)
      end)

      local seq = parse_kitty_seq(esc_codes, { strict = true })
      -- stylua: ignore
      eq({
        a = 'd',           -- Perform a deletion
        d = 'i',           -- Target an image or image
        i = seq.control.i, -- Specific kitty image to delete
        q = '2',           -- Suppress all responses
      }, seq.control, 'delete image (and all placements)')
    end)

    it('can hide a placement in neovim', function()
      local esc_codes = exec_lua(function()
        -- Preload our image and place it somewhere
        local id = vim.ui.img.load(img_file)
        local placement_id = vim.ui.img.place(id)

        _G.data = {} -- Reset our data to make sure we start clean

        -- Hide the placement
        vim.ui.img.hide(placement_id)

        -- Return esc codes sent
        return table.concat(_G.data)
      end)

      local seq = parse_kitty_seq(esc_codes, { strict = true })
      -- stylua: ignore
      eq({
        a = 'd',           -- Perform a deletion
        d = 'i',           -- Target an image or placement
        i = seq.control.i, -- Specific kitty image to hide
        p = seq.control.p, -- Specific kitty placement to hide
        q = '2',           -- Suppress all responses
      }, seq.control, 'delete placement')
    end)

    it('can update a placement in neovim', function()
      local esc_codes = exec_lua(function()
        -- Preload our image and place it somewhere
        local id = vim.ui.img.load(img_file)
        local placement_id = vim.ui.img.place(id)

        _G.data = {} -- Reset our data to make sure we start clean

        -- Perform the update of the placement
        vim.ui.img.place(placement_id, {
          col = 5,
          row = 6,
          width = 7,
          height = 8,
          z = 9,
        })

        -- Return esc codes sent
        return table.concat(_G.data)
      end)

      -- First, we save the current cursor position to restore it later
      eq(escape_ansi('\0277'), escape_ansi(string.sub(esc_codes, 1, 2)), 'cursor save')
      esc_codes = string.sub(esc_codes, 3)

      -- Second, we hide the cursor so it doesn't jump around on screeen
      eq(escape_ansi('\027[?25l'), escape_ansi(string.sub(esc_codes, 1, 6)), 'cursor hide')
      esc_codes = string.sub(esc_codes, 7)

      -- Third, we move the cursor to the top-left of image position
      eq(escape_ansi('\027[6;5H'), escape_ansi(string.sub(esc_codes, 1, 6)), 'cursor movement')
      esc_codes = string.sub(esc_codes, 7)

      -- Fourth, we display the image using its id and a image id,
      -- which for kitty will result in a flicker-free visual update
      local seq = parse_kitty_seq(esc_codes, { strict = true })
      eq({
        a = 'p',
        i = seq.control.i,
        p = seq.control.p,
        C = '1',
        q = '2',
        c = '7',
        r = '8',
        z = '9',
      }, seq.control, 'display image control data')
      esc_codes = string.sub(esc_codes, seq.j + 1)

      -- Fifth, we restore the cursor position to where it was before displaying images
      eq(escape_ansi('\0278'), escape_ansi(string.sub(esc_codes, 1, 2)), 'cursor restore')
      esc_codes = string.sub(esc_codes, 3)

      -- Sixth, we show the cursor again
      eq(escape_ansi('\027[?25h'), escape_ansi(string.sub(esc_codes, 1, 6)), 'cursor show')
    end)
  end)
end)
