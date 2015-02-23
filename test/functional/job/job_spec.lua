
local helpers = require('test.functional.helpers')
local clear, nvim, eq, neq, ok, expect, eval, next_message, run, stop, session
  = helpers.clear, helpers.nvim, helpers.eq, helpers.neq, helpers.ok,
  helpers.expect, helpers.eval, helpers.next_message, helpers.run,
  helpers.stop, helpers.session

local channel = nvim('get_api_info')[1]

describe('jobs', function()
  before_each(clear)

  -- Creates the string to make an autocmd to notify us.
  local notify_str = function(expr1, expr2)
    local str = "au! JobActivity xxx call rpcnotify("..channel..", "..expr1
    if expr2 ~= nil then
      str = str..", "..expr2
    end
    return str..")"
  end

  local notify_job = function()
    return "au! JobActivity xxx call rpcnotify("..channel..", 'j', v:job_data)"
  end

  it('returns 0 when it fails to start', function()
    local status, rv = pcall(eval, "jobstart('', '')")
    eq(false, status)
    ok(rv ~= nil)
  end)

  it('calls JobActivity when the job writes and exits', function()
    nvim('command', notify_str('v:job_data[1]'))
    nvim('command', "call jobstart('xxx', 'echo')")
    eq({'notification', 'stdout', {}}, next_message())
    eq({'notification', 'exit', {}}, next_message())
  end)

  it('allows interactive commands', function()
    nvim('command', notify_str('v:job_data[1]', 'get(v:job_data, 2)'))
    nvim('command', "let j = jobstart('xxx', 'cat', ['-'])")
    neq(0, eval('j'))
    nvim('command', 'call jobsend(j, "abc\\n")')
    eq({'notification', 'stdout', {{'abc', ''}}}, next_message())
    nvim('command', 'call jobsend(j, "123\\nxyz\\n")')
    eq({'notification', 'stdout', {{'123', 'xyz', ''}}}, next_message())
    nvim('command', 'call jobsend(j, [123, "xyz"])')
    eq({'notification', 'stdout', {{'123', 'xyz', ''}}}, next_message())
    nvim('command', "call jobstop(j)")
    eq({'notification', 'exit', {0}}, next_message())
  end)

  it('preserves NULs', function()
    -- Make a file with NULs in it.
    local filename = os.tmpname()
    local file = io.open(filename, "w")
    file:write("abc\0def\n")
    file:close()

    -- v:job_data preserves NULs.
    nvim('command', notify_str('v:job_data[1]', 'get(v:job_data, 2)'))
    nvim('command', "let j = jobstart('xxx', 'cat', ['"..filename.."'])")
    eq({'notification', 'stdout', {{'abc\ndef', ''}}}, next_message())
    eq({'notification', 'exit', {0}}, next_message())
    os.remove(filename)

    -- jobsend() preserves NULs.
    nvim('command', "let j = jobstart('xxx', 'cat', ['-'])")
    nvim('command', [[call jobsend(j, ["123\n456"])]])
    eq({'notification', 'stdout', {{'123\n456', ''}}}, next_message())
    nvim('command', "call jobstop(j)")
  end)

  it('will retain data that does not end in a newline', function()
    nvim('command', notify_str('v:job_data[1]', 'get(v:job_data, 2)'))
    nvim('command', "let j = jobstart('xxx', 'cat', ['-'])")
    nvim('command', 'call jobsend(j, "abc\\nxyz")')
    eq({'notification', 'stdout', {{'abc', ''}}}, next_message())
    nvim('command', "call jobstop(j)")
    eq({'notification', 'stdout', {{'xyz'}}}, next_message())
    eq({'notification', 'exit', {0}}, next_message())
  end)

  local flags_test = function(flags, expect1, expect2)
    nvim('command', notify_str('v:job_data[1]', 'get(v:job_data, 2)'))
    nvim('command', "let j = jobstart('xxx', 'cat', ['-'], "..flags..")")
    nvim('command', 'call jobsend(j, "abc\\nxyz")')
    eq({'notification', 'stdout', {expect1}}, next_message())
    nvim('command', "call jobstop(j)")
    if expect2 ~= nil then
      eq({'notification', 'stdout', {expect2}}, next_message())
    end
    eq({'notification', 'exit', {0}}, next_message())
  end

  it('will flush all output if third argument is greater than zero', function()
    flags_test('1', 'abc\nxyz')
  end)
  
  it('will flush all incoming data if third argument contains "u"', function()
    flags_test("'u'", {'abc', 'xyz'})
  end)

  it('will make v:job_data[2] a string if third argument contains "s"', function()
    flags_test("'s'", 'abc\n', 'xyz')
  end)

  it('will make v:job_data[2] a list if third argument contains "l"', function()
    flags_test("'l'", {'abc', ''}, {'xyz'})
  end)

  it('will make v:job_data[2] an unbuffered string if third argument contains "us"', function()
    flags_test("'us'", 'abc\nxyz')
  end)

  it('will make v:job_data[2] an unbuffered list if third argument contains "ul"', function()
    flags_test("'ul'", {'abc', 'xyz'})
  end)

  it('will not allow jobsend/stop on a non-existent job', function()
    eq(false, pcall(eval, "jobsend(-1, 'lol')"))
    eq(false, pcall(eval, "jobstop(-1)"))
  end)

  it('will not allow jobstop twice on the same job', function()
    nvim('command', "let j = jobstart('xxx', 'cat', ['-'])")
    neq(0, eval('j'))
    eq(true, pcall(eval, "jobstop(j)"))
    eq(false, pcall(eval, "jobstop(j)"))
  end)

  it('will not cause a memory leak if we leave a job running', function()
    nvim('command', "call jobstart('xxx', 'cat', ['-'])")
  end)

  -- FIXME need to wait until jobsend succeeds before calling jobstop
  pending('will only emit the "exit" event after "stdout" and "stderr"', function()
    nvim('command', notify_job())
    nvim('command', "let j = jobstart('xxx', 'cat', ['-'])")
    local jobid = nvim('eval', 'j')
    nvim('eval', 'jobsend(j, "abcdef")')
    nvim('eval', 'jobstop(j)')
    eq({'notification', 'j', {{jobid, 'stdout', {'abcdef'}}}}, next_message())
    eq({'notification', 'j', {{jobid, 'exit'}}}, next_message())
  end)
end)
