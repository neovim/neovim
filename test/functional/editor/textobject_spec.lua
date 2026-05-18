local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local api = n.api
local clear = n.clear
local command = n.command
local eq = t.eq
local eval = n.eval
local feed = n.feed
local fn = n.fn

local function set_lines(lines)
  api.nvim_buf_set_lines(0, 0, -1, true, lines)
end

local function get_lines()
  return api.nvim_buf_get_lines(0, 0, -1, true)
end

local function set_cursor(row, col)
  api.nvim_win_set_cursor(0, { row, col })
end

describe('line textobject', function()
  before_each(clear)

  it('selects the current line without surrounding whitespace', function()
    set_lines({ 'one', '  two words  ', 'three' })
    set_cursor(2, 4)
    feed('yil')
    eq('two words', fn.getreg('"'))

    set_cursor(2, 4)
    feed('vily')
    eq('two words', fn.getreg('"'))
    eq('v', fn.visualmode())

    set_cursor(2, 4)
    feed('Vily')
    eq('two words', fn.getreg('"'))
    eq('v', fn.visualmode())

    set_cursor(2, 0)
    feed('0v$ily')
    eq('two words', fn.getreg('"'))

    set_cursor(1, 0)
    feed('Vjily')
    eq('two words', fn.getreg('"'))

    command('set selection=exclusive')
    set_cursor(2, 4)
    feed('vily')
    eq('two words', fn.getreg('"'))
    command('set selection&')

    set_cursor(2, 4)
    feed('dil')
    eq({ 'one', '    ', 'three' }, get_lines())

    set_lines({ '  αβ  ', '  ', 'last' })
    set_cursor(1, 2)
    feed('yil')
    eq('αβ', fn.getreg('"'))

    command('set selection=exclusive')
    set_cursor(1, 2)
    feed('vily')
    eq('αβ', fn.getreg('"'))
    command('set selection&')

    fn.setreg('"', 'unchanged')
    set_cursor(2, 0)
    eq(0, fn.assert_beeps('normal yil'))
    eq('unchanged', fn.getreg('"'))

    set_cursor(2, 0)
    eq(0, fn.assert_beeps('normal vily'))
    eq('unchanged', fn.getreg('"'))
  end)

  it('selects all lines without moving the cursor for yank', function()
    set_lines({ '  αβ  ', '  ', 'last' })
    command('let g:textobj_line_yank_pos = []')
    command([[autocmd TextYankPost <buffer> ++once let g:textobj_line_yank_pos = getpos('.')]])

    set_cursor(3, 0)
    feed('yal')
    eq('  αβ  \n  \nlast\n', fn.getreg('"'))
    eq({ 0, 3, 1, 0 }, fn.getpos('.'))
    eq({ 0, 3, 1, 0 }, eval('g:textobj_line_yank_pos'))

    set_cursor(3, 0)
    feed('valy')
    eq('  αβ  \n  \nlast\n', fn.getreg('"'))
    eq('V', fn.visualmode())

    set_cursor(2, 0)
    feed('dal')
    eq({ '' }, get_lines())
  end)
end)
