local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local clear, eval, eq = n.clear, n.eval, t.eq
local feed, command, expect = n.feed, n.command, n.expect
local api, fn, neq = n.api, n.fn, t.neq

describe('TextYankPost', function()
  local function expect_event(expected)
    eq(
      vim.tbl_extend('force', {
        inclusive = false,
        regname = '',
        visual = false,
      }, expected),
      eval('g:event')
    )
  end

  before_each(function()
    clear()

    -- emulate the clipboard so system clipboard isn't affected
    command('set rtp^=test/functional/fixtures')

    command('let g:count = 0')
    command('autocmd TextYankPost * let g:event = copy(v:event)')
    command('autocmd TextYankPost * let g:count += 1')

    api.nvim_buf_set_lines(0, 0, -1, true, {
      'foo\0bar',
      'baz text',
    })
  end)

  it('is executed after yank and handles register types', function()
    feed('yy')
    expect_event({ operator = 'y', regcontents = { 'foo\nbar' }, regtype = 'V' })
    eq(1, eval('g:count'))

    -- v:event is cleared after the autocommand is done
    eq({}, eval('v:event'))

    feed('+yw')
    expect_event({ operator = 'y', regcontents = { 'baz ' }, regtype = 'v' })
    eq(2, eval('g:count'))

    feed('<c-v>eky')
    expect_event({
      inclusive = true,
      operator = 'y',
      regcontents = { 'foo', 'baz' },
      regtype = '\0223', -- ^V + block width
      visual = true,
    })
    eq(3, eval('g:count'))
  end)

  it('makes v:event immutable', function()
    feed('yy')
    expect_event({ operator = 'y', regcontents = { 'foo\nbar' }, regtype = 'V' })

    command('set debug=msg')
    -- the regcontents should not be changed without copy.
    local status, err = pcall(command, 'call extend(g:event.regcontents, ["more text"])')
    eq(false, status)
    neq(nil, string.find(err, ':E742:'))

    -- can't mutate keys inside the autocommand
    command('autocmd! TextYankPost * let v:event.regcontents = 0')
    status, err = pcall(command, 'normal yy')
    eq(false, status)
    neq(nil, string.find(err, ':E46:'))

    -- can't add keys inside the autocommand
    command('autocmd! TextYankPost * let v:event.mykey = 0')
    status, err = pcall(command, 'normal yy')
    eq(false, status)
    neq(nil, string.find(err, ':E742:'))
  end)

  it('is not invoked recursively', function()
    command('autocmd TextYankPost * normal "+yy')
    feed('yy')
    expect_event({ operator = 'y', regcontents = { 'foo\nbar' }, regtype = 'V' })
    eq(1, eval('g:count'))
    eq({ 'foo\nbar' }, fn.getreg('+', 1, 1))
  end)

  it('is executed after delete and change', function()
    feed('dw')
    expect_event({ operator = 'd', regcontents = { 'foo' }, regtype = 'v' })
    eq(1, eval('g:count'))

    feed('dd')
    expect_event({ operator = 'd', regcontents = { '\nbar' }, regtype = 'V' })
    eq(2, eval('g:count'))

    feed('cwspam<esc>')
    expect_event({
      inclusive = true,
      operator = 'c',
      regcontents = { 'baz' },
      regtype = 'v',
    })
    eq(3, eval('g:count'))
  end)

  it('is not executed after black-hole operation', function()
    feed('"_dd')
    eq(0, eval('g:count'))

    feed('"_cwgood<esc>')
    eq(0, eval('g:count'))

    expect([[
      good text]])
    feed('"_yy')
    eq(0, eval('g:count'))

    command('delete _')
    eq(0, eval('g:count'))
  end)

  it('gives the correct register name', function()
    feed('$"byiw')
    expect_event({
      inclusive = true,
      operator = 'y',
      regcontents = { 'bar' },
      regname = 'b',
      regtype = 'v',
    })

    feed('"*yy')
    expect_event({
      inclusive = true,
      operator = 'y',
      regcontents = { 'foo\nbar' },
      regname = '*',
      regtype = 'V',
    })

    command('set clipboard=unnamed')

    -- regname still shows the name the user requested
    feed('yy')
    expect_event({
      inclusive = true,
      operator = 'y',
      regcontents = { 'foo\nbar' },
      regname = '',
      regtype = 'V',
    })

    feed('"*yy')
    expect_event({
      inclusive = true,
      operator = 'y',
      regcontents = { 'foo\nbar' },
      regname = '*',
      regtype = 'V',
    })
  end)

  it('works with Ex commands', function()
    command('1delete +')
    expect_event({
      operator = 'd',
      regcontents = { 'foo\nbar' },
      regname = '+',
      regtype = 'V',
    })
    eq(1, eval('g:count'))

    command('yank')
    expect_event({ operator = 'y', regcontents = { 'baz text' }, regtype = 'V' })
    eq(2, eval('g:count'))

    command('normal yw')
    expect_event({ operator = 'y', regcontents = { 'baz ' }, regtype = 'v' })
    eq(3, eval('g:count'))

    command('normal! dd')
    expect_event({ operator = 'd', regcontents = { 'baz text' }, regtype = 'V' })
    eq(4, eval('g:count'))
  end)

  it('updates numbered registers correctly #10225', function()
    command('autocmd TextYankPost * let g:reg = getreg("1")')
    feed('"adj')
    eq('foo\nbar\nbaz text\n', eval('g:reg'))
  end)
end)
