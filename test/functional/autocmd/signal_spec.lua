local t = require('test.functional.testutil')(after_each)

local clear = t.clear
local command = t.command
local eq = t.eq
local fn = t.fn
local next_msg = t.next_msg
local is_os = t.is_os
local skip = t.skip

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
