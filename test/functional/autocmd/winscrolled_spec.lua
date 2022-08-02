local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local command = helpers.command
local feed = helpers.feed
local meths = helpers.meths
local assert_alive = helpers.assert_alive

before_each(clear)

describe('WinScrolled', function()
  local win_id

  before_each(function()
    win_id = meths.get_current_win().id
    command(string.format('autocmd WinScrolled %d let g:matched = v:true', win_id))
    command('let g:scrolled = 0')
    command('autocmd WinScrolled * let g:scrolled += 1')
    command([[autocmd WinScrolled * let g:amatch = str2nr(expand('<amatch>'))]])
    command([[autocmd WinScrolled * let g:afile = str2nr(expand('<afile>'))]])
  end)

  after_each(function()
    eq(true, eval('g:matched'))
    eq(win_id, eval('g:amatch'))
    eq(win_id, eval('g:afile'))
  end)

  it('is triggered by scrolling vertically', function()
    local lines = {'123', '123'}
    meths.buf_set_lines(0, 0, -1, true, lines)
    eq(0, eval('g:scrolled'))
    feed('<C-E>')
    eq(1, eval('g:scrolled'))
  end)

  it('is triggered by scrolling horizontally', function()
    command('set nowrap')
    local width = meths.win_get_width(0)
    local line = '123' .. ('*'):rep(width * 2)
    local lines = {line, line}
    meths.buf_set_lines(0, 0, -1, true, lines)
    eq(0, eval('g:scrolled'))
    feed('zl')
    eq(1, eval('g:scrolled'))
  end)

  it('is triggered by horizontal scrolling from cursor move', function()
    command('set nowrap')
    local lines = {'', '', 'Foo'}
    meths.buf_set_lines(0, 0, -1, true, lines)
    meths.win_set_cursor(0, {3, 0})
    eq(0, eval('g:scrolled'))
    feed('zl')
    eq(1, eval('g:scrolled'))
    feed('zl')
    eq(2, eval('g:scrolled'))
    feed('h')
    eq(3, eval('g:scrolled'))
  end)

  it('is triggered when the window scrolls in Insert mode', function()
    local height = meths.win_get_height(0)
    local lines = {}
    for i = 1, height * 2 do
      lines[i] = tostring(i)
    end
    meths.buf_set_lines(0, 0, -1, true, lines)
    feed('L')
    eq(0, eval('g:scrolled'))
    feed('A<CR><Esc>')
    eq(1, eval('g:scrolled'))
  end)
end)

it('closing window in WinScrolled does not cause use-after-free #13265', function()
  local lines = {'aaa', 'bbb'}
  meths.buf_set_lines(0, 0, -1, true, lines)
  command('vsplit')
  command('autocmd WinScrolled * close')
  feed('<C-E>')
  assert_alive()
end)
