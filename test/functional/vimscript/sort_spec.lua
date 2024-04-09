local t = require('test.functional.testutil')()

local eq = t.eq
local NIL = vim.NIL
local eval = t.eval
local clear = t.clear
local api = t.api
local fn = t.fn
local command = t.command
local exc_exec = t.exc_exec
local pcall_err = t.pcall_err

before_each(clear)

describe('sort()', function()
  it('errors out when sorting special values', function()
    eq(
      'Vim(call):E362: Using a boolean value as a Float',
      exc_exec('call sort([v:true, v:false], "f")')
    )
  end)

  it('sorts “wrong” values between -0.0001 and 0.0001, preserving order', function()
    api.nvim_set_var('list', {
      true,
      false,
      NIL,
      {},
      { a = 42 },
      'check',
      0.0001,
      -0.0001,
    })
    command('call insert(g:list, function("tr"))')
    local error_lines = fn.split(fn.execute('silent! call sort(g:list, "f")'), '\n')
    local errors = {}
    for _, err in ipairs(error_lines) do
      errors[err] = true
    end
    eq({
      ['E362: Using a boolean value as a Float'] = true,
      ['E891: Using a Funcref as a Float'] = true,
      ['E892: Using a String as a Float'] = true,
      ['E893: Using a List as a Float'] = true,
      ['E894: Using a Dictionary as a Float'] = true,
      ['E907: Using a special value as a Float'] = true,
    }, errors)
    eq(
      "[-1.0e-4, function('tr'), v:true, v:false, v:null, [], {'a': 42}, 'check', 1.0e-4]",
      eval('string(g:list)')
    )
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
    eq(
      'Vim(let):E745: Using a List as a Number',
      pcall_err(command, 'let sl = sort([1, 0, [], 3, 2], "Cmp")')
    )
  end)
end)
