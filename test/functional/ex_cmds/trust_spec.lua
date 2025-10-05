local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local clear = n.clear
local command = n.command
local exec_capture = n.exec_capture
local matches = t.matches
local pathsep = n.get_pathsep()
local is_os = t.is_os
local fn = n.fn

describe(':trust', function()
  local xstate = 'Xstate'

  before_each(function()
    n.mkdir_p(xstate .. pathsep .. (is_os('win') and 'nvim-data' or 'nvim'))
    t.write_file('test_file', 'test')
    clear { env = { XDG_STATE_HOME = xstate } }
  end)

  after_each(function()
    os.remove('test_file')
    n.rmdir(xstate)
  end)

  it('is not executed when inside false condition', function()
    command('edit test_file')
    eq('', exec_capture('if 0 | trust | endif'))
    eq(nil, vim.uv.fs_stat(fn.stdpath('state') .. pathsep .. 'trust'))
  end)

  it('trust then deny then remove a file using current buffer', function()
    local cwd = fn.getcwd()
    local hash = fn.sha256(t.read_file('test_file'))

    command('edit test_file')
    matches('^Allowed in trust database%: ".*test_file"$', exec_capture('trust'))
    local trust = t.read_file(fn.stdpath('state') .. pathsep .. 'trust')
    eq(string.format('%s %s', hash, cwd .. pathsep .. 'test_file'), vim.trim(trust))

    matches('^Denied in trust database%: ".*test_file"$', exec_capture('trust ++deny'))
    trust = t.read_file(fn.stdpath('state') .. pathsep .. 'trust')
    eq(string.format('! %s', cwd .. pathsep .. 'test_file'), vim.trim(trust))

    matches('^Removed from trust database%: ".*test_file"$', exec_capture('trust ++remove'))
    trust = t.read_file(fn.stdpath('state') .. pathsep .. 'trust')
    eq(string.format(''), vim.trim(trust))
  end)

  it('deny then trust then remove a file using current buffer', function()
    local cwd = fn.getcwd()
    local hash = fn.sha256(t.read_file('test_file'))

    command('edit test_file')
    matches('^Denied in trust database%: ".*test_file"$', exec_capture('trust ++deny'))
    local trust = t.read_file(fn.stdpath('state') .. pathsep .. 'trust')
    eq(string.format('! %s', cwd .. pathsep .. 'test_file'), vim.trim(trust))

    matches('^Allowed in trust database%: ".*test_file"$', exec_capture('trust'))
    trust = t.read_file(fn.stdpath('state') .. pathsep .. 'trust')
    eq(string.format('%s %s', hash, cwd .. pathsep .. 'test_file'), vim.trim(trust))

    matches('^Removed from trust database%: ".*test_file"$', exec_capture('trust ++remove'))
    trust = t.read_file(fn.stdpath('state') .. pathsep .. 'trust')
    eq(string.format(''), vim.trim(trust))
  end)

  it('deny then remove a file using file path', function()
    local cwd = fn.getcwd()

    matches('^Denied in trust database%: ".*test_file"$', exec_capture('trust ++deny test_file'))
    local trust = t.read_file(fn.stdpath('state') .. pathsep .. 'trust')
    eq(string.format('! %s', cwd .. pathsep .. 'test_file'), vim.trim(trust))

    matches(
      '^Removed from trust database%: ".*test_file"$',
      exec_capture('trust ++remove test_file')
    )
    trust = t.read_file(fn.stdpath('state') .. pathsep .. 'trust')
    eq(string.format(''), vim.trim(trust))
  end)
end)
