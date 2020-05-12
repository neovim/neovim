local lfs = require('lfs')
local helpers = require('test.functional.helpers')(after_each)
local clear, eq = helpers.clear, helpers.eq
local eval, command = helpers.eval, helpers.command

describe('autochdir behavior', function()
  local dir = 'Xtest-functional-legacy-autochdir'

  before_each(function()
    lfs.mkdir(dir)
    clear()
  end)

  after_each(function()
    helpers.rmdir(dir)
  end)

  -- Tests vim/vim/777 without test_autochdir().
  it('sets filename', function()
    command('set acd')
    command('new')
    command('w '..dir..'/Xtest')
    eq('Xtest', eval("expand('%')"))
    eq(dir, eval([[substitute(getcwd(), '.*[/\\]\(\k*\)', '\1', '')]]))
  end)
end)
