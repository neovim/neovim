local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local clear = helpers.clear
local meths = helpers.meths
local command = helpers.command
local exc_exec = helpers.exc_exec
local redir_exec = helpers.redir_exec

before_each(clear)

describe('uniq()', function()
  it('errors out when processing special values', function()
    eq('Vim(call):E907: Using a special value as a Float',
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
    eq('\nE745: Using a List as a Number\nE882: Uniq compare function failed',
       redir_exec('let fl = uniq([0, 0, [], 1, 1], "Cmp")'))
    eq({0, {}, 1, 1}, meths.get_var('fl'))
  end)
end)
