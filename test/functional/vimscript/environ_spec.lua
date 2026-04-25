local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local environ = n.fn.environ
local exists = n.fn.exists
local system = n.fn.system
local nvim_prog = n.nvim_prog
local command = n.command
local eval = n.eval
local setenv = n.fn.setenv

describe('vim.fn.environ()', function()
  it('exists() handles empty env variable', function()
    clear({ env = { EMPTY_VAR = '' } })
    eq(1, exists('$EMPTY_VAR'))
    eq(0, exists('$DOES_NOT_EXIST'))
  end)

  it('handles empty env variable', function()
    clear({ env = { EMPTY_VAR = '' } })
    eq('', environ()['EMPTY_VAR'])
    -- vim.env returns nil if the value is empty string. 🤷
    eq(vim.NIL, n.exec_lua('return vim.env.EMPTY_VAR'))
    eq(nil, environ()['DOES_NOT_EXIST'])
    eq(vim.NIL, n.exec_lua('return vim.env.DOES_NOT_EXIST'))
  end)

  it('results match getenv()', function()
    clear()
    eq(
      true,
      n.exec_lua([[
        local env = vim.fn.environ()
        assert(vim.tbl_count(env) > 10, 'environ() should have some env vars!')
        for k, v in pairs(env) do
          if v ~= '' and vim.fn.getenv(k) ~= v then
            error(('environ()[%q] = %q, but vim.fn.getenv(%q) = %q'):format(k, v, k, vim.fn.getenv(k)))
          end
        end
        return true
      ]])
    )
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
