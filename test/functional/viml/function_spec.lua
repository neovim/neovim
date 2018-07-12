local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local clear = helpers.clear
local dedent = helpers.dedent
local redir_exec = helpers.redir_exec

before_each(clear)

local function check_func(fname, body, indent)
  if type(body) == 'number' then
    body = ('return %i'):format(body)
  end
  eq(dedent(([[

      function %s()%s
      endfunction]]
    ), 3):format(
      fname,
      body and ('\n1' .. (' '):rep(2 + (indent or 8)) .. body) or ''),
  redir_exec('function ' .. fname))
end

describe(':endfunction', function()
  it('accepts bang', function()
    eq('', redir_exec([[
      function F()
      endfunction!
    ]]))
    check_func('F')
    eq('', redir_exec([[
      function! F()
        return 1
      endfunction!
    ]]))
    check_func('F', 1)
  end)
  it('accepts comments', function()
    eq('', redir_exec([[
      function F1()
      endfunction " Comment
    ]]))
    check_func('F1')
    eq('', redir_exec([[
      function F2()
      endfunction " }}}
    ]]))
    check_func('F2')
    eq('', redir_exec([[
      function F3()
      endfunction " F3
    ]]))
    check_func('F3')
    eq('', redir_exec([[
      function F4()
      endfunction! " F4
    ]]))
    check_func('F4')
    eq('', redir_exec([[
      function! F4()
        return 2
      endfunction! " F4
    ]]))
    check_func('F4', 2)
  end)
  it('accepts function name', function()
    eq('', redir_exec([[
      function F0()
      endfunction F0
    ]]))
    check_func('F0')
    eq('', redir_exec([[
      function F1()
      endfunction! F1
    ]]))
    check_func('F1')
    eq('', redir_exec([[
      function! F2()
      endfunction! F2
    ]]))
    check_func('F2')
    eq('', redir_exec([[
      function! F2()
        return 3
      endfunction! F2
    ]]))
    check_func('F2', 3)
  end)
  it('accepts weird characters', function()
    eq('', redir_exec([[
      function F1()
      endfunction: }}}
    ]]))
    check_func('F1')
    -- From accurev
    eq('', redir_exec([[
      function F2()
      endfunction :}}}
    ]]))
    check_func('F2')
    -- From cream-vimabbrev
    eq('', redir_exec([[
      function F3()
      endfunction 1}}}
    ]]))
    check_func('F3')
    -- From pyunit
    eq('', redir_exec([[
      function F4()
      endfunction # }}}
    ]]))
    check_func('F4')
    -- From vim-lldb
    eq('', redir_exec([[
      function F5()
      endfunction()
    ]]))
    check_func('F5')
    -- From vim-mail
    eq('', redir_exec([[
      function F6()
      endfunction;
    ]]))
    check_func('F6')
  end)
  it('accepts commented bar', function()
    eq('', redir_exec([[
      function F1()
      endfunction " F1 | echo 42
    ]]))
    check_func('F1')
    eq('', redir_exec([[
      function! F1()
        return 42
      endfunction! " F1 | echo 42
    ]]))
    check_func('F1', 42)
  end)
  it('accepts uncommented bar', function()
    eq('\n42', redir_exec([[
      function F1()
      endfunction | echo 42
    ]]))
    check_func('F1')
  end)
  it('allows running multiple commands', function()
    eq('\n2', redir_exec([[
      function F1()
        echo 2
      endfunction
      call F1()
    ]]))
    check_func('F1', 'echo 2')
    eq('\n2\n3\n4', redir_exec([[
      function F2()
        echo 2
      endfunction F2
      function F3()
        echo 3
      endfunction " F3
      function! F4()
        echo 4
      endfunction!
      call F2()
      call F3()
      call F4()
    ]]))
    check_func('F2', 'echo 2')
    check_func('F3', 'echo 3')
    check_func('F4', 'echo 4')
  end)
  it('allows running multiple commands with only one character in between',
  function()
    eq('\n3', redir_exec(dedent([[
      function! F1()
        echo 3
      endfunction!
      call F1()]])))
    check_func('F1', 'echo 3', 2)
    eq('\n4', redir_exec(dedent([[
      function F5()
        echo 4
      endfunction
      call F5()]])))
    check_func('F5', 'echo 4', 2)
    eq('\n5', redir_exec(dedent([[
      function F6()
        echo 5
      endfunction " TEST
      call F6()]])))
    check_func('F6', 'echo 5', 2)
    eq('\n6', redir_exec(dedent([[
      function F7()
        echo 6
      endfunction F7
      call F7()]])))
    check_func('F7', 'echo 6', 2)
    eq('\n2\n3\n4', redir_exec(dedent([[
      function F2()
        echo 2
      endfunction F2
      function F3()
        echo 3
      endfunction " F3
      function! F4()
        echo 4
      endfunction!
      call F2()
      call F3()
      call F4()]])))
    check_func('F2', 'echo 2', 2)
    check_func('F3', 'echo 3', 2)
    check_func('F4', 'echo 4', 2)
  end)
end)
-- vim: foldmarker=▶,▲
