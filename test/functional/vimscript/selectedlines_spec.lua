local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local curbuf = helpers.curbuf
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local feed = helpers.feed

local virtualedit = false


local input = {
  'ab',
  'cdefgh',
  'ijk',
  'lmnopqrst',
  '',
  '    uvwxyz',
  '', -- double width characters
  'äƃĉđē', -- utf-8 2 byte characters
  '',
}

local function set_cursor(cursorpos)
  local row, col = unpack(cursorpos)
  -- it is easier to use feed keys instead of evaluating correctly
  -- all 4 arguments for setcursorcharpos for virtualedit cases
  feed('gg0')
  if row > 1 then
    feed(tostring(row - 1)..'j')
  end
  if col > 1 then
    feed(tostring(col - 1)..'l')
  end

  local _, row2, col2, _, cwant2 = unpack(exec_lua([[return vim.fn.getcursorcharpos()]]))
  if virtualedit then
    col2 = cwant2
  end
  if row ~= row2 or col ~= col2 then
      error(string.format('failed to set cursor: %d %d %d %d', row, col, row2, col2))
  end
end

local function mode()
  return exec_lua([[return vim.fn.mode()]])
end

local function select(pos1, pos2, selection_type)
  feed('<esc>')
  set_cursor(pos1)
  feed(selection_type)
  set_cursor(pos2)
  eq(selection_type, mode())
end

local function selected_lines()
  local m = mode()
  local lines = exec_lua([[return vim.fn.selectedlines()]])
  eq(m, mode())
  return lines
end

local function test_selection(
  pos1,
  pos2,
  selection_type,
  expected_inclusive,
  expected_exclusive,
  virtual
)
  if virtual then
    exec_lua([[vim.o.virtualedit = 'all']])
    virtualedit = true
  else
    exec_lua([[vim.o.virtualedit = '']])
    virtualedit = false
  end
  for selection, expected in pairs({ inclusive = expected_inclusive, exclusive = expected_exclusive }) do
    exec_lua('vim.o.selection = ...', selection)
    select(pos1, pos2, selection_type)
    eq(expected, selected_lines(), selection)
    select(pos2, pos1, selection_type)
    eq(expected, selected_lines(), selection .. ' reversed')
  end
end

describe('selectedlines() function', function()
  before_each(function()
    clear()
    curbuf('set_lines', 0, 1, true, input)
  end)

  it('visual linewise', function()
    test_selection({ 1, 1 }, { 3, 1 }, 'V',
                   { input[1], input[2], input[3] },
                   { input[1], input[2], input[3] }
    )
  end)
  it('visual charwise single char', function()
    test_selection({ 2, 2 }, { 2, 2 }, 'v', { 'd' }, { 'd' })
    test_selection({ 7, 2 }, { 7, 2 }, 'v', { '' }, { '' })
    test_selection({ 8, 2 }, { 8, 2 }, 'v', { 'ƃ' }, { 'ƃ' })
  end)
  it('visual charwise single line', function()
    test_selection({ 2, 2 }, { 2, 5 }, 'v', { 'defg' }, { 'def' })
  end)
  it('visual charwise multi line', function()
    test_selection({ 2, 2 }, { 4, 5 }, 'v', { 'defgh', input[3], 'lmnop' }, { 'defgh', input[3], 'lmno' })
  end)
  it('visual charwise multi line empty line start', function()
    test_selection({ 5, 1 }, { 6, 6 }, 'v', { '', '    uv' }, { '', '    u' })
  end)
  it('visual charwise multi line empty line end', function()
    test_selection({ 2, 2 }, { 5, 1 }, 'v',
                   { 'defgh', input[3], input[4], '' },
                   { 'defgh', input[3], input[4] }
    )
  end)
  it('visual charwise double-width chars', function()
    test_selection({ 7, 2 }, { 7, 4 }, 'v', { '' }, { '' })
  end)
  it('visual charwise utf-8 double-byte chars', function()
    test_selection({ 8, 2 }, { 8, 4 }, 'v', { 'ƃĉđ' }, { 'ƃĉ' })
  end)
  it('blockwise single line', function()
    test_selection({ 2, 2 }, { 2, 5 }, '', { 'defg' }, { 'def' })
  end)
  it('blockwise multi line', function()
    test_selection({ 1, 2 }, { 8, 4 }, '',
                   { 'b', 'def', 'jk', 'mno', '   ', '   ', ' ', 'ƃĉđ' },
                   { 'b', 'de', 'jk', 'mn', '  ', '  ', '  ', 'ƃĉ' })
  end)

  -- virtualedit
  it('visual linewise virtual', function()
    test_selection({ 1, 8 }, { 3, 8 }, 'V',
                   { input[1], input[2], input[3] },
                   { input[1], input[2], input[3] }, true)
  end)
  it('visual charwise single char virtual', function()
    test_selection({ 1, 8 }, { 1, 8 }, 'v', { ' ' }, { ' ' }, true)
  end)
  it('visual charwise single line virtual', function()
    test_selection({ 2, 5 }, { 2, 8 }, 'v', { 'gh  ' }, { 'gh ' }, true)
    test_selection({ 1, 8 }, { 1, 11 }, 'v', { '    ' }, { '   ' }, true)
  end)
  it('visual charwise multi line empty line start virtual', function()
    test_selection({ 5, 1 }, { 6, 6 }, 'v', { '', '    uv' }, { '', '    u' }, true)
  end)
  it('visual charwise multi line empty line end virtual', function()
    test_selection({ 2, 2 }, { 5, 1 }, 'v',
                   { 'defgh', input[3], input[4], ' ' },
                   { 'defgh', input[3], input[4] }, true)
    test_selection({ 8, 2 }, { 9, 1 }, 'v', { 'ƃĉđē', ' ' }, { 'ƃĉđē' }, true)
    test_selection({ 8, 2 }, { 9, 2 }, 'v', { 'ƃĉđē', '  ' }, { 'ƃĉđē', ' ' }, true)
  end)
  it('charwise multi line virtual', function()
    test_selection({ 1, 8 }, { 2, 8 }, 'v', { '', 'cdefgh  ' }, { '', 'cdefgh ' }, true)
  end)
  it('blockwise multi line virtual', function()
    test_selection({ 1, 2 }, { 8, 4 }, '',
                   { 'b  ', 'def', 'jk ', 'mno', '   ', '   ', ' ', 'ƃĉđ' },
                   { 'b ', 'de', 'jk', 'mn', '  ', '  ', '  ', 'ƃĉ' }, true)
    test_selection({ 1, 5 }, { 8, 7 }, '',
                   { '   ', 'gh ', '   ', 'pqr', '   ', 'uvw', ' ', 'ē  ' },
                   { '  ', 'gh', '  ', 'pq', '  ', 'uv', '', 'ē ' }, true)
  end)
end)
