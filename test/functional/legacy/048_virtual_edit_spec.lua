-- This is a test of 'virtualedit'.

local helpers = require('test.functional.helpers')
local feed, insert, clear, execute, expect, write_file =
  helpers.feed, helpers.insert, helpers.clear, helpers.execute,
  helpers.expect, helpers.write_file

describe('virtualedit', function()

  setup(function()
    write_file('test.in', 'a\x16b\x0dsd\n')
  end)
  before_each(clear)
  teardown(function()
    os.remove('test.in')
  end)

  it('part 1', function()
    insert([[
      foo, bar
      keyword keyw
      ]])
    execute('set ve=all')
    -- Insert "keyword keyw", ESC, C CTRL-N, shows "keyword ykeyword".
    -- Repeating CTRL-N fixes it. (Mary Ellen Foster).
    feed('2/w<cr>')
    feed('C<C-N><esc>')
    expect([[
      foo, bar
      keyword keyword
      ]])
  end)

  it('part 2', function()
    insert('all your base are belong to us')
    execute('set ve=all')
    -- Using "C" then <CR> moves the last remaining character to the next
    -- line.  (Mary Ellen Foster).
    execute('/are')
    feed('C<CR>are belong to vim<esc>')
    expect([[
      all your base 
      are belong to vim]])
  end)

  it('part 3', function()
    insert('1 2 3 4 5 6')
    execute('set ve=all')
    -- When past the end of a line that ends in a single character "b" skips
    -- that word.
    feed('^$15lbC7<esc>')
    expect('1 2 3 4 5 7')
  end)

  it('part 4', function()
    insert("'i'")
    execute('set ve=all')
    -- Make sure 'i' works.
    feed("$4li<lt>-- should be 3 ' '<esc>")
    expect("'i'   <-- should be 3 ' '")
  end)

  it('part 5', function()
    insert("'C'")
    execute('set ve=all')
    -- Make sure 'C' works.
    feed("$4lC<lt>-- should be 3 ' '<esc>")
    expect("'C'   <-- should be 3 ' '")
  end)

  it('part 6', function()
    insert("'a'")
    execute('set ve=all')
    -- Make sure 'a' works.
    feed("$4la<lt>-- should be 4 ' '<esc>")
    expect("'a'    <-- should be 4 ' '")
  end)

  it('part 7', function()
    insert("'A'")
    execute('set ve=all')
    -- Make sure 'A' works.
    feed("$4lA<lt>-- should be 0 ' '<esc>")
    expect("'A'<-- should be 0 ' '")
  end)

  it('part 8', function()
    insert("'D'")
    execute('set ve=all')
    -- Make sure 'D' works.
    feed("$4lDi<lt>-- 'D' should be intact<esc>")
    expect("'D'   <-- 'D' should be intact")
  end)

  it('part 9', function()
    insert([[
      this is a test
      this is a test
      this is a test
      "r"
      ]])
    -- Test for yank bug reported by Mark Waggoner.
    execute('set ve=block')
    feed('gg^2w<C-V>3jyGp<cr>')
    expect([[
      this is a test
      this is a test
      this is a test
      "r"
      a
      a
      a
       ]])
  end)

  it('part 10', function()
    insert('"r"')
    execute('set ve=all')
    -- Test "r" beyond the end of the line.
    execute('/^"r"')
    feed("$5lrxa<lt>-- should be 'x'<esc>")
    expect([["r"    x<-- should be 'x']])
  end)

  it('part 11', function()
    insert('"r"\t')
    execute('set ve=all')
    -- Test "r" on a tab.
    -- Note that for this test, 'ts' must be 8 (the default).
    feed("^5lrxA<lt>-- should be '  x  '<esc>")
    expect([["r"  x  <-- should be '  x  ']])
  end)

  it('part 12', function()
    execute('e test.in')
    execute('set ve=all')
    -- Test to make sure 'x' can delete control characters.
    execute('set display=uhex')
    feed('^xxxxxxi[This line should contain only the text between the brackets.]<esc>')
    expect('[This line should contain only the text between the brackets.]')
  end)

  it('part 13', function()
    insert('abcv6efi.him0kl')
    execute('set ve=all')
    -- Test for ^Y/^E due to bad w_virtcol value, reported by.
    -- Roy <royl@netropolis.net>.
    feed('^O<esc>3li<C-E><esc>4li<C-E><esc>4li<C-E>   <lt>-- should show the name of a noted text editor<esc><CR>')
    feed('^o<esc>4li<C-Y><esc>4li<C-Y><esc>4li<C-Y>   <lt>-- and its version number<esc>-dd<cr>')
    -- We need an extra newline character because the helpers function
    -- dedent() is used in expect().  If we don't have this newline the string
    -- delimiter of the expect() argument goes after "number" but then
    -- dedent() messes up the indent of the lines.
    feed('Go<esc>')
    expect([[
         v   i   m   <-- should show the name of a noted text editor
          6   .   0   <-- and its version number
      ]])
  end)

  it('part 14', function()
    insert('foo, bar')
    execute('set ve=all')
    -- Test for yanking and pasting using the small delete register.
    execute('/^foo')
    feed('dewve"-p')
    expect(', foo')
  end)
end)
