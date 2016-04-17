describe(':if block', function()
  local ito, itoe
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
  end
  ito('Runs if 1', [[
    echo 1
    if 1
      echo 2
    end
    echo 3
  ]], {1, 2, 3})
  ito('Does not run if 0', [[
    echo 1
    if 0
      echo 2
    end
    echo 3
  ]], {1, 3})
  ito('Runs if 0 ... else', [[
    echo 1
    if 0
      echo 2
    else
      echo 3
    end
    echo 4
  ]], {1, 3, 4})
  ito('Runs if 0 ... elseif 1', [[
    echo 1
    if 0
      echo 2
    elseif 1
      echo 3
    end
    echo 4
  ]], {1, 3, 4})
  ito('Runs if 0 ... elseif 1, but not else', [[
    echo 1
    if 0
      echo 2
    elseif 1
      echo 3
    else
      echo 4
    end
    echo 5
  ]], {1, 3, 5})
  ito('Runs if 0 ... second elseif 1', [[
    echo 1
    if 0
      echo 2
    elseif 0
      echo 3
    elseif 1
      echo 4
    end
    echo 5
  ]], {1, 4, 5})
  ito('Runs if 0 ... second elseif 1, but not else', [[
    echo 1
    if 0
      echo 2
    elseif 0
      echo 3
    elseif 1
      echo 4
    else
      echo 5
    end
    echo 6
  ]], {1, 4, 6})
  ito('Handles empty :if 0', [[
    echo 1
    if 0
    end
    echo 2
  ]], {1, 2})
  ito('Handles empty :if 1', [[
    echo 1
    if 1
    end
    echo 2
  ]], {1, 2})
  ito('Handles empty :if 0 ... else', [[
    echo 1
    if 0
    else
    end
    echo 2
  ]], {1, 2})
  ito('Handles empty :if 1 ... else', [[
    echo 1
    if 1
    else
    end
    echo 2
  ]], {1, 2})
  ito('Handles empty :if 0 ... elseif 1 ... else', [[
    echo 1
    if 0
    elseif 1
    else
    end
    echo 2
  ]], {1, 2})
  ito('Handles empty :if 0 ... elseif 1', [[
    echo 1
    if 0
    elseif 1
    end
    echo 2
  ]], {1, 2})
end)

describe(':try block', function()
  local ito, itoe
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
  end
  ito('Handles empty :try', [[
    echo 1
    try
    endtry
    echo 2
  ]], {1, 2})
  ito('Handles empty :try .. catch', [[
    echo 1
    try
    catch
    endtry
    echo 2
  ]], {1, 2})
  ito('Handles empty :try .. finally', [[
    echo 1
    try
    finally
    endtry
    echo 2
  ]], {1, 2})
  ito('Handles empty :try .. catch .. finally', [[
    echo 1
    try
    catch
    finally
    endtry
    echo 2
  ]], {1, 2})
  ito('Handles empty :try .. catch .. catch .. finally', [[
    echo 1
    try
    catch
    catch
    finally
    endtry
    echo 2
  ]], {1, 2})
  ito(':catch shows correct v:exception', [[
    try
      echo a
    catch
      echo v:exception
    endtry
  ]], {'Vim(echo):E121: Undefined variable: a'})
  ito('v:exception is empty outside of the :catch if there was no exception', [[
    try
    catch
    endtry
    echo v:exception
  ]], {''})
  ito('v:exception is empty outside of the :catch if there was exception', [[
    try
      echo a
    catch
    endtry
    echo v:exception
  ]], {''})
  ito('v:exception is empty before :try', [[
    echo v:exception
    try
    catch
    endtry
  ]], {''})
  ito('v:exception before :try, inside it, :catch, :finally and at the end', [[
    echo v:exception
    try
      echo v:exception
      echo a
    catch
      echo v:exception
    finally
      echo v:exception
    endtry
    echo v:exception
  ]], {'', '', 'Vim(echo):E121: Undefined variable: a', '', ''})
  ito('Sets v:throwpoint to the empty value', [[
    echo v:throwpoint
    try
      echo a
    catch
      echo v:throwpoint
    endtry
    echo v:throwpoint
  ]], {'', '', ''})
  itoe('Does not throw Vim-prefixed messages', {
    'throw "Vim"',
    'throw "Vim(echo):E121: Undefined variable: a"',
    'throw "Vimoentshu"',
  }, {
    'Vim(throw):E608: Cannot :throw exceptions with \'Vim\' prefix',
    'Vim(throw):E608: Cannot :throw exceptions with \'Vim\' prefix',
    'Vim(throw):E608: Cannot :throw exceptions with \'Vim\' prefix',
  })
  itoe('Catches exception raised by :throw', {
    'throw "abc"'
  }, {'abc'})
end)

describe(':function definition', function()
  local ito, itoe
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
  end
  ito('Calls user-defined function with default return value', [[
    function Abc()
      echo 'Abc'
    endfunction
    echo Abc()
    delfunction Abc
  ]], {'Abc', 0})
  ito('Does not add `self` for regular call', [[
    function Abc()
      echo self
    endfunction
    try
      echo Abc()
    catch
      echo v:exception
    endtry
    delfunction Abc
  ]], {
    'Vim(echo):E121: Undefined variable: self'
  })
  ito('Function accepts arguments', [[
    function Abc(a, b, c)
      echo a:a
      echo a:b
      echo a:c
    endfunction
    echo Abc(1, 2, 3)
    delfunction Abc
  ]], {1, 2, 3, 0})
  ito('Varargs function', [[
    function Abc(...)
      echo a:0
      echo a:000
    endfunction
    echo Abc(1, 2, 3)
    echo Abc()
    delfunction Abc
  ]], {
    3, {1, 2, 3}, 0,
    0, {_t='list'}, 0,
  })
  ito('Normal args + varargs function', [[
    function Abc(a, b, c, ...)
      echo a:a
      echo a:b
      echo a:c
      echo a:0
      echo a:000
    endfunction
    echo Abc(1, 2, 3)
    echo Abc(1, 2, 3, 4, 5)
    delfunction Abc
  ]], {
    1, 2, 3, 0, {_t='list'}, 0,
    1, 2, 3, 2, {4, 5}, 0,
  })
end)

describe(':for loops', function()
  local ito, itoe
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
  end
  ito('Iterates over a list', [[
    for i in [1, 2, 3]
      echo i
    endfor
    echo i
    unlet i
  ]], {1, 2, 3, 3})
  ito('Iterates over a list of lists, using simple list unpacking', [[
    for [i, j] in [ [1, 2], [3, 4], [5, 6] ]
      echo j
      echo i
    endfor
    unlet i j
  ]], {2, 1, 4, 3, 6, 5})
  ito('Iterates over a list of lists, using rest list unpacking', [[
    for [i; j] in [ [1, 2], [3, 4], [5, 6] ]
      echo j
      echo i
    endfor
    unlet i j
  ]], {{2}, 1, {4}, 3, {6}, 5})
  ito('respects :break', [[
    for i in [1, 2, 3, 4, 5, 6]
      echo i
      if i % 2 == 0
        break
      endif
    endfor
    unlet i
  ]], {1, 2})
  ito('respects :continue', [[
    for i in [1, 2, 3, 4, 5, 6]
      if i % 2 == 0
        continue
      endif
      echo i
    endfor
    unlet i
  ]], {1, 3, 5})
  for _, v in ipairs({{'dictionary', '{}'},
                      {'string', '""'},
                      {'number', '0'},
                      {'funcref', 'function("string")'},
                      {'float', '0.0'}}) do
    ito('Fails to iterate over a ' .. v[1], string.format([[
      try
        for i in %s
          echo i
        endfor
        echo i
      catch
        echo v:exception
      endtry
    ]], v[2]), {'Vim(for):E714: List required'})
  end
end)

describe(':while loop', function()
  local ito, itoe
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
  end
  ito('works', [[
    let i = 0
    let j = 10
    while i < j
      let i += 1
      let j -= 1
      echo i
      echo j
    endwhile
    unlet i j
  ]], {1, 9, 2, 8, 3, 7, 4, 6, 5, 5})
  ito('respects :break', [[
    let i = 0
    while i < 10
      let i += 1
      echo i
      if i % 2 == 0
        break
      endif
    endwhile
    unlet i
  ]], {1, 2})
  ito('respects :continue', [[
    let i = 0
    while i < 10
      let i += 1
      if i % 2 == 0
        continue
      endif
      echo i
    endwhile
    unlet i
  ]], {1, 3, 5, 7, 9})
end)

describe(':break command', function()
  local ito, itoe
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
  end
  itoe('does not work outside the loop', {
    'break'
  }, {
    'Vim(break):E587: :break without :while or :for'
  })
  itoe('does not work inside a function inside the :for loop', {
    'for i in [1, 2, 3]|function Abc()|break|endfunction|call Abc()|endfor',
    'delfunction Abc',
    'unlet i',
  }, {
    'Vim(break):E587: :break without :while or :for'
  })
  itoe('does not work inside a function inside the :while loop', {
    'let i = 0',
    'while i < 3|function Abc()|break|endfunction|call Abc()|let i+=1|endwhile',
    'delfunction Abc',
    'unlet i',
  }, {
    'Vim(break):E587: :break without :while or :for'
  })
end)

describe(':continue command', function()
  local ito, itoe
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
  end
  itoe('does not work outside the loop', {
    'continue'
  }, {
    'Vim(continue):E586: :continue without :while or :for'
  })
  itoe('does not work inside a function inside the :for loop', {
    'for i in [1, 2, 3]|function Abc()|continue|endfunction|call Abc()|endfor',
    'delfunction Abc',
    'unlet i',
  }, {
    'Vim(continue):E586: :continue without :while or :for'
  })
  itoe('does not work inside a function inside the :while loop', {
    'let i = 0',
    'while i < 3|function Abc()|continue|endfunction|call Abc()|let i+=1|endwhile',
    'delfunction Abc',
    'unlet i',
  }, {
    'Vim(continue):E586: :continue without :while or :for'
  })
end)

describe('Function calls', function()
  local ito, itoe
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
  end
  ito('Fails to call function: too many arguments (empty argument list)', [[
    function Abc()
    endfunction
    try
      echo Abc(1)
    catch
      echo v:exception
    endtry
    delfunction Abc
  ]], {
    'Vim(echo):E118: Too many arguments for function: Abc',
  })
  ito('Fails to call function: non-empty argument list', [[
    function Abc(a, b)
    endfunction
    try
      echo Abc(1)
    catch
      echo v:exception
    endtry
    try
      echo Abc(1, 2, 3)
    catch
      echo v:exception
    endtry
    delfunction Abc
  ]], {
    'Vim(echo):E119: Not enough arguments for function: Abc',
    'Vim(echo):E118: Too many arguments for function: Abc',
  })
  ito('Fails to call function: not enough arguments, with varargs', [[
    function Abc(a, b, ...)
    endfunction
    try
      echo Abc(1)
    catch
      echo v:exception
    endtry
    delfunction Abc
  ]], {
    'Vim(echo):E119: Not enough arguments for function: Abc',
  })
  ito('Proceeds on error', [[
    function Abc()
      echo 1
      echo b
      echo 2
    endfunction
    echo 0
    echo Abc()
    echo 4
    delfunction Abc
  ]], {0, 1, 2, 0, 4})
  ito('Does not proceed on error when using :function-abort', [[
    function Abc() abort
      echo 1
      echo b
      echo 2
    endfunction
    echo 0
    echo Abc()
    echo 4
    delfunction Abc
  ]], {0, 1, -1, 4})
  itoe('Catches errors from aborted functions', {
    'function Abc()|echo 1|echo b|echo 2|endfunction',
    'echo 0',
    'echo Abc()',
    'echo 4',
    'delfunction Abc',
  }, {0, 1, 'Vim(echo):E121: Undefined variable: b', 4})
  ito('Returns not specified zero value successfully', [[
    function Abc()
    endfunction
    echo -1
    echo Abc()
    echo 1
    delfunction Abc
  ]], {-1, 0, 1})
  ito('Returns not specified zero value successfully (with body)', [[
    function Abc()
      echo -1
    endfunction
    echo -2
    echo Abc()
    echo 1
    delfunction Abc
  ]], {-2, -1, 0, 1})
  ito('Returns specified value successfully', [[
    function Abc()
      return 2
    endfunction
    echo 1
    echo Abc()
    echo 3
    delfunction Abc
  ]], {1, 2, 3})
  ito('Returns not specified zero value successfully (with abort)', [[
    function Abc() abort
    endfunction
    echo -1
    echo Abc()
    echo 1
    delfunction Abc
  ]], {-1, 0, 1})
  ito('Returns not specified zero value successfully (with body and abort)', [[
    function Abc() abort
      echo -1
    endfunction
    echo -2
    echo Abc()
    echo 1
    delfunction Abc
  ]], {-2, -1, 0, 1})
  ito('Returns specified value successfully (with abort)', [[
    function Abc() abort
      return 2
    endfunction
    echo 1
    echo Abc()
    echo 3
    delfunction Abc
  ]], {1, 2, 3})
end)

describe('Dictionary functions', function()
  local ito, itoe
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
  end
  -- XXX Incompatible behavior
  ito('Sets self only when calling regular function with a dictionary', [[
    function Abc()
      echo self.a
    endfunction
    let d = {'a': 10, 'f': function('Abc')}
    echo d.f()
    try
      echo Abc()
    catch
      echo v:exception
    endtry
    delfunction Abc
    unlet d
  ]], {10, 0, 'Vim(echo):E121: Undefined variable: self'})
  -- XXX Incompatible behavior
  ito('Allows to define regular function inside a dictionary', [[
    let d = {'a': 11}
    function d.f()
      echo self.a
    endfunction
    echo d.f()
    try
      echo call(d.f, [])
    catch
      echo v:exception
    endtry
    unlet d
  ]], {11, 0, 'Vim(echo):E121: Undefined variable: self'})
end)
