-- vim: set foldmethod=marker foldmarker=[[,]] :
-- Test whether glob()/globpath() return correct results with certain escaped
-- characters.

local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local command, expect = helpers.command, helpers.expect

describe('glob() and globpath()', function()
  setup(clear)

  setup(function()
    if helpers.iswin() then
      os.execute("md sautest\\autoload")
      os.execute(".>sautest\\autoload\\Test104.vim 2>nul")
      os.execute(".>sautest\\autoload\\footest.vim 2>nul")
    else
      os.execute("mkdir -p sautest/autoload")
      os.execute("touch sautest/autoload/Test104.vim")
      os.execute("touch sautest/autoload/footest.vim")
    end
  end)

  it('is working', function()
    -- Make sure glob() doesn't use the shell
    command('set shell=doesnotexist')

    -- Consistent sorting of file names
    command('set nofileignorecase')

    if helpers.iswin() then
      command([[$put =glob('Xxx{')]])
      command([[$put =glob('Xxx$')]])

      command('silent w! Xxx{')
      command([[w! Xxx$]])
      command([[$put =glob('Xxx{')]])
      command([[$put =glob('Xxx$')]])

      command([[$put =string(globpath('sautest\autoload', '*.vim'))]])
      command([[$put =string(globpath('sautest\autoload', '*.vim', 0, 1))]])
      expect([=[



        Xxx{
        Xxx$
        'sautest\autoload\Test104.vim
        sautest\autoload\footest.vim'
        ['sautest\autoload\Test104.vim', 'sautest\autoload\footest.vim']]=])
    else
      command([[$put =glob('Xxx\{')]])
      command([[$put =glob('Xxx\$')]])

      command('silent w! Xxx{')
      command([[w! Xxx\$]])
      command([[$put =glob('Xxx\{')]])
      command([[$put =glob('Xxx\$')]])

      command("$put =string(globpath('sautest/autoload', '*.vim'))")
      command("$put =string(globpath('sautest/autoload', '*.vim', 0, 1))")
      expect([=[



        Xxx{
        Xxx$
        'sautest/autoload/Test104.vim
        sautest/autoload/footest.vim'
        ['sautest/autoload/Test104.vim', 'sautest/autoload/footest.vim']]=])
    end
  end)

  teardown(function()
    if helpers.iswin() then
      os.execute('del /q/f Xxx{ Xxx$')
      os.execute('rd /q sautest')
    else
      os.execute("rm -rf sautest Xxx{ Xxx$")
    end
  end)
end)
