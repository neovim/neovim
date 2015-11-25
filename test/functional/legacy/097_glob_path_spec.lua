-- vim: set foldmethod=marker foldmarker=[[,]] :
-- Test whether glob()/globpath() return correct results with certain escaped
-- characters.

local helpers = require('test.functional.helpers')
local clear = helpers.clear
local execute, expect = helpers.execute, helpers.expect

describe('glob() and globpath()', function()
  setup(clear)

  setup(function()
    os.execute("mkdir -p sautest/autoload")
    os.execute("touch sautest/autoload/Test104.vim")
    os.execute("touch sautest/autoload/footest.vim")
  end)

  it('is working', function()
    -- Make sure glob() doesn't use the shell
    execute('set shell=doesnotexist')

    -- Consistent sorting of file names
    execute('set nofileignorecase')

    execute([[$put =glob('Xxx\{')]])
    execute([[$put =glob('Xxx\$')]])

    execute('w! Xxx{')
    execute([[w! Xxx\$]])
    execute([[$put =glob('Xxx\{')]])
    execute([[$put =glob('Xxx\$')]])

    execute("$put =string(globpath('sautest/autoload', '*.vim'))")
    execute("$put =string(globpath('sautest/autoload', '*.vim', 0, 1))")

    expect([=[
      
      
      
      Xxx{
      Xxx$
      'sautest/autoload/Test104.vim
      sautest/autoload/footest.vim'
      ['sautest/autoload/Test104.vim', 'sautest/autoload/footest.vim']]=])
  end)

  teardown(function()
    os.execute("rm -rf sautest Xxx{ Xxx$")
  end)
end)
