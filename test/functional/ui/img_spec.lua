local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
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

  it('can set an image relative to the terminal ui', function()
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

  it('can set an image relative to the editor', function()
    local result = exec_lua(function()
      _G.data = {}
      vim.ui.img.set(PNG_IMG_BYTES, {
        row = 2,
        col = 1,
        width = 3,
        height = 4,
        zindex = 123,
        relative = 'editor',
      })
      local cfg = nil
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        local c = vim.api.nvim_win_get_config(w)
        if c.relative ~= '' then
          cfg = c
        end
      end
      return { esc_codes = table.concat(_G.data), cfg = cfg }
    end)

    -- Transmit image bytes
    local esc = result.esc_codes
    local seq = parse_kitty_seq(esc, { strict = true })
    local image_id = seq.control.i
    eq(
      { f = '100', a = 't', t = 'd', i = image_id, q = '2', m = '0' },
      seq.control,
      'transmit control'
    )
    eq(base64_encode(PNG_IMG_BYTES), seq.data, 'transmit payload')
    esc = string.sub(esc, seq.j + 1)

    -- Virtual placement (no cursor management sequences)
    seq = parse_kitty_seq(esc, { strict = true })
    eq(
      { a = 'p', U = '1', i = image_id, p = seq.control.p, c = '3', r = '4', q = '2' },
      seq.control,
      'virtual placement'
    )
    esc = string.sub(esc, seq.j + 1)
    eq('', esc, 'no cursor management sequences')

    -- Floating window at the correct editor-relative position (0-indexed)
    assert(result.cfg ~= nil, 'floating window was created')
    eq('editor', result.cfg.relative)
    eq(1, result.cfg.row) -- row=2 (1-indexed) → 1 (0-indexed)
    eq(0, result.cfg.col) -- col=1 (1-indexed) → 0 (0-indexed)
    eq(3, result.cfg.width)
    eq(4, result.cfg.height)
    eq(123, result.cfg.zindex)
  end)

  it('can set an image relative to a buffer', function()
    local result = exec_lua(function()
      _G.data = {}
      vim.ui.img.set(PNG_IMG_BYTES, { buf = 0, row = 2, col = 1, width = 4, height = 3 })
      local ns_id = vim.api.nvim_get_namespaces()['vim.ui.img.kitty']
      local marks = vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, { details = true })
      return { esc_codes = table.concat(_G.data), mark = marks[1] }
    end)

    -- Transmit image bytes
    local esc = result.esc_codes
    local seq = parse_kitty_seq(esc, { strict = true })
    local image_id = seq.control.i
    eq(
      { f = '100', a = 't', t = 'd', i = image_id, q = '2', m = '0' },
      seq.control,
      'transmit control'
    )
    eq(base64_encode(PNG_IMG_BYTES), seq.data)
    esc = string.sub(esc, seq.j + 1)

    -- Virtual placement (no cursor management sequences)
    seq = parse_kitty_seq(esc, { strict = true })
    eq(
      { a = 'p', U = '1', i = image_id, p = seq.control.p, c = '4', r = '3', q = '2' },
      seq.control,
      'virtual placement'
    )
    esc = string.sub(esc, seq.j + 1)
    eq('', esc, 'no cursor management')

    -- Extmark created at the correct buffer position (0-indexed)
    eq(1, result.mark[2]) -- row=2 (1-indexed) → 1 (0-indexed)
    eq(0, result.mark[3]) -- col=1 (1-indexed) → 0 (0-indexed)
    eq(3, #result.mark[4].virt_lines) -- height=3 lines

    for _, line in ipairs(result.mark[4].virt_lines) do
      local last = line[#line]
      eq(2, #last)
      assert(last[2]:find('NvimImgPlaceholder_'), 'placeholder highlight on last chunk')
    end
  end)

  it('can update an image relative to the terminal ui', function()
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

  it('can update an image relative to the editor', function()
    local result = exec_lua(function()
      local id = vim.ui.img.set(PNG_IMG_BYTES, {
        row = 1,
        col = 1,
        width = 10,
        height = 20,
        zindex = 99,
        relative = 'editor',
      })

      vim.ui.img.set(id, { col = 5, row = 6, width = 7, height = 8, zindex = 9 })

      -- Partial update: only change row
      vim.ui.img.set(id, { row = 50 })
      local info = vim.ui.img.get(id)

      local cfg = nil
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        local c = vim.api.nvim_win_get_config(w)
        if c.relative ~= '' then
          cfg = c
        end
      end

      return { info = info, cfg = cfg }
    end)

    -- Verify partial update merged opts
    eq({ row = 50, col = 5, width = 7, height = 8, zindex = 9, relative = 'editor' }, result.info)

    -- Floating window reflects final merged state (0-indexed)
    eq(49, result.cfg.row) -- row=50 (1-indexed) → 49 (0-indexed)
    eq(4, result.cfg.col) -- col=5  (1-indexed) → 4  (0-indexed)
    eq(7, result.cfg.width)
    eq(8, result.cfg.height)
    eq(9, result.cfg.zindex)
  end)

  it('can update an image relative to a buffer', function()
    local result = exec_lua(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.fn['repeat']({ '' }, 10))
      local id = vim.ui.img.set(PNG_IMG_BYTES, { buf = 0, row = 1, col = 1, width = 4, height = 3 })

      _G.data = {}
      vim.ui.img.set(id, { row = 2, col = 1, width = 6, height = 5 })
      local esc_codes = table.concat(_G.data)

      -- Partial update: only change row, other fields preserved
      vim.ui.img.set(id, { row = 10 })
      local info = vim.ui.img.get(id)

      local ns_id = vim.api.nvim_get_namespaces()['vim.ui.img.kitty']
      local marks = vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, { details = true })

      return { esc_codes = esc_codes, info = info, mark = marks[1] }
    end)

    -- Verify partial update merged opts
    eq({ buf = 0, row = 10, col = 1, width = 6, height = 5 }, result.info)

    -- Virtual placement updated with new dimensions (no cursor management)
    local esc = result.esc_codes
    local seq = parse_kitty_seq(esc, { strict = true })
    eq(
      { a = 'p', U = '1', i = seq.control.i, p = seq.control.p, c = '6', r = '5', q = '2' },
      seq.control,
      'virtual placement'
    )
    esc = string.sub(esc, seq.j + 1)
    eq('', esc, 'no cursor management')

    -- Extmark reflects final merged position (0-indexed)
    eq(9, result.mark[2]) -- row=10 (1-indexed) → 9 (0-indexed)
    eq(0, result.mark[3]) -- col=1  (1-indexed) → 0 (0-indexed)
  end)

  it('can get image info relative to the terminal ui', function()
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

  it('can get image info relative to the editor', function()
    local info = exec_lua(function()
      local id = vim.ui.img.set(PNG_IMG_BYTES, {
        row = 5,
        col = 10,
        width = 20,
        height = 15,
        zindex = 42,
        relative = 'editor',
      })
      return vim.ui.img.get(id)
    end)

    eq({ row = 5, col = 10, width = 20, height = 15, zindex = 42, relative = 'editor' }, info)
  end)

  it('can get image info relative to a buffer', function()
    local info = exec_lua(function()
      local id = vim.ui.img.set(PNG_IMG_BYTES, {
        buf = 0,
        row = 1,
        col = 1,
        width = 20,
        height = 15,
      })
      return vim.ui.img.get(id)
    end)

    eq({ buf = 0, row = 1, col = 1, width = 20, height = 15 }, info)
  end)

  it('can delete an image relative to the terminal ui', function()
    local result = exec_lua(function()
      local id = vim.ui.img.set(PNG_IMG_BYTES, { row = 1, col = 1, width = 2, height = 2 })

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
    eq({ a = 'd', d = 'i', i = seq.control.i, q = '2' }, seq.control, 'delete sequence')

    eq(true, result.found)
    eq(nil, result.after)
    eq(false, result.not_found)
  end)

  it('can delete an image relative to the editor', function()
    local result = exec_lua(function()
      local wins_start = #vim.api.nvim_list_wins()
      local id = vim.ui.img.set(
        PNG_IMG_BYTES,
        { row = 1, col = 1, width = 2, height = 2, relative = 'editor' }
      )
      local wins_after_set = #vim.api.nvim_list_wins()

      _G.data = {}
      local found = vim.ui.img.del(id)
      local after = vim.ui.img.get(id)
      local not_found = vim.ui.img.del(id)
      local wins_after_del = #vim.api.nvim_list_wins()

      return {
        esc_codes = table.concat(_G.data),
        found = found,
        after = after,
        not_found = not_found,
        wins_start = wins_start,
        wins_after_set = wins_after_set,
        wins_after_del = wins_after_del,
      }
    end)

    local seq = parse_kitty_seq(result.esc_codes, { strict = true })
    eq({ a = 'd', d = 'i', i = seq.control.i, q = '2' }, seq.control, 'delete sequence')

    eq(true, result.found)
    eq(nil, result.after)
    eq(false, result.not_found)
    eq(result.wins_start + 1, result.wins_after_set, 'floating window created')
    eq(result.wins_start, result.wins_after_del, 'floating window closed')
  end)

  it('can delete an image relative to a buffer', function()
    local result = exec_lua(function()
      local id = vim.ui.img.set(PNG_IMG_BYTES, { buf = 0, row = 1, col = 1, width = 4, height = 2 })

      _G.data = {}
      local found = vim.ui.img.del(id)
      local after = vim.ui.img.get(id)
      local not_found = vim.ui.img.del(id)
      local ns_id = vim.api.nvim_get_namespaces()['vim.ui.img.kitty']
      local marks = vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {})

      return {
        esc_codes = table.concat(_G.data),
        found = found,
        after = after,
        not_found = not_found,
        marks = marks,
      }
    end)

    local seq = parse_kitty_seq(result.esc_codes, { strict = true })
    eq({ a = 'd', d = 'i', i = seq.control.i, q = '2' }, seq.control, 'delete sequence')

    eq(true, result.found)
    eq(nil, result.after)
    eq(false, result.not_found)
    eq({}, result.marks, 'extmark removed')
  end)

  it('can delete all images', function()
    local result = exec_lua(function()
      local id1 = vim.ui.img.set(PNG_IMG_BYTES, { row = 1, col = 1 })
      local id2 = vim.ui.img.set(PNG_IMG_BYTES, { row = 2, col = 2 })

      _G.data = {}
      local deleted = vim.ui.img.del(math.huge)
      return {
        esc_codes = table.concat(_G.data),
        deleted = deleted,
        after_id1 = vim.ui.img.get(id1),
        after_id2 = vim.ui.img.get(id2),
        not_deleted = vim.ui.img.del(math.huge), -- nothing to delete
      }
    end)

    local seq = parse_kitty_seq(result.esc_codes, { strict = true })
    eq({ a = 'd', d = 'A', q = '2' }, seq.control, 'delete all control data')

    eq(true, result.deleted)
    eq(nil, result.after_id1)
    eq(nil, result.after_id2)
    eq(false, result.not_deleted)
  end)

  it('extmark is hidden when its anchor line is deleted', function()
    local result = exec_lua(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'line 1', 'line 2', 'line 3' })
      vim.ui.img.set(PNG_IMG_BYTES, { buf = 0, row = 2, col = 1, width = 4, height = 3 })
      local ns_id = vim.api.nvim_get_namespaces()['vim.ui.img.kitty']
      local before = vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, { details = true })

      -- Simulate dd: delete the anchor line (row 2 = 0-indexed row 1)
      vim.api.nvim_buf_set_lines(0, 1, 2, false, {})

      local after = vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, { details = true })
      return { before = before, after = after }
    end)

    -- Before: mark exists with invalidate flag set
    eq(1, #result.before, 'extmark exists before deletion')
    eq(true, result.before[1][4].invalidate, 'extmark has invalidate flag')

    -- After: mark is hidden (invalid=true), not rendered, but retained for undo
    eq(1, #result.after, 'extmark still exists after deletion')
    eq(true, result.after[1][4].invalid, 'extmark hidden after anchor line deleted')
  end)

  it('fails to set an image when dimensions cannot be derived', function()
    -- Non-PNG data has no IHDR to read; with no explicit width/height this must fail.
    local ok, err = exec_lua(function()
      return pcall(vim.ui.img.set, 'not a png', { buf = 0 })
    end)
    eq(false, ok)
    assert(err:find('width and height required'), err)
  end)

  it('fails to set an oversized editor placement', function()
    local ok, err = exec_lua(function()
      return pcall(vim.ui.img.set, PNG_IMG_BYTES, {
        relative = 'editor',
        row = 1,
        col = 1,
        width = 298,
        height = 4,
      })
    end)
    eq(false, ok)
    assert(err:find('width exceeds kitty placeholder limit'), err)
    assert(err:find('width=298'), err)
    assert(err:find('max=297'), err)
  end)

  it('fails to set an oversized buffer placement', function()
    local ok, err = exec_lua(function()
      return pcall(vim.ui.img.set, PNG_IMG_BYTES, {
        buf = 0,
        row = 1,
        col = 1,
        width = 4,
        height = 298,
      })
    end)
    eq(false, ok)
    assert(err:find('height exceeds kitty placeholder limit'), err)
    assert(err:find('height=298'), err)
    assert(err:find('max=297'), err)
  end)

  it('can set an image relative to a buffer with padding', function()
    local virt_lines = exec_lua(function()
      vim.ui.img.set(PNG_IMG_BYTES, { buf = 0, row = 1, col = 1, width = 2, height = 2, pad = 3 })
      local ns_id = vim.api.nvim_get_namespaces()['vim.ui.img.kitty']
      local marks = vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, { details = true })
      return marks[1][4].virt_lines
    end)

    eq(2, #virt_lines)
    for _, line in ipairs(virt_lines) do
      eq('   ', line[1][1], 'leading pad spaces')
      eq('Normal', line[1][2], 'pad highlight group')
      assert(line[2][2]:find('NvimImgPlaceholder_'), 'placeholder highlight on second chunk')
    end
  end)
end)
