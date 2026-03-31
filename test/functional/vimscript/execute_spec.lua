local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local eq = t.eq
local eval = n.eval
local clear = n.clear
local source = n.source
local exc_exec = n.exc_exec
local pcall_err = t.pcall_err
local fn = n.fn
local command = n.command
local feed = n.feed
local is_os = t.is_os

describe('execute()', function()
  before_each(clear)

  it('captures the same result as :redir', function()
    command([[
      echomsg 'foo 1'
      echomsg 'foo 2'
      redir => g:__redir_output
        silent! messages
      redir END
    ]])
    eq(eval('g:__redir_output'), fn.execute('messages'))
  end)

  it('captures the concatenated outputs of a List of commands', function()
    eq('foobar', fn.execute({ 'echon "foo"', 'echon "bar"' }))
    eq('\nfoo\nbar', fn.execute({ 'echo "foo"', 'echo "bar"' }))
  end)

  it('supports nested execute("execute(...)")', function()
    eq('42', fn.execute([[echon execute("echon execute('echon 42')")]]))
  end)

  it('supports nested :redir to a variable', function()
    source([[
    function! g:Foo()
      let a = ''
      redir => a
      silent echon "foo"
      redir END
      return a
    endfunction
    function! g:Bar()
      let a = ''
      redir => a
      silent echon "bar1"
      call g:Foo()
      silent echon "bar2"
      redir END
      silent echon "bar3"
      return a
    endfunction
    ]])
    eq('top1bar1foobar2bar3', fn.execute('echon "top1"|call g:Bar()'))
  end)

  it('supports nested :redir to a register', function()
    source([[
    let @a = ''
    function! g:Foo()
      redir @a>>
      silent echon "foo"
      redir END
      return @a
    endfunction
    function! g:Bar()
      redir @a>>
      silent echon "bar1"
      call g:Foo()
      silent echon "bar2"
      redir END
      silent echon "bar3"
      return @a
    endfunction
    ]])
    eq('top1bar1foobar2bar3', fn.execute('echon "top1"|call g:Bar()'))
    -- :redir itself doesn't nest, so the redirection ends in g:Foo
    eq('bar1foo', eval('@a'))
  end)

  it('captures a transformed string', function()
    eq('^A', fn.execute('echon "\\<C-a>"'))
  end)

  it('returns empty string if the argument list is empty', function()
    eq('', fn.execute({}))
    eq(0, exc_exec('let g:ret = execute(v:_null_list)'))
    eq('', eval('g:ret'))
  end)

  it('captures errors', function()
    local ret
    ret = exc_exec('call execute(v:_null_dict)')
    eq('Vim(call):E731: Using a Dictionary as a String', ret)
    ret = exc_exec('call execute(function("tr"))')
    eq('Vim(call):E729: Using a Funcref as a String', ret)
    ret = exc_exec('call execute(["echo 42", v:_null_dict, "echo 44"])')
    eq('Vim:E731: Using a Dictionary as a String', ret)
    ret = exc_exec('call execute(["echo 42", function("tr"), "echo 44"])')
    eq('Vim:E729: Using a Funcref as a String', ret)
  end)

  it('captures output with highlights', function()
    eq(
      '\nErrorMsg       xxx ctermfg=15 ctermbg=1 guifg=White guibg=Red',
      eval('execute("hi ErrorMsg")')
    )
  end)

  it('does not corrupt the command display #5422', function()
    local screen = Screen.new(70, 7)
    feed(':echo execute("hi ErrorMsg")<CR>')
    screen:expect(
      [[
                                                                            |
      {1:~                                                                     }|*2
      {2:                                                                      }|
                                                                            |
      ErrorMsg       xxx ctermfg=15 ctermbg=1 guifg=White guibg=Red         |
      {3:Press ENTER or type command to continue}^                               |
    ]],
      {
        [1] = { bold = true, foreground = Screen.colors.Blue1 },
        [2] = { bold = true, reverse = true },
        [3] = { bold = true, foreground = Screen.colors.SeaGreen4 },
      }
    )
    feed('<CR>')
  end)

  it('places cursor correctly #6035', function()
    local screen = Screen.new(40, 6)
    source([=[
      " test 1: non-silenced output goes as usual
      function! Test1()
        echo 1234
        let x = execute('echon "abcdef"', '')
        echon 'ABCD'
      endfunction

      " test 2: silenced output does not affect ui
      function! Test2()
        echo 1234
        let x = execute('echon "abcdef"', 'silent')
        echon 'ABCD'
      endfunction

      " test 3: silenced! error does not affect ui
      function! Test3()
        echo 1234
        let x = execute('echoerr "abcdef"', 'silent!')
        echon 'ABCDXZYZ'
      endfunction

      " test 4: silenced echoerr goes as usual
      " bug here
      function! Test4()
        echo 1234
        let x = execute('echoerr "abcdef"', 'silent')
        echon 'ABCD'
      endfunction

      " test 5: silenced! echoerr does not affect ui
      function! Test5()
        echo 1234
        let x = execute('echoerr "abcdef"', 'silent!')
        echon 'ABCD'
      endfunction

      " test 6: silenced error goes as usual
      function! Test6()
        echo 1234
        let x = execute('echo undefined', 'silent')
        echon 'ABCD'
      endfunction

      " test 7: existing error does not mess the result
      function! Test7()
        " display from Test6() is still visible
        " why does the "abcdef" goes into a newline
        let x = execute('echon "abcdef"', '')
        echon 'ABCD'
      endfunction
    ]=])

    feed([[:call Test1()<cr>]])
    screen:expect([[
      ^                                        |
      {1:~                                       }|*4
      ABCD                                    |
    ]])

    feed([[:call Test2()<cr>]])
    screen:expect([[
      ^                                        |
      {1:~                                       }|*4
      1234ABCD                                |
    ]])

    feed([[:call Test3()<cr>]])
    screen:expect([[
      ^                                        |
      {1:~                                       }|*4
      1234ABCDXZYZ                            |
    ]])

    feed([[:call Test4()<cr>]])
    -- unexpected: need to fix
    -- echoerr does not set did_emsg
    -- "ef" was overwritten since msg_col was recovered wrongly
    screen:expect([[
      {3:                                        }|
      1234                                    |
      {9:Error in function Test4:}                |
      {8:line    2:}                              |
      {9:abcd}ABCD                                |
      {6:Press ENTER or type command to continue}^ |
    ]])

    feed([[<cr>]]) -- to clear screen
    feed([[:call Test5()<cr>]])
    screen:expect([[
      ^                                        |
      {1:~                                       }|*4
      1234ABCD                                |
    ]])

    feed([[:call Test6()<cr>]])
    screen:expect([[
      {3:                                        }|
                                              |
      {9:Error in function Test6:}                |
      {8:line    2:}                              |
      {9:E121}ABCD                                |
      {6:Press ENTER or type command to continue}^ |
    ]])

    feed([[:call Test7()<cr>]])
    screen:expect([[
                                              |
      {9:Error in function Test6:}                |
      {8:line    2:}                              |
      {9:E121}ABCD                                |
      ABCD                                    |
      {6:Press ENTER or type command to continue}^ |
    ]])
  end)

  -- This deviates from vim behavior, but is consistent
  -- with how nvim currently displays the output.
  it('captures shell-command output', function()
    local win_lf = is_os('win') and '\13' or ''
    eq('\n:!echo foo\r\n\nfoo' .. win_lf .. '\n', fn.execute('!echo foo'))
  end)

  describe('{silent} argument', function()
    it('captures & displays output for ""', function()
      local screen = Screen.new(40, 5)
      command('let g:mes = execute("echon 42", "")')
      screen:expect([[
      ^                                        |
      {1:~                                       }|*3
      42                                      |
      ]])
      eq('42', eval('g:mes'))
    end)

    it('gives E493 instead of prompting on backwards range for ""', function()
      command('split')
      eq(
        'Vim(windo):E493: Backwards range given: 2,1windo echo',
        pcall_err(fn.execute, '2,1windo echo', '')
      )
      eq(
        'Vim(windo):E493: Backwards range given: 2,1windo echo',
        pcall_err(fn.execute, { '2,1windo echo' }, '')
      )
    end)

    it('captures but does not display output for "silent"', function()
      local screen = Screen.new(40, 5)
      command('let g:mes = execute("echon 42")')
      screen:expect([[
      ^                                        |
      {1:~                                       }|*3
                                              |
      ]])
      eq('42', eval('g:mes'))

      command('let g:mes = execute("echon 13", "silent")')
      screen:expect {
        grid = [[
      ^                                        |
      {1:~                                       }|*3
                                              |
      ]],
        unchanged = true,
      }
      eq('13', eval('g:mes'))
    end)

    it('suppresses errors for "silent!"', function()
      eq(0, exc_exec('let g:mes = execute(0.0, "silent!")'))
      eq('', eval('g:mes'))

      eq(0, exc_exec('let g:mes = execute("echon add(1, 1)", "silent!")'))
      eq('1', eval('g:mes'))

      eq(0, exc_exec('let g:mes = execute(["echon 42", "echon add(1, 1)"], "silent!")'))
      eq('421', eval('g:mes'))
    end)

    it('propagates errors for "" and "silent"', function()
      local ret
      ret = exc_exec('call execute(v:_null_dict, "silent")')
      eq('Vim(call):E731: Using a Dictionary as a String', ret)

      ret = exc_exec('call execute("echo add(1, 1)", "")')
      eq('Vim(echo):E897: List or Blob required', ret)

      ret = exc_exec('call execute(["echon 42", "echo add(1, 1)"], "")')
      eq('Vim(echo):E897: List or Blob required', ret)

      ret = exc_exec('call execute("echo add(1, 1)", "silent")')
      eq('Vim(echo):E897: List or Blob required', ret)

      ret = exc_exec('call execute(["echon 42", "echo add(1, 1)"], "silent")')
      eq('Vim(echo):E897: List or Blob required', ret)
    end)
  end)
end)
