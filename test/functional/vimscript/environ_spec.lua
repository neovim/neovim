local t = require('test.functional.testutil')()
local clear = t.clear
local eq = t.eq
local environ = t.fn.environ
local exists = t.fn.exists
local system = t.fn.system
local nvim_prog = t.nvim_prog
local command = t.command
local eval = t.eval
local setenv = t.fn.setenv

describe('environment variables', function()
  it('environ() handles empty env variable', function()
    clear({ env = { EMPTY_VAR = '' } })
    eq('', environ()['EMPTY_VAR'])
    eq(nil, environ()['DOES_NOT_EXIST'])
  end)

  it('exists() handles empty env variable', function()
    clear({ env = { EMPTY_VAR = '' } })
    eq(1, exists('$EMPTY_VAR'))
    eq(0, exists('$DOES_NOT_EXIST'))
  end)
end)

describe('empty $HOME', function()
  local original_home = os.getenv('HOME')

  before_each(clear)

  -- recover $HOME after each test
  after_each(function()
    if original_home ~= nil then
      setenv('HOME', original_home)
    end
    os.remove('test_empty_home')
    os.remove('./~')
  end)

  local function tilde_in_cwd()
    -- get files in cwd
    command("let test_empty_home_cwd_files = split(globpath('.', '*'), '\n')")
    -- get the index of the file named '~'
    command('let test_empty_home_tilde_index = index(test_empty_home_cwd_files, "./~")')
    return eval('test_empty_home_tilde_index') ~= -1
  end

  local function write_and_test_tilde()
    system({
      nvim_prog,
      '-u',
      'NONE',
      '-i',
      'NONE',
      '--headless',
      '-c',
      'write test_empty_home',
      '+q',
    })
    eq(false, tilde_in_cwd())
  end

  it("'~' folder not created in cwd if $HOME and related env not defined", function()
    command('unlet $HOME')
    write_and_test_tilde()

    command("let $HOMEDRIVE='C:'")
    command("let $USERPROFILE='C:\\'")
    write_and_test_tilde()

    command('unlet $HOMEDRIVE')
    write_and_test_tilde()

    command('unlet $USERPROFILE')
    write_and_test_tilde()

    command("let $HOME='%USERPROFILE%'")
    command("let $USERPROFILE='C:\\'")
    write_and_test_tilde()
  end)

  it("'~' folder not created in cwd if writing a file with invalid $HOME", function()
    setenv('HOME', '/path/does/not/exist')
    write_and_test_tilde()
  end)

  it("'~' folder not created in cwd if writing a file with $HOME=''", function()
    command("let $HOME=''")
    write_and_test_tilde()
  end)
end)
