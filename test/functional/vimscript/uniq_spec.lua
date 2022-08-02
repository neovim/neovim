local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local clear = helpers.clear
local command = helpers.command
local exc_exec = helpers.exc_exec
local pcall_err = helpers.pcall_err

before_each(clear)

describe('uniq()', function()
  it('errors out when processing special values', function()
    eq('Vim(call):E362: Using a boolean value as a Float',
       exc_exec('call uniq([v:true, v:false], "f")'))
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
    eq('Vim(let):E745: Using a List as a Number',
       pcall_err(command, 'let fl = uniq([0, 0, [], 1, 1], "Cmp")'))
  end)
end)
