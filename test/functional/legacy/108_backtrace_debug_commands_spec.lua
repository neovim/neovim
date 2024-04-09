-- Tests for backtrace debug commands.

local t = require('test.functional.testutil')()
local command = t.command
local feed, clear = t.feed, t.clear
local feed_command, expect = t.feed_command, t.expect

describe('108', function()
  before_each(clear)

  it('is working', function()
    command('set shortmess-=F')
    feed_command('lang mess C')
    feed_command('function! Foo()')
    feed_command('   let var1 = 1')
    feed_command('   let var2 = Bar(var1) + 9')
    feed_command('   return var2')
    feed_command('endfunction')
    feed_command('function! Bar(var)')
    feed_command('    let var1 = 2 + a:var')
    feed_command('    let var2 = Bazz(var1) + 4')
    feed_command('    return var2')
    feed_command('endfunction')
    feed_command('function! Bazz(var)')
    feed_command('    let var1 = 3 + a:var')
    feed_command('    let var3 = "another var"')
    feed_command('    return var1')
    feed_command('endfunction')
    feed_command('new')
    feed_command('debuggreedy')
    feed_command('redir => out')
    feed_command('debug echo Foo()')
    feed('step<cr>')
    feed('step<cr>')
    feed('step<cr>')
    feed('step<cr>')
    feed('step<cr>')
    feed('step<cr>')
    feed([[echo "- show backtrace:\n"<cr>]])
    feed('backtrace<cr>')
    feed([[echo "\nshow variables on different levels:\n"<cr>]])
    feed('echo var1<cr>')
    feed('up<cr>')
    feed('back<cr>')
    feed('echo var1<cr>')
    feed('u<cr>')
    feed('bt<cr>')
    feed('echo var1<cr>')
    feed([[echo "\n- undefined vars:\n"<cr>]])
    feed('step<cr>')
    feed('frame 2<cr>')
    feed('echo "undefined var3 on former level:"<cr>')
    feed('echo var3<cr>')
    feed('fr 0<cr>')
    feed([[echo "here var3 is defined with \"another var\":"<cr>]])
    feed('echo var3<cr>')
    feed('step<cr>')
    feed('step<cr>')
    feed('step<cr>')
    feed('up<cr>')
    feed([[echo "\nundefined var2 on former level"<cr>]])
    feed('echo var2<cr>')
    feed('down<cr>')
    feed('echo "here var2 is defined with 10:"<cr>')
    feed('echo var2<cr>')
    feed([[echo "\n- backtrace movements:\n"<cr>]])
    feed('b<cr>')
    feed([[echo "\nnext command cannot go down, we are on bottom\n"<cr>]])
    feed('down<cr>')
    feed('up<cr>')
    feed([[echo "\nnext command cannot go up, we are on top\n"<cr>]])
    feed('up<cr>')
    feed('b<cr>')
    feed('echo "fil is not frame or finish, it is file"<cr>')
    feed('fil<cr>')
    feed([[echo "\n- relative backtrace movement\n"<cr>]])
    feed('fr -1<cr>')
    feed('frame<cr>')
    feed('fra +1<cr>')
    feed('fram<cr>')
    feed([[echo "\n- go beyond limits does not crash\n"<cr>]])
    feed('fr 100<cr>')
    feed('fra<cr>')
    feed('frame -40<cr>')
    feed('fram<cr>')
    feed([[echo "\n- final result 19:"<cr>]])
    feed('cont<cr>')
    feed_command('0debuggreedy')
    feed_command('redir END')
    feed_command('$put =out')

    -- Assert buffer contents.
    expect([=[



      - show backtrace:

        2 function Foo[2]
        1 Bar[2]
      ->0 Bazz
      line 2: let var3 = "another var"

      show variables on different levels:

      6
        2 function Foo[2]
      ->1 Bar[2]
        0 Bazz
      line 2: let var3 = "another var"
      3
      ->2 function Foo[2]
        1 Bar[2]
        0 Bazz
      line 2: let var3 = "another var"
      1

      - undefined vars:

      undefined var3 on former level:
      Error detected while processing function Foo[2]..Bar[2]..Bazz:
      line    3:
      E121: Undefined variable: var3
      here var3 is defined with "another var":
      another var

      undefined var2 on former level
      Error detected while processing function Foo[2]..Bar:
      line    3:
      E121: Undefined variable: var2
      here var2 is defined with 10:
      10

      - backtrace movements:

        1 function Foo[2]
      ->0 Bar
      line 3: End of function

      next command cannot go down, we are on bottom

      frame is zero

      next command cannot go up, we are on top

      frame at highest level: 1
      ->1 function Foo[2]
        0 Bar
      line 3: End of function
      fil is not frame or finish, it is file
      "[No Name]" --No lines in buffer--

      - relative backtrace movement

        1 function Foo[2]
      ->0 Bar
      line 3: End of function
      ->1 function Foo[2]
        0 Bar
      line 3: End of function

      - go beyond limits does not crash

      frame at highest level: 1
      ->1 function Foo[2]
        0 Bar
      line 3: End of function
      frame is zero
        1 function Foo[2]
      ->0 Bar
      line 3: End of function

      - final result 19:
      19
      ]=])
  end)
end)
