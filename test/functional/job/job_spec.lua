
local helpers = require('test.functional.helpers')
local clear, nvim, eq, neq, ok, expect, eval, next_message, run, stop, session
  = helpers.clear, helpers.nvim, helpers.eq, helpers.neq, helpers.ok,
  helpers.expect, helpers.eval, helpers.next_message, helpers.run,
  helpers.stop, helpers.session
local insert = helpers.insert

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

  it('will not buffer data if it doesnt end in newlines', function()
    nvim('command', notify_str('v:job_data[1]', 'get(v:job_data, 2)'))
    nvim('command', "let j = jobstart('xxx', 'cat', ['-'])")
    nvim('command', 'call jobsend(j, "abc\\nxyz")')
    eq({'notification', 'stdout', {{'abc', 'xyz'}}}, next_message())
    nvim('command', "call jobstop(j)")
    eq({'notification', 'exit', {0}}, next_message())
  end)

  it('can preserve newlines', function()
    nvim('command', notify_str('v:job_data[1]', 'get(v:job_data, 2)'))
    nvim('command', "let j = jobstart('xxx', 'cat', ['-'])")
    nvim('command', 'call jobsend(j, "a\\n\\nc\\n\\n\\n\\nb\\n\\n")')
    eq({'notification', 'stdout', {{'a', '', 'c', '', '', '', 'b', '', ''}}},
      next_message())
  end)

  it('can preserve nuls', function()
    nvim('command', notify_str('v:job_data[1]', 'get(v:job_data, 2)'))
    nvim('command', "let j = jobstart('xxx', 'cat', ['-'])")
    nvim('command', 'call jobsend(j, ["\n123\n", "abc\\nxyz\n"])')
    eq({'notification', 'stdout', {{'\n123\n', 'abc\nxyz\n', ''}}},
      next_message())
    nvim('command', "call jobstop(j)")
    eq({'notification', 'exit', {0}}, next_message())
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

  describe('running tty-test program', function()
    local function next_chunk()
      local rv = ''
      while true do
        local msg = next_message()
        local data = msg[3][1]
        for i = 1, #data do
          data[i] = data[i]:gsub('\n', '\000')
        end
        rv = table.concat(data, '\n')
        rv = rv:gsub('\r\n$', '')
        if rv ~= '' then
          break
        end
      end
      return rv
    end

    local function send(str)
      nvim('command', 'call jobsend(j, "'..str..'")')
    end

    before_each(function() 
      -- the full path to tty-test seems to be required when running on travis.
      insert('build/bin/tty-test')
      nvim('command', 'let exec = expand("<cfile>:p")')
      nvim('command', notify_str('v:job_data[1]', 'get(v:job_data, 2)'))
      nvim('command', "let j = jobstart('xxx', exec, [], {})")
      eq('tty ready', next_chunk())
    end)

    it('echoing input', function()
      send('test')
      -- the tty driver will echo input by default
      eq('test', next_chunk())
    end)

    it('resizing window', function()
      nvim('command', 'call jobresize(j, 40, 10)')
      eq('screen resized. rows: 10, columns: 40', next_chunk())
      nvim('command', 'call jobresize(j, 10, 40)')
      eq('screen resized. rows: 40, columns: 10', next_chunk())
    end)

    -- FIXME This test is flawed because there is no telling when the OS will send chunks of data.
    pending('preprocessing ctrl+c with terminal driver', function()
      send('\\<c-c>')
      eq('^Cinterrupt received, press again to exit', next_chunk())
      send('\\<c-c>')
      eq('^Ctty done', next_chunk())
      eq({'notification', 'exit', {0}}, next_message())
    end)
  end)
end)
