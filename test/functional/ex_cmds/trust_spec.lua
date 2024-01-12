local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local clear = helpers.clear
local command = helpers.command
local exec_capture = helpers.exec_capture
local matches = helpers.matches
local pathsep = helpers.get_pathsep()
local is_os = helpers.is_os
local fn = helpers.fn

describe(':trust', function()
  local xstate = 'Xstate'

  setup(function()
    helpers.mkdir_p(xstate .. pathsep .. (is_os('win') and 'nvim-data' or 'nvim'))
  end)

  teardown(function()
    helpers.rmdir(xstate)
  end)

  before_each(function()
    helpers.write_file('test_file', 'test')
    clear { env = { XDG_STATE_HOME = xstate } }
  end)

  after_each(function()
    os.remove('test_file')
  end)

  it('trust then deny then remove a file using current buffer', function()
    local cwd = fn.getcwd()
    local hash = fn.sha256(helpers.read_file('test_file'))

    command('edit test_file')
    matches('^Allowed ".*test_file" in trust database%.$', exec_capture('trust'))
    local trust = helpers.read_file(fn.stdpath('state') .. pathsep .. 'trust')
    eq(string.format('%s %s', hash, cwd .. pathsep .. 'test_file'), vim.trim(trust))

    matches('^Denied ".*test_file" in trust database%.$', exec_capture('trust ++deny'))
    trust = helpers.read_file(fn.stdpath('state') .. pathsep .. 'trust')
    eq(string.format('! %s', cwd .. pathsep .. 'test_file'), vim.trim(trust))

    matches('^Removed ".*test_file" from trust database%.$', exec_capture('trust ++remove'))
    trust = helpers.read_file(fn.stdpath('state') .. pathsep .. 'trust')
    eq(string.format(''), vim.trim(trust))
  end)

  it('deny then trust then remove a file using current buffer', function()
    local cwd = fn.getcwd()
    local hash = fn.sha256(helpers.read_file('test_file'))

    command('edit test_file')
    matches('^Denied ".*test_file" in trust database%.$', exec_capture('trust ++deny'))
    local trust = helpers.read_file(fn.stdpath('state') .. pathsep .. 'trust')
    eq(string.format('! %s', cwd .. pathsep .. 'test_file'), vim.trim(trust))

    matches('^Allowed ".*test_file" in trust database%.$', exec_capture('trust'))
    trust = helpers.read_file(fn.stdpath('state') .. pathsep .. 'trust')
    eq(string.format('%s %s', hash, cwd .. pathsep .. 'test_file'), vim.trim(trust))

    matches('^Removed ".*test_file" from trust database%.$', exec_capture('trust ++remove'))
    trust = helpers.read_file(fn.stdpath('state') .. pathsep .. 'trust')
    eq(string.format(''), vim.trim(trust))
  end)

  it('deny then remove a file using file path', function()
    local cwd = fn.getcwd()

    matches('^Denied ".*test_file" in trust database%.$', exec_capture('trust ++deny test_file'))
    local trust = helpers.read_file(fn.stdpath('state') .. pathsep .. 'trust')
    eq(string.format('! %s', cwd .. pathsep .. 'test_file'), vim.trim(trust))

    matches(
      '^Removed ".*test_file" from trust database%.$',
      exec_capture('trust ++remove test_file')
    )
    trust = helpers.read_file(fn.stdpath('state') .. pathsep .. 'trust')
    eq(string.format(''), vim.trim(trust))
  end)
end)
