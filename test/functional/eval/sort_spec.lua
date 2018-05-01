local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local NIL = helpers.NIL
local eval = helpers.eval
local clear = helpers.clear
local meths = helpers.meths
local funcs = helpers.funcs
local command = helpers.command
local exc_exec = helpers.exc_exec
local redir_exec = helpers.redir_exec

before_each(clear)

describe('sort()', function()
  it('errors out when sorting special values', function()
    eq('Vim(call):E907: Using a special value as a Float',
       exc_exec('call sort([v:true, v:false], "f")'))
  end)

  it('sorts “wrong” values between -0.0001 and 0.0001, preserving order',
  function()
    meths.set_var('list', {true, false, NIL, {}, {a=42}, 'check',
                           0.0001, -0.0001})
    command('call insert(g:list, function("tr"))')
    local error_lines = funcs.split(
        funcs.execute('silent! call sort(g:list, "f")'), '\n')
    local errors = {}
    for _, err in ipairs(error_lines) do
      errors[err] = true
    end
    eq({
      ['E891: Using a Funcref as a Float']=true,
      ['E892: Using a String as a Float']=true,
      ['E893: Using a List as a Float']=true,
      ['E894: Using a Dictionary as a Float']=true,
      ['E907: Using a special value as a Float']=true,
    }, errors)
    eq('[-1.0e-4, function(\'tr\'), v:true, v:false, v:null, [], {\'a\': 42}, \'check\', 1.0e-4]',
       eval('string(g:list)'))
  end)

  it('can yield E702 and stop sorting after that', function()
    command([[
      function Cmp(a, b)
        if type(a:a) == type([]) || type(a:b) == type([])
          return []
        endif
        return (a:a > a:b) - (a:a < a:b)
      endfunction
    ]])
    eq('\nE745: Using a List as a Number\nE702: Sort compare function failed',
       redir_exec('let sl = sort([1, 0, [], 3, 2], "Cmp")'))
    eq({1, 0, {}, 3, 2}, meths.get_var('sl'))
  end)
end)
