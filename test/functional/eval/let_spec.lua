local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local clear = helpers.clear
local meths = helpers.meths
local redir_exec = helpers.redir_exec

before_each(clear)

describe(':let command', function()
  it('correctly lists variables with curly-braces', function()
    meths.set_var('v', {0})
    eq('\nv                     [0]', redir_exec('let {"v"}'))
  end)

  it('correctly lists variables with subscript', function()
    meths.set_var('v', {0})
    eq('\nv[0]                  #0', redir_exec('let v[0]'))
    eq('\ng:["v"][0]            #0', redir_exec('let g:["v"][0]'))
    eq('\n{"g:"}["v"][0]        #0', redir_exec('let {"g:"}["v"][0]'))
  end)
end)
