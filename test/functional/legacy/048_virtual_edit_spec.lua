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
    -- Insert "keyword keyw", ESC, C CTRL-N, shows "keyword ykeyword".
    -- Repeating CTRL-N fixes it. (Mary Ellen Foster).
    insert([[
      foo, bar
      keyword keyw
      ]])
    execute('set ve=all')
    feed('2/w<cr>')
    feed('C<C-N><esc>')
    expect([[
      foo, bar
      keyword keyword
      ]])
  end)

  it('part 2', function()
    -- Using "C" then <CR> moves the last remaining character to the next
    -- line.  (Mary Ellen Foster).
    insert('all your base are belong to us')
    execute('set ve=all')
    execute('/are')
    feed('C<CR>are belong to vim<esc>')
    expect([[
      all your base 
      are belong to vim]])
  end)

  it('part 3', function()
    -- When past the end of a line that ends in a single character "b" skips
    -- that word.
    insert('1 2 3 4 5 6')
    execute('set ve=all')
    feed('^$15lbC7<esc>')
    expect('1 2 3 4 5 7')
  end)

  it('part 4', function()
    -- Make sure 'i' works.
    insert("'i'")
    execute('set ve=all')
    feed("$4li<lt>-- should be 3 ' '<esc>")
    expect("'i'   <-- should be 3 ' '")
  end)

  it('part 5', function()
    -- Make sure 'C' works.
    insert("'C'")
    execute('set ve=all')
    feed("$4lC<lt>-- should be 3 ' '<esc>")
    expect("'C'   <-- should be 3 ' '")
  end)

  it('part 6', function()
    -- Make sure 'a' works.
    insert("'a'")
    execute('set ve=all')
    feed("$4la<lt>-- should be 4 ' '<esc>")
    expect("'a'    <-- should be 4 ' '")
  end)

  it('part 7', function()
    -- Make sure 'A' works.
    insert("'A'")
    execute('set ve=all')
    feed("$4lA<lt>-- should be 0 ' '<esc>")
    expect("'A'<-- should be 0 ' '")
  end)

  it('part 8', function()
    -- Make sure 'D' works.
    insert("'D'")
    execute('set ve=all')
    feed("$4lDi<lt>-- 'D' should be intact<esc>")
    expect("'D'   <-- 'D' should be intact")
  end)

  it('part 9', function()
    -- Test for yank bug reported by Mark Waggoner.
    insert([[
      this is a test
      this is a test
      this is a test
      "r"
      ]])
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
    -- Test "r" beyond the end of the line.
    insert('"r"')
    execute('set ve=all')
    execute('/^"r"')
    feed("$5lrxa<lt>-- should be 'x'<esc>")
    expect([["r"    x<-- should be 'x']])
  end)

  it('part 11', function()
    -- Test "r" on a tab.
    -- Note that for this test, 'ts' must be 8 (the default).
    insert('"r"\t')
    execute('set ve=all')
    feed("^5lrxA<lt>-- should be '  x  '<esc>")
    expect([["r"  x  <-- should be '  x  ']])
  end)

  it('part 12', function()
    -- Test to make sure 'x' can delete control characters.
    execute('e test.in')
    execute('set ve=all')
    execute('set display=uhex')
    feed('^xxxxxxi[This line should contain only the text between the brackets.]<esc>')
    expect('[This line should contain only the text between the brackets.]')
  end)

  it('part 13', function()
    -- Test for ^Y/^E due to bad w_virtcol value, reported by.
    -- Roy <royl@netropolis.net>.
    insert('abcv6efi.him0kl')
    execute('set ve=all')
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
    -- Test for yanking and pasting using the small delete register.
    insert('foo, bar')
    execute('set ve=all')
    execute('/^foo')
    feed('dewve"-p')
    expect(', foo')
  end)
end)
