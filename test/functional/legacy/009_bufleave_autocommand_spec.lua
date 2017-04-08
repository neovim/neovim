-- Test for Bufleave autocommand that deletes the buffer we are about to edit.

local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local clear = helpers.clear
local meths = helpers.meths
local expect = helpers.expect
local command = helpers.command
local exc_exec = helpers.exc_exec
local curbufmeths = helpers.curbufmeths

describe('BufLeave autocommand', function()
  setup(clear)

  it('is working', function()
    meths.set_option('hidden', true)
    curbufmeths.set_lines(0, 1, false, {
      'start of test file xx',
      'end of test file xx'})

    command('autocmd BufLeave * bwipeout yy')
    eq('Vim(edit):E143: Autocommands unexpectedly deleted new buffer yy',
       exc_exec('edit yy'))

    expect([[
      start of test file xx
      end of test file xx]])
  end)
end)
