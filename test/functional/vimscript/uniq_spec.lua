local t = require('test.functional.testutil')(after_each)

local eq = t.eq
local clear = t.clear
local command = t.command
local exc_exec = t.exc_exec
local pcall_err = t.pcall_err

before_each(clear)

describe('uniq()', function()
  it('errors out when processing special values', function()
    eq(
      'Vim(call):E362: Using a boolean value as a Float',
      exc_exec('call uniq([v:true, v:false], "f")')
    )
  end)

  it('can yield E882 and stop filtering after that', function()
    command([[
      function Cmp(a, b)
        if type(a:a) == type([]) || type(a:b) == type([])
          return []
        endif
        return (a:a > a:b) - (a:a < a:b)
      endfunction
    ]])
    eq(
      'Vim(let):E745: Using a List as a Number',
      pcall_err(command, 'let fl = uniq([0, 0, [], 1, 1], "Cmp")')
    )
  end)
end)
