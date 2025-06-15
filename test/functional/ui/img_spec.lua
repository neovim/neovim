local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq

local clear = n.clear
local exec_lua = n.exec_lua

---Max time to wait for an operation to complete in our tests.
---@type integer
local TEST_TIMEOUT = 10000

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

---Sets up the provider `name` to write data to a global `_G.data`.
---@param name string
local function setup_provider(name)
  exec_lua(function()
    _G.data = {}

    -- NOTE: If we support multiple providers, then we would want
    --       to configure here the provider to be used.

    -- Eagerly load the provider so we can inject a function
    -- to capture the output being written
    vim.ui.img.providers.load(name, {
      write = function(...)
        vim.list_extend(_G.data, { ... })
      end,
    })
  end)
end

---Executes zero or more operations for the image at `file`.
---
---If operation `show`, will create a image using `opts` and store as `id` for future ops.
---If operation `hide`, will hide a image referenced by `id`.
---If operation `update`, will update a image using `opts` referenced by `id`.
---If operation 'clear', will wipe the output data at that point in processing operations.
---
---Note that `data` can be supplied during `show` operation to supply them to the image.
---
---Returns the output from executing the following operations.
---@param ... { op:'show'|'hide'|'update'|'clear', id?:integer, data?:string, file?:string, opts?:vim.ui.img.Opts }
---@return string output
local function img_execute(...)
  local args = { ... }

  return exec_lua(function()
    ---@type table<integer, vim.ui.Image>
    local images = {}

    -- Reset our data to make sure we start clean
    _G.data = {}

    for _, arg in ipairs(args) do
      if arg.op == 'show' then
        -- Create the image (if first time) without loading as some providers need
        -- the data while others do not
        local opts = {
          data = arg.data,
          file = assert(arg.file, 'operation show requires a file'),
        }
        local img = vim.ui.img.new(opts)

        -- Perform the actual show operation
        assert(img:show(arg.opts):wait({ timeout = TEST_TIMEOUT }))

        -- Save the image if we were given an id to refer to it later
        local id = arg.id
        if id then
          images[id] = img
        end
      elseif arg.op == 'hide' then
        local id = assert(arg.id, 'operation hide requires an id')
        local img = assert(images[id], 'no image with id ' .. tostring(id))
        img:hide():wait({ timeout = TEST_TIMEOUT })
      elseif arg.op == 'update' then
        local id = assert(arg.id, 'operation update requires an id')
        local img = assert(images[id], 'no image with id ' .. tostring(id))
        img:update(arg.opts):wait({ timeout = TEST_TIMEOUT })
      elseif arg.op == 'clear' then
        _G.data = {}
      end
    end

    return table.concat(_G.data)
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
    -- Synchronous loading from disk
    ---@type vim.ui.Image
    local sync_img = exec_lua(function()
      return assert(vim.ui.img.load(img_file):wait())
    end)

    eq(img_file, sync_img.file)
    eq(PNG_IMG_BYTES, sync_img.data)
  end)

  describe('kitty provider', function()
    before_each(function()
      setup_provider('kitty')
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
      local esc_codes = img_execute({
        op = 'show',
        file = img_file,
        id = 12345,
        opts = {
          col = 1,
          row = 2,
          width = 3,
          height = 4,
          z = 123,
        },
      })

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
      local esc_codes = img_execute({
        op = 'show',
        file = img_file,
        id = 12345,
      }, { op = 'clear' }, { op = 'hide', id = 12345 })

      local seq = parse_kitty_seq(esc_codes, { strict = true })
      -- stylua: ignore
      eq({
        a = 'd',           -- Perform a deletion
        d = 'i',           -- Target an image or image
        i = seq.control.i, -- Specific kitty image to delete
        p = seq.control.p, -- Specific kitty image to delete
        q = '2',           -- Suppress all responses
      }, seq.control, 'delete image and image')
    end)

    it('can update an image in neovim', function()
      local esc_codes = img_execute({
        op = 'show',
        file = img_file,
        id = 12345,
      }, { op = 'clear' }, {
        op = 'update',
        id = 12345,
        opts = {
          col = 5,
          row = 6,
          width = 7,
          height = 8,
          z = 9,
        },
      })

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
