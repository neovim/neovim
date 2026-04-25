local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local clear = n.clear
local command = n.command
local exec_capture = n.exec_capture
local matches = t.matches
local is_os = t.is_os
local fn = n.fn

describe(':trust', function()
  local xstate = 'Xstate_ex_trust'
  local test_file = 'Xtest_functional_ex_cmds_trust'
  local empty_file = 'Xtest_functional_ex_cmds_trust_empty'

  before_each(function()
    n.mkdir_p(vim.fs.joinpath(xstate, is_os('win') and 'nvim-data' or 'nvim'))
    t.write_file(test_file, 'test')
    t.write_file(empty_file, '')
    clear { env = { XDG_STATE_HOME = xstate } }
  end)

  after_each(function()
    os.remove(test_file)
    os.remove(empty_file)
    n.rmdir(xstate)
  end)

  --- @param s string
  local function fmt(s)
    return s:format(test_file)
  end

  local function assert_trust_entry(expected)
    local trust = t.read_file(vim.fs.joinpath(fn.stdpath('state'), 'trust'))
    eq(expected, vim.trim(trust))
  end

  it('is not executed when inside false condition', function()
    command(fmt('edit %s'))
    eq('', exec_capture('if 0 | trust | endif'))
    eq(nil, vim.uv.fs_stat(vim.fs.joinpath(fn.stdpath('state'), 'trust')))
  end)

  it('trust then deny then remove a file using current buffer', function()
    local cwd = fn.getcwd()
    local hash = fn.sha256(assert(t.read_file(test_file)))

    command(fmt('edit %s'))
    matches(fmt('^Allowed in trust database%%: ".*%s"$'), exec_capture('trust'))
    assert_trust_entry(('%s %s'):format(hash, vim.fs.joinpath(cwd, test_file)))

    matches(fmt('^Denied in trust database%%: ".*%s"$'), exec_capture('trust ++deny'))
    assert_trust_entry(('! %s'):format(vim.fs.joinpath(cwd, test_file)))

    matches(fmt('^Removed from trust database%%: ".*%s"$'), exec_capture('trust ++remove'))
    assert_trust_entry('')
  end)

  it('trust an empty file using current buffer', function()
    local cwd = fn.getcwd()
    local hash = fn.sha256(assert(t.read_file(empty_file)))

    command('edit ' .. empty_file)
    matches('^Allowed in trust database%: ".*' .. empty_file .. '"$', exec_capture('trust'))
    assert_trust_entry(('%s %s'):format(hash, vim.fs.joinpath(cwd, empty_file)))
  end)

  it('deny then trust then remove a file using current buffer', function()
    local cwd = fn.getcwd()
    local hash = fn.sha256(assert(t.read_file(test_file)))

    command(fmt('edit %s'))
    matches(fmt('^Denied in trust database%%: ".*%s"$'), exec_capture('trust ++deny'))
    assert_trust_entry(('! %s'):format(vim.fs.joinpath(cwd, test_file)))

    matches(fmt('^Allowed in trust database%%: ".*%s"$'), exec_capture('trust'))
    assert_trust_entry(('%s %s'):format(hash, vim.fs.joinpath(cwd, test_file)))

    matches(fmt('^Removed from trust database%%: ".*%s"$'), exec_capture('trust ++remove'))
    assert_trust_entry('')
  end)

  it('deny then remove a file using file path', function()
    local cwd = fn.getcwd()

    matches(fmt('^Denied in trust database%%: ".*%s"$'), exec_capture(fmt('trust ++deny %s')))
    assert_trust_entry(('! %s'):format(vim.fs.joinpath(cwd, test_file)))

    matches(fmt('^Removed from trust database%%: ".*%s"$'), exec_capture(fmt('trust ++remove %s')))
    assert_trust_entry('')
  end)
end)
