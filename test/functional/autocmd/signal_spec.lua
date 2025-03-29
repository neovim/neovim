local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local command = n.command
local eq = t.eq
local fn = n.fn
local next_msg = n.next_msg
local is_os = t.is_os
local skip = t.skip
local read_file = t.read_file
local feed = n.feed
local retry = t.retry

if skip(is_os('win'), 'Only applies to POSIX systems') then
  return
end

local function posix_kill(signame, pid)
  os.execute('kill -s ' .. signame .. ' -- ' .. pid .. ' >/dev/null')
end

describe('autocmd Signal', function()
  before_each(clear)

  it('matches *', function()
    command('autocmd Signal * call rpcnotify(1, "foo")')
    posix_kill('USR1', fn.getpid())
    eq({ 'notification', 'foo', {} }, next_msg())
  end)

  it('matches SIGUSR1', function()
    command('autocmd Signal SIGUSR1 call rpcnotify(1, "foo")')
    posix_kill('USR1', fn.getpid())
    eq({ 'notification', 'foo', {} }, next_msg())
  end)

  it('matches SIGWINCH', function()
    command('autocmd Signal SIGWINCH call rpcnotify(1, "foo")')
    posix_kill('WINCH', fn.getpid())
    eq({ 'notification', 'foo', {} }, next_msg())
  end)

  it('does not match unknown patterns', function()
    command('autocmd Signal SIGUSR2 call rpcnotify(1, "foo")')
    posix_kill('USR1', fn.getpid())
    eq(nil, next_msg(500))
  end)
end)

describe('autowriteall on kill', function()
  before_each(clear)

  local function test_deadly_sig(signame, awa, should_write)
    local testfile = 'Xtest_SIG' .. signame .. (awa and '_awa' or '_noawa')
    local teststr = 'Testaaaaaaa'

    if awa then
      command('set awa')
    end

    command('edit ' .. testfile)
    feed('i' .. teststr)
    posix_kill(signame, fn.getpid())

    retry(nil, 1000, function()
      eq((should_write and (teststr .. '\n') or nil), read_file(testfile))
    end)
  end

  it('write if SIGHUP & awa on', function()
    test_deadly_sig('HUP', true, true)
  end)

  it('write if SIGQUIT & awa on', function()
    test_deadly_sig('QUIT', true, true)
  end)

  it('write if SIGTSTP & awa on', function()
    test_deadly_sig('TSTP', true, true)
  end)

  it('dont write if SIGTERM & awa on', function()
    test_deadly_sig('TERM', true, false)
  end)

  it('dont write if SIGKILL & awa on', function()
    test_deadly_sig('KILL', true, false)
  end)

  it('dont write if SIGHUP & awa off', function()
    test_deadly_sig('HUP', false, false)
  end)

  it('dont write if SIGQUIT & awa off', function()
    test_deadly_sig('HUP', false, false)
  end)

  it('dont write if SIGTSTP & awa off', function()
    test_deadly_sig('TSTP', false, false)
  end)

  it('dont write if SIGTERM & awa off', function()
    test_deadly_sig('TERM', false, false)
  end)

  it('dont write if SIGKILL & awa off', function()
    test_deadly_sig('KILL', false, false)
  end)
end)
