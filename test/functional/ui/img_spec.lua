---@diagnostic disable: no-unknown

local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local eq = t.eq
local matches = t.matches

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

---Mock nvim_ui_send to capture escape sequence output, and install scoped
---override helpers for tests that replace core functions.
local function setup_img_api()
  exec_lua(function()
    _G.data = {} ---@type string[]
    local original_ui_send = vim.api.nvim_ui_send
    --- @diagnostic disable-next-line: duplicate-set-field
    vim.api.nvim_ui_send = function(d)
      table.insert(_G.data, d)
    end
    _G._original_ui_send = original_ui_send

    ---Replaces {tbl}[{key}] with {value} for the duration of a single call,
    ---restoring the original afterwards even when the call errors.
    ---@param tbl table
    ---@param key string
    ---@param value any
    ---@return fun(fn:function):...
    function _G.with_override(tbl, key, value)
      return function(fn)
        local orig = tbl[key]
        tbl[key] = value
        local results = { pcall(fn) }
        tbl[key] = orig

        if not results[1] then
          error(results[2], 0)
        end
        return unpack(results, 2)
      end
    end

    ---Wraps `vim.tty.query_apc` to support providing a fake response.
    ---@param id_to_resp_fn fun(id:string):string?
    ---@return fun(fn:function):...
    function _G.with_fake_tty(id_to_resp_fn)
      ---@param query string
      ---@param _ table
      ---@param on_resp fun(resp:string)
      local function query_fn(query, _, on_resp)
        ---@type string?
        local id = query:match('i=(%d+)')

        local resp = id and id_to_resp_fn(id)
        if resp then
          on_resp(resp)
        end
      end

      return _G.with_override(vim.tty, 'query_apc', query_fn)
    end

    ---Wraps `vim.api.nvim_list_uis` to report the given fake {uis}.
    ---@param uis table[]
    ---@return fun(fn:function):...
    function _G.with_fake_uis(uis)
      return _G.with_override(vim.api, 'nvim_list_uis', function()
        return uis
      end)
    end
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

  it('should be able to set an image relative to the terminal ui', function()
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

  it('should be able to set an image relative to the editor', function()
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

  it('should be able to set an image relative to a buffer', function()
    local result = exec_lua(function()
      _G.data = {}
      vim.ui.img.set(PNG_IMG_BYTES, { buf = 0, row = 2, col = 1, width = 4, height = 3 })
      local ns_id = vim.api.nvim_get_namespaces()['vim.ui.img._placement']
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

  it('should be able to update an image relative to the terminal ui', function()
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
      local info = assert(vim.ui.img.get(id))

      return { esc_codes = esc_codes, info = info }
    end)

    -- Verify partial update merged opts
    eq(
      { row = 50, col = 5, width = 7, height = 8, zindex = 9, relative = 'ui', pad = 0 },
      result.info
    )

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

  it('should be able to update an image relative to the editor', function()
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
      local info = assert(vim.ui.img.get(id))

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
    eq(
      { row = 50, col = 5, width = 7, height = 8, zindex = 9, relative = 'editor', pad = 0 },
      result.info
    )

    -- Floating window reflects final merged state (0-indexed)
    eq(49, result.cfg.row) -- row=50 (1-indexed) → 49 (0-indexed)
    eq(4, result.cfg.col) -- col=5  (1-indexed) → 4  (0-indexed)
    eq(7, result.cfg.width)
    eq(8, result.cfg.height)
    eq(9, result.cfg.zindex)
  end)

  it('should be able to update an image relative to a buffer', function()
    local result = exec_lua(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.fn['repeat']({ '' }, 10))
      local id = vim.ui.img.set(PNG_IMG_BYTES, { buf = 0, row = 1, col = 1, width = 4, height = 3 })

      _G.data = {}
      vim.ui.img.set(id, { row = 2, col = 1, width = 6, height = 5 })
      local esc_codes = table.concat(_G.data)

      -- Partial update: only change row, other fields preserved
      vim.ui.img.set(id, { row = 10 })
      local info = assert(vim.ui.img.get(id))

      local ns_id = vim.api.nvim_get_namespaces()['vim.ui.img._placement']
      local marks = vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, { details = true })

      return {
        esc_codes = esc_codes,
        info = info,
        mark = marks[1],
        cur = vim.api.nvim_get_current_buf(),
      }
    end)

    -- Verify partial update merged opts
    eq({
      buf = result.cur,
      row = 10,
      col = 1,
      width = 6,
      height = 5,
      relative = 'buffer',
      pad = 0,
    }, result.info)

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

  it('should support getting image info relative to the terminal ui', function()
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

    eq(
      { row = 5, col = 10, width = 20, height = 15, zindex = 42, relative = 'ui', pad = 0 },
      result.info
    )
    eq(nil, result.missing)
  end)

  it('should support getting image info relative to the editor', function()
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

    eq(
      { row = 5, col = 10, width = 20, height = 15, zindex = 42, relative = 'editor', pad = 0 },
      info
    )
  end)

  it('should support getting image info relative to a buffer', function()
    local result = exec_lua(function()
      local id = vim.ui.img.set(PNG_IMG_BYTES, {
        buf = 0,
        row = 1,
        col = 1,
        width = 20,
        height = 15,
      })
      return { info = vim.ui.img.get(id), cur = vim.api.nvim_get_current_buf() }
    end)

    eq({
      buf = result.cur,
      row = 1,
      col = 1,
      width = 20,
      height = 15,
      relative = 'buffer',
      pad = 0,
    }, result.info)
  end)

  it('should support deleting an image relative to the terminal ui', function()
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
    eq({ a = 'd', d = 'I', i = seq.control.i, q = '2' }, seq.control, 'delete sequence')

    eq(true, result.found)
    eq(nil, result.after)
    eq(false, result.not_found)
  end)

  it('should support deleting an image relative to the editor', function()
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
    eq({ a = 'd', d = 'I', i = seq.control.i, q = '2' }, seq.control, 'delete sequence')

    eq(true, result.found)
    eq(nil, result.after)
    eq(false, result.not_found)
    eq(result.wins_start + 1, result.wins_after_set, 'floating window created')
    eq(result.wins_start, result.wins_after_del, 'floating window closed')
  end)

  it('should support deleting an image relative to a buffer', function()
    local result = exec_lua(function()
      local id = vim.ui.img.set(PNG_IMG_BYTES, { buf = 0, row = 1, col = 1, width = 4, height = 2 })

      _G.data = {}
      local found = vim.ui.img.del(id)
      local after = vim.ui.img.get(id)
      local not_found = vim.ui.img.del(id)
      local ns_id = vim.api.nvim_get_namespaces()['vim.ui.img._placement']
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
    eq({ a = 'd', d = 'I', i = seq.control.i, q = '2' }, seq.control, 'delete sequence')

    eq(true, result.found)
    eq(nil, result.after)
    eq(false, result.not_found)
    eq({}, result.marks, 'extmark removed')
  end)

  it('should support deleting all images owned by this nvim instance', function()
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

    local deleted_ids = {}
    local esc = result.esc_codes
    while esc ~= '' do
      local seq = parse_kitty_seq(esc, { strict = true })
      eq('d', seq.control.a, 'delete sequence')
      eq('I', seq.control.d, 'delete frees the transmitted data')
      assert(seq.control.i, 'delete targets a specific image id')
      deleted_ids[#deleted_ids + 1] = seq.control.i
      esc = string.sub(esc, seq.j + 1)
    end
    eq(2, #deleted_ids, 'one delete per image')
    assert(deleted_ids[1] ~= deleted_ids[2], 'each image deleted by its own id')

    eq(true, result.deleted)
    eq(nil, result.after_id1)
    eq(nil, result.after_id2)
    eq(false, result.not_deleted)
  end)

  it('should hide the extmark when its anchor line is deleted', function()
    local result = exec_lua(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'line 1', 'line 2', 'line 3' })
      vim.ui.img.set(PNG_IMG_BYTES, { buf = 0, row = 2, col = 1, width = 4, height = 3 })
      local ns_id = vim.api.nvim_get_namespaces()['vim.ui.img._placement']
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

  it('should fail to set an image when cannot derive dimensions for relative=editor', function()
    -- Non-PNG data has no IHDR to read; with no explicit width/height this must fail
    local ok, err = exec_lua(function()
      return pcall(vim.ui.img.set, 'not a png', { relative = 'editor' })
    end)

    eq(false, ok)
    assert(err:find('width and height required'), err)
  end)

  it('should fail to set an image when cannot derive dimensions for relative=buffer', function()
    -- Non-PNG data has no IHDR to read; with no explicit width/height this must fail
    local ok, err = exec_lua(function()
      return pcall(vim.ui.img.set, 'not a png', { relative = 'buffer', buf = 0 })
    end)

    eq(false, ok)
    assert(err:find('width and height required'), err)
  end)

  it('should fail when trying to set an oversized image for relative=editor', function()
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
    assert(err:find('width exceeds placeholder limit'), err)
    assert(err:find('width=298'), err)
    assert(err:find('max=297'), err)
  end)

  it('should fail when trying to set an oversized image for relative=buffer', function()
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
    assert(err:find('height exceeds placeholder limit'), err)
    assert(err:find('height=298'), err)
    assert(err:find('max=297'), err)
  end)

  it('can set an image relative to a buffer with padding', function()
    local virt_lines = exec_lua(function()
      vim.ui.img.set(PNG_IMG_BYTES, { buf = 0, row = 1, col = 1, width = 2, height = 2, pad = 3 })
      local ns_id = vim.api.nvim_get_namespaces()['vim.ui.img._placement']
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

  it('should support setting image padding when relative=editor', function()
    local result = exec_lua(function()
      _G.data = {}

      vim.ui.img.set(PNG_IMG_BYTES, {
        row = 2,
        col = 1,
        width = 3,
        height = 4,
        zindex = 7,
        relative = 'editor',
        pad = 2,
      })

      local cfg
      local scratch_buf
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        local c = vim.api.nvim_win_get_config(w)
        if c.relative == 'editor' and c.width == 5 then
          cfg = c
          scratch_buf = vim.api.nvim_win_get_buf(w)
        end
      end

      local lines = vim.api.nvim_buf_get_lines(scratch_buf, 0, -1, false)
      return { cfg = cfg, lines = lines }
    end)

    assert(result.cfg ~= nil, 'floating window was created')
    eq(5, result.cfg.width, 'float width = opts.width + opts.pad')
    eq(4, result.cfg.height)
    eq(0, result.cfg.col, 'float col stays at opts.col-1; pad lives inside the float')
    eq(4, #result.lines, 'one line per row')
    for _, line in ipairs(result.lines) do
      eq('  ', line:sub(1, 2), 'first 2 cells are pad blanks')
    end
  end)

  it('should delete the image when relative=editor and its window is externally closed', function()
    local result = exec_lua(function()
      _G.data = {}
      local id = vim.ui.img.set(PNG_IMG_BYTES, {
        row = 1,
        col = 1,
        width = 2,
        height = 2,
        relative = 'editor',
      })

      -- Find the float winid + its scratch buffer
      local float_win, scratch_buf
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        local c = vim.api.nvim_win_get_config(w)
        if c.relative == 'editor' and c.width == 2 then
          float_win = w
          scratch_buf = vim.api.nvim_win_get_buf(w)
        end
      end

      -- Externally close the float (simulating a user `:close`)
      vim.api.nvim_win_close(float_win, true)

      -- Give WinClosed autocmd a chance to fire.
      vim.cmd('redraw')

      return {
        buf_valid_after_close = vim.api.nvim_buf_is_valid(scratch_buf),
        info_after_close = vim.ui.img.get(id),
        del_after_close = vim.ui.img.del(id),
      }
    end)

    eq(false, result.buf_valid_after_close, 'scratch buf reaped on WinClosed')
    eq(nil, result.info_after_close, 'image fully deleted on WinClosed')
    eq(false, result.del_after_close, 'nothing left to delete')
  end)

  it('should delete the image when its anchor buffer is wiped', function()
    local result = exec_lua(function()
      local buf = vim.api.nvim_create_buf(true, false)
      local id =
        vim.ui.img.set(PNG_IMG_BYTES, { buf = buf, row = 1, col = 1, width = 2, height = 2 })
      local info_before = vim.ui.img.get(id)
      vim.api.nvim_buf_delete(buf, { force = true })
      return {
        info_before = info_before,
        info_after = vim.ui.img.get(id),
        del_after = vim.ui.img.del(id),
      }
    end)
    assert(result.info_before ~= nil, 'image existed before wipeout')
    eq(nil, result.info_after, 'image fully deleted on BufWipeout')
    eq(false, result.del_after, 'nothing left to delete')
  end)

  it('should be able to update an image from relative=ui to relative=editor', function()
    local result = exec_lua(function()
      _G.data = {}
      local id = vim.ui.img.set(PNG_IMG_BYTES, {
        row = 1,
        col = 1,
        width = 3,
        height = 3, -- ui by default
      })
      _G.data = {}
      vim.ui.img.set(id, { relative = 'editor', row = 2, col = 1, width = 3, height = 3 })
      local info = assert(vim.ui.img.get(id))
      local cfg
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        local c = vim.api.nvim_win_get_config(w)
        if c.relative == 'editor' and c.width == 3 then
          cfg = c
        end
      end
      return { info = info, cfg = cfg }
    end)

    eq('editor', result.info.relative)
    assert(result.cfg ~= nil, 'editor float created after ui->editor transition')
    eq(1, result.cfg.row)
    eq(0, result.cfg.col)
  end)

  it('should be able to update an image from relative=editor to relative=buffer', function()
    local result = exec_lua(function()
      _G.data = {}
      local id = vim.ui.img.set(PNG_IMG_BYTES, {
        relative = 'editor',
        row = 2,
        col = 1,
        width = 3,
        height = 3,
      })
      _G.data = {}
      vim.ui.img.set(id, { relative = 'buffer', buf = 0, row = 1, col = 1, width = 3, height = 3 })

      local ns_id = vim.api.nvim_get_namespaces()['vim.ui.img._placement']
      local marks = vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, { details = true })

      local editor_float_present = false
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        local c = vim.api.nvim_win_get_config(w)
        if c.relative == 'editor' and c.width == 3 then
          editor_float_present = true
        end
      end

      return {
        info = vim.ui.img.get(id),
        marks_count = #marks,
        editor_float_present = editor_float_present,
      }
    end)

    eq('buffer', result.info.relative)
    eq(1, result.marks_count, 'buffer-mode extmark exists after editor→buffer transition')
    eq(false, result.editor_float_present, 'editor float closed after transition')
  end)

  it('should be able to update an image from relative=buffer to relative=editor', function()
    local result = exec_lua(function()
      _G.data = {}
      local id = vim.ui.img.set(PNG_IMG_BYTES, {
        relative = 'buffer',
        buf = 0,
        row = 1,
        col = 1,
        width = 4,
        height = 3,
      })
      _G.data = {}
      vim.ui.img.set(id, { relative = 'editor', row = 2, col = 1, width = 4, height = 3 })

      local ns_id = vim.api.nvim_get_namespaces()['vim.ui.img._placement']
      local marks = vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, { details = true })

      -- Filter out invalidated marks (extmark survives invalidation)
      local live_marks = 0
      for _, m in ipairs(marks) do
        if not (m[4] and m[4].invalid) then
          live_marks = live_marks + 1
        end
      end

      local cfg
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        local c = vim.api.nvim_win_get_config(w)
        if c.relative == 'editor' and c.width == 4 then
          cfg = c
        end
      end

      return {
        info = vim.ui.img.get(id),
        live_marks = live_marks,
        cfg = cfg,
      }
    end)

    eq('editor', result.info.relative)
    assert(result.cfg ~= nil, 'editor float created after buffer→editor transition')
    eq(0, result.live_marks, 'live buffer extmarks removed after transition')
  end)

  it('should not accumulate extmarks across updates to a relative=editor image', function()
    local result = exec_lua(function()
      local id = vim.ui.img.set(
        PNG_IMG_BYTES,
        { row = 1, col = 1, width = 3, height = 3, relative = 'editor' }
      )

      local scratch_buf
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        local c = vim.api.nvim_win_get_config(w)
        if c.relative == 'editor' then
          scratch_buf = vim.api.nvim_win_get_buf(w)
        end
      end

      local ns_id = vim.api.nvim_get_namespaces()['vim.ui.img._placement']
      local before = #vim.api.nvim_buf_get_extmarks(scratch_buf, ns_id, 0, -1, {})
      vim.ui.img.set(id, { row = 2 })
      vim.ui.img.set(id, { row = 3, width = 4 })

      local after = #vim.api.nvim_buf_get_extmarks(scratch_buf, ns_id, 0, -1, {})
      return { before = before, after = after }
    end)

    eq(1, result.before, 'single highlight extmark after set')
    eq(1, result.after, 'highlight extmark reused across updates')
  end)

  it('should keep editor-relative images anchored at screen edges', function()
    local Screen = require('test.functional.ui.screen')
    local screen = Screen.new(80, 24)
    local pos = exec_lua(function()
      vim.ui.img.set(
        PNG_IMG_BYTES,
        { row = 5, col = 76, width = 10, height = 3, relative = 'editor' }
      )

      local win
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_config(w).relative == 'editor' then
          win = w
        end
      end

      vim.cmd('redraw')
      return vim.api.nvim_win_get_position(win)
    end)

    screen:detach()

    -- col=76 (1-indexed) -> 75 (0-indexed)
    --
    -- Without fixed=true the float would slide left to 70 so that all 10
    -- columns fit on the 80-col screen; anchored, it stays at 75 and the
    -- overflow is clipped
    eq(4, pos[1])
    eq(75, pos[2])
  end)

  it('should return a deep copy of the image opts when retrieved', function()
    local result = exec_lua(function()
      local opts = { buf = 0, row = 1, col = 1 }
      local id = vim.ui.img.set(PNG_IMG_BYTES, opts)
      local info = assert(vim.ui.img.get(id))
      return {
        caller_width = opts.width,
        caller_height = opts.height,
        derived_width = info.width,
        derived_height = info.height,
      }
    end)

    eq(nil, result.caller_width, 'caller opts not mutated')
    eq(nil, result.caller_height, 'caller opts not mutated')
    assert(result.derived_width ~= nil, 'derived width tracked internally')
    assert(result.derived_height ~= nil, 'derived height tracked internally')
  end)

  it('should return canonicalized image opts from get()', function()
    local result = exec_lua(function()
      local id = vim.ui.img.set(PNG_IMG_BYTES, { buf = 0, row = 2, width = 3, height = 2 })
      local opts = assert(vim.ui.img.get(id))
      vim.ui.img.del(id)

      return {
        buf = opts.buf,
        cur = vim.api.nvim_get_current_buf(),
        relative = opts.relative,
      }
    end)

    eq(result.cur, result.buf, 'buf=0 resolved at creation')
    eq('buffer', result.relative)
  end)

  it('should not reparent a buffer image on partial update from another buffer', function()
    local result = exec_lua(function()
      local first = vim.api.nvim_get_current_buf()

      -- Content keeps the unnamed buffer alive across :enew instead of being wiped
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c', 'd', 'e' })

      local id = vim.ui.img.set(PNG_IMG_BYTES, { buf = 0, row = 1, width = 2, height = 1 })
      vim.cmd.enew()
      vim.ui.img.set(id, { row = 3 })

      local opts = assert(vim.ui.img.get(id))
      vim.ui.img.del(id)

      return { buf = opts.buf, first = first, row = opts.row }
    end)

    eq(result.first, result.buf, 'image stayed in its original buffer')
    eq(3, result.row)
  end)

  it('should not alter the existing image when an attempt to update fails', function()
    local result = exec_lua(function()
      local id = vim.ui.img.set(PNG_IMG_BYTES, { buf = 0, row = 1, width = 2, height = 1 })
      local ok = pcall(vim.ui.img.set, id, { row = 99999 })
      local opts = assert(vim.ui.img.get(id))
      vim.ui.img.del(id)
      return { ok = ok, row = opts.row }
    end)

    eq(false, result.ok)
    eq(1, result.row)
  end)

  it('should free the transmitted image from terminal memory when failing to create it', function()
    local result = exec_lua(function()
      _G.data = {}
      local ok =
        pcall(vim.ui.img.set, PNG_IMG_BYTES, { buf = 0, row = 99999, width = 2, height = 1 })
      return { ok = ok, esc_codes = table.concat(_G.data) }
    end)

    eq(false, result.ok)

    local last = result.esc_codes:match('.*(\027_G.-\027\\)')
    assert(last, 'a graphics escape was sent after the failure')

    local seq = parse_kitty_seq(last, { strict = true })
    eq('d', seq.control.a, 'last escape deletes the image')
    eq('I', seq.control.d, 'delete frees the transmitted data')
  end)

  it('should clean up the image placement when creation fails', function()
    local result = exec_lua(function()
      local before = #vim.api.nvim_list_bufs()
      local ok = pcall(
        vim.ui.img.set,
        PNG_IMG_BYTES,
        { relative = 'editor', row = 1, col = 1, width = 2, height = 1, zindex = 0 }
      )
      return { ok = ok, before = before, after = #vim.api.nvim_list_bufs() }
    end)

    eq(false, result.ok)
    eq(result.before, result.after, 'scratch buffer cleaned up on failure')
  end)

  it('should clean up the replacement image when failing to update it', function()
    local result = exec_lua(function()
      local id = vim.ui.img.set(PNG_IMG_BYTES, { buf = 0, row = 1, width = 2, height = 1 })
      local before = #vim.api.nvim_list_bufs()
      local ok = pcall(vim.ui.img.set, id, { relative = 'editor', zindex = 0 })
      local opts = assert(vim.ui.img.get(id))
      vim.ui.img.del(id)
      return {
        ok = ok,
        before = before,
        after = #vim.api.nvim_list_bufs(),
        relative = opts.relative,
      }
    end)

    eq(false, result.ok)
    eq(result.before, result.after, 'scratch buffer cleaned up on failure')
    eq('buffer', result.relative, 'image still anchored in its buffer')
  end)

  it('should transmit large images in chunks', function()
    local result = exec_lua(function()
      _G.data = {}
      local data = string.rep('x', 9000)
      local id = vim.ui.img.set(data, { row = 1, col = 1 })
      vim.ui.img.del(id)
      return { esc_codes = table.concat(_G.data), b64 = vim.base64.encode(data) }
    end)

    local chunks = {}
    local esc = result.esc_codes
    while true do
      local seq = parse_kitty_seq(esc, { strict = true })
      chunks[#chunks + 1] = seq
      esc = string.sub(esc, seq.j + 1)
      if seq.control.m == '0' then
        break
      end
    end

    eq(3, #chunks)
    eq('t', chunks[1].control.a, 'control keys only on the first chunk')
    eq('1', chunks[1].control.m)
    eq(nil, chunks[2].control.a, 'middle chunk carries only the continuation key')
    eq('1', chunks[2].control.m)
    eq('0', chunks[3].control.m, 'final chunk terminates the transmission')
    eq(0, #chunks[1].data % 4, 'non-final chunk size is a multiple of 4')
    eq(0, #chunks[2].data % 4, 'non-final chunk size is a multiple of 4')
    eq(result.b64, chunks[1].data .. chunks[2].data .. chunks[3].data, 'payload reassembles')
  end)

  it('should reuse the image and placement ids across ui updates', function()
    local result = exec_lua(function()
      _G.data = {}

      local id = vim.ui.img.set(PNG_IMG_BYTES, { row = 1, col = 1, width = 2, height = 2 })

      local created = table.concat(_G.data)
      _G.data = {}
      vim.ui.img.set(id, { row = 5 })

      local updated = table.concat(_G.data)
      vim.ui.img.del(id)

      return { id = id, created = created, updated = updated }
    end)

    local transmit = parse_kitty_seq(result.created, { strict = true })
    local place = parse_kitty_seq(string.sub(result.created, transmit.j + 1))
    local update = parse_kitty_seq(result.updated)

    eq(tostring(result.id), place.control.i, 'returned id is the transmitted image id')
    eq('p', update.control.a)
    eq(place.control.i, update.control.i, 'image id reused')
    eq(place.control.p, update.control.p, 'placement id reused')
  end)

  it('should delete images individually when deleting all images', function()
    local result = exec_lua(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c' })
      vim.ui.img.set(
        PNG_IMG_BYTES,
        { relative = 'editor', row = 1, col = 1, width = 2, height = 1 }
      )
      vim.ui.img.set(PNG_IMG_BYTES, { buf = 0, row = 1, width = 2, height = 1 })
      local wins_before = #vim.api.nvim_list_wins()
      local ns_id = vim.api.nvim_get_namespaces()['vim.ui.img._placement']

      _G.data = {}
      vim.ui.img.del(math.huge)

      return {
        esc_codes = table.concat(_G.data),
        wins_before = wins_before,
        wins_after = #vim.api.nvim_list_wins(),
        marks = vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {}),
      }
    end)

    eq(result.wins_before - 1, result.wins_after, 'float closed')
    eq({}, result.marks, 'extmark removed')

    local count = 0
    local esc = result.esc_codes
    while esc ~= '' do
      local seq = parse_kitty_seq(esc, { strict = true })
      eq('I', seq.control.d, 'per-image delete frees the transmitted data')
      count = count + 1
      esc = string.sub(esc, seq.j + 1)
    end
    eq(2, count, 'one delete per image')
  end)

  it('should clear the placeholder highlight when an image is deleted', function()
    local created = exec_lua(function()
      _G.data = {}
      _G.img_id = vim.ui.img.set(PNG_IMG_BYTES, { buf = 0, row = 1, width = 2, height = 1 })
      return table.concat(_G.data)
    end)
    local handle = parse_kitty_seq(created, { strict = true }).control.i

    local result = exec_lua(function(hl)
      local before = vim.api.nvim_get_hl(0, { name = hl })
      vim.ui.img.del(_G.img_id)
      local after = vim.api.nvim_get_hl(0, { name = hl })
      return { before = before, after = after }
    end, 'NvimImgPlaceholder_' .. handle)

    eq(tonumber(handle), result.before.fg, 'highlight encodes the image id')
    eq({}, result.after, 'highlight cleared on delete')
  end)

  it('should be able to detect whether a terminal supports displaying images', function()
    local result = exec_lua(function()
      local kitty = require('vim.ui.img._kitty')
      local with_fake_tty, with_override = _G.with_fake_tty, _G.with_override

      local function check_supported()
        return kitty.supported({ timeout = 50 })
      end

      local out = {}

      out.ok, out.ok_msg = with_fake_tty(function(id)
        return '\027_Gi=' .. id .. ';OK'
      end)(check_supported)

      out.err, out.err_msg = with_fake_tty(function(id)
        return '\027_Gi=' .. id .. ';ENODATA:Missing image data'
      end)(check_supported)

      out.other = with_fake_tty(function(id)
        return '\027_Gi=' .. (tonumber(id) + 1) .. ';OK'
      end)(check_supported)

      out.apple = with_override(vim.env, 'TERM_PROGRAM', 'Apple_Terminal')(check_supported)

      return out
    end)

    eq(true, result.ok)
    eq(nil, result.ok_msg)
    eq(true, result.err, 'responding terminal is supported even with an error status')
    eq('ENODATA:Missing image data', result.err_msg)
    eq(false, result.other, 'response for another query id is ignored')
    eq(false, result.apple, 'Apple_Terminal is rejected without querying')
  end)

  it('should move a buffer image when given a different buffer in an update', function()
    local result = exec_lua(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c' })
      local first = vim.api.nvim_get_current_buf()
      local other = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_lines(other, 0, -1, false, { 'x', 'y', 'z' })

      local id = vim.ui.img.set(PNG_IMG_BYTES, { buf = 0, row = 1, width = 2, height = 1 })
      vim.ui.img.set(id, { buf = other })

      local ns_id = vim.api.nvim_get_namespaces()['vim.ui.img._placement']
      local opts = assert(vim.ui.img.get(id))
      local r = {
        buf = opts.buf,
        other = other,
        first_marks = #vim.api.nvim_buf_get_extmarks(first, ns_id, 0, -1, {}),
        other_marks = #vim.api.nvim_buf_get_extmarks(other, ns_id, 0, -1, {}),
      }
      vim.ui.img.del(id)
      return r
    end)

    eq(result.other, result.buf)
    eq(0, result.first_marks, 'extmark removed from the original buffer')
    eq(1, result.other_marks, 'extmark created in the target buffer')
  end)

  it('should delete every image anchored in a wiped buffer', function()
    local result = exec_lua(function()
      local buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'a', 'b', 'c' })
      local id1 = vim.ui.img.set(PNG_IMG_BYTES, { buf = buf, row = 1, width = 2, height = 1 })
      local id2 = vim.ui.img.set(PNG_IMG_BYTES, { buf = buf, row = 2, width = 2, height = 1 })
      vim.api.nvim_buf_delete(buf, { force = true })
      return { after1 = vim.ui.img.get(id1), after2 = vim.ui.img.get(id2) }
    end)
    eq(nil, result.after1)
    eq(nil, result.after2)
  end)

  it('should not query the terminal cell size without a tty ui', function()
    local esc_codes = exec_lua(function()
      _G.data = {}
      -- Without explicit dimensions, they are derived from the image and cell size
      vim.ui.img.set(PNG_IMG_BYTES, { relative = 'editor' })
      return table.concat(_G.data)
    end)

    matches('\027_G', esc_codes) -- kitty escapes are still emitted
    eq(nil, esc_codes:find('\027%[16t')) -- but no cell size query
  end)

  it('should query the terminal cell size with a tty ui', function()
    local result = exec_lua(function()
      ---@type string?
      local query

      ---@param payload string
      ---@param _ table
      ---@param on_resp fun(resp:string):boolean?
      local function request_fn(payload, _, on_resp)
        query = payload
        -- Report a cell size of 2x2 pixels
        on_resp('\027[6;2;2t')
      end

      -- Pretend the attached UI is hosted in a terminal
      local esc_codes = _G.with_fake_uis({ { stdout_tty = true, width = 80, height = 24 } })(
        function()
          return _G.with_override(vim.tty, 'request', request_fn)(function()
            _G.data = {}
            vim.ui.img.set(PNG_IMG_BYTES, { relative = 'editor' })
            return table.concat(_G.data)
          end)
        end
      )

      return { query = query, esc_codes = esc_codes }
    end)

    eq('\027[16t', result.query)

    -- The 4x4 pixel image spans 2x2 cells given the reported cell size
    local seq = parse_kitty_seq(result.esc_codes, { strict = true })
    seq = parse_kitty_seq(string.sub(result.esc_codes, seq.j + 1), { strict = true })
    eq('2', seq.control.c, 'derived width in cells')
    eq('2', seq.control.r, 'derived height in cells')
  end)

  describe('backend selection', function()
    it('should keep using the backend that created an image', function()
      local result = exec_lua(function()
        -- Created without any ext_images UI, so the image uses the kitty backend
        local id = vim.ui.img.set(PNG_IMG_BYTES, { row = 1, col = 1 })
        local kitty_calls = #_G.data

        -- Pretend a UI with ext_images attached afterwards: updates and
        -- deletion still go to the kitty backend that owns the image
        local update_calls, del_calls = _G.with_fake_uis({
          { ext_images = true, width = 80, height = 24 },
        })(function()
          vim.ui.img.set(id, { row = 5, col = 5 })
          local update_calls = #_G.data
          vim.ui.img.del(id)
          return update_calls, #_G.data
        end)

        return {
          kitty_calls = kitty_calls,
          update_calls = update_calls,
          del_calls = del_calls,
        }
      end)

      assert(result.kitty_calls > 0, 'expected kitty termcodes for creation')
      assert(result.update_calls > result.kitty_calls, 'expected kitty termcodes for update')
      assert(result.del_calls > result.update_calls, 'expected kitty termcodes for delete')
    end)

    it('should use UI events for new images when an ext_images UI is attached', function()
      local result = exec_lua(function()
        local events = {} ---@type string[]
        for _, name in ipairs({ 'nvim__ui_img_data', 'nvim__ui_img_set', 'nvim__ui_img_del' }) do
          --- @diagnostic disable-next-line: no-unknown
          vim.api[name] = function()
            table.insert(events, name)
          end
        end

        _G.with_fake_uis({ { ext_images = true, width = 80, height = 24 } })(function()
          local id = vim.ui.img.set(PNG_IMG_BYTES, { row = 1, col = 1 })
          vim.ui.img.del(id)
        end)

        return { events = events, termcodes = #_G.data }
      end)

      eq({ 'nvim__ui_img_data', 'nvim__ui_img_set', 'nvim__ui_img_del' }, result.events)
      eq(0, result.termcodes)
    end)
  end)
end)

describe('vim.ui.img._diacritic', function()
  before_each(clear)

  it('builds a placeholder grid of the requested shape', function()
    local result = exec_lua(function()
      local d = require('vim.ui.img._diacritic')
      local lines = d.grid(3, 2)
      return {
        n = #lines,
        rows_differ = lines[1] ~= lines[2],
        cell00 = vim.startswith(lines[1], d.cell_to_unicode(0, 0)),
      }
    end)
    eq(2, result.n)
    eq(true, result.rows_differ, 'row diacritics differ per row')
    eq(true, result.cell00, 'first cell encodes row 0, col 0')
  end)

  it('rejects grids beyond the diacritic table', function()
    local err = exec_lua(function()
      local d = require('vim.ui.img._diacritic')
      local ok, e = pcall(d.grid, 9999, 1)
      return not ok and e or nil
    end)
    matches('width exceeds placeholder limit', err)
  end)

  it('derives the highlight name from the image id', function()
    eq(
      'NvimImgPlaceholder_42',
      exec_lua(function()
        return require('vim.ui.img._diacritic').hl_name(42)
      end)
    )
  end)
end)

describe('vim.ui.img._placement', function()
  before_each(clear)

  it('canonicalizes buf=0 to the current buffer at construction', function()
    local result = exec_lua(function()
      local p = require('vim.ui.img._placement').new({ buf = 0, row = 1, width = 2, height = 2 })
      return { buf = p.buf, cur = vim.api.nvim_get_current_buf(), relative = p.relative }
    end)
    eq(result.cur, result.buf)
    eq('buffer', result.relative)
  end)

  it('requires width/height for non-ui placements', function()
    local err = exec_lua(function()
      local ok, e = pcall(require('vim.ui.img._placement').new, { relative = 'editor' })
      return not ok and e or nil
    end)
    matches('width and height required', err)
  end)

  it('reuses an editor float across replacement placements', function()
    local result = exec_lua(function()
      local p1 = require('vim.ui.img._placement').new({
        relative = 'editor',
        row = 2,
        col = 3,
        width = 4,
        height = 2,
      })
      local render = function(w, h)
        local d = require('vim.ui.img._diacritic')
        return d.grid(w, h), d.hl_name(1)
      end
      p1:set(render)
      local wins_after_create = #vim.api.nvim_list_wins()
      local p2, reused = p1:with({ row = 5 })
      p2:set(render)
      local wins_after_update = #vim.api.nvim_list_wins()
      local pos ---@type integer[]
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        if p2:owns_win(w) then
          pos = vim.api.nvim_win_get_position(w)
        end
      end
      p2:del()
      return {
        create = wins_after_create,
        update = wins_after_update,
        reused = reused,
        row = pos[1],
        wins_after_del = #vim.api.nvim_list_wins(),
      }
    end)
    eq(result.create, result.update, 'float reused, not recreated')
    eq(true, result.reused)
    eq(4, result.row, 'row 5 (1-indexed) -> 4 (0-indexed)')
    eq(result.create - 1, result.wins_after_del)
  end)

  it('leaves the replaced placement untouched when set() fails', function()
    local result = exec_lua(function()
      local p1 = require('vim.ui.img._placement').new({ buf = 0, row = 1, width = 2, height = 1 })
      local render = function(w, h)
        local d = require('vim.ui.img._diacritic')
        return d.grid(w, h), d.hl_name(1)
      end
      p1:set(render)
      local p2 = p1:with({ row = 9999 })
      local ok = pcall(p2.set, p2, render)
      local opts = p1:opts()
      p1:del()
      return { ok = ok, row = opts.row }
    end)
    eq(false, result.ok)
    eq(1, result.row, 'replaced placement still reports its applied geometry')
  end)

  it('does not reuse artifacts across relative or buffer changes', function()
    local result = exec_lua(function()
      local p = require('vim.ui.img._placement').new({ buf = 0, row = 1, width = 2, height = 1 })
      local _, cross_relative = p:with({ relative = 'editor' })
      local other_buf = vim.api.nvim_create_buf(true, false)
      local _, cross_buffer = p:with({ buf = other_buf })
      local _, same = p:with({ row = 2 })
      return { cross_relative = cross_relative, cross_buffer = cross_buffer, same = same }
    end)
    eq(false, result.cross_relative)
    eq(false, result.cross_buffer)
    eq(true, result.same)
  end)
end)

describe('vim.ui.img (ext_images)', function()
  local Screen = require('test.functional.ui.screen')

  local screen

  before_each(function()
    clear()
    screen = Screen.new(80, 24, { ext_images = true })
  end)

  ---Waits until image {id} satisfies {predicate}, returning its latest
  ---state. Images are keyed by the same id vim.ui.img.set() returns.
  ---@param id integer
  ---@param predicate fun(img:table|nil):boolean?
  ---@return table|nil img
  local function wait_for_image(id, predicate)
    screen:expect(function()
      assert(predicate(screen.images[id]), 'image state not reached for id ' .. id)
    end)
    return screen.images[id]
  end

  ---True when an image has both its data and a placement.
  ---@param img table|nil
  ---@return boolean
  local function placed(img)
    return img ~= nil and img.data ~= nil and img.placement ~= nil
  end

  it('should transmit data and directly place an image relative to the terminal ui', function()
    local id = exec_lua(function()
      return vim.ui.img.set(PNG_IMG_BYTES, {
        row = 3,
        col = 5,
        width = 20,
        height = 10,
        zindex = 42,
      })
    end)

    local img = assert(wait_for_image(id, placed))
    eq(PNG_IMG_BYTES, img.data)
    -- The UI protocol is 0-indexed, unlike the 1-indexed Lua interface
    eq({ row = 2, col = 4, width = 20, height = 10, zindex = 42 }, img.placement)
  end)

  it('should place an image relative to the editor as a virtual placement', function()
    local id = exec_lua(function()
      return vim.ui.img.set(PNG_IMG_BYTES, { relative = 'editor', width = 4, height = 2 })
    end)

    local img = assert(wait_for_image(id, placed))
    eq(PNG_IMG_BYTES, img.data)
    eq({ virtual = true, width = 4, height = 2 }, img.placement)
  end)

  it('should place an image relative to a buffer as a virtual placement', function()
    local id = exec_lua(function()
      return vim.ui.img.set(PNG_IMG_BYTES, { buf = 0, row = 1, col = 1, width = 4, height = 2 })
    end)

    local img = assert(wait_for_image(id, placed))
    eq(PNG_IMG_BYTES, img.data)
    eq({ virtual = true, width = 4, height = 2 }, img.placement)
  end)

  it('should not retransmit image data when updating an image', function()
    local id = exec_lua(function()
      return vim.ui.img.set(PNG_IMG_BYTES, { row = 1, col = 1, width = 10, height = 5 })
    end)

    wait_for_image(id, placed)

    exec_lua(function()
      vim.ui.img.set(id, { row = 5, col = 9 })
    end)

    local img = assert(wait_for_image(id, function(img)
      return placed(img) and img.placement.row == 4
    end))

    -- Update opts merge with those from creation, converted to 0-indexed
    eq({ row = 4, col = 8, width = 10, height = 5 }, img.placement)
    eq(1, img.data_events)
  end)

  it('should re-place a virtual placement when resizing it', function()
    local id = exec_lua(function()
      return vim.ui.img.set(PNG_IMG_BYTES, { relative = 'editor', width = 4, height = 2 })
    end)

    wait_for_image(id, placed)

    exec_lua(function()
      vim.ui.img.set(id, { width = 6, height = 3 })
    end)

    local img = assert(wait_for_image(id, function(img)
      return placed(img) and img.placement.width == 6
    end))

    eq({ virtual = true, width = 6, height = 3 }, img.placement)
    eq(1, img.data_events)
  end)

  it('should transition an image from a direct to a virtual placement', function()
    local id = exec_lua(function()
      return vim.ui.img.set(PNG_IMG_BYTES, { row = 2, col = 2 })
    end)

    wait_for_image(id, placed)

    exec_lua(function()
      vim.ui.img.set(id, { relative = 'editor', width = 4, height = 2 })
    end)

    local img = assert(wait_for_image(id, function(img)
      return placed(img) and img.placement.virtual == true
    end))

    eq({ virtual = true, width = 4, height = 2 }, img.placement)
    eq(1, img.data_events)
  end)

  it('should support deleting an image', function()
    local id = exec_lua(function()
      return vim.ui.img.set(PNG_IMG_BYTES, { row = 1, col = 1 })
    end)

    wait_for_image(id, placed)

    local result = exec_lua(function()
      return { found = vim.ui.img.del(id), not_found = vim.ui.img.del(id) }
    end)

    eq(true, result.found)
    eq(false, result.not_found)
    wait_for_image(id, function(img)
      return img == nil
    end)
  end)

  it('should delete each image when deleting all images', function()
    local ids = exec_lua(function()
      return {
        vim.ui.img.set(PNG_IMG_BYTES, { row = 1, col = 1 }),
        vim.ui.img.set(PNG_IMG_BYTES, { relative = 'editor', width = 2, height = 2 }),
      }
    end)

    for _, id in ipairs(ids) do
      wait_for_image(id, placed)
    end

    exec_lua(function()
      vim.ui.img.del(math.huge)
    end)

    for _, id in ipairs(ids) do
      wait_for_image(id, function(img)
        return img == nil
      end)
    end
  end)

  it('should not emit kitty termcodes', function()
    local id = exec_lua(function()
      _G.data = {}
      --- @diagnostic disable-next-line: duplicate-set-field
      vim.api.nvim_ui_send = function(d)
        table.insert(_G.data, d)
      end
      return vim.ui.img.set(PNG_IMG_BYTES, { row = 1, col = 1 })
    end)

    wait_for_image(id, placed)
    eq({}, exec_lua('return _G.data'))
  end)

  it('should derive placement extent without querying the terminal', function()
    local id = exec_lua(function()
      _G.data = {}
      --- @diagnostic disable-next-line: duplicate-set-field
      vim.api.nvim_ui_send = function(d)
        table.insert(_G.data, d)
      end
      -- No width/height given: derived from the PNG dimensions and cell size
      return vim.ui.img.set(PNG_IMG_BYTES, { relative = 'editor' })
    end)

    local img = assert(wait_for_image(id, placed))
    -- The 4x4 pixel PNG covers a single cell with the default cell size
    eq({ virtual = true, width = 1, height = 1 }, img.placement)
    -- No UI has a tty, so no cell size query (or any other termcode) is sent
    eq({}, exec_lua('return _G.data'))
  end)

  it('should report image support without querying the terminal', function()
    eq(true, exec_lua('return vim.ui.img._supported({ timeout = 0 })'))
  end)

  it('should not send img events to UIs without ext_images', function()
    clear()
    screen = Screen.new(40, 6)

    exec_lua(function()
      vim.api.nvim__ui_img_data(99, 'png-bytes', {})
      vim.api.nvim__ui_img_set(99, { row = 0, col = 0 })
    end)

    -- Wrongly broadcast img events would have been flushed before this
    -- grid update, since UI events are delivered in order
    exec_lua(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'sync' })
    end)
    screen:expect({ any = 'sync' })

    eq({}, screen.images)
  end)
end)
