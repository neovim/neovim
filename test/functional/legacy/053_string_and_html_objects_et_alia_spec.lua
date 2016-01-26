-- Tests for string and html text objects.
-- Note that the end-of-line moves the cursor to the next test line.
-- Also test match() and matchstr()
-- Also test the gn command and repeating it.

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect
local eq, eval = helpers.eq, helpers.eval

local function expect_line(text)
  return eq(text, eval('getline(".")'))
end

local function expect_line_above(text)
  return eq(text, eval('getline(line(".")-1)'))
end

describe('text objects:', function()
  before_each(clear)

  it('quote objects', function()
    insert([[
      start: "wo\"rd\\" foo
      'foo' 'bar' 'piep'
      bla bla `quote` blah
      out " in "noXno"
      "'" 'blah' rep 'buh'
      bla `s*`d-`+++`l**` b`la
      voo "nah" sdf " asdf" sdf " sdf" sd]])
    execute('/^start:/')
    feed('da"<cr>')
    feed("0va'a'rx<cr>")
    feed('02f`da`<cr>')
    feed('0fXdi"<cr>')
    feed("03f'vi'ry<cr>")
    execute('set quoteescape=+*-')
    feed('di`<cr>')
    feed('$F"va"oha"i"rz<cr>')
    expect([[
      start: foo
      xxxxxxxxxxxx'piep'
      bla bla blah
      out " in ""
      "'" 'blah'yyyyy'buh'
      bla `` b`la
      voo "zzzzzzzzzzzzzzzzzzzzzzzzzzzzsd]])
  end)

  it('html objects', function()
    insert([[
      <begin>
      -<b>asdf<i>Xasdf</i>asdf</b>-
      -<b>asdX<i>a<i />sdf</i>asdf</b>-
      -<b>asdf<i>Xasdf</i>asdf</b>-
      -<b>asdX<i>as<b />df</i>asdf</b>-
      -<b>
      innertext object
      </b>
      </begin>]])
    execute('/^<begin')
    feed('jfXdit<cr>')
    feed('0fXdit<cr>')
    feed('fXdat<cr>')
    feed('0fXdat<cr>')
    feed('dit<cr>')
    expect([[
      <begin>
      -<b>asdf<i></i>asdf</b>-
      -<b></b>-
      -<b>asdfasdf</b>-
      --
      -<b></b>
      </begin>]])
  end)
  it('are working', function()
    insert([[
      <begin>
      -<b>asdf<i>Xasdf</i>asdf</b>-
      -<b>asdX<i>a<i />sdf</i>asdf</b>-
      -<b>asdf<i>Xasdf</i>asdf</b>-
      -<b>asdX<i>as<b />df</i>asdf</b>-
      -<b>
      innertext object
      </b>
      </begin>
      ]])

    execute('/^<begin')
    feed('jfXdit<cr>')
    feed('0fXdit<cr>')
    feed('fXdat<cr>')
    feed('0fXdat<cr>')
    feed('dit<cr>')


    -- Assert buffer contents.
    expect([[
      <begin>
      -<b>asdf<i></i>asdf</b>-
      -<b></b>-
      -<b>asdfasdf</b>-
      --
      -<b></b>
      </begin>]])
  end)
end)
describe('text matching functions:', function()
  before_each(clear)
  it('matchstr()', function()
    eq('b',  eval([[matchstr("abcd", ".",  0,  2)]]))
    eq('bc', eval([[matchstr("abcd", "..", 0,  2)]]))
    -- next line: zero and negative -> first match
    eq('c',  eval([[matchstr("abcd", ".",  2,  0)]]))
    eq('a',  eval([[matchstr("abcd", ".",  0, -1)]]))
  end)
  it('match()', function()
    eq(-1, eval("match('abcd', '.', 0, 5)"))
    eq(0,  eval("match('abcd', '.', 0, -1)"))
    eq(0,  eval("match('abc', '.', 0, 1)"))
    eq(1,  eval("match('abc', '.', 0, 2)"))
    eq(2,  eval("match('abc', '.', 0, 3)"))
    eq(-1, eval("match('abc', '.', 0, 4)"))
    eq(1,  eval("match('abc', '.', 1, 1)"))
    eq(2,  eval("match('abc', '.', 2, 1)"))
    eq(-1, eval("match('abc', '.', 3, 1)"))
    eq(3,  eval("match('abc', '$', 0, 1)"))
    eq(-1, eval("match('abc', '$', 0, 2)"))
    eq(3,  eval("match('abc', '$', 1, 1)"))
    eq(3,  eval("match('abc', '$', 2, 1)"))
    eq(3,  eval("match('abc', '$', 3, 1)"))
    eq(-1, eval("match('abc', '$', 4, 1)"))
    eq(0,  eval([[match('abc', '\zs', 0, 1)]]))
    eq(1,  eval([[match('abc', '\zs', 0, 2)]]))
    eq(2,  eval([[match('abc', '\zs', 0, 3)]]))
    eq(3,  eval([[match('abc', '\zs', 0, 4)]]))
    eq(-1, eval([[match('abc', '\zs', 0, 5)]]))
    eq(1,  eval([[match('abc', '\zs', 1, 1)]]))
    eq(2,  eval([[match('abc', '\zs', 2, 1)]]))
    eq(3,  eval([[match('abc', '\zs', 3, 1)]]))
    eq(-1, eval([[match('abc', '\zs', 4, 1)]]))
  end)
end)
describe('search and gn (and repeat)', function()
  it('search and gn', function()
    insert([[
      SEARCH:
      foobar
      one
      two
      abcdx | abcdx | abcdx
      join 
      lines
      zero width pattern
      delete first and last chars
      uniquepattern uniquepattern
      my very excellent mother just served us nachos
      for (i=0; i<=10; i++)
      a:10
      
      a:1
      
      a:20
      Y
      text
      Y
      --1
      Johnny
      --2
      Johnny
      --3
      Depp
      --4
      Depp
      --5
      end:]])
    execute('/^foobar')
    feed('gncsearchmatch<esc>')
    execute([[/one\_s*two\_s]])
    execute('1')
    feed('gnd<cr>')
    execute('/[a]bcdx')
    execute('1')
    feed('2gnd/join<cr>')
    execute('/$')
    feed('0gnd<cr>')
    execute([[/\>\zs]])
    feed('0gnd/^<cr>')
    feed([[gnd$h/\zs<cr>]])
    feed('gnd/[u]niquepattern/s<cr>')
    feed('vlgnd<cr>')
    execute('/mother')
    execute('set selection=exclusive')
    feed('$cgNmongoose<esc>/i<cr>')
    feed('cgnj<esc>')
    -- Make sure there is no other match y uppercase.
    execute('/x59')
    feed('gggnd<cr>')
    -- Test repeating dgn.
    execute('/^Johnny')
    feed('ggdgn.<cr>')
    -- Test repeating gUgn.
    execute('/^Depp')
    feed('gggUgn.<cr>')
    feed([[gg/a:0\@!\zs\d\+<cr>]])
    feed('nygno<esc>p<cr>')
    expect([[
      SEARCH:
      searchmatch
      abcdx |  | abcdx
      join lines
      zerowidth pattern
      elete first and last char
       uniquepattern
      my very excellent mongoose just served us nachos
      for (j=0; i<=10; i++)
      a:10
      
      a:1
      1
      
      a:20
      
      text
      Y
      --1
      
      --2
      
      --3
      DEPP
      --4
      DEPP
      --5
      end:]])
  end)
end)
