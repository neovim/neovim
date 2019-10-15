local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local environ = helpers.funcs.environ
local exists = helpers.funcs.exists
local command = helpers.command
local nvim_prog = helpers.nvim_prog
local setenv = helpers.funcs.setenv
local unsetenv = helpers.funcs.unsetenv
local system = helpers.funcs.system
local eval = helpers.eval

describe('environment variables', function()
  it('environ() handles empty env variable', function()
    clear({env={EMPTY_VAR=""}})
    eq("", environ()['EMPTY_VAR'])
    eq(nil, environ()['DOES_NOT_EXIST'])
  end)

  it('exists() handles empty env variable', function()
    clear({env={EMPTY_VAR=""}})
    eq(1, exists('$EMPTY_VAR'))
    eq(0, exists('$DOES_NOT_EXIST'))
  end)
end)

describe('empty $HOME', function()
  local original_home = ''

  -- save $HOME before each test
  before_each(function()
    original_home = os.getenv('HOME')
  end)

  -- recover $HOME after each test
  after_each(function()
    if original_home ~= nil then
      setenv('HOME', original_home)
    end
    os.remove('test_empty_home')
  end)

  it("'~' folder not created in pwd if writing a file with empty $HOME", function()
    setenv('HOME', '')
    system({nvim_prog, '-u', 'NONE', '-i', 'NONE', '--headless',
                                          '-c', 'write test_empty_home', '+q'})
    -- get files in pwd
    command("let test_empty_home_pwd_files = split(globpath('.', '*'), '\n')")
    -- get the index of the file named '~'
    command('let test_empty_home_tilde_index = index(test_empty_home_pwd_files, "./~")')

    -- expect './~' not found
    eq(-1, eval('test_empty_home_tilde_index'))
  end)

  it("'~' folder not created in pwd if writing a file with invalid $HOME", function()
    setenv('HOME', '/path/does/not/exist')
    system({nvim_prog, '-u', 'NONE', '-i', 'NONE', '--headless',
                                          '-c', 'write test_empty_home', '+q'})
    -- get files in pwd
    command("let test_empty_home_pwd_files = split(globpath('.', '*'), '\n')")
    -- get the index of the file named '~'
    command('let test_empty_home_tilde_index = index(test_empty_home_pwd_files, "./~")')

    -- expect './~' not found
    eq(-1, eval('test_empty_home_tilde_index'))
  end)

end)
