local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local clear = helpers.clear
local command = helpers.command
local pathsep = helpers.get_pathsep()
local iswin = helpers.iswin()
local funcs = helpers.funcs

describe(':trust', function()
  local xstate = 'Xstate'

  setup(function()
    helpers.mkdir_p(xstate .. pathsep .. (iswin and 'nvim-data' or 'nvim'))
  end)

  teardown(function()
    helpers.rmdir(xstate)
  end)

  before_each(function()
    helpers.write_file('test_file', 'test')
    clear{env={XDG_STATE_HOME=xstate}}
  end)

  after_each(function()
    os.remove('test_file')
  end)

  it('allow then deny then forget a file', function()
    local cwd = funcs.getcwd()
    local hash = funcs.sha256(helpers.read_file('test_file'))

    command('trust allow test_file')
    local trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
    eq(string.format('%s %s', hash, cwd .. pathsep .. 'test_file'), vim.trim(trust))

    command('trust deny test_file')
    trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
    eq(string.format('! %s', cwd .. pathsep .. 'test_file'), vim.trim(trust))

    command('trust forget test_file')
    trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
    eq(string.format(''), vim.trim(trust))
  end)

  it('deny then allow then forget a file', function()
    local cwd = funcs.getcwd()
    local hash = funcs.sha256(helpers.read_file('test_file'))

    command('trust deny test_file')
    local trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
    eq(string.format('! %s', cwd .. pathsep .. 'test_file'), vim.trim(trust))

    command('trust allow test_file')
    trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
    eq(string.format('%s %s', hash, cwd .. pathsep .. 'test_file'), vim.trim(trust))

    command('trust forget test_file')
    trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
    eq(string.format(''), vim.trim(trust))
  end)
end)
