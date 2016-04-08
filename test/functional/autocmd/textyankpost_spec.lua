local helpers = require('test.functional.helpers')
local clear, eval, eq, insert = helpers.clear, helpers.eval, helpers.eq, helpers.insert
local feed, execute, expect, command = helpers.feed, helpers.execute, helpers.expect, helpers.command
local curbufmeths, funcs, neq = helpers.curbufmeths, helpers.funcs, helpers.neq

describe('TextYankPost', function()
  before_each(function()
    clear()

    -- emulate the clipboard so system clipboard isn't affected
    execute('let &rtp = "test/functional/fixtures,".&rtp')

    execute('let g:count = 0')
    execute('autocmd TextYankPost * let g:event = copy(v:event)')
    execute('autocmd TextYankPost * let g:count += 1')

    curbufmeths.set_lines(0, -1, true, {
      'foo\0bar',
      'baz text',
    })
  end)

  it('is executed after yank and handles register types', function()
    feed('yy')
    eq({
      operator = 'y',
      regcontents = { 'foo\nbar' },
      regname = '',
      regtype = 'V'
    }, eval('g:event'))
    eq(1, eval('g:count'))

    -- v:event is cleared after the autocommand is done
    eq({}, eval('v:event'))

    feed('+yw')
    eq({
      operator = 'y',
      regcontents = { 'baz ' },
      regname = '',
      regtype = 'v'
    }, eval('g:event'))
    eq(2, eval('g:count'))

    feed('<c-v>eky')
    eq({
      operator = 'y',
      regcontents = { 'foo', 'baz' },
      regname = '',
      regtype = "\0223" -- ^V + block width
    }, eval('g:event'))
    eq(3, eval('g:count'))
  end)

  it('makes v:event immutable', function()
    feed('yy')
    eq({
      operator = 'y',
      regcontents = { 'foo\nbar' },
      regname = '',
      regtype = 'V'
    }, eval('g:event'))

    execute('set debug=msg')
    -- the regcontents should not be changed without copy.
    local status, err = pcall(command,'call extend(g:event.regcontents, ["more text"])')
    eq(status,false)
    neq(nil, string.find(err, ':E742:'))

    -- can't mutate keys inside the autocommand
    execute('autocmd! TextYankPost * let v:event.regcontents = 0')
    status, err = pcall(command,'normal yy')
    eq(status,false)
    neq(nil, string.find(err, ':E46:'))

    -- can't add keys inside the autocommand
    execute('autocmd! TextYankPost * let v:event.mykey = 0')
    status, err = pcall(command,'normal yy')
    eq(status,false)
    neq(nil, string.find(err, ':E742:'))
  end)

  it('is not invoked recursively', function()
    execute('autocmd TextYankPost * normal "+yy')
    feed('yy')
    eq({
      operator = 'y',
      regcontents = { 'foo\nbar' },
      regname = '',
      regtype = 'V'
    }, eval('g:event'))
    eq(1, eval('g:count'))
    eq({ 'foo\nbar' }, funcs.getreg('+',1,1))
  end)

  it('is executed after delete and change', function()
    feed('dw')
    eq({
      operator = 'd',
      regcontents = { 'foo' },
      regname = '',
      regtype = 'v'
    }, eval('g:event'))
    eq(1, eval('g:count'))

    feed('dd')
    eq({
      operator = 'd',
      regcontents = { '\nbar' },
      regname = '',
      regtype = 'V'
    }, eval('g:event'))
    eq(2, eval('g:count'))

    feed('cwspam<esc>')
    eq({
      operator = 'c',
      regcontents = { 'baz' },
      regname = '',
      regtype = 'v'
    }, eval('g:event'))
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

    execute('delete _')
    eq(0, eval('g:count'))
  end)

  it('gives the correct register name', function()
    feed('$"byiw')
    eq({
      operator = 'y',
      regcontents = { 'bar' },
      regname = 'b',
      regtype = 'v'
    }, eval('g:event'))

    feed('"*yy')
    eq({
      operator = 'y',
      regcontents = { 'foo\nbar' },
      regname = '*',
      regtype = 'V'
    }, eval('g:event'))

    execute("set clipboard=unnamed")

    -- regname still shows the name the user requested
    feed('yy')
    eq({
      operator = 'y',
      regcontents = { 'foo\nbar' },
      regname = '',
      regtype = 'V'
    }, eval('g:event'))

    feed('"*yy')
    eq({
      operator = 'y',
      regcontents = { 'foo\nbar' },
      regname = '*',
      regtype = 'V'
    }, eval('g:event'))
  end)

  it('works with Ex commands', function()
    execute('1delete +')
    eq({
      operator = 'd',
      regcontents = { 'foo\nbar' },
      regname = '+',
      regtype = 'V'
    }, eval('g:event'))
    eq(1, eval('g:count'))

    execute('yank')
    eq({
      operator = 'y',
      regcontents = { 'baz text' },
      regname = '',
      regtype = 'V'
    }, eval('g:event'))
    eq(2, eval('g:count'))

    execute('normal yw')
    eq({
      operator = 'y',
      regcontents = { 'baz ' },
      regname = '',
      regtype = 'v'
    }, eval('g:event'))
    eq(3, eval('g:count'))

    execute('normal! dd')
    eq({
      operator = 'd',
      regcontents = { 'baz text' },
      regname = '',
      regtype = 'V'
    }, eval('g:event'))
    eq(4, eval('g:count'))
  end)

end)
