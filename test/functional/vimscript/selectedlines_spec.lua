local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local curbuf = helpers.curbuf
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local feed = helpers.feed

local function set_cursor(cursorpos)
  exec_lua('vim.fn.setcursorcharpos(unpack(...))', cursorpos)
end

local function mode()
  return exec_lua[[return vim.fn.mode()]]
end

local function selected_lines()
  local m = mode()
  local lines = exec_lua[[return vim.fn.selectedlines()]]
  eq(m, mode())
  return lines
end

local function test_selection(cursorpos, selection_macro, expected_inclusive, expected_exclusive, virtual)
  if virtual then
    exec_lua[[vim.o.virtualedit = 'all']]
  end

  exec_lua[[vim.o.selection = 'inclusive']]
  set_cursor(cursorpos)
  feed(selection_macro)
  eq(expected_inclusive, selected_lines(), 'inclusive')
  feed('o')
  eq(expected_inclusive, selected_lines(), 'inclusive reversed')
  feed('<esc>')

  exec_lua[[vim.o.selection = 'exclusive']]
  set_cursor(cursorpos)
  feed(selection_macro)
  eq(expected_exclusive, selected_lines(), 'exclusive')
  feed('o')
  eq(expected_exclusive, selected_lines(), 'exclusive reversed')
  feed('<esc>')
end

local input = {
  'ab',
  'cdefgh',
  'ijk',
  'lmnopqrst',
  '',
  '    uvwxyz',
  '', -- double width characters
  'äƃĉđē',      -- utf-8 2 byte characters
  '',
}


describe('selectedlines() function', function()

  before_each(function()
    clear()
    curbuf('set_lines', 0, 1, true, input)
  end)

  it('visual linewise', function()
    test_selection({1, 1}, 'V2j', {input[1], input[2], input[3]}, {input[1], input[2], input[3]})
  end)
  it('visual charwise single char', function()
    test_selection({2, 2}, 'v', {'d'}, {'d'})
    test_selection({7, 2}, 'v', {''}, {''})
    test_selection({8, 2}, 'v', {'ƃ'}, {'ƃ'})
  end)
  it('visual charwise single line', function()
    test_selection({2, 2}, 'v3l', {'defg'}, {'def'})
  end)
  it('visual charwise multi line', function()
    test_selection({2, 2}, 'v2j3l', {'defgh', input[3], 'lmnop'}, {'defgh', input[3], 'lmno'})
  end)
  it('visual charwise multi line empty line start', function()
    test_selection({5, 1}, 'vj5l',
                    {'', '    uv'},
                    {'', '    u'})
  end)
  it('visual charwise multi line empty line end', function()
    test_selection({2, 2}, 'v3j',
                    {'defgh', input[3], input[4], ''},
                    {'defgh', input[3], input[4]})
    test_selection({8, 2}, 'v3j',
                    {'ƃĉđē', ''},
                    {'ƃĉđē' }, true)
  end)
  it('visual charwise double-width chars', function()
    test_selection({7, 2}, 'v2l', {''}, {''})
  end)
  it('visual charwise utf-8 double-byte chars', function()
    test_selection({8, 2}, 'v2l', {'ƃĉđ'}, {'ƃĉ'})
  end)
  it('blockwise single line', function()
    test_selection({2,2}, '3l', {'defg'}, {'def'})
  end)
  it('blockwise multi line', function()
    test_selection({1,2}, '7j2l',
                   {'b', 'def', 'jk', 'mno', '   ', '   ', ' ', 'ƃĉđ'},
                   {'b', 'de', 'jk', 'mn', '  ', '  ', '  ', 'ƃĉ'})
  end)

  -- virtual
  it('visual linewise virtual', function()
    test_selection({1, 1}, '7lV2j', {input[1], input[2], input[3]}, {input[1], input[2], input[3]}, true)
  end)
  it('visual charwise single char virtual', function()
    test_selection({1, 1}, '7lv', {' '}, {' '}, true)
  end)
  it('visual charwise single line virtual', function()
    test_selection({2, 5}, 'v3l', {'gh  '}, {'gh '}, true)
    test_selection({1, 1}, '7lv3l', {'    '}, {'   '}, true)
  end)
  it('visual charwise multi line empty line start', function()
    test_selection({5, 1}, 'vj5l',
                    {'', '    uv'},
                    {'', '    u'}, true)
  end)
  it('visual charwise multi line empty line end', function()
    test_selection({2, 2}, 'v3j0',
                    {'defgh', input[3], input[4], ' '},
                    {'defgh', input[3], input[4]}, true)
    test_selection({8, 2}, 'v3j0',
                    {'ƃĉđē', ' '},
                    {'ƃĉđē' }, true)
  end)
  it('charwise multi line virtual', function()
    test_selection({1,1}, '7lvj',
                   {'', 'cdefgh  '},
                   {'', 'cdefgh '}, true)
  end)
  it('blockwise multi line virtual', function()
    test_selection({1,2}, '7j2l',
                   {'b  ', 'def', 'jk ', 'mno', '   ', '   ', ' ', 'ƃĉđ'},
                   {'b ', 'de', 'jk', 'mn', '  ', '  ', '  ', 'ƃĉ'}, true)
    test_selection({1,1}, '4l7j2l',
                   {'   ', 'gh ', '   ', 'pqr', '   ', 'uvw', ' ', 'ē  '},
                   {'  ', 'gh', '  ', 'pq', '  ', 'uv', '', 'ē '}, true)
  end)
end)
