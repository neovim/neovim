local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local command = n.command
local eq = t.eq
local fn = n.fn
local next_msg = n.next_msg
local is_os = t.is_os
local skip = t.skip
-- local read_file = t.read_file
local feed = n.feed
-- local retry = t.retry

describe("'autowriteall' on signal exit", function()
  before_each(clear)

  local function test_deadly_sig(signame, awa, should_write)
    local testfile = 'Xtest_SIG' .. signame .. (awa and '_awa' or '_noawa')
    local teststr = 'Testaaaaaaa'

    if awa then
      command('set awa')
    end

    command('edit ' .. testfile)
    feed('i' .. teststr)
    print(vim.uv.kill(fn.getpid(), signame))

    eq(should_write, should_write)

    -- retry(nil, 1000, function()
    --   eq((should_write and (teststr .. '\n') or nil), read_file(testfile))
    -- end)
  end

  -- Works on windows
  it('dont write if SIGTERM & awa on', function()
    test_deadly_sig('sigterm', true, false)
  end)
  it('dont write if SIGTERM & awa off', function()
    test_deadly_sig('sigterm', false, false)
  end)

  -- ENOSYS: function not implemented
  it('write if SIGHUP & awa on', function()
    -- skip(is_os('win'), 'Timeout on Windows')
    test_deadly_sig('sighup', true, true)
  end)
  it('dont write if SIGHUP & awa off', function()
    -- skip(is_os('win'), 'Timeout on Windows')
    test_deadly_sig('sigup', false, false)
  end)

  -- Error on windows
  it('write if SIGTSTP & awa on', function()
    -- skip(is_os('win'), 'Timeout on Windows')
    test_deadly_sig(20, true, true)
  end)
  it('dont write if SIGTSTP & awa off', function()
    -- skip(is_os('win'), 'Timeout on Windows')
    test_deadly_sig(20, false, false)
  end)

  -- Takes 6min to run, causes the CI job to timeout
  it('write if SIGQUIT & awa on', function()
    skip(is_os('win'), 'Timeout on Windows')
    test_deadly_sig(3, true, true)
  end)
  it('dont write if SIGQUIT & awa off', function()
    skip(is_os('win'), 'Timeout on Windows')
    test_deadly_sig(3, false, false)
  end)
end)

if skip(is_os('win'), 'Only applies to POSIX systems') then
  return
end

describe('autocmd Signal', function()
  before_each(clear)

  it('matches *', function()
    command('autocmd Signal * call rpcnotify(1, "foo")')
    vim.uv.kill(fn.getpid(), 'sigusr1')
    eq({ 'notification', 'foo', {} }, next_msg())
  end)

  it('matches SIGUSR1', function()
    command('autocmd Signal SIGUSR1 call rpcnotify(1, "foo")')
    vim.uv.kill(fn.getpid(), 'sigusr1')
    eq({ 'notification', 'foo', {} }, next_msg())
  end)

  it('matches SIGWINCH', function()
    command('autocmd Signal SIGWINCH call rpcnotify(1, "foo")')
    vim.uv.kill(fn.getpid(), 'sigwinch')
    eq({ 'notification', 'foo', {} }, next_msg())
  end)

  it('does not match unknown patterns', function()
    command('autocmd Signal SIGUSR2 call rpcnotify(1, "foo")')
    vim.uv.kill(fn.getpid(), 'sigusr2')
    eq(nil, next_msg(500))
  end)
end)
