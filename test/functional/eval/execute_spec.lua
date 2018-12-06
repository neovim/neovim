local helpers = require('test.functional.helpers')(after_each)
local eq = helpers.eq
local eval = helpers.eval
local clear = helpers.clear
local source = helpers.source
local redir_exec = helpers.redir_exec
local exc_exec = helpers.exc_exec
local funcs = helpers.funcs
local Screen = require('test.functional.ui.screen')
local command = helpers.command
local feed = helpers.feed
local iswin = helpers.iswin

describe('execute()', function()
  before_each(clear)

  it('captures the same result as :redir', function()
    eq(redir_exec('messages'), funcs.execute('messages'))
  end)

  it('captures the concatenated outputs of a List of commands', function()
    eq("foobar", funcs.execute({'echon "foo"', 'echon "bar"'}))
    eq("\nfoo\nbar", funcs.execute({'echo "foo"', 'echo "bar"'}))
  end)

  it('supports nested execute("execute(...)")', function()
    eq('42', funcs.execute([[echon execute("echon execute('echon 42')")]]))
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
    eq('top1bar1foobar2bar3', funcs.execute('echon "top1"|call g:Bar()'))
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
    eq('top1bar1foobar2bar3', funcs.execute('echon "top1"|call g:Bar()'))
    -- :redir itself doesn't nest, so the redirection ends in g:Foo
    eq('bar1foo', eval('@a'))
  end)

  it('captures a transformed string', function()
    eq('^A', funcs.execute('echon "\\<C-a>"'))
  end)

  it('returns empty string if the argument list is empty', function()
    eq('', funcs.execute({}))
    eq(0, exc_exec('let g:ret = execute(v:_null_list)'))
    eq('', eval('g:ret'))
  end)

  it('captures errors', function()
    local ret
    ret = exc_exec('call execute(0.0)')
    eq('Vim(call):E806: using Float as a String', ret)
    ret = exc_exec('call execute(v:_null_dict)')
    eq('Vim(call):E731: using Dictionary as a String', ret)
    ret = exc_exec('call execute(function("tr"))')
    eq('Vim(call):E729: using Funcref as a String', ret)
    ret = exc_exec('call execute(["echo 42", 0.0, "echo 44"])')
    eq('Vim:E806: using Float as a String', ret)
    ret = exc_exec('call execute(["echo 42", v:_null_dict, "echo 44"])')
    eq('Vim:E731: using Dictionary as a String', ret)
    ret = exc_exec('call execute(["echo 42", function("tr"), "echo 44"])')
    eq('Vim:E729: using Funcref as a String', ret)
  end)

  it('captures output with highlights', function()
    eq('\nErrorMsg       xxx ctermfg=15 ctermbg=1 guifg=White guibg=Red',
       eval('execute("hi ErrorMsg")'))
  end)

  it('does not corrupt the command display #5422', function()
    local screen = Screen.new(70, 7)
    screen:attach()
    feed(':echo execute("hi ErrorMsg")<CR>')
    screen:expect([[
                                                                            |
      {1:~                                                                     }|
      {1:~                                                                     }|
      {2:                                                                      }|
      :echo execute("hi ErrorMsg")                                          |
      ErrorMsg       xxx ctermfg=15 ctermbg=1 guifg=White guibg=Red         |
      {3:Press ENTER or type command to continue}^                               |
    ]], {
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {bold = true, reverse = true},
      [3] = {bold = true, foreground = Screen.colors.SeaGreen4},
    })
    feed('<CR>')
  end)

  it('places cursor correctly #6035', function()
    local screen = Screen.new(40, 5)
    screen:attach()
    source([=[
      " test 1
      function! Test1a()
        echo 12345678
        let x = execute('echo 1234567890', '')
        echon '1234'
      endfunction

      function! Test1b()
        echo 12345678
        echo 1234567890
        echon '1234'
      endfunction

      " test 2
      function! Test2a()
        echo 12345678
        let x = execute('echo 1234567890', 'silent')
        echon '1234'
      endfunction

      function! Test2b()
        echo 12345678
        silent echo 1234567890
        echon '1234'
      endfunction

      " test 3
      function! Test3a()
        echo 12345678
        let x = execute('echoerr 1234567890', 'silent!')
        echon '1234'
      endfunction

      function! Test3b()
        echo 12345678
        silent! echoerr 1234567890
        echon '1234'
      endfunction

      " test 4
      function! Test4a()
        echo 12345678
        let x = execute('echoerr 1234567890', 'silent')
        echon '1234'
      endfunction

      function! Test4b()
        echo 12345678
        silent echoerr 1234567890
        echon '1234'
      endfunction
    ]=])

    feed([[:call Test1a()<cr>]])
    screen:expect([[
                                              |
                                              |
      12345678                                |
      12345678901234                          |
      Press ENTER or type command to continue^ |
    ]])

    feed([[:call Test1b()<cr>]])
    screen:expect([[
      12345678                                |
      12345678901234                          |
      12345678                                |
      12345678901234                          |
      Press ENTER or type command to continue^ |
    ]])

    feed([[:call Test2a()<cr>]])
    screen:expect([[
      12345678901234                          |
      12345678                                |
      12345678901234                          |
      123456781234                            |
      Press ENTER or type command to continue^ |
    ]])

    feed([[:call Test2b()<cr>]])
    screen:expect([[
      12345678                                |
      12345678901234                          |
      123456781234                            |
      123456781234                            |
      Press ENTER or type command to continue^ |
    ]])

    feed([[:call Test3a()<cr>]])
    screen:expect([[
      12345678901234                          |
      123456781234                            |
      123456781234                            |
      123456781234                            |
      Press ENTER or type command to continue^ |
    ]])

    feed([[:call Test3b()<cr>]])
    screen:expect([[
      123456781234                            |
      123456781234                            |
      123456781234                            |
      123456781234                            |
      Press ENTER or type command to continue^ |
    ]])

    feed([[:call Test4a()<cr>]])
    screen:expect([[
      Error detected while processing function|
       Test4a:                                |
      line    2:                              |
      123456781234                            |
      Press ENTER or type command to continue^ |
    ]])

    feed([[:call Test4b()<cr>]])
    screen:expect([[
      Error detected while processing function|
       Test4b:                                |
      line    2:                              |
      12345678901234                          |
      Press ENTER or type command to continue^ |
    ]])


  end)

  -- This deviates from vim behavior, but is consistent
  -- with how nvim currently displays the output.
  it('captures shell-command output', function()
    local win_lf = iswin() and '\13' or ''
    eq('\n:!echo foo\r\n\nfoo'..win_lf..'\n', funcs.execute('!echo foo'))
  end)

  describe('{silent} argument', function()
    it('captures & displays output for ""', function()
      local screen = Screen.new(40, 5)
      screen:attach()
      command('let g:mes = execute("echon 42", "")')
      screen:expect([[
      ^                                        |
      ~                                       |
      ~                                       |
      ~                                       |
      42                                      |
      ]])
      eq('42', eval('g:mes'))
    end)

    it('captures but does not display output for "silent"', function()
      local screen = Screen.new(40, 5)
      screen:attach()
      command('let g:mes = execute("echon 42")')
      screen:expect([[
      ^                                        |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
      ]])
      eq('42', eval('g:mes'))

      command('let g:mes = execute("echon 13", "silent")')
      screen:expect{grid=[[
      ^                                        |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
      ]], unchanged=true}
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
      ret = exc_exec('call execute(0.0, "")')
      eq('Vim(call):E806: using Float as a String', ret)

      ret = exc_exec('call execute(v:_null_dict, "silent")')
      eq('Vim(call):E731: using Dictionary as a String', ret)

      ret = exc_exec('call execute("echo add(1, 1)", "")')
      eq('Vim(echo):E714: List required', ret)

      ret = exc_exec('call execute(["echon 42", "echo add(1, 1)"], "")')
      eq('Vim(echo):E714: List required', ret)

      ret = exc_exec('call execute("echo add(1, 1)", "silent")')
      eq('Vim(echo):E714: List required', ret)

      ret = exc_exec('call execute(["echon 42", "echo add(1, 1)"], "silent")')
      eq('Vim(echo):E714: List required', ret)
    end)
  end)
end)
