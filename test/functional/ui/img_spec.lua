local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq

local clear = n.clear
local exec_lua = n.exec_lua

---4x4 PNG image bytes.
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

---Mock nvim_ui_send to capture escape sequence output.
local function setup_img_api()
  exec_lua(function()
    _G.data = {}
    local original_ui_send = vim.api.nvim_ui_send
    vim.api.nvim_ui_send = function(d)
      table.insert(_G.data, d)
    end
    _G._original_ui_send = original_ui_send
  end)
end

---@param esc string
---@param opts? {strict?:boolean}
---@return {i:integer, j:integer, control:table<string, string>, data:string|nil}
local function parse_kitty_seq(esc, opts)
  opts = opts or {}
  local i, j, c, d = string.find(esc, '\027_G([^;\027]+)([^\027]*)\027\\')
  assert(c, 'invalid kitty escape sequence: ' .. escape_ansi(esc))

  if opts.strict then
    assert(i == 1, 'not starting with kitty graphics sequence: ' .. escape_ansi(esc))
  end

  ---@type table<string, string>
  local control = {}
  local idx = 0
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

  ---@type string|nil
  local payload
  if d and d ~= '' then
    payload = string.sub(d, 2)
  end

  return { i = i, j = j, control = control, data = payload }
end

describe('vim.ui.img', function()
  before_each(function()
    clear()
    setup_img_api()
  end)

  it('can set an image', function()
    local esc_codes = exec_lua(function()
      _G.data = {}
      vim.ui.img.set(PNG_IMG_BYTES, {
        col = 1,
        row = 2,
        width = 3,
        height = 4,
        zindex = 123,
      })
      return table.concat(_G.data)
    end)

    -- Transmit image bytes
    local seq = parse_kitty_seq(esc_codes, { strict = true })
    local image_id = seq.control.i
    eq({
      f = '100',
      a = 't',
      t = 'd',
      i = image_id,
      q = '2',
      m = '0',
    }, seq.control, 'transmit image control data')
    eq(base64_encode(PNG_IMG_BYTES), seq.data)
    esc_codes = string.sub(esc_codes, seq.j + 1)

    -- Cursor save
    eq(escape_ansi('\0277'), escape_ansi(string.sub(esc_codes, 1, 2)), 'cursor save')
    esc_codes = string.sub(esc_codes, 3)

    -- Cursor hide
    eq(escape_ansi('\027[?25l'), escape_ansi(string.sub(esc_codes, 1, 6)), 'cursor hide')
    esc_codes = string.sub(esc_codes, 7)

    -- Cursor move
    eq(escape_ansi('\027[2;1H'), escape_ansi(string.sub(esc_codes, 1, 6)), 'cursor movement')
    esc_codes = string.sub(esc_codes, 7)

    -- Place image
    seq = parse_kitty_seq(esc_codes, { strict = true })
    eq({
      a = 'p',
      i = image_id,
      p = seq.control.p,
      C = '1',
      q = '2',
      c = '3',
      r = '4',
      z = '123',
    }, seq.control, 'display image control data')
    esc_codes = string.sub(esc_codes, seq.j + 1)

    -- Cursor restore
    eq(escape_ansi('\0278'), escape_ansi(string.sub(esc_codes, 1, 2)), 'cursor restore')
    esc_codes = string.sub(esc_codes, 3)

    -- Cursor show
    eq(escape_ansi('\027[?25h'), escape_ansi(string.sub(esc_codes, 1, 6)), 'cursor show')
  end)

  it('can get image info', function()
    local result = exec_lua(function()
      local id = vim.ui.img.set(PNG_IMG_BYTES, {
        row = 5,
        col = 10,
        width = 20,
        height = 15,
        zindex = 42,
      })

      return {
        info = vim.ui.img.get(id),
        missing = vim.ui.img.get(999999),
      }
    end)

    eq({ row = 5, col = 10, width = 20, height = 15, zindex = 42 }, result.info)
    eq(nil, result.missing)
  end)

  it('can update an image', function()
    local result = exec_lua(function()
      local id = vim.ui.img.set(PNG_IMG_BYTES, {
        row = 1,
        col = 1,
        width = 10,
        height = 20,
        zindex = 99,
      })

      _G.data = {}
      vim.ui.img.set(id, {
        col = 5,
        row = 6,
        width = 7,
        height = 8,
        zindex = 9,
      })
      local esc_codes = table.concat(_G.data)

      -- Partial update: only change row, other fields preserved
      vim.ui.img.set(id, { row = 50 })
      local info = vim.ui.img.get(id)

      return { esc_codes = esc_codes, info = info }
    end)

    -- Verify partial update merged opts
    eq({ row = 50, col = 5, width = 7, height = 8, zindex = 9 }, result.info)

    local esc_codes = result.esc_codes

    -- Cursor save
    eq(escape_ansi('\0277'), escape_ansi(string.sub(esc_codes, 1, 2)), 'cursor save')
    esc_codes = string.sub(esc_codes, 3)

    -- Cursor hide
    eq(escape_ansi('\027[?25l'), escape_ansi(string.sub(esc_codes, 1, 6)), 'cursor hide')
    esc_codes = string.sub(esc_codes, 7)

    -- Cursor move to new position
    eq(escape_ansi('\027[6;5H'), escape_ansi(string.sub(esc_codes, 1, 6)), 'cursor movement')
    esc_codes = string.sub(esc_codes, 7)

    -- Place command reuses same placement ID (flicker-free update)
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
    }, seq.control, 'update image control data')
    esc_codes = string.sub(esc_codes, seq.j + 1)

    -- Cursor restore
    eq(escape_ansi('\0278'), escape_ansi(string.sub(esc_codes, 1, 2)), 'cursor restore')
    esc_codes = string.sub(esc_codes, 3)

    -- Cursor show
    eq(escape_ansi('\027[?25h'), escape_ansi(string.sub(esc_codes, 1, 6)), 'cursor show')
  end)

  it('can delete an image', function()
    local result = exec_lua(function()
      local id = vim.ui.img.set(PNG_IMG_BYTES, { row = 1, col = 1 })

      _G.data = {}
      local found = vim.ui.img.del(id)
      local after = vim.ui.img.get(id)
      local not_found = vim.ui.img.del(id)

      return {
        esc_codes = table.concat(_G.data),
        found = found,
        after = after,
        not_found = not_found,
      }
    end)

    local seq = parse_kitty_seq(result.esc_codes, { strict = true })
    eq({
      a = 'd',
      d = 'i',
      i = seq.control.i,
      q = '2',
    }, seq.control, 'delete image')

    eq(true, result.found)
    eq(nil, result.after)
    eq(false, result.not_found)
  end)
end)
