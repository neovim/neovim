-- Tests if :mksession saves cursor columns correctly in presence of tab and
-- multibyte characters when fileencoding=latin1.
--
-- Same as legacy test 92 but using Latin-1 file encoding.

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('store cursor position in session file in Latin-1', function()
  setup(clear)

  teardown(function()
    os.remove('test.in')
    os.remove('test.out')
  end)

  it('is working', function()
    insert([[
      start:
      no multibyte chAracter
      	one leaDing tab
          four leadinG spaces
      two		consecutive tabs
      two	tabs	in one line
      one � multibyteCharacter
      a� �  two multiByte characters
      A���  three mulTibyte characters]])
    -- Must write buffer to disk for :mksession. See the comments in
    -- "092_mksession_cursor_cols_utf8_spec.lua".
    execute('write! test.in')

    execute('set sessionoptions=buffers splitbelow fileencoding=latin1')

    -- Move the cursor through the buffer lines and position it with "|".
    execute('/^start:')
    execute('vsplit')
    feed('j16|:split<cr>')
    feed('j16|:split<cr>')
    feed('j16|:split<cr>')
    feed('j8|:split<cr>')
    feed('j8|:split<cr>')
    feed('j16|:split<cr>')
    feed('j16|:split<cr>')
    feed('j16|')

    -- Again move the cursor through the buffer and position it with "|". This
    -- time also perform a horizontal scroll at every step.
    execute('wincmd l')
    execute('/^start:')
    execute('set nowrap')
    feed('j16|3zl:split<cr>')
    feed('j016|3zl:split<cr>')
    feed('j016|3zl:split<cr>')
    feed('j08|3zl:split<cr>')
    feed('j08|3zl:split<cr>')
    feed('j016|3zl:split<cr>')
    feed('j016|3zl:split<cr>')
    feed('j016|3zl:split<cr>')

    -- Create the session file, read it back in, and prepare for verification.
    execute('mksession! test.out')
    execute('new test.out')
    execute([[v/\(^ *normal! 0\|^ *exe 'normal!\)/d]])

    -- Assert buffer contents.
    expect([[
      normal! 016|
      normal! 016|
      normal! 016|
      normal! 08|
      normal! 08|
      normal! 016|
      normal! 016|
      normal! 016|
        exe 'normal! ' . s:c . '|zs' . 16 . '|'
        normal! 016|
        exe 'normal! ' . s:c . '|zs' . 16 . '|'
        normal! 016|
        exe 'normal! ' . s:c . '|zs' . 16 . '|'
        normal! 016|
        exe 'normal! ' . s:c . '|zs' . 8 . '|'
        normal! 08|
        exe 'normal! ' . s:c . '|zs' . 8 . '|'
        normal! 08|
        exe 'normal! ' . s:c . '|zs' . 16 . '|'
        normal! 016|
        exe 'normal! ' . s:c . '|zs' . 16 . '|'
        normal! 016|
        exe 'normal! ' . s:c . '|zs' . 16 . '|'
        normal! 016|
        exe 'normal! ' . s:c . '|zs' . 16 . '|'
        normal! 016|]])
  end)
end)
