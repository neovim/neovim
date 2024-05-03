local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local request = n.request
local eq = t.eq
local ok = t.ok
local pcall_err = t.pcall_err
local insert = n.insert
local feed = n.feed
local clear = n.clear
local command = n.command
local exec = n.exec
local api = n.api
local assert_alive = n.assert_alive

local function expect(contents)
  return eq(contents, n.curbuf_contents())
end

local function set_extmark(ns_id, id, line, col, opts)
  if opts == nil then
    opts = {}
  end
  if id ~= nil and id ~= 0 then
    opts.id = id
  end
  return api.nvim_buf_set_extmark(0, ns_id, line, col, opts)
end

local function get_extmarks(ns_id, start, end_, opts)
  if opts == nil then
    opts = {}
  end
  return api.nvim_buf_get_extmarks(0, ns_id, start, end_, opts)
end

local function get_extmark_by_id(ns_id, id, opts)
  if opts == nil then
    opts = {}
  end
  return api.nvim_buf_get_extmark_by_id(0, ns_id, id, opts)
end

local function check_undo_redo(ns, mark, sr, sc, er, ec) --s = start, e = end
  local rv = get_extmark_by_id(ns, mark)
  eq({ er, ec }, rv)
  feed('u')
  rv = get_extmark_by_id(ns, mark)
  eq({ sr, sc }, rv)
  feed('<c-r>')
  rv = get_extmark_by_id(ns, mark)
  eq({ er, ec }, rv)
end

local function batch_set(ns_id, positions)
  local ids = {}
  for _, pos in ipairs(positions) do
    table.insert(ids, set_extmark(ns_id, 0, pos[1], pos[2]))
  end
  return ids
end

local function batch_check(ns_id, ids, positions)
  local actual, expected = {}, {}
  for i, id in ipairs(ids) do
    expected[id] = positions[i]
  end
  for _, mark in pairs(get_extmarks(ns_id, 0, -1, {})) do
    actual[mark[1]] = { mark[2], mark[3] }
  end
  eq(expected, actual)
end

local function batch_check_undo_redo(ns_id, ids, before, after)
  batch_check(ns_id, ids, after)
  feed('u')
  batch_check(ns_id, ids, before)
  feed('<c-r>')
  batch_check(ns_id, ids, after)
end

describe('API/extmarks', function()
  local screen
  local marks, positions, init_text, row, col
  local ns, ns2

  before_each(function()
    -- Initialize some namespaces and insert 12345 into a buffer
    marks = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }
    positions = { { 0, 0 }, { 0, 2 }, { 0, 3 } }

    init_text = '12345'
    row = 0
    col = 2

    clear()

    insert(init_text)
    ns = request('nvim_create_namespace', 'my-fancy-plugin')
    ns2 = request('nvim_create_namespace', 'my-fancy-plugin2')
  end)

  it('validation', function()
    eq(
      "Invalid 'end_col': expected Integer, got Array",
      pcall_err(set_extmark, ns, marks[2], 0, 0, { end_col = {}, end_row = 1 })
    )
    eq(
      "Invalid 'end_row': expected Integer, got Array",
      pcall_err(set_extmark, ns, marks[2], 0, 0, { end_col = 1, end_row = {} })
    )
    eq(
      "Invalid 'virt_text_pos': expected String, got Integer",
      pcall_err(set_extmark, ns, marks[2], 0, 0, { virt_text_pos = 0 })
    )
    eq(
      "Invalid 'virt_text_pos': 'foo'",
      pcall_err(set_extmark, ns, marks[2], 0, 0, { virt_text_pos = 'foo' })
    )
    eq(
      "Invalid 'hl_mode': expected String, got Integer",
      pcall_err(set_extmark, ns, marks[2], 0, 0, { hl_mode = 0 })
    )
    eq("Invalid 'hl_mode': 'foo'", pcall_err(set_extmark, ns, marks[2], 0, 0, { hl_mode = 'foo' }))
    eq(
      "Invalid 'id': expected Integer, got Array",
      pcall_err(set_extmark, ns, {}, 0, 0, { end_col = 1, end_row = 1 })
    )
    eq(
      'Invalid mark position: expected 2 Integer items',
      pcall_err(get_extmarks, ns, {}, { -1, -1 })
    )
    eq(
      'Invalid mark position: expected mark id Integer or 2-item Array',
      pcall_err(get_extmarks, ns, true, { -1, -1 })
    )
    -- No memory leak with virt_text, virt_lines, sign_text
    eq(
      'right_gravity is not a boolean',
      pcall_err(set_extmark, ns, marks[2], 0, 0, {
        virt_text = { { 'foo', 'Normal' } },
        virt_lines = { { { 'bar', 'Normal' } } },
        sign_text = 'a',
        right_gravity = 'baz',
      })
    )
  end)

  it('can end extranges past final newline using end_col = 0', function()
    set_extmark(ns, marks[1], 0, 0, {
      end_col = 0,
      end_row = 1,
    })
    eq(
      "Invalid 'end_col': out of range",
      pcall_err(set_extmark, ns, marks[2], 0, 0, { end_col = 1, end_row = 1 })
    )
  end)

  it('can end extranges past final newline when strict mode is false', function()
    set_extmark(ns, marks[1], 0, 0, {
      end_col = 1,
      end_row = 1,
      strict = false,
    })
  end)

  it('can end extranges past final column when strict mode is false', function()
    set_extmark(ns, marks[1], 0, 0, {
      end_col = 6,
      end_row = 0,
      strict = false,
    })
  end)

  it('adds, updates  and deletes marks', function()
    local rv = set_extmark(ns, marks[1], positions[1][1], positions[1][2])
    eq(marks[1], rv)
    rv = get_extmark_by_id(ns, marks[1])
    eq({ positions[1][1], positions[1][2] }, rv)
    -- Test adding a second mark on same row works
    rv = set_extmark(ns, marks[2], positions[2][1], positions[2][2])
    eq(marks[2], rv)

    -- Test an update, (same pos)
    rv = set_extmark(ns, marks[1], positions[1][1], positions[1][2])
    eq(marks[1], rv)
    rv = get_extmark_by_id(ns, marks[2])
    eq({ positions[2][1], positions[2][2] }, rv)
    -- Test an update, (new pos)
    row = positions[1][1]
    col = positions[1][2] + 1
    rv = set_extmark(ns, marks[1], row, col)
    eq(marks[1], rv)
    rv = get_extmark_by_id(ns, marks[1])
    eq({ row, col }, rv)

    -- remove the test marks
    eq(true, api.nvim_buf_del_extmark(0, ns, marks[1]))
    eq(false, api.nvim_buf_del_extmark(0, ns, marks[1]))
    eq(true, api.nvim_buf_del_extmark(0, ns, marks[2]))
    eq(false, api.nvim_buf_del_extmark(0, ns, marks[3]))
    eq(false, api.nvim_buf_del_extmark(0, ns, 1000))
  end)

  it('can clear a specific namespace range', function()
    set_extmark(ns, 1, 0, 1)
    set_extmark(ns2, 1, 0, 1)
    -- force a new undo buffer
    feed('o<esc>')
    api.nvim_buf_clear_namespace(0, ns2, 0, -1)
    eq({ { 1, 0, 1 } }, get_extmarks(ns, { 0, 0 }, { -1, -1 }))
    eq({}, get_extmarks(ns2, { 0, 0 }, { -1, -1 }))
    feed('u')
    eq({ { 1, 0, 1 } }, get_extmarks(ns, { 0, 0 }, { -1, -1 }))
    eq({}, get_extmarks(ns2, { 0, 0 }, { -1, -1 }))
    feed('<c-r>')
    eq({ { 1, 0, 1 } }, get_extmarks(ns, { 0, 0 }, { -1, -1 }))
    eq({}, get_extmarks(ns2, { 0, 0 }, { -1, -1 }))
  end)

  it('can clear a namespace range using 0,-1', function()
    set_extmark(ns, 1, 0, 1)
    set_extmark(ns2, 1, 0, 1)
    -- force a new undo buffer
    feed('o<esc>')
    api.nvim_buf_clear_namespace(0, -1, 0, -1)
    eq({}, get_extmarks(ns, { 0, 0 }, { -1, -1 }))
    eq({}, get_extmarks(ns2, { 0, 0 }, { -1, -1 }))
    feed('u')
    eq({}, get_extmarks(ns, { 0, 0 }, { -1, -1 }))
    eq({}, get_extmarks(ns2, { 0, 0 }, { -1, -1 }))
    feed('<c-r>')
    eq({}, get_extmarks(ns, { 0, 0 }, { -1, -1 }))
    eq({}, get_extmarks(ns2, { 0, 0 }, { -1, -1 }))
  end)

  it('can undo with extmarks (#25147)', function()
    feed('itest<esc>')
    set_extmark(ns, 1, 0, 0)
    set_extmark(ns, 2, 1, 0)
    eq({ { 1, 0, 0 }, { 2, 1, 0 } }, get_extmarks(ns, { 0, 0 }, { -1, -1 }))
    feed('dd')
    eq({ { 1, 1, 0 }, { 2, 1, 0 } }, get_extmarks(ns, { 0, 0 }, { -1, -1 }))
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    eq({}, get_extmarks(ns, { 0, 0 }, { -1, -1 }))
    set_extmark(ns, 1, 0, 0, { right_gravity = false })
    set_extmark(ns, 2, 1, 0, { right_gravity = false })
    eq({ { 1, 0, 0 }, { 2, 1, 0 } }, get_extmarks(ns, { 0, 0 }, { -1, -1 }))
    feed('u')
    eq({ { 1, 0, 0 }, { 2, 1, 0 } }, get_extmarks(ns, { 0, 0 }, { -1, -1 }))
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
  end)

  it('querying for information and ranges', function()
    --marks = {1, 2, 3}
    --positions = {{0, 0,}, {0, 2}, {0, 3}}
    -- add some more marks
    for i, m in ipairs(marks) do
      if positions[i] ~= nil then
        local rv = set_extmark(ns, m, positions[i][1], positions[i][2])
        eq(m, rv)
      end
    end

    -- {0, 0} and {-1, -1} work as extreme values
    eq({ { 1, 0, 0 } }, get_extmarks(ns, { 0, 0 }, { 0, 0 }))
    eq({}, get_extmarks(ns, { -1, -1 }, { -1, -1 }))
    local rv = get_extmarks(ns, { 0, 0 }, { -1, -1 })
    for i, m in ipairs(marks) do
      if positions[i] ~= nil then
        eq({ m, positions[i][1], positions[i][2] }, rv[i])
      end
    end

    -- 0 and -1 works as short hand extreme values
    eq({ { 1, 0, 0 } }, get_extmarks(ns, 0, 0))
    eq({}, get_extmarks(ns, -1, -1))
    rv = get_extmarks(ns, 0, -1)
    for i, m in ipairs(marks) do
      if positions[i] ~= nil then
        eq({ m, positions[i][1], positions[i][2] }, rv[i])
      end
    end

    -- next with mark id
    rv = get_extmarks(ns, marks[1], { -1, -1 }, { limit = 1 })
    eq({ { marks[1], positions[1][1], positions[1][2] } }, rv)
    rv = get_extmarks(ns, marks[2], { -1, -1 }, { limit = 1 })
    eq({ { marks[2], positions[2][1], positions[2][2] } }, rv)
    -- next with positional when mark exists at position
    rv = get_extmarks(ns, positions[1], { -1, -1 }, { limit = 1 })
    eq({ { marks[1], positions[1][1], positions[1][2] } }, rv)
    -- next with positional index (no mark at position)
    rv = get_extmarks(ns, { positions[1][1], positions[1][2] + 1 }, { -1, -1 }, { limit = 1 })
    eq({ { marks[2], positions[2][1], positions[2][2] } }, rv)
    -- next with Extremity index
    rv = get_extmarks(ns, { 0, 0 }, { -1, -1 }, { limit = 1 })
    eq({ { marks[1], positions[1][1], positions[1][2] } }, rv)

    -- nextrange with mark id
    rv = get_extmarks(ns, marks[1], marks[3])
    eq({ marks[1], positions[1][1], positions[1][2] }, rv[1])
    eq({ marks[2], positions[2][1], positions[2][2] }, rv[2])
    -- nextrange with `limit`
    rv = get_extmarks(ns, marks[1], marks[3], { limit = 2 })
    eq(2, #rv)
    -- nextrange with positional when mark exists at position
    rv = get_extmarks(ns, positions[1], positions[3])
    eq({ marks[1], positions[1][1], positions[1][2] }, rv[1])
    eq({ marks[2], positions[2][1], positions[2][2] }, rv[2])
    rv = get_extmarks(ns, positions[2], positions[3])
    eq(2, #rv)
    -- nextrange with positional index (no mark at position)
    local lower = { positions[1][1], positions[2][2] - 1 }
    local upper = { positions[2][1], positions[3][2] - 1 }
    rv = get_extmarks(ns, lower, upper)
    eq({ { marks[2], positions[2][1], positions[2][2] } }, rv)
    lower = { positions[3][1], positions[3][2] + 1 }
    upper = { positions[3][1], positions[3][2] + 2 }
    rv = get_extmarks(ns, lower, upper)
    eq({}, rv)
    -- nextrange with extremity index
    lower = { positions[2][1], positions[2][2] + 1 }
    upper = { -1, -1 }
    rv = get_extmarks(ns, lower, upper)
    eq({ { marks[3], positions[3][1], positions[3][2] } }, rv)

    -- prev with mark id
    rv = get_extmarks(ns, marks[3], { 0, 0 }, { limit = 1 })
    eq({ { marks[3], positions[3][1], positions[3][2] } }, rv)
    rv = get_extmarks(ns, marks[2], { 0, 0 }, { limit = 1 })
    eq({ { marks[2], positions[2][1], positions[2][2] } }, rv)
    -- prev with positional when mark exists at position
    rv = get_extmarks(ns, positions[3], { 0, 0 }, { limit = 1 })
    eq({ { marks[3], positions[3][1], positions[3][2] } }, rv)
    -- prev with positional index (no mark at position)
    rv = get_extmarks(ns, { positions[1][1], positions[1][2] + 1 }, { 0, 0 }, { limit = 1 })
    eq({ { marks[1], positions[1][1], positions[1][2] } }, rv)
    -- prev with Extremity index
    rv = get_extmarks(ns, { -1, -1 }, { 0, 0 }, { limit = 1 })
    eq({ { marks[3], positions[3][1], positions[3][2] } }, rv)

    -- prevrange with mark id
    rv = get_extmarks(ns, marks[3], marks[1])
    eq({ marks[3], positions[3][1], positions[3][2] }, rv[1])
    eq({ marks[2], positions[2][1], positions[2][2] }, rv[2])
    eq({ marks[1], positions[1][1], positions[1][2] }, rv[3])
    -- prevrange with limit
    rv = get_extmarks(ns, marks[3], marks[1], { limit = 2 })
    eq(2, #rv)
    -- prevrange with positional when mark exists at position
    rv = get_extmarks(ns, positions[3], positions[1])
    eq({
      { marks[3], positions[3][1], positions[3][2] },
      { marks[2], positions[2][1], positions[2][2] },
      { marks[1], positions[1][1], positions[1][2] },
    }, rv)
    rv = get_extmarks(ns, positions[2], positions[1])
    eq(2, #rv)
    -- prevrange with positional index (no mark at position)
    lower = { positions[2][1], positions[2][2] + 1 }
    upper = { positions[3][1], positions[3][2] + 1 }
    rv = get_extmarks(ns, upper, lower)
    eq({ { marks[3], positions[3][1], positions[3][2] } }, rv)
    lower = { positions[3][1], positions[3][2] + 1 }
    upper = { positions[3][1], positions[3][2] + 2 }
    rv = get_extmarks(ns, upper, lower)
    eq({}, rv)
    -- prevrange with extremity index
    lower = { 0, 0 }
    upper = { positions[2][1], positions[2][2] - 1 }
    rv = get_extmarks(ns, upper, lower)
    eq({ { marks[1], positions[1][1], positions[1][2] } }, rv)
  end)

  it('querying for information with limit', function()
    -- add some more marks
    for i, m in ipairs(marks) do
      if positions[i] ~= nil then
        local rv = set_extmark(ns, m, positions[i][1], positions[i][2])
        eq(m, rv)
      end
    end

    local rv = get_extmarks(ns, { 0, 0 }, { -1, -1 }, { limit = 1 })
    eq(1, #rv)
    rv = get_extmarks(ns, { 0, 0 }, { -1, -1 }, { limit = 2 })
    eq(2, #rv)
    rv = get_extmarks(ns, { 0, 0 }, { -1, -1 }, { limit = 3 })
    eq(3, #rv)

    -- now in reverse
    rv = get_extmarks(ns, { 0, 0 }, { -1, -1 }, { limit = 1 })
    eq(1, #rv)
    rv = get_extmarks(ns, { 0, 0 }, { -1, -1 }, { limit = 2 })
    eq(2, #rv)
    rv = get_extmarks(ns, { 0, 0 }, { -1, -1 }, { limit = 3 })
    eq(3, #rv)
  end)

  it('get_marks works when mark col > upper col', function()
    feed('A<cr>12345<esc>')
    feed('A<cr>12345<esc>')
    set_extmark(ns, 10, 0, 2) -- this shouldn't be found
    set_extmark(ns, 11, 2, 1) -- this shouldn't be found
    set_extmark(ns, marks[1], 0, 4) -- check col > our upper bound
    set_extmark(ns, marks[2], 1, 1) -- check col < lower bound
    set_extmark(ns, marks[3], 2, 0) -- check is inclusive
    eq(
      { { marks[1], 0, 4 }, { marks[2], 1, 1 }, { marks[3], 2, 0 } },
      get_extmarks(ns, { 0, 3 }, { 2, 0 })
    )
  end)

  it('get_marks works in reverse when mark col < lower col', function()
    feed('A<cr>12345<esc>')
    feed('A<cr>12345<esc>')
    set_extmark(ns, 10, 0, 1) -- this shouldn't be found
    set_extmark(ns, 11, 2, 4) -- this shouldn't be found
    set_extmark(ns, marks[1], 2, 1) -- check col < our lower bound
    set_extmark(ns, marks[2], 1, 4) -- check col > upper bound
    set_extmark(ns, marks[3], 0, 2) -- check is inclusive
    local rv = get_extmarks(ns, { 2, 3 }, { 0, 2 })
    eq({ { marks[1], 2, 1 }, { marks[2], 1, 4 }, { marks[3], 0, 2 } }, rv)
  end)

  it('get_marks limit=0 returns nothing', function()
    set_extmark(ns, marks[1], positions[1][1], positions[1][2])
    local rv = get_extmarks(ns, { -1, -1 }, { -1, -1 }, { limit = 0 })
    eq({}, rv)
  end)

  it('marks move with line insertations', function()
    set_extmark(ns, marks[1], 0, 0)
    feed('yyP')
    check_undo_redo(ns, marks[1], 0, 0, 1, 0)
  end)

  it('marks move with multiline insertations', function()
    feed('a<cr>22<cr>33<esc>')
    set_extmark(ns, marks[1], 1, 1)
    feed('ggVGyP')
    check_undo_redo(ns, marks[1], 1, 1, 4, 1)
  end)

  it('marks move with line join', function()
    -- do_join in ops.c
    feed('a<cr>222<esc>')
    set_extmark(ns, marks[1], 1, 0)
    feed('ggJ')
    check_undo_redo(ns, marks[1], 1, 0, 0, 6)
  end)

  it('join works when no marks are present', function()
    screen = Screen.new(15, 10)
    screen:attach()
    feed('a<cr>1<esc>')
    feed('kJ')
    -- This shouldn't seg fault
    screen:expect([[
      12345^ 1        |
      {1:~              }|*8
                     |
    ]])
  end)

  it('marks move with multiline join', function()
    -- do_join in ops.c
    feed('a<cr>222<cr>333<cr>444<esc>')
    set_extmark(ns, marks[1], 3, 0)
    feed('2GVGJ')
    check_undo_redo(ns, marks[1], 3, 0, 1, 8)
  end)

  it('marks move with line deletes', function()
    feed('a<cr>222<cr>333<cr>444<esc>')
    set_extmark(ns, marks[1], 2, 1)
    feed('ggjdd')
    check_undo_redo(ns, marks[1], 2, 1, 1, 1)
  end)

  it('marks move with multiline deletes', function()
    feed('a<cr>222<cr>333<cr>444<esc>')
    set_extmark(ns, marks[1], 3, 0)
    feed('gg2dd')
    check_undo_redo(ns, marks[1], 3, 0, 1, 0)
    -- regression test, undoing multiline delete when mark is on row 1
    feed('ugg3dd')
    check_undo_redo(ns, marks[1], 3, 0, 0, 0)
  end)

  it('marks move with open line', function()
    -- open_line in change.c
    -- testing marks below are also moved
    feed('yyP')
    set_extmark(ns, marks[1], 0, 4)
    set_extmark(ns, marks[2], 1, 4)
    feed('1G<s-o><esc>')
    check_undo_redo(ns, marks[1], 0, 4, 1, 4)
    check_undo_redo(ns, marks[2], 1, 4, 2, 4)
    feed('2Go<esc>')
    check_undo_redo(ns, marks[1], 1, 4, 1, 4)
    check_undo_redo(ns, marks[2], 2, 4, 3, 4)
  end)

  it('marks move with char inserts', function()
    -- insertchar in edit.c (the ins_str branch)
    screen = Screen.new(15, 10)
    screen:attach()
    set_extmark(ns, marks[1], 0, 3)
    feed('0')
    insert('abc')
    screen:expect([[
      ab^c12345       |
      {1:~              }|*8
                     |
    ]])
    local rv = get_extmark_by_id(ns, marks[1])
    eq({ 0, 6 }, rv)
    check_undo_redo(ns, marks[1], 0, 3, 0, 6)
  end)

  -- gravity right as definted in tk library
  it('marks have gravity right', function()
    -- insertchar in edit.c (the ins_str branch)
    set_extmark(ns, marks[1], 0, 2)
    feed('03l')
    insert('X')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)

    -- check multibyte chars
    feed('03l<esc>')
    insert('～～')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
  end)

  it('we can insert multibyte chars', function()
    -- insertchar in edit.c
    feed('a<cr>12345<esc>')
    set_extmark(ns, marks[1], 1, 2)
    -- Insert a fullwidth (two col) tilde, NICE
    feed('0i～<esc>')
    check_undo_redo(ns, marks[1], 1, 2, 1, 5)
  end)

  it('marks move with blockwise inserts', function()
    -- op_insert in ops.c
    feed('a<cr>12345<esc>')
    set_extmark(ns, marks[1], 1, 2)
    feed('0<c-v>lkI9<esc>')
    check_undo_redo(ns, marks[1], 1, 2, 1, 3)
  end)

  it('marks move with line splits (using enter)', function()
    -- open_line in change.c
    -- testing marks below are also moved
    feed('yyP')
    set_extmark(ns, marks[1], 0, 4)
    set_extmark(ns, marks[2], 1, 4)
    feed('1Gla<cr><esc>')
    check_undo_redo(ns, marks[1], 0, 4, 1, 2)
    check_undo_redo(ns, marks[2], 1, 4, 2, 4)
  end)

  it('marks at last line move on insert new line', function()
    -- open_line in change.c
    set_extmark(ns, marks[1], 0, 4)
    feed('0i<cr><esc>')
    check_undo_redo(ns, marks[1], 0, 4, 1, 4)
  end)

  it('yet again marks move with line splits', function()
    -- the first test above wasn't catching all errors..
    feed('A67890<esc>')
    set_extmark(ns, marks[1], 0, 4)
    feed('04li<cr><esc>')
    check_undo_redo(ns, marks[1], 0, 4, 1, 0)
  end)

  it('and one last time line splits...', function()
    set_extmark(ns, marks[1], 0, 1)
    set_extmark(ns, marks[2], 0, 2)
    feed('02li<cr><esc>')
    check_undo_redo(ns, marks[1], 0, 1, 0, 1)
    check_undo_redo(ns, marks[2], 0, 2, 1, 0)
  end)

  it('multiple marks move with mark splits', function()
    set_extmark(ns, marks[1], 0, 1)
    set_extmark(ns, marks[2], 0, 3)
    feed('0li<cr><esc>')
    check_undo_redo(ns, marks[1], 0, 1, 1, 0)
    check_undo_redo(ns, marks[2], 0, 3, 1, 2)
  end)

  it('deleting right before a mark works', function()
    -- op_delete in ops.c
    set_extmark(ns, marks[1], 0, 2)
    feed('0lx')
    check_undo_redo(ns, marks[1], 0, 2, 0, 1)
  end)

  it('deleting right after a mark works', function()
    -- op_delete in ops.c
    set_extmark(ns, marks[1], 0, 2)
    feed('02lx')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
  end)

  it('marks move with char deletes', function()
    -- op_delete in ops.c
    set_extmark(ns, marks[1], 0, 2)
    feed('02dl')
    check_undo_redo(ns, marks[1], 0, 2, 0, 0)
    -- from the other side (nothing should happen)
    feed('$x')
    check_undo_redo(ns, marks[1], 0, 0, 0, 0)
  end)

  it('marks move with char deletes over a range', function()
    -- op_delete in ops.c
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    feed('0l3dl<esc>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 1)
    check_undo_redo(ns, marks[2], 0, 3, 0, 1)
    -- delete 1, nothing should happen to our marks
    feed('u')
    feed('$x')
    check_undo_redo(ns, marks[2], 0, 3, 0, 3)
  end)

  it('deleting marks at end of line works', function()
    set_extmark(ns, marks[1], 0, 4)
    feed('$x')
    check_undo_redo(ns, marks[1], 0, 4, 0, 4)
    -- check the copy happened correctly on delete at eol
    feed('$x')
    check_undo_redo(ns, marks[1], 0, 4, 0, 3)
    feed('u')
    check_undo_redo(ns, marks[1], 0, 4, 0, 4)
  end)

  it('marks move with blockwise deletes', function()
    -- op_delete in ops.c
    feed('a<cr>12345<esc>')
    set_extmark(ns, marks[1], 1, 4)
    feed('h<c-v>hhkd')
    check_undo_redo(ns, marks[1], 1, 4, 1, 1)
  end)

  it('marks move with blockwise deletes over a range', function()
    -- op_delete in ops.c
    feed('a<cr>12345<esc>')
    set_extmark(ns, marks[1], 0, 1)
    set_extmark(ns, marks[2], 0, 3)
    set_extmark(ns, marks[3], 1, 2)
    feed('0<c-v>k3lx')
    check_undo_redo(ns, marks[1], 0, 1, 0, 0)
    check_undo_redo(ns, marks[2], 0, 3, 0, 0)
    check_undo_redo(ns, marks[3], 1, 2, 1, 0)
    -- delete 1, nothing should happen to our marks
    feed('u')
    feed('$<c-v>jx')
    check_undo_redo(ns, marks[2], 0, 3, 0, 3)
    check_undo_redo(ns, marks[3], 1, 2, 1, 2)
  end)

  it('works with char deletes over multilines', function()
    feed('a<cr>12345<cr>test-me<esc>')
    set_extmark(ns, marks[1], 2, 5)
    feed('gg')
    feed('dv?-m?<cr>')
    check_undo_redo(ns, marks[1], 2, 5, 0, 0)
  end)

  it('marks outside of deleted range move with visual char deletes', function()
    -- op_delete in ops.c
    set_extmark(ns, marks[1], 0, 3)
    feed('0vx<esc>')
    check_undo_redo(ns, marks[1], 0, 3, 0, 2)

    feed('u')
    feed('0vlx<esc>')
    check_undo_redo(ns, marks[1], 0, 3, 0, 1)

    feed('u')
    feed('0v2lx<esc>')
    check_undo_redo(ns, marks[1], 0, 3, 0, 0)

    -- from the other side (nothing should happen)
    feed('$vx')
    check_undo_redo(ns, marks[1], 0, 0, 0, 0)
  end)

  it('marks outside of deleted range move with char deletes', function()
    -- op_delete in ops.c
    set_extmark(ns, marks[1], 0, 3)
    feed('0x<esc>')
    check_undo_redo(ns, marks[1], 0, 3, 0, 2)

    feed('u')
    feed('02x<esc>')
    check_undo_redo(ns, marks[1], 0, 3, 0, 1)

    feed('u')
    feed('0v3lx<esc>')
    check_undo_redo(ns, marks[1], 0, 3, 0, 0)

    -- from the other side (nothing should happen)
    feed('u')
    feed('$vx')
    check_undo_redo(ns, marks[1], 0, 3, 0, 3)
  end)

  it('marks move with P(backward) paste', function()
    -- do_put in ops.c
    feed('0iabc<esc>')
    set_extmark(ns, marks[1], 0, 7)
    feed('0veyP')
    check_undo_redo(ns, marks[1], 0, 7, 0, 15)
  end)

  it('marks move with p(forward) paste', function()
    -- do_put in ops.c
    feed('0iabc<esc>')
    set_extmark(ns, marks[1], 0, 7)
    feed('0veyp')
    check_undo_redo(ns, marks[1], 0, 7, 0, 15)
  end)

  it('marks move with blockwise P(backward) paste', function()
    -- do_put in ops.c
    feed('a<cr>12345<esc>')
    set_extmark(ns, marks[1], 1, 4)
    feed('<c-v>hhkyP<esc>')
    check_undo_redo(ns, marks[1], 1, 4, 1, 7)
  end)

  it('marks move with blockwise p(forward) paste', function()
    -- do_put in ops.c
    feed('a<cr>12345<esc>')
    set_extmark(ns, marks[1], 1, 4)
    feed('<c-v>hhkyp<esc>')
    check_undo_redo(ns, marks[1], 1, 4, 1, 7)
  end)

  describe('multiline regions', function()
    before_each(function()
      feed('dd')
      -- Achtung: code has been spiced with some unicode,
      -- to make life more interesting.
      -- luacheck whines about TABs inside strings for whatever reason.
      -- luacheck: push ignore 621
      insert([[
        static int nlua_rpcrequest(lua_State *lstate)
        {
          Ïf (!nlua_is_deferred_safe(lstate)) {
        	// strictly not allowed
            Яetörn luaL_error(lstate, e_luv_api_disabled, "rpcrequest");
          }
          return nlua_rpc(lstate, true);
        }]])
      -- luacheck: pop
    end)

    it('delete', function()
      local pos1 = {
        { 2, 4 },
        { 2, 12 },
        { 2, 13 },
        { 2, 14 },
        { 2, 25 },
        { 4, 8 },
        { 4, 10 },
        { 4, 20 },
        { 5, 3 },
        { 6, 10 },
      }
      local ids = batch_set(ns, pos1)
      batch_check(ns, ids, pos1)
      feed('3Gfiv2+ftd')
      batch_check_undo_redo(ns, ids, pos1, {
        { 2, 4 },
        { 2, 12 },
        { 2, 13 },
        { 2, 13 },
        { 2, 13 },
        { 2, 13 },
        { 2, 15 },
        { 2, 25 },
        { 3, 3 },
        { 4, 10 },
      })
    end)

    it('can get overlapping extmarks', function()
      set_extmark(ns, 1, 0, 0, { end_row = 5, end_col = 0 })
      set_extmark(ns, 2, 2, 5, { end_row = 2, end_col = 30 })
      set_extmark(ns, 3, 0, 5, { end_row = 2, end_col = 10 })
      set_extmark(ns, 4, 0, 0, { end_row = 1, end_col = 0 })
      eq({ { 2, 2, 5 } }, get_extmarks(ns, { 2, 0 }, { 2, -1 }, { overlap = false }))
      eq(
        { { 1, 0, 0 }, { 3, 0, 5 }, { 2, 2, 5 } },
        get_extmarks(ns, { 2, 0 }, { 2, -1 }, { overlap = true })
      )
    end)
  end)

  it('replace works', function()
    set_extmark(ns, marks[1], 0, 2)
    feed('0r2')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
  end)

  it('blockwise replace works', function()
    feed('a<cr>12345<esc>')
    set_extmark(ns, marks[1], 0, 2)
    feed('0<c-v>llkr1<esc>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 3)
  end)

  it('shift line', function()
    -- shift_line in ops.c
    feed(':set shiftwidth=4<cr><esc>')
    set_extmark(ns, marks[1], 0, 2)
    feed('0>>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 6)
    expect('    12345')

    feed('>>')
    -- this is counter-intuitive. But what happens
    -- is that 4 spaces gets extended to one tab (== 8 spaces)
    check_undo_redo(ns, marks[1], 0, 6, 0, 3)
    expect('\t12345')

    feed('<LT><LT>') -- have to escape, same as <<
    check_undo_redo(ns, marks[1], 0, 3, 0, 6)
  end)

  it('blockwise shift', function()
    -- shift_block in ops.c
    feed(':set shiftwidth=4<cr><esc>')
    feed('a<cr>12345<esc>')
    set_extmark(ns, marks[1], 1, 2)
    feed('0<c-v>k>')
    check_undo_redo(ns, marks[1], 1, 2, 1, 6)
    feed('<c-v>j>')
    expect('\t12345\n\t12345')
    check_undo_redo(ns, marks[1], 1, 6, 1, 3)

    feed('<c-v>j<LT>')
    check_undo_redo(ns, marks[1], 1, 3, 1, 6)
  end)

  it('tab works with expandtab', function()
    -- ins_tab in edit.c
    feed(':set expandtab<cr><esc>')
    feed(':set shiftwidth=2<cr><esc>')
    set_extmark(ns, marks[1], 0, 2)
    feed('0i<tab><tab><esc>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 6)
  end)

  it('tabs work', function()
    -- ins_tab in edit.c
    feed(':set noexpandtab<cr><esc>')
    feed(':set shiftwidth=2<cr><esc>')
    feed(':set softtabstop=2<cr><esc>')
    feed(':set tabstop=8<cr><esc>')
    set_extmark(ns, marks[1], 0, 2)
    feed('0i<tab><esc>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 4)
    feed('0iX<tab><esc>')
    check_undo_redo(ns, marks[1], 0, 4, 0, 6)
  end)

  it('marks move when using :move', function()
    set_extmark(ns, marks[1], 0, 0)
    feed('A<cr>2<esc>:1move 2<cr><esc>')
    check_undo_redo(ns, marks[1], 0, 0, 1, 0)
    -- test codepath when moving lines up
    feed(':2move 0<cr><esc>')
    check_undo_redo(ns, marks[1], 1, 0, 0, 0)
  end)

  it('marks move when using :move part 2', function()
    -- make sure we didn't get lucky with the math...
    feed('A<cr>2<cr>3<cr>4<cr>5<cr>6<esc>')
    set_extmark(ns, marks[1], 1, 0)
    feed(':2,3move 5<cr><esc>')
    check_undo_redo(ns, marks[1], 1, 0, 3, 0)
    -- test codepath when moving lines up
    feed(':4,5move 1<cr><esc>')
    check_undo_redo(ns, marks[1], 3, 0, 1, 0)
  end)

  it('undo and redo of set and unset marks', function()
    -- Force a new undo head
    feed('o<esc>')
    set_extmark(ns, marks[1], 0, 1)
    feed('o<esc>')
    set_extmark(ns, marks[2], 0, -1)
    set_extmark(ns, marks[3], 0, -1)

    feed('u')
    local rv = get_extmarks(ns, { 0, 0 }, { -1, -1 })
    eq(3, #rv)

    feed('<c-r>')
    rv = get_extmarks(ns, { 0, 0 }, { -1, -1 })
    eq(3, #rv)

    -- Test updates
    feed('o<esc>')
    set_extmark(ns, marks[1], positions[1][1], positions[1][2])
    rv = get_extmarks(ns, marks[1], marks[1], { limit = 1 })
    eq(1, #rv)
    feed('u')
    feed('<c-r>')
    -- old value is NOT kept in history
    check_undo_redo(
      ns,
      marks[1],
      positions[1][1],
      positions[1][2],
      positions[1][1],
      positions[1][2]
    )

    -- Test unset
    feed('o<esc>')
    api.nvim_buf_del_extmark(0, ns, marks[3])
    feed('u')
    rv = get_extmarks(ns, { 0, 0 }, { -1, -1 })
    -- undo does NOT restore deleted marks
    eq(2, #rv)
    feed('<c-r>')
    rv = get_extmarks(ns, { 0, 0 }, { -1, -1 })
    eq(2, #rv)
  end)

  it('undo and redo of marks deleted during edits', function()
    -- test extmark_adjust
    feed('A<cr>12345<esc>')
    set_extmark(ns, marks[1], 1, 2)
    feed('dd')
    check_undo_redo(ns, marks[1], 1, 2, 1, 0)
  end)

  it('namespaces work properly', function()
    local rv = set_extmark(ns, marks[1], positions[1][1], positions[1][2])
    eq(1, rv)
    rv = set_extmark(ns2, marks[1], positions[1][1], positions[1][2])
    eq(1, rv)
    rv = get_extmarks(ns, { 0, 0 }, { -1, -1 })
    eq(1, #rv)
    rv = get_extmarks(ns2, { 0, 0 }, { -1, -1 })
    eq(1, #rv)

    -- Set more marks for testing the ranges
    set_extmark(ns, marks[2], positions[2][1], positions[2][2])
    set_extmark(ns, marks[3], positions[3][1], positions[3][2])
    set_extmark(ns2, marks[2], positions[2][1], positions[2][2])
    set_extmark(ns2, marks[3], positions[3][1], positions[3][2])

    -- get_next (limit set)
    rv = get_extmarks(ns, { 0, 0 }, positions[2], { limit = 1 })
    eq(1, #rv)
    rv = get_extmarks(ns2, { 0, 0 }, positions[2], { limit = 1 })
    eq(1, #rv)
    -- get_prev (limit set)
    rv = get_extmarks(ns, positions[1], { 0, 0 }, { limit = 1 })
    eq(1, #rv)
    rv = get_extmarks(ns2, positions[1], { 0, 0 }, { limit = 1 })
    eq(1, #rv)

    -- get_next (no limit)
    rv = get_extmarks(ns, positions[1], positions[2])
    eq(2, #rv)
    rv = get_extmarks(ns2, positions[1], positions[2])
    eq(2, #rv)
    -- get_prev (no limit)
    rv = get_extmarks(ns, positions[2], positions[1])
    eq(2, #rv)
    rv = get_extmarks(ns2, positions[2], positions[1])
    eq(2, #rv)

    api.nvim_buf_del_extmark(0, ns, marks[1])
    rv = get_extmarks(ns, { 0, 0 }, { -1, -1 })
    eq(2, #rv)
    api.nvim_buf_del_extmark(0, ns2, marks[1])
    rv = get_extmarks(ns2, { 0, 0 }, { -1, -1 })
    eq(2, #rv)
  end)

  it('mark set can create unique identifiers', function()
    -- create mark with id 1
    eq(1, set_extmark(ns, 1, positions[1][1], positions[1][2]))
    -- ask for unique id, it should be the next one, i e 2
    eq(2, set_extmark(ns, 0, positions[1][1], positions[1][2]))
    eq(3, set_extmark(ns, 3, positions[2][1], positions[2][2]))
    eq(4, set_extmark(ns, 0, positions[1][1], positions[1][2]))

    -- mixing manual and allocated id:s are not recommended, but it should
    -- do something reasonable
    eq(6, set_extmark(ns, 6, positions[2][1], positions[2][2]))
    eq(7, set_extmark(ns, 0, positions[1][1], positions[1][2]))
    eq(8, set_extmark(ns, 0, positions[1][1], positions[1][2]))
  end)

  it('auto indenting with enter works', function()
    -- op_reindent in ops.c
    feed(':set cindent<cr><esc>')
    feed(':set autoindent<cr><esc>')
    feed(':set shiftwidth=2<cr><esc>')
    feed('0iint <esc>A {1M1<esc>b<esc>')
    -- Set the mark on the M, should move..
    set_extmark(ns, marks[1], 0, 12)
    -- Set the mark before the cursor, should stay there
    set_extmark(ns, marks[2], 0, 10)
    feed('i<cr><esc>')
    local rv = get_extmark_by_id(ns, marks[1])
    eq({ 1, 3 }, rv)
    rv = get_extmark_by_id(ns, marks[2])
    eq({ 0, 10 }, rv)
    check_undo_redo(ns, marks[1], 0, 12, 1, 3)
  end)

  it('auto indenting entire line works', function()
    feed(':set cindent<cr><esc>')
    feed(':set autoindent<cr><esc>')
    feed(':set shiftwidth=2<cr><esc>')
    -- <c-f> will force an indent of 2
    feed('0iint <esc>A {<cr><esc>0i1M1<esc>')
    set_extmark(ns, marks[1], 1, 1)
    feed('0i<c-f><esc>')
    local rv = get_extmark_by_id(ns, marks[1])
    eq({ 1, 3 }, rv)
    check_undo_redo(ns, marks[1], 1, 1, 1, 3)
    -- now check when cursor at eol
    feed('uA<c-f><esc>')
    rv = get_extmark_by_id(ns, marks[1])
    eq({ 1, 3 }, rv)
  end)

  it('removing auto indenting with <C-D> works', function()
    feed(':set cindent<cr><esc>')
    feed(':set autoindent<cr><esc>')
    feed(':set shiftwidth=2<cr><esc>')
    feed('0i<tab><esc>')
    set_extmark(ns, marks[1], 0, 3)
    feed('bi<c-d><esc>')
    local rv = get_extmark_by_id(ns, marks[1])
    eq({ 0, 1 }, rv)
    check_undo_redo(ns, marks[1], 0, 3, 0, 1)
    -- check when cursor at eol
    feed('uA<c-d><esc>')
    rv = get_extmark_by_id(ns, marks[1])
    eq({ 0, 1 }, rv)
  end)

  it('indenting multiple lines with = works', function()
    feed(':set cindent<cr><esc>')
    feed(':set autoindent<cr><esc>')
    feed(':set shiftwidth=2<cr><esc>')
    feed('0iint <esc>A {<cr><bs>1M1<cr><bs>2M2<esc>')
    set_extmark(ns, marks[1], 1, 1)
    set_extmark(ns, marks[2], 2, 1)
    feed('=gg')
    check_undo_redo(ns, marks[1], 1, 1, 1, 3)
    check_undo_redo(ns, marks[2], 2, 1, 2, 5)
  end)

  it('substitutes by deleting inside the replace matches', function()
    -- do_sub in ex_cmds.c
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    feed(':s/34/xx<cr>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 4)
    check_undo_redo(ns, marks[2], 0, 3, 0, 4)
  end)

  it('substitutes when insert text > deleted', function()
    -- do_sub in ex_cmds.c
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    feed(':s/34/xxx<cr>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 5)
    check_undo_redo(ns, marks[2], 0, 3, 0, 5)
  end)

  it('substitutes when marks around eol', function()
    -- do_sub in ex_cmds.c
    set_extmark(ns, marks[1], 0, 4)
    set_extmark(ns, marks[2], 0, 5)
    feed(':s/5/xxx<cr>')
    check_undo_redo(ns, marks[1], 0, 4, 0, 7)
    check_undo_redo(ns, marks[2], 0, 5, 0, 7)
  end)

  it('substitutes over range insert text > deleted', function()
    -- do_sub in ex_cmds.c
    feed('A<cr>x34xx<esc>')
    feed('A<cr>xxx34<esc>')
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 1, 1)
    set_extmark(ns, marks[3], 2, 4)
    feed(':1,3s/34/xxx<cr><esc>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 5)
    check_undo_redo(ns, marks[2], 1, 1, 1, 4)
    check_undo_redo(ns, marks[3], 2, 4, 2, 6)
  end)

  it('substitutes multiple matches in a line', function()
    -- do_sub in ex_cmds.c
    feed('ddi3x3x3<esc>')
    set_extmark(ns, marks[1], 0, 0)
    set_extmark(ns, marks[2], 0, 2)
    set_extmark(ns, marks[3], 0, 4)
    feed(':s/3/yy/g<cr><esc>')
    check_undo_redo(ns, marks[1], 0, 0, 0, 2)
    check_undo_redo(ns, marks[2], 0, 2, 0, 5)
    check_undo_redo(ns, marks[3], 0, 4, 0, 8)
  end)

  it('substitutes over multiple lines with newline in pattern', function()
    feed('A<cr>67890<cr>xx<esc>')
    set_extmark(ns, marks[1], 0, 3)
    set_extmark(ns, marks[2], 0, 4)
    set_extmark(ns, marks[3], 1, 0)
    set_extmark(ns, marks[4], 1, 5)
    set_extmark(ns, marks[5], 2, 0)
    feed([[:1,2s:5\n:5 <cr>]])
    check_undo_redo(ns, marks[1], 0, 3, 0, 3)
    check_undo_redo(ns, marks[2], 0, 4, 0, 6)
    check_undo_redo(ns, marks[3], 1, 0, 0, 6)
    check_undo_redo(ns, marks[4], 1, 5, 0, 11)
    check_undo_redo(ns, marks[5], 2, 0, 1, 0)
  end)

  it('inserting', function()
    feed('A<cr>67890<cr>xx<esc>')
    set_extmark(ns, marks[1], 0, 3)
    set_extmark(ns, marks[2], 0, 4)
    set_extmark(ns, marks[3], 1, 0)
    set_extmark(ns, marks[4], 1, 5)
    set_extmark(ns, marks[5], 2, 0)
    set_extmark(ns, marks[6], 1, 2)
    feed([[:1,2s:5\n67:X<cr>]])
    check_undo_redo(ns, marks[1], 0, 3, 0, 3)
    check_undo_redo(ns, marks[2], 0, 4, 0, 5)
    check_undo_redo(ns, marks[3], 1, 0, 0, 5)
    check_undo_redo(ns, marks[4], 1, 5, 0, 8)
    check_undo_redo(ns, marks[5], 2, 0, 1, 0)
    check_undo_redo(ns, marks[6], 1, 2, 0, 5)
  end)

  it('substitutes with multiple newlines in pattern', function()
    feed('A<cr>67890<cr>xx<esc>')
    set_extmark(ns, marks[1], 0, 4)
    set_extmark(ns, marks[2], 0, 5)
    set_extmark(ns, marks[3], 1, 0)
    set_extmark(ns, marks[4], 1, 5)
    set_extmark(ns, marks[5], 2, 0)
    feed([[:1,2s:\n.*\n:X<cr>]])
    check_undo_redo(ns, marks[1], 0, 4, 0, 4)
    check_undo_redo(ns, marks[2], 0, 5, 0, 6)
    check_undo_redo(ns, marks[3], 1, 0, 0, 6)
    check_undo_redo(ns, marks[4], 1, 5, 0, 6)
    check_undo_redo(ns, marks[5], 2, 0, 0, 6)
  end)

  it('substitutes over multiple lines with replace in substitution', function()
    feed('A<cr>67890<cr>xx<esc>')
    set_extmark(ns, marks[1], 0, 1)
    set_extmark(ns, marks[2], 0, 2)
    set_extmark(ns, marks[3], 0, 4)
    set_extmark(ns, marks[4], 1, 0)
    set_extmark(ns, marks[5], 2, 0)
    feed([[:1,2s:3:\r<cr>]])
    check_undo_redo(ns, marks[1], 0, 1, 0, 1)
    check_undo_redo(ns, marks[2], 0, 2, 1, 0)
    check_undo_redo(ns, marks[3], 0, 4, 1, 1)
    check_undo_redo(ns, marks[4], 1, 0, 2, 0)
    check_undo_redo(ns, marks[5], 2, 0, 3, 0)
    feed('u')
    feed([[:1,2s:3:\rxx<cr>]])
    eq({ 1, 3 }, get_extmark_by_id(ns, marks[3]))
  end)

  it('substitutes over multiple lines with replace in substitution', function()
    feed('A<cr>x3<cr>xx<esc>')
    set_extmark(ns, marks[1], 1, 0)
    set_extmark(ns, marks[2], 1, 1)
    set_extmark(ns, marks[3], 1, 2)
    feed([[:2,2s:3:\r<cr>]])
    check_undo_redo(ns, marks[1], 1, 0, 1, 0)
    check_undo_redo(ns, marks[2], 1, 1, 2, 0)
    check_undo_redo(ns, marks[3], 1, 2, 2, 0)
  end)

  it('substitutes over multiple lines with replace in substitution', function()
    feed('A<cr>x3<cr>xx<esc>')
    set_extmark(ns, marks[1], 0, 1)
    set_extmark(ns, marks[2], 0, 2)
    set_extmark(ns, marks[3], 0, 4)
    set_extmark(ns, marks[4], 1, 1)
    set_extmark(ns, marks[5], 2, 0)
    feed([[:1,2s:3:\r<cr>]])
    check_undo_redo(ns, marks[1], 0, 1, 0, 1)
    check_undo_redo(ns, marks[2], 0, 2, 1, 0)
    check_undo_redo(ns, marks[3], 0, 4, 1, 1)
    check_undo_redo(ns, marks[4], 1, 1, 3, 0)
    check_undo_redo(ns, marks[5], 2, 0, 4, 0)
    feed('u')
    feed([[:1,2s:3:\rxx<cr>]])
    check_undo_redo(ns, marks[3], 0, 4, 1, 3)
  end)

  it('substitutes with newline in match and sub, delta is 0', function()
    feed('A<cr>67890<cr>xx<esc>')
    set_extmark(ns, marks[1], 0, 3)
    set_extmark(ns, marks[2], 0, 4)
    set_extmark(ns, marks[3], 0, 5)
    set_extmark(ns, marks[4], 1, 0)
    set_extmark(ns, marks[5], 1, 5)
    set_extmark(ns, marks[6], 2, 0)
    feed([[:1,1s:5\n:\r<cr>]])
    check_undo_redo(ns, marks[1], 0, 3, 0, 3)
    check_undo_redo(ns, marks[2], 0, 4, 1, 0)
    check_undo_redo(ns, marks[3], 0, 5, 1, 0)
    check_undo_redo(ns, marks[4], 1, 0, 1, 0)
    check_undo_redo(ns, marks[5], 1, 5, 1, 5)
    check_undo_redo(ns, marks[6], 2, 0, 2, 0)
  end)

  it('substitutes with newline in match and sub, delta > 0', function()
    feed('A<cr>67890<cr>xx<esc>')
    set_extmark(ns, marks[1], 0, 3)
    set_extmark(ns, marks[2], 0, 4)
    set_extmark(ns, marks[3], 0, 5)
    set_extmark(ns, marks[4], 1, 0)
    set_extmark(ns, marks[5], 1, 5)
    set_extmark(ns, marks[6], 2, 0)
    feed([[:1,1s:5\n:\r\r<cr>]])
    check_undo_redo(ns, marks[1], 0, 3, 0, 3)
    check_undo_redo(ns, marks[2], 0, 4, 2, 0)
    check_undo_redo(ns, marks[3], 0, 5, 2, 0)
    check_undo_redo(ns, marks[4], 1, 0, 2, 0)
    check_undo_redo(ns, marks[5], 1, 5, 2, 5)
    check_undo_redo(ns, marks[6], 2, 0, 3, 0)
  end)

  it('substitutes with newline in match and sub, delta < 0', function()
    feed('A<cr>67890<cr>xx<cr>xx<esc>')
    set_extmark(ns, marks[1], 0, 3)
    set_extmark(ns, marks[2], 0, 4)
    set_extmark(ns, marks[3], 0, 5)
    set_extmark(ns, marks[4], 1, 0)
    set_extmark(ns, marks[5], 1, 5)
    set_extmark(ns, marks[6], 2, 1)
    set_extmark(ns, marks[7], 3, 0)
    feed([[:1,2s:5\n.*\n:\r<cr>]])
    check_undo_redo(ns, marks[1], 0, 3, 0, 3)
    check_undo_redo(ns, marks[2], 0, 4, 1, 0)
    check_undo_redo(ns, marks[3], 0, 5, 1, 0)
    check_undo_redo(ns, marks[4], 1, 0, 1, 0)
    check_undo_redo(ns, marks[5], 1, 5, 1, 0)
    check_undo_redo(ns, marks[6], 2, 1, 1, 1)
    check_undo_redo(ns, marks[7], 3, 0, 2, 0)
  end)

  it('substitutes with backrefs, newline inserted into sub', function()
    feed('A<cr>67890<cr>xx<cr>xx<esc>')
    set_extmark(ns, marks[1], 0, 3)
    set_extmark(ns, marks[2], 0, 4)
    set_extmark(ns, marks[3], 0, 5)
    set_extmark(ns, marks[4], 1, 0)
    set_extmark(ns, marks[5], 1, 5)
    set_extmark(ns, marks[6], 2, 0)
    feed([[:1,1s:5\(\n\):\0\1<cr>]])
    check_undo_redo(ns, marks[1], 0, 3, 0, 3)
    check_undo_redo(ns, marks[2], 0, 4, 2, 0)
    check_undo_redo(ns, marks[3], 0, 5, 2, 0)
    check_undo_redo(ns, marks[4], 1, 0, 2, 0)
    check_undo_redo(ns, marks[5], 1, 5, 2, 5)
    check_undo_redo(ns, marks[6], 2, 0, 3, 0)
  end)

  it('substitutes a ^', function()
    set_extmark(ns, marks[1], 0, 0)
    set_extmark(ns, marks[2], 0, 1)
    feed([[:s:^:x<cr>]])
    check_undo_redo(ns, marks[1], 0, 0, 0, 1)
    check_undo_redo(ns, marks[2], 0, 1, 0, 2)
  end)

  it('using <c-a> without increase in order of magnitude', function()
    -- do_addsub in ops.c
    feed('ddiabc998xxx<esc>Tc')
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    set_extmark(ns, marks[3], 0, 5)
    set_extmark(ns, marks[4], 0, 6)
    set_extmark(ns, marks[5], 0, 7)
    feed('<c-a>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
    check_undo_redo(ns, marks[2], 0, 3, 0, 6)
    check_undo_redo(ns, marks[3], 0, 5, 0, 6)
    check_undo_redo(ns, marks[4], 0, 6, 0, 6)
    check_undo_redo(ns, marks[5], 0, 7, 0, 7)
  end)

  it('using <c-a> when increase in order of magnitude', function()
    -- do_addsub in ops.c
    feed('ddiabc999xxx<esc>Tc')
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    set_extmark(ns, marks[3], 0, 5)
    set_extmark(ns, marks[4], 0, 6)
    set_extmark(ns, marks[5], 0, 7)
    feed('<c-a>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
    check_undo_redo(ns, marks[2], 0, 3, 0, 7)
    check_undo_redo(ns, marks[3], 0, 5, 0, 7)
    check_undo_redo(ns, marks[4], 0, 6, 0, 7)
    check_undo_redo(ns, marks[5], 0, 7, 0, 8)
  end)

  it('using <c-a> when negative and without decrease in order of magnitude', function()
    feed('ddiabc-999xxx<esc>T-')
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    set_extmark(ns, marks[3], 0, 6)
    set_extmark(ns, marks[4], 0, 7)
    set_extmark(ns, marks[5], 0, 8)
    feed('<c-a>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
    check_undo_redo(ns, marks[2], 0, 3, 0, 7)
    check_undo_redo(ns, marks[3], 0, 6, 0, 7)
    check_undo_redo(ns, marks[4], 0, 7, 0, 7)
    check_undo_redo(ns, marks[5], 0, 8, 0, 8)
  end)

  it('using <c-a> when negative and decrease in order of magnitude', function()
    feed('ddiabc-1000xxx<esc>T-')
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    set_extmark(ns, marks[3], 0, 7)
    set_extmark(ns, marks[4], 0, 8)
    set_extmark(ns, marks[5], 0, 9)
    feed('<c-a>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
    check_undo_redo(ns, marks[2], 0, 3, 0, 7)
    check_undo_redo(ns, marks[3], 0, 7, 0, 7)
    check_undo_redo(ns, marks[4], 0, 8, 0, 7)
    check_undo_redo(ns, marks[5], 0, 9, 0, 8)
  end)

  it('using <c-x> without decrease in order of magnitude', function()
    -- do_addsub in ops.c
    feed('ddiabc999xxx<esc>Tc')
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    set_extmark(ns, marks[3], 0, 5)
    set_extmark(ns, marks[4], 0, 6)
    set_extmark(ns, marks[5], 0, 7)
    feed('<c-x>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
    check_undo_redo(ns, marks[2], 0, 3, 0, 6)
    check_undo_redo(ns, marks[3], 0, 5, 0, 6)
    check_undo_redo(ns, marks[4], 0, 6, 0, 6)
    check_undo_redo(ns, marks[5], 0, 7, 0, 7)
  end)

  it('using <c-x> when decrease in order of magnitude', function()
    -- do_addsub in ops.c
    feed('ddiabc1000xxx<esc>Tc')
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    set_extmark(ns, marks[3], 0, 6)
    set_extmark(ns, marks[4], 0, 7)
    set_extmark(ns, marks[5], 0, 8)
    feed('<c-x>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
    check_undo_redo(ns, marks[2], 0, 3, 0, 6)
    check_undo_redo(ns, marks[3], 0, 6, 0, 6)
    check_undo_redo(ns, marks[4], 0, 7, 0, 6)
    check_undo_redo(ns, marks[5], 0, 8, 0, 7)
  end)

  it('using <c-x> when negative and without increase in order of magnitude', function()
    feed('ddiabc-998xxx<esc>T-')
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    set_extmark(ns, marks[3], 0, 6)
    set_extmark(ns, marks[4], 0, 7)
    set_extmark(ns, marks[5], 0, 8)
    feed('<c-x>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
    check_undo_redo(ns, marks[2], 0, 3, 0, 7)
    check_undo_redo(ns, marks[3], 0, 6, 0, 7)
    check_undo_redo(ns, marks[4], 0, 7, 0, 7)
    check_undo_redo(ns, marks[5], 0, 8, 0, 8)
  end)

  it('using <c-x> when negative and increase in order of magnitude', function()
    feed('ddiabc-999xxx<esc>T-')
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    set_extmark(ns, marks[3], 0, 6)
    set_extmark(ns, marks[4], 0, 7)
    set_extmark(ns, marks[5], 0, 8)
    feed('<c-x>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
    check_undo_redo(ns, marks[2], 0, 3, 0, 8)
    check_undo_redo(ns, marks[3], 0, 6, 0, 8)
    check_undo_redo(ns, marks[4], 0, 7, 0, 8)
    check_undo_redo(ns, marks[5], 0, 8, 0, 9)
  end)

  it('throws consistent error codes', function()
    local ns_invalid = ns2 + 1
    eq(
      "Invalid 'ns_id': 3",
      pcall_err(set_extmark, ns_invalid, marks[1], positions[1][1], positions[1][2])
    )
    eq("Invalid 'ns_id': 3", pcall_err(api.nvim_buf_del_extmark, 0, ns_invalid, marks[1]))
    eq("Invalid 'ns_id': 3", pcall_err(get_extmarks, ns_invalid, positions[1], positions[2]))
    eq("Invalid 'ns_id': 3", pcall_err(get_extmark_by_id, ns_invalid, marks[1]))
  end)

  it('when col = line-length, set the mark on eol', function()
    set_extmark(ns, marks[1], 0, -1)
    local rv = get_extmark_by_id(ns, marks[1])
    eq({ 0, init_text:len() }, rv)
    -- Test another
    set_extmark(ns, marks[1], 0, -1)
    rv = get_extmark_by_id(ns, marks[1])
    eq({ 0, init_text:len() }, rv)
  end)

  it('when col = line-length, set the mark on eol', function()
    local invalid_col = init_text:len() + 1
    eq("Invalid 'col': out of range", pcall_err(set_extmark, ns, marks[1], 0, invalid_col))
  end)

  it('fails when line > line_count', function()
    local invalid_col = init_text:len() + 1
    local invalid_lnum = 3
    eq(
      "Invalid 'line': out of range",
      pcall_err(set_extmark, ns, marks[1], invalid_lnum, invalid_col)
    )
    eq({}, get_extmark_by_id(ns, marks[1]))
  end)

  it('bug from check_col in extmark_set', function()
    -- This bug was caused by extmark_set always using check_col. check_col
    -- always uses the current buffer. This wasn't working during undo so we
    -- now use check_col and check_lnum only when they are required.
    feed('A<cr>67890<cr>xx<esc>')
    feed('A<cr>12345<cr>67890<cr>xx<esc>')
    set_extmark(ns, marks[1], 3, 4)
    feed([[:1,5s:5\n:5 <cr>]])
    check_undo_redo(ns, marks[1], 3, 4, 2, 6)
  end)

  it('in read-only buffer', function()
    command('view! runtime/doc/help.txt')
    eq(true, api.nvim_get_option_value('ro', {}))
    local id = set_extmark(ns, 0, 0, 2)
    eq({ { id, 0, 2 } }, get_extmarks(ns, 0, -1))
  end)

  it('can set a mark to other buffer', function()
    local buf = request('nvim_create_buf', 0, 1)
    request('nvim_buf_set_lines', buf, 0, -1, 1, { '', '' })
    local id = api.nvim_buf_set_extmark(buf, ns, 1, 0, {})
    eq({ { id, 1, 0 } }, api.nvim_buf_get_extmarks(buf, ns, 0, -1, {}))
  end)

  it('does not crash with append/delete/undo sequence', function()
    exec([[
      let ns = nvim_create_namespace('myplugin')
      call nvim_buf_set_extmark(0, ns, 0, 0, {})
      call append(0, '')
      %delete
      undo]])
    assert_alive()
  end)

  it('works with left and right gravity', function()
    -- right gravity should move with inserted text, while
    -- left gravity should stay in place.
    api.nvim_buf_set_extmark(0, ns, 0, 5, { right_gravity = false })
    api.nvim_buf_set_extmark(0, ns, 0, 5, { right_gravity = true })
    feed([[Aasdfasdf]])

    eq({ { 1, 0, 5 }, { 2, 0, 13 } }, api.nvim_buf_get_extmarks(0, ns, 0, -1, {}))

    -- but both move when text is inserted before
    feed([[<esc>Iasdf<esc>]])
    -- eq({}, api.nvim_buf_get_lines(0, 0, -1, true))
    eq({ { 1, 0, 9 }, { 2, 0, 17 } }, api.nvim_buf_get_extmarks(0, ns, 0, -1, {}))

    -- clear text
    api.nvim_buf_set_text(0, 0, 0, 0, 17, {})

    -- handles set_text correctly as well
    eq({ { 1, 0, 0 }, { 2, 0, 0 } }, api.nvim_buf_get_extmarks(0, ns, 0, -1, {}))
    api.nvim_buf_set_text(0, 0, 0, 0, 0, { 'asdfasdf' })
    eq({ { 1, 0, 0 }, { 2, 0, 8 } }, api.nvim_buf_get_extmarks(0, ns, 0, -1, {}))

    feed('u')
    -- handles pasting
    exec([[let @a='asdfasdf']])
    feed([["ap]])
    eq({ { 1, 0, 0 }, { 2, 0, 8 } }, api.nvim_buf_get_extmarks(0, ns, 0, -1, {}))
  end)

  it('can accept "end_row" or "end_line" #16548', function()
    set_extmark(ns, marks[1], 0, 0, {
      end_col = 0,
      end_line = 1,
    })
    eq({
      {
        1,
        0,
        0,
        {
          ns_id = 1,
          end_col = 0,
          end_row = 1,
          right_gravity = true,
          end_right_gravity = false,
        },
      },
    }, get_extmarks(ns, 0, -1, { details = true }))
  end)

  it('in prompt buffer', function()
    feed('dd')
    local id = set_extmark(ns, marks[1], 0, 0, {})
    api.nvim_set_option_value('buftype', 'prompt', {})
    feed('i<esc>')
    eq({ { id, 0, 2 } }, get_extmarks(ns, 0, -1))
  end)

  it('can get details', function()
    set_extmark(ns, marks[1], 0, 0, {
      conceal = 'c',
      cursorline_hl_group = 'Statement',
      end_col = 0,
      end_right_gravity = true,
      end_row = 1,
      hl_eol = true,
      hl_group = 'String',
      hl_mode = 'blend',
      line_hl_group = 'Statement',
      number_hl_group = 'Statement',
      priority = 0,
      right_gravity = false,
      sign_hl_group = 'Statement',
      sign_text = '>>',
      spell = true,
      virt_lines = {
        { { 'lines', 'Macro' }, { '???' } },
        { { 'stack', { 'Type', 'Search' } }, { '!!!' } },
      },
      virt_lines_above = true,
      virt_lines_leftcol = true,
      virt_text = { { 'text', 'Macro' }, { '???' }, { 'stack', { 'Type', 'Search' } } },
      virt_text_hide = true,
      virt_text_pos = 'right_align',
    })
    set_extmark(ns, marks[2], 0, 0, {
      priority = 0,
      virt_text = { { '', 'Macro' }, { '', { 'Type', 'Search' } }, { '' } },
      virt_text_win_col = 1,
    })
    eq({
      0,
      0,
      {
        conceal = 'c',
        cursorline_hl_group = 'Statement',
        end_col = 0,
        end_right_gravity = true,
        end_row = 1,
        hl_eol = true,
        hl_group = 'String',
        hl_mode = 'blend',
        line_hl_group = 'Statement',
        ns_id = 1,
        number_hl_group = 'Statement',
        priority = 0,
        right_gravity = false,
        sign_hl_group = 'Statement',
        sign_text = '>>',
        spell = true,
        virt_lines = {
          { { 'lines', 'Macro' }, { '???' } },
          { { 'stack', { 'Type', 'Search' } }, { '!!!' } },
        },
        virt_lines_above = true,
        virt_lines_leftcol = true,
        virt_text = { { 'text', 'Macro' }, { '???' }, { 'stack', { 'Type', 'Search' } } },
        virt_text_repeat_linebreak = false,
        virt_text_hide = true,
        virt_text_pos = 'right_align',
      },
    }, get_extmark_by_id(ns, marks[1], { details = true }))
    eq({
      0,
      0,
      {
        ns_id = 1,
        right_gravity = true,
        priority = 0,
        virt_text = { { '', 'Macro' }, { '', { 'Type', 'Search' } }, { '' } },
        virt_text_repeat_linebreak = false,
        virt_text_hide = false,
        virt_text_pos = 'win_col',
        virt_text_win_col = 1,
      },
    }, get_extmark_by_id(ns, marks[2], { details = true }))
    set_extmark(ns, marks[3], 0, 0, { cursorline_hl_group = 'Statement' })
    eq({
      0,
      0,
      {
        ns_id = 1,
        cursorline_hl_group = 'Statement',
        priority = 4096,
        right_gravity = true,
      },
    }, get_extmark_by_id(ns, marks[3], { details = true }))
    set_extmark(ns, marks[4], 0, 0, {
      end_col = 1,
      conceal = 'a',
      spell = true,
    })
    eq({
      0,
      0,
      {
        conceal = 'a',
        end_col = 1,
        end_right_gravity = false,
        end_row = 0,
        ns_id = 1,
        right_gravity = true,
        spell = true,
      },
    }, get_extmark_by_id(ns, marks[4], { details = true }))
    set_extmark(ns, marks[5], 0, 0, {
      end_col = 1,
      spell = false,
    })
    eq({
      0,
      0,
      {
        end_col = 1,
        end_right_gravity = false,
        end_row = 0,
        ns_id = 1,
        right_gravity = true,
        spell = false,
      },
    }, get_extmark_by_id(ns, marks[5], { details = true }))
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    -- legacy sign mark includes sign name
    command('sign define sign1 text=s1 texthl=Title linehl=LineNR numhl=Normal culhl=CursorLine')
    command('sign place 1 name=sign1 line=1')
    eq({
      {
        1,
        0,
        0,
        {
          cursorline_hl_group = 'CursorLine',
          invalidate = true,
          line_hl_group = 'LineNr',
          ns_id = 0,
          number_hl_group = 'Normal',
          priority = 10,
          right_gravity = true,
          sign_hl_group = 'Title',
          sign_name = 'sign1',
          sign_text = 's1',
          undo_restore = false,
        },
      },
    }, get_extmarks(-1, 0, -1, { details = true }))
  end)

  it('can get marks from anonymous namespaces', function()
    ns = request('nvim_create_namespace', '')
    ns2 = request('nvim_create_namespace', '')
    set_extmark(ns, 1, 0, 0, {})
    set_extmark(ns2, 2, 1, 0, {})
    eq({
      { 1, 0, 0, { ns_id = ns, right_gravity = true } },
      { 2, 1, 0, { ns_id = ns2, right_gravity = true } },
    }, get_extmarks(-1, 0, -1, { details = true }))
  end)

  it('can filter by extmark properties', function()
    set_extmark(ns, 1, 0, 0, {})
    set_extmark(ns, 2, 0, 0, { hl_group = 'Normal' })
    set_extmark(ns, 3, 0, 0, { sign_text = '>>' })
    set_extmark(ns, 4, 0, 0, { virt_text = { { 'text', 'Normal' } } })
    set_extmark(ns, 5, 0, 0, { virt_lines = { { { 'line', 'Normal' } } } })
    eq(5, #get_extmarks(-1, 0, -1, {}))
    eq({ { 2, 0, 0 } }, get_extmarks(-1, 0, -1, { type = 'highlight' }))
    eq({ { 3, 0, 0 } }, get_extmarks(-1, 0, -1, { type = 'sign' }))
    eq({ { 4, 0, 0 } }, get_extmarks(-1, 0, -1, { type = 'virt_text' }))
    eq({ { 5, 0, 0 } }, get_extmarks(-1, 0, -1, { type = 'virt_lines' }))
  end)

  it('invalidated marks are deleted', function()
    screen = Screen.new(40, 6)
    screen:attach()
    feed('dd6iaaa bbb ccc<CR><ESC>gg')
    api.nvim_set_option_value('signcolumn', 'auto:2', {})
    set_extmark(ns, 1, 0, 0, { invalidate = true, sign_text = 'S1', end_row = 1 })
    set_extmark(ns, 2, 1, 0, { invalidate = true, sign_text = 'S2', end_row = 2 })
    -- mark with invalidate is removed
    command('d2')
    screen:expect([[
      S2^aaa bbb ccc                           |
      {7:  }aaa bbb ccc                           |*3
      {7:  }                                      |
                                              |
    ]])
    -- mark is restored with undo_restore == true
    command('silent undo')
    screen:expect([[
      S1{7:  }^aaa bbb ccc                         |
      S1S2aaa bbb ccc                         |
      S2{7:  }aaa bbb ccc                         |
      {7:    }aaa bbb ccc                         |*2
                                              |
    ]])
    -- decor is not removed twice
    command('d3')
    api.nvim_buf_del_extmark(0, ns, 1)
    command('silent undo')
    -- mark is deleted with undo_restore == false
    set_extmark(ns, 1, 0, 0, { invalidate = true, undo_restore = false, sign_text = 'S1' })
    set_extmark(ns, 2, 1, 0, { invalidate = true, undo_restore = false, sign_text = 'S2' })
    command('1d 2')
    eq(0, #get_extmarks(-1, 0, -1, {}))
    -- mark is not removed when deleting bytes before the range
    set_extmark(
      ns,
      3,
      0,
      4,
      { invalidate = true, undo_restore = false, hl_group = 'Error', end_col = 7 }
    )
    feed('dw')
    eq(3, get_extmark_by_id(ns, 3, { details = true })[3].end_col)
    -- mark is not removed when deleting bytes at the start of the range
    feed('x')
    eq(2, get_extmark_by_id(ns, 3, { details = true })[3].end_col)
    -- mark is not removed when deleting bytes from the end of the range
    feed('lx')
    eq(1, get_extmark_by_id(ns, 3, { details = true })[3].end_col)
    -- mark is not removed when deleting bytes beyond end of the range
    feed('x')
    eq(1, get_extmark_by_id(ns, 3, { details = true })[3].end_col)
    -- mark is removed when all bytes in the range are deleted
    feed('hx')
    eq({}, get_extmark_by_id(ns, 3, {}))
    -- multiline mark is not removed when start of its range is deleted
    set_extmark(
      ns,
      4,
      1,
      4,
      { undo_restore = false, invalidate = true, hl_group = 'Error', end_col = 7, end_row = 3 }
    )
    feed('ddDdd')
    eq({ 0, 0 }, get_extmark_by_id(ns, 4, {}))
    -- multiline mark is removed when entirety of its range is deleted
    feed('vj2ed')
    eq({}, get_extmark_by_id(ns, 4, {}))
  end)

  it('can set a URL', function()
    set_extmark(ns, 1, 0, 0, { url = 'https://example.com', end_col = 3 })
    local extmarks = get_extmarks(ns, 0, -1, { details = true })
    eq(1, #extmarks)
    eq('https://example.com', extmarks[1][4].url)
  end)

  it('respects priority', function()
    screen = Screen.new(15, 10)
    screen:attach()

    set_extmark(ns, marks[1], 0, 0, {
      hl_group = 'Comment',
      end_col = 2,
      priority = 20,
    })

    -- Extmark defined after first extmark but has lower priority, first extmark "wins"
    set_extmark(ns, marks[2], 0, 0, {
      hl_group = 'String',
      end_col = 2,
      priority = 10,
    })

    screen:expect {
      grid = [[
      {1:12}34^5          |
      {2:~              }|*8
                     |
    ]],
      attr_ids = {
        [1] = { foreground = Screen.colors.Blue1 },
        [2] = { foreground = Screen.colors.Blue1, bold = true },
      },
    }
  end)
end)

describe('Extmarks buffer api with many marks', function()
  local ns1
  local ns2
  local ns_marks = {}
  before_each(function()
    clear()
    ns1 = request('nvim_create_namespace', 'ns1')
    ns2 = request('nvim_create_namespace', 'ns2')
    ns_marks = { [ns1] = {}, [ns2] = {} }
    local lines = {}
    for i = 1, 30 do
      lines[#lines + 1] = string.rep('x ', i)
    end
    api.nvim_buf_set_lines(0, 0, -1, true, lines)
    local ns = ns1
    local q = 0
    for i = 0, 29 do
      for j = 0, i do
        local id = set_extmark(ns, 0, i, j)
        eq(nil, ns_marks[ns][id])
        ok(id > 0)
        ns_marks[ns][id] = { i, j }
        ns = ns1 + ns2 - ns
        q = q + 1
      end
    end
    eq(233, #ns_marks[ns1])
    eq(232, #ns_marks[ns2])
  end)

  local function get_marks(ns)
    local mark_list = get_extmarks(ns, 0, -1)
    local marks = {}
    for _, mark in ipairs(mark_list) do
      local id, row, col = unpack(mark)
      eq(nil, marks[id], 'duplicate mark')
      marks[id] = { row, col }
    end
    return marks
  end

  it('can get marks', function()
    eq(ns_marks[ns1], get_marks(ns1))
    eq(ns_marks[ns2], get_marks(ns2))
  end)

  it('can clear all marks in ns', function()
    api.nvim_buf_clear_namespace(0, ns1, 0, -1)
    eq({}, get_marks(ns1))
    eq(ns_marks[ns2], get_marks(ns2))
    api.nvim_buf_clear_namespace(0, ns2, 0, -1)
    eq({}, get_marks(ns1))
    eq({}, get_marks(ns2))
  end)

  it('can clear line range', function()
    api.nvim_buf_clear_namespace(0, ns1, 10, 20)
    for id, mark in pairs(ns_marks[ns1]) do
      if 10 <= mark[1] and mark[1] < 20 then
        ns_marks[ns1][id] = nil
      end
    end
    eq(ns_marks[ns1], get_marks(ns1))
    eq(ns_marks[ns2], get_marks(ns2))

    api.nvim_buf_clear_namespace(0, ns1, 0, 10)
    for id, mark in pairs(ns_marks[ns1]) do
      if mark[1] < 10 then
        ns_marks[ns1][id] = nil
      end
    end
    eq(ns_marks[ns1], get_marks(ns1))
    eq(ns_marks[ns2], get_marks(ns2))

    api.nvim_buf_clear_namespace(0, ns1, 20, -1)
    for id, mark in pairs(ns_marks[ns1]) do
      if mark[1] >= 20 then
        ns_marks[ns1][id] = nil
      end
    end
    eq(ns_marks[ns1], get_marks(ns1))
    eq(ns_marks[ns2], get_marks(ns2))
  end)

  it('can delete line', function()
    feed('10Gdd')
    for _, marks in pairs(ns_marks) do
      for id, mark in pairs(marks) do
        if mark[1] == 9 then
          marks[id] = { 9, 0 }
        elseif mark[1] >= 10 then
          mark[1] = mark[1] - 1
        end
      end
    end
    eq(ns_marks[ns1], get_marks(ns1))
    eq(ns_marks[ns2], get_marks(ns2))
  end)

  it('can delete lines', function()
    feed('10G10dd')
    for _, marks in pairs(ns_marks) do
      for id, mark in pairs(marks) do
        if 9 <= mark[1] and mark[1] < 19 then
          marks[id] = { 9, 0 }
        elseif mark[1] >= 19 then
          mark[1] = mark[1] - 10
        end
      end
    end
    eq(ns_marks[ns1], get_marks(ns1))
    eq(ns_marks[ns2], get_marks(ns2))
  end)

  it('can wipe buffer', function()
    command('bwipe!')
    eq({}, get_marks(ns1))
    eq({}, get_marks(ns2))
  end)
end)

describe('API/win_extmark', function()
  local screen
  local marks, line1, line2
  local ns

  before_each(function()
    -- Initialize some namespaces and insert text into a buffer
    marks = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }

    line1 = 'non ui-watched line'
    line2 = 'ui-watched line'

    clear()

    insert(line1)
    feed('o<esc>')
    insert(line2)
    ns = request('nvim_create_namespace', 'extmark-ui')
  end)

  it('sends and only sends ui-watched marks to ui', function()
    screen = Screen.new(20, 4)
    screen:attach()
    -- should send this
    set_extmark(ns, marks[1], 1, 0, { ui_watched = true })
    -- should not send this
    set_extmark(ns, marks[2], 0, 0, { ui_watched = false })
    screen:expect({
      grid = [[
      non ui-watched line |
      ui-watched lin^e     |
      {1:~                   }|
                          |
    ]],
      extmarks = {
        [2] = {
          -- positioned at the end of the 2nd line
          { 1000, ns, marks[1], 1, 16 },
        },
      },
    })
  end)

  it('sends multiple ui-watched marks to ui', function()
    screen = Screen.new(20, 4)
    screen:attach()
    feed('15A!<Esc>')
    -- should send all of these
    set_extmark(ns, marks[1], 1, 0, { ui_watched = true, virt_text_pos = 'overlay' })
    set_extmark(ns, marks[2], 1, 2, { ui_watched = true, virt_text_pos = 'overlay' })
    set_extmark(ns, marks[3], 1, 4, { ui_watched = true, virt_text_pos = 'overlay' })
    set_extmark(ns, marks[4], 1, 6, { ui_watched = true, virt_text_pos = 'overlay' })
    set_extmark(ns, marks[5], 1, 8, { ui_watched = true })
    screen:expect({
      grid = [[
      non ui-watched line |
      ui-watched line!!!!!|
      !!!!!!!!!^!          |
                          |
    ]],
      extmarks = {
        [2] = {
          -- notification from 1st call
          { 1000, ns, marks[1], 1, 0 },
          -- notifications from 2nd call
          { 1000, ns, marks[1], 1, 0 },
          { 1000, ns, marks[2], 1, 2 },
          -- notifications from 3rd call
          { 1000, ns, marks[1], 1, 0 },
          { 1000, ns, marks[2], 1, 2 },
          { 1000, ns, marks[3], 1, 4 },
          -- notifications from 4th call
          { 1000, ns, marks[1], 1, 0 },
          { 1000, ns, marks[2], 1, 2 },
          { 1000, ns, marks[3], 1, 4 },
          { 1000, ns, marks[4], 1, 6 },
          -- final
          --   overlay
          { 1000, ns, marks[1], 1, 0 },
          { 1000, ns, marks[2], 1, 2 },
          { 1000, ns, marks[3], 1, 4 },
          { 1000, ns, marks[4], 1, 6 },
          --   eol
          { 1000, ns, marks[5], 2, 11 },
        },
      },
    })
  end)

  it('updates ui-watched marks', function()
    screen = Screen.new(20, 4)
    screen:attach()
    -- should send this
    set_extmark(ns, marks[1], 1, 0, { ui_watched = true })
    -- should not send this
    set_extmark(ns, marks[2], 0, 0, { ui_watched = false })
    -- make some changes
    insert(' update')
    screen:expect({
      grid = [[
      non ui-watched line |
      ui-watched linupdat^e|
      e                   |
                          |
    ]],
      extmarks = {
        [2] = {
          -- positioned at the end of the 2nd line
          { 1000, ns, marks[1], 1, 16 },
          -- updated and wrapped to 3rd line
          { 1000, ns, marks[1], 2, 2 },
        },
      },
    })
    feed('<c-e>')
    screen:expect({
      grid = [[
      ui-watched linupdat^e|
      e                   |
      {1:~                   }|
                          |
    ]],
      extmarks = {
        [2] = {
          -- positioned at the end of the 2nd line
          { 1000, ns, marks[1], 1, 16 },
          -- updated and wrapped to 3rd line
          { 1000, ns, marks[1], 2, 2 },
          -- scrolled up one line, should be handled by grid scroll
        },
      },
    })
  end)

  it('sends ui-watched to splits', function()
    screen = Screen.new(20, 8)
    screen:attach({ ext_multigrid = true })
    -- should send this
    set_extmark(ns, marks[1], 1, 0, { ui_watched = true })
    -- should not send this
    set_extmark(ns, marks[2], 0, 0, { ui_watched = false })
    command('split')
    screen:expect({
      grid = [[
        ## grid 1
          [4:--------------------]|*3
          {3:[No Name] [+]       }|
          [2:--------------------]|*2
          {2:[No Name] [+]       }|
          [3:--------------------]|
        ## grid 2
          non ui-watched line |
          ui-watched line     |
        ## grid 3
                              |
        ## grid 4
          non ui-watched line |
          ui-watched lin^e     |
          {1:~                   }|
    ]],
      extmarks = {
        [2] = {
          -- positioned at the end of the 2nd line
          { 1000, ns, marks[1], 1, 16 },
          -- updated after split
          { 1000, ns, marks[1], 1, 16 },
        },
        [4] = {
          -- only after split
          { 1001, ns, marks[1], 1, 16 },
        },
      },
    })
    -- make some changes
    insert(' update')
    screen:expect({
      grid = [[
        ## grid 1
          [4:--------------------]|*3
          {3:[No Name] [+]       }|
          [2:--------------------]|*2
          {2:[No Name] [+]       }|
          [3:--------------------]|
        ## grid 2
          non ui-watched line |
          ui-watched linupd{1:@@@}|
        ## grid 3
                              |
        ## grid 4
          non ui-watched line |
          ui-watched linupdat^e|
          e                   |
    ]],
      extmarks = {
        [2] = {
          -- positioned at the end of the 2nd line
          { 1000, ns, marks[1], 1, 16 },
          -- updated after split
          { 1000, ns, marks[1], 1, 16 },
        },
        [4] = {
          { 1001, ns, marks[1], 1, 16 },
          -- updated
          { 1001, ns, marks[1], 2, 2 },
        },
      },
    })
  end)
end)
