local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local exec = helpers.exec
local command = helpers.command
local feed = helpers.feed
local meths = helpers.meths
local assert_alive = helpers.assert_alive

before_each(clear)

describe('WinResized', function()
  -- oldtest: Test_WinResized()
  it('works', function()
    exec([[
      set scrolloff=0
      call setline(1, ['111', '222'])
      vnew
      call setline(1, ['aaa', 'bbb'])
      new
      call setline(1, ['foo', 'bar'])

      let g:resized = 0
      au WinResized * let g:resized += 1
      au WinResized * let g:v_event = deepcopy(v:event)
    ]])
    eq(0, eval('g:resized'))

    -- increase window height, two windows will be reported
    feed('<C-W>+')
    eq(1, eval('g:resized'))
    eq({windows = {1002, 1001}}, eval('g:v_event'))

    -- increase window width, three windows will be reported
    feed('<C-W>>')
    eq(2, eval('g:resized'))
    eq({windows = {1002, 1001, 1000}}, eval('g:v_event'))
  end)
end)

describe('WinScrolled', function()
  local win_id

  before_each(function()
    win_id = meths.get_current_win().id
    command(string.format('autocmd WinScrolled %d let g:matched = v:true', win_id))
    exec([[
      let g:scrolled = 0
      au WinScrolled * let g:scrolled += 1
      au WinScrolled * let g:amatch = str2nr(expand('<amatch>'))
      au WinScrolled * let g:afile = str2nr(expand('<afile>'))
      au WinScrolled * let g:v_event = deepcopy(v:event)
    ]])
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
    eq({
      all = {leftcol = 0, topline = 1, topfill = 0, width = 0, height = 0, skipcol = 0},
      ['1000'] = {leftcol = 0, topline = 1, topfill = 0, width = 0, height = 0, skipcol = 0},
    }, eval('g:v_event'))

    feed('<C-Y>')
    eq(2, eval('g:scrolled'))
    eq({
      all = {leftcol = 0, topline = 1, topfill = 0, width = 0, height = 0, skipcol = 0},
      ['1000'] = {leftcol = 0, topline = -1, topfill = 0, width = 0, height = 0, skipcol = 0},
    }, eval('g:v_event'))
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
    eq({
      all = {leftcol = 1, topline = 0, topfill = 0, width = 0, height = 0, skipcol = 0},
      ['1000'] = {leftcol = 1, topline = 0, topfill = 0, width = 0, height = 0, skipcol = 0},
    }, eval('g:v_event'))

    feed('zh')
    eq(2, eval('g:scrolled'))
    eq({
      all = {leftcol = 1, topline = 0, topfill = 0, width = 0, height = 0, skipcol = 0},
      ['1000'] = {leftcol = -1, topline = 0, topfill = 0, width = 0, height = 0, skipcol = 0},
    }, eval('g:v_event'))
  end)

  it('is triggered by horizontal scrolling from cursor move', function()
    command('set nowrap')
    local lines = {'', '', 'Foo'}
    meths.buf_set_lines(0, 0, -1, true, lines)
    meths.win_set_cursor(0, {3, 0})
    eq(0, eval('g:scrolled'))

    feed('zl')
    eq(1, eval('g:scrolled'))
    eq({
      all = {leftcol = 1, topline = 0, topfill = 0, width = 0, height = 0, skipcol = 0},
      ['1000'] = {leftcol = 1, topline = 0, topfill = 0, width = 0, height = 0, skipcol = 0},
    }, eval('g:v_event'))

    feed('zl')
    eq(2, eval('g:scrolled'))
    eq({
      all = {leftcol = 1, topline = 0, topfill = 0, width = 0, height = 0, skipcol = 0},
      ['1000'] = {leftcol = 1, topline = 0, topfill = 0, width = 0, height = 0, skipcol = 0},
    }, eval('g:v_event'))

    feed('h')
    eq(3, eval('g:scrolled'))
    eq({
      all = {leftcol = 1, topline = 0, topfill = 0, width = 0, height = 0, skipcol = 0},
      ['1000'] = {leftcol = -1, topline = 0, topfill = 0, width = 0, height = 0, skipcol = 0},
    }, eval('g:v_event'))

    feed('zh')
    eq(4, eval('g:scrolled'))
    eq({
      all = {leftcol = 1, topline = 0, topfill = 0, width = 0, height = 0, skipcol = 0},
      ['1000'] = {leftcol = -1, topline = 0, topfill = 0, width = 0, height = 0, skipcol = 0},
    }, eval('g:v_event'))
  end)

  -- oldtest: Test_WinScrolled_long_wrapped()
  it('is triggered by scrolling on a long wrapped line #19968', function()
    local height = meths.win_get_height(0)
    local width = meths.win_get_width(0)
    meths.buf_set_lines(0, 0, -1, true, {('foo'):rep(height * width)})
    meths.win_set_cursor(0, {1, height * width - 1})
    eq(0, eval('g:scrolled'))

    feed('gj')
    eq(1, eval('g:scrolled'))
    eq({
      all = {leftcol = 0, topline = 0, topfill = 0, width = 0, height = 0, skipcol = width},
      ['1000'] = {leftcol = 0, topline = 0, topfill = 0, width = 0, height = 0, skipcol = width},
    }, eval('g:v_event'))

    feed('0')
    eq(2, eval('g:scrolled'))
    eq({
      all = {leftcol = 0, topline = 0, topfill = 0, width = 0, height = 0, skipcol = width},
      ['1000'] = {leftcol = 0, topline = 0, topfill = 0, width = 0, height = 0, skipcol = -width},
    }, eval('g:v_event'))

    feed('$')
    eq(3, eval('g:scrolled'))
  end)

  it('is triggered when the window scrolls in Insert mode', function()
    local height = meths.win_get_height(0)
    local lines = {}
    for i = 1, height * 2 do
      lines[i] = tostring(i)
    end
    meths.buf_set_lines(0, 0, -1, true, lines)

    feed('M')
    eq(0, eval('g:scrolled'))

    feed('i<C-X><C-E><Esc>')
    eq(1, eval('g:scrolled'))
    eq({
      all = {leftcol = 0, topline = 1, topfill = 0, width = 0, height = 0, skipcol = 0},
      ['1000'] = {leftcol = 0, topline = 1, topfill = 0, width = 0, height = 0, skipcol = 0},
    }, eval('g:v_event'))

    feed('i<C-X><C-Y><Esc>')
    eq(2, eval('g:scrolled'))
    eq({
      all = {leftcol = 0, topline = 1, topfill = 0, width = 0, height = 0, skipcol = 0},
      ['1000'] = {leftcol = 0, topline = -1, topfill = 0, width = 0, height = 0, skipcol = 0},
    }, eval('g:v_event'))

    feed('L')
    eq(2, eval('g:scrolled'))

    feed('A<CR><Esc>')
    eq(3, eval('g:scrolled'))
    eq({
      all = {leftcol = 0, topline = 1, topfill = 0, width = 0, height = 0, skipcol = 0},
      ['1000'] = {leftcol = 0, topline = 1, topfill = 0, width = 0, height = 0, skipcol = 0},
    }, eval('g:v_event'))
  end)
end)

describe('WinScrolled', function()
  -- oldtest: Test_WinScrolled_mouse()
  it('is triggered by mouse scrolling in another window', function()
    local screen = Screen.new(75, 10)
    screen:attach()
    exec([[
      set nowrap scrolloff=0
      set mouse=a
      call setline(1, ['foo']->repeat(32))
      split
      let g:scrolled = 0
      au WinScrolled * let g:scrolled += 1
    ]])
    eq(0, eval('g:scrolled'))

    -- With the upper split focused, send a scroll-down event to the unfocused one.
    meths.input_mouse('wheel', 'down', '', 0, 6, 0)
    eq(1, eval('g:scrolled'))

    -- Again, but this time while we're in insert mode.
    feed('i')
    meths.input_mouse('wheel', 'down', '', 0, 6, 0)
    feed('<Esc>')
    eq(2, eval('g:scrolled'))
  end)

  -- oldtest: Test_WinScrolled_close_curwin()
  it('closing window does not cause use-after-free #13265', function()
    exec([[
      set nowrap scrolloff=0
      call setline(1, ['aaa', 'bbb'])
      vsplit
      au WinScrolled * close
    ]])

    -- This was using freed memory
    feed('<C-E>')
    assert_alive()
  end)

  -- oldtest: Test_WinScrolled_diff()
  it('is triggered for both windows when scrolling in diff mode', function()
    exec([[
      set diffopt+=foldcolumn:0
      call setline(1, ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'])
      vnew
      call setline(1, ['d', 'e', 'f', 'g', 'h', 'i'])
      windo diffthis
      au WinScrolled * let g:v_event = deepcopy(v:event)
    ]])

    feed('<C-E>')
    eq({
      all = {leftcol = 0, topline = 1, topfill = 1, width = 0, height = 0, skipcol = 0},
      ['1000'] = {leftcol = 0, topline = 1, topfill = 0, width = 0, height = 0, skipcol = 0},
      ['1001'] = {leftcol = 0, topline = 0, topfill = -1, width = 0, height = 0, skipcol = 0},
    }, eval('g:v_event'))

    feed('2<C-E>')
    eq({
      all = {leftcol = 0, topline = 2, topfill = 2, width = 0, height = 0, skipcol = 0},
      ['1000'] = {leftcol = 0, topline = 2, topfill = 0, width = 0, height = 0, skipcol = 0},
      ['1001'] = {leftcol = 0, topline = 0, topfill = -2, width = 0, height = 0, skipcol = 0},
    }, eval('g:v_event'))

    feed('<C-E>')
    eq({
      all = {leftcol = 0, topline = 2, topfill = 0, width = 0, height = 0, skipcol = 0},
      ['1000'] = {leftcol = 0, topline = 1, topfill = 0, width = 0, height = 0, skipcol = 0},
      ['1001'] = {leftcol = 0, topline = 1, topfill = 0, width = 0, height = 0, skipcol = 0},
    }, eval('g:v_event'))

    feed('2<C-Y>')
    eq({
      all = {leftcol = 0, topline = 3, topfill = 1, width = 0, height = 0, skipcol = 0},
      ['1000'] = {leftcol = 0, topline = -2, topfill = 0, width = 0, height = 0, skipcol = 0},
      ['1001'] = {leftcol = 0, topline = -1, topfill = 1, width = 0, height = 0, skipcol = 0},
    }, eval('g:v_event'))
  end)

  it('is triggered by mouse scrolling in unfocused floating window #18222', function()
    local screen = Screen.new(80, 24)
    screen:attach()

    exec([[
      let g:scrolled = 0
      autocmd WinScrolled * let g:scrolled += 1
      autocmd WinScrolled * let g:amatch = expand('<amatch>')
      autocmd WinScrolled * let g:v_event = deepcopy(v:event)
    ]])
    eq(0, eval('g:scrolled'))

    local buf = meths.create_buf(true, true)
    meths.buf_set_lines(buf, 0, -1, false, {'a', 'b', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n'})
    local win = meths.open_win(buf, false, {
      height = 5,
      width = 10,
      col = 0,
      row = 1,
      relative = 'editor',
      style = 'minimal'
    })
    local winid_str = tostring(win.id)
    -- WinScrolled should not be triggered when creating a new floating window
    eq(0, eval('g:scrolled'))

    meths.input_mouse('wheel', 'down', '', 0, 3, 3)
    eq(1, eval('g:scrolled'))
    eq(winid_str, eval('g:amatch'))
    eq({
      all = {leftcol = 0, topline = 3, topfill = 0, width = 0, height = 0, skipcol = 0},
      [winid_str] = {leftcol = 0, topline = 3, topfill = 0, width = 0, height = 0, skipcol = 0},
    }, eval('g:v_event'))

    meths.input_mouse('wheel', 'up', '', 0, 3, 3)
    eq(2, eval('g:scrolled'))
    eq(tostring(win.id), eval('g:amatch'))
    eq({
      all = {leftcol = 0, topline = 3, topfill = 0, width = 0, height = 0, skipcol = 0},
      [winid_str] = {leftcol = 0, topline = -3, topfill = 0, width = 0, height = 0, skipcol = 0},
    }, eval('g:v_event'))
  end)
end)
