-- Tests for nested function.

local n = require('test.functional.testnvim')()

local clear, insert = n.clear, n.insert
local command, expect, source = n.command, n.expect, n.source

describe('test_nested_function', function()
  setup(clear)

  it('is working', function()
    insert([[
      result:]])

    source([[
      :fu! NestedFunc()
      :  fu! Func1()
      :    $put ='Func1'
      :  endfunction
      :  call Func1()
      :  fu! s:func2()
      :    $put ='s:func2'
      :  endfunction
      :  call s:func2()
      :  fu! s:_func3()
      :    $put ='s:_func3'
      :  endfunction
      :  call s:_func3()
      :  let fn = 'Func4'
      :  fu! {fn}()
      :    $put ='Func4'
      :  endfunction
      :  call {fn}()
      :  let fn = 'func5'
      :  fu! s:{fn}()
      :    $put ='s:func5'
      :  endfunction
      :  call s:{fn}()
      :endfunction]])
    command('call NestedFunc()')

    -- Assert buffer contents.
    expect([[
      result:
      Func1
      s:func2
      s:_func3
      Func4
      s:func5]])
  end)
end)
