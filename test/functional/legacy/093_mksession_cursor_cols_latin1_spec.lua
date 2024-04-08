-- Tests if :mksession saves cursor columns correctly in presence of tab and
-- multibyte characters when fileencoding=latin1.
--
-- Same as legacy test 92 but using Latin-1 file encoding.

local t = require('test.functional.testutil')(after_each)
local feed, insert = t.feed, t.insert
local clear, feed_command, expect = t.clear, t.feed_command, t.expect

describe('store cursor position in session file in Latin-1', function()
  setup(clear)

  teardown(function()
    os.remove('test.in')
    os.remove('test.out')
  end)

  -- luacheck: ignore 621 (Indentation)
  it('is working', function()
    insert([[
      start:
      no multibyte chAracter
      	one leaDing tab
          four leadinG spaces
      two		consecutive tabs
      two	tabs	in one line
      one ä multibyteCharacter
      aä Ä  two multiByte characters
      Aäöü  three mulTibyte characters]])
    -- Must write buffer to disk for :mksession. See the comments in
    -- "092_mksession_cursor_cols_utf8_spec.lua".
    feed_command('write! test.in')

    feed_command('set sessionoptions=buffers splitbelow fileencoding=latin1')

    -- Move the cursor through the buffer lines and position it with "|".
    feed_command('/^start:')
    feed_command('vsplit')
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
    feed_command('wincmd l')
    feed_command('/^start:')
    feed_command('set nowrap')
    feed('j16|3zl:split<cr>')
    feed('j016|3zl:split<cr>')
    feed('j016|3zl:split<cr>')
    feed('j08|3zl:split<cr>')
    feed('j08|3zl:split<cr>')
    feed('j016|3zl:split<cr>')
    feed('j016|3zl:split<cr>')
    feed('j016|3zl:split<cr>')

    -- Create the session file, read it back in, and prepare for verification.
    feed_command('mksession! test.out')
    feed_command('new test.out')
    feed_command([[v/\(^ *normal! 0\|^ *exe 'normal!\)/d]])

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
