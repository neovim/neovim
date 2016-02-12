-- Tests for vertical splits and filler lines in diff mode
-- Also tests restoration of saved options by :diffoff.

local helpers = require('test.functional.helpers')
local feed = helpers.feed
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect
local write_file = helpers.write_file
local eq, eval, dedent = helpers.eq, helpers.eval, helpers.dedent

local function expect_string_var(name, text)
  return eq(dedent(text), eval(name))
end

describe('47', function()
  setup(function()
    clear()
    write_file('Xtest', '1 aa\n2 bb\n3 cc\n4 dd\n5 ee\n')
    write_file('Xtest2', '2 bb\n3 cc\nX dd\nxxx\n5 ee\n1 aa\n')
    write_file('Nop', '2 bb\nyyy\n3 cc\nX dd\nxxx\nzzzz\n5 ee\n1 aa\n')
  end)
  teardown(function()
    os.remove('Xtest')
    os.remove('Xtest2')
    os.remove('Nop')
  end)

  it('is working', function()
    execute('edit Nop')
    execute('set foldmethod=marker foldcolumn=4')
    execute('redir => nodiffsettings')
    execute('silent! :set diff? fdm? fdc? scb? crb? wrap?')
    execute('redir END')
    expect_string_var('nodiffsettings', [[
      
      
      nodiff
        foldmethod=marker
        foldcolumn=4
      noscrollbind
      nocursorbind
        wrap
      ]])
    execute('vert diffsplit Xtest')
    execute('vert diffsplit Xtest2')
    execute('redir => diffsettings')
    execute('silent! :set diff? fdm? fdc? scb? crb? wrap?')
    execute('redir END')
    expect_string_var('diffsettings', [[
      
      
        diff
        foldmethod=diff
        foldcolumn=2
        scrollbind
        cursorbind
      nowrap
      ]])
    execute('let diff_fdm = &fdm')
    execute('let diff_fdc = &fdc')
    -- Repeat entering diff mode here to see if this saves the wrong settings.
    execute('diffthis')
    -- Jump to second window for a moment to have filler line appear at start of.
    -- first window.
    feed('<C-W><C-W>gg<C-W>pgg')
    execute('let one = winline()')
    feed('j')
    execute('let one = one . "-" . winline()')
    feed('j')
    execute('let one = one . "-" . winline()')
    feed('j')
    execute('let one = one . "-" . winline()')
    feed('j')
    execute('let one = one . "-" . winline()')
    feed('j')
    execute('let one = one . "-" . winline()')
    feed('<C-W><C-W>gg')
    execute('let two = winline()')
    feed('j')
    execute('let two = two . "-" . winline()')
    feed('j')
    execute('let two = two . "-" . winline()')
    feed('j')
    execute('let two = two . "-" . winline()')
    feed('j')
    execute('let two = two . "-" . winline()')
    feed('<C-W><C-W>gg')
    execute('let three = winline()')
    feed('j')
    execute('let three = three . "-" . winline()')
    feed('j')
    execute('let three = three . "-" . winline()')
    feed('j')
    execute('let three = three . "-" . winline()')
    feed('j')
    execute('let three = three . "-" . winline()')
    feed('j')
    execute('let three = three . "-" . winline()')
    feed('j')
    execute('let three = three . "-" . winline()')
    expect_string_var('one', '2-4-5-6-8-9')
    expect_string_var('two', '1-2-4-5-8')
    expect_string_var('three', '2-3-4-5-6-7-8')

    feed('<C-W><C-W>')

    -- Test diffoff.
    execute('diffoff!')
    feed('1<C-W><C-W><cr>')
    execute('let &diff = 1')
    execute('let &fdm = diff_fdm')
    execute('let &fdc = diff_fdc')
    feed('4<C-W><C-W><cr>')
    execute('diffoff!')
    feed('1<C-W><C-W><cr>')
    execute('redir => nd1')
    execute('silent! :set diff? fdm? fdc? scb? crb? wrap?')
    execute('redir END')
    expect_string_var('nd1', [[
      
      
      nodiff
        foldmethod=marker
        foldcolumn=4
      noscrollbind
      nocursorbind
        wrap
      ]])
    feed('<C-W><C-W><cr>')
    execute('redir => nd2')
    execute('silent! :set diff? fdm? fdc? scb? crb? wrap?')
    execute('redir END')
    expect_string_var('nd2', [[
      
      
      nodiff
        foldmethod=marker
        foldcolumn=4
      noscrollbind
      nocursorbind
        wrap
      ]])
    feed('<C-W><C-W><cr>')
    execute('redir => nd3')
    execute('silent! :set diff? fdm? fdc? scb? crb? wrap?')
    execute('redir END')
    expect_string_var('nd2', [[
      
      
      nodiff
        foldmethod=marker
        foldcolumn=4
      noscrollbind
      nocursorbind
        wrap
      ]])
    feed('<C-W><C-W><cr>')

    -- Test that diffing shows correct filler lines.
    execute('windo :bw!')
    execute('enew')
    execute('put =range(4,10)')
    execute('1d _')
    execute('vnew')
    execute('put =range(1,10)')
    execute('1d _')
    execute('windo :diffthis')
    execute('wincmd h')
    execute([[let w0=line('w0')]])
    eq(1, eval('w0'))
  end)
end)
