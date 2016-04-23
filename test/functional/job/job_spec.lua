
local helpers = require('test.functional.helpers')(after_each)
local clear, eq, eval, execute, feed, insert, neq, next_msg, nvim,
  nvim_dir, ok, source, write_file, mkdir, rmdir = helpers.clear,
  helpers.eq, helpers.eval, helpers.execute, helpers.feed,
  helpers.insert, helpers.neq, helpers.next_message, helpers.nvim,
  helpers.nvim_dir, helpers.ok, helpers.source,
  helpers.write_file, helpers.mkdir, helpers.rmdir
local Screen = require('test.functional.ui.screen')


describe('jobs', function()
  local channel

  before_each(function()
    clear()
    channel = nvim('get_api_info')[1]
    nvim('set_var', 'channel', channel)
    source([[
    function! s:OnEvent(id, data, event)
      let userdata = get(self, 'user')
      call rpcnotify(g:channel, a:event, userdata, a:data)
    endfunction
    let g:job_opts = {
    \ 'on_stdout': function('s:OnEvent'),
    \ 'on_stderr': function('s:OnEvent'),
    \ 'on_exit': function('s:OnEvent'),
    \ 'user': 0
    \ }
    ]])
  end)

  it('uses &shell and &shellcmdflag if passed a string', function()
    nvim('command', "let $VAR = 'abc'")
    nvim('command', "let j = jobstart('echo $VAR', g:job_opts)")
    eq({'notification', 'stdout', {0, {'abc', ''}}}, next_msg())
    eq({'notification', 'exit', {0, 0}}, next_msg())
  end)

  it('changes to given / directory', function()
    nvim('command', "let g:job_opts.cwd = '/'")
    nvim('command', "let j = jobstart('pwd', g:job_opts)")
    eq({'notification', 'stdout', {0, {'/', ''}}}, next_msg())
    eq({'notification', 'exit', {0, 0}}, next_msg())
  end)

  it('changes to given `cwd` directory', function()
    local dir = eval('resolve(tempname())')
    mkdir(dir)
    nvim('command', "let g:job_opts.cwd = '" .. dir .. "'")
    nvim('command', "let j = jobstart('pwd', g:job_opts)")
    eq({'notification', 'stdout', {0, {dir, ''}}}, next_msg())
    eq({'notification', 'exit', {0, 0}}, next_msg())
    rmdir(dir)
  end)

  it('fails to change to invalid `cwd`', function()
    local dir = eval('resolve(tempname())."-bogus"')
    local _, err = pcall(function()
      nvim('command', "let g:job_opts.cwd = '" .. dir .. "'")
      nvim('command', "let j = jobstart('pwd', g:job_opts)")
    end)
    ok(string.find(err, "E475: Invalid argument: expected valid directory$") ~= nil)
  end)

  it('returns 0 when it fails to start', function()
    local status, rv = pcall(eval, "jobstart([])")
    eq(false, status)
    ok(rv ~= nil)
  end)

  it('invokes callbacks when the job writes and exits', function()
    nvim('command', "call jobstart(['echo'], g:job_opts)")
    eq({'notification', 'stdout', {0, {'', ''}}}, next_msg())
    eq({'notification', 'exit', {0, 0}}, next_msg())
  end)

  it('allows interactive commands', function()
    nvim('command', "let j = jobstart(['cat', '-'], g:job_opts)")
    neq(0, eval('j'))
    nvim('command', 'call jobsend(j, "abc\\n")')
    eq({'notification', 'stdout', {0, {'abc', ''}}}, next_msg())
    nvim('command', 'call jobsend(j, "123\\nxyz\\n")')
    eq({'notification', 'stdout', {0, {'123', 'xyz', ''}}}, next_msg())
    nvim('command', 'call jobsend(j, [123, "xyz", ""])')
    eq({'notification', 'stdout', {0, {'123', 'xyz', ''}}}, next_msg())
    nvim('command', "call jobstop(j)")
    eq({'notification', 'exit', {0, 0}}, next_msg())
  end)

  it('preserves NULs', function()
    -- Make a file with NULs in it.
    local filename = os.tmpname()
    write_file(filename, "abc\0def\n")

    nvim('command', "let j = jobstart(['cat', '"..filename.."'], g:job_opts)")
    eq({'notification', 'stdout', {0, {'abc\ndef', ''}}}, next_msg())
    eq({'notification', 'exit', {0, 0}}, next_msg())
    os.remove(filename)

    -- jobsend() preserves NULs.
    nvim('command', "let j = jobstart(['cat', '-'], g:job_opts)")
    nvim('command', [[call jobsend(j, ["123\n456",""])]])
    eq({'notification', 'stdout', {0, {'123\n456', ''}}}, next_msg())
    nvim('command', "call jobstop(j)")
  end)

  it("will not buffer data if it doesn't end in newlines", function()
    nvim('command', "let j = jobstart(['cat', '-'], g:job_opts)")
    nvim('command', 'call jobsend(j, "abc\\nxyz")')
    eq({'notification', 'stdout', {0, {'abc', 'xyz'}}}, next_msg())
    nvim('command', "call jobstop(j)")
    eq({'notification', 'exit', {0, 0}}, next_msg())
  end)

  it('can preserve newlines', function()
    nvim('command', "let j = jobstart(['cat', '-'], g:job_opts)")
    nvim('command', 'call jobsend(j, "a\\n\\nc\\n\\n\\n\\nb\\n\\n")')
    eq({'notification', 'stdout',
      {0, {'a', '', 'c', '', '', '', 'b', '', ''}}}, next_msg())
  end)

  it('can preserve nuls', function()
    nvim('command', "let j = jobstart(['cat', '-'], g:job_opts)")
    nvim('command', 'call jobsend(j, ["\n123\n", "abc\\nxyz\n", ""])')
    eq({'notification', 'stdout', {0, {'\n123\n', 'abc\nxyz\n', ''}}},
      next_msg())
    nvim('command', "call jobstop(j)")
    eq({'notification', 'exit', {0, 0}}, next_msg())
  end)

  it('can avoid sending final newline', function()
    nvim('command', "let j = jobstart(['cat', '-'], g:job_opts)")
    nvim('command', 'call jobsend(j, ["some data", "without\nfinal nl"])')
    eq({'notification', 'stdout', {0, {'some data', 'without\nfinal nl'}}},
      next_msg())
    nvim('command', "call jobstop(j)")
    eq({'notification', 'exit', {0, 0}}, next_msg())
  end)

  it('can close the job streams with jobclose', function()
    nvim('command', "let j = jobstart(['cat', '-'], g:job_opts)")
    nvim('command', 'call jobclose(j, "stdin")')
    eq({'notification', 'exit', {0, 0}}, next_msg())
  end)

  it("won't allow jobsend with a job that closed stdin", function()
    nvim('command', "let j = jobstart(['cat', '-'], g:job_opts)")
    nvim('command', 'call jobclose(j, "stdin")')
    eq(false, pcall(function()
      nvim('command', 'call jobsend(j, ["some data"])')
    end))
  end)

  it('will not allow jobsend/stop on a non-existent job', function()
    eq(false, pcall(eval, "jobsend(-1, 'lol')"))
    eq(false, pcall(eval, "jobstop(-1)"))
  end)

  it('will not allow jobstop twice on the same job', function()
    nvim('command', "let j = jobstart(['cat', '-'], g:job_opts)")
    neq(0, eval('j'))
    eq(true, pcall(eval, "jobstop(j)"))
    eq(false, pcall(eval, "jobstop(j)"))
  end)

  it('will not cause a memory leak if we leave a job running', function()
    nvim('command', "call jobstart(['cat', '-'], g:job_opts)")
  end)

  it('can get the pid value using getpid', function()
    nvim('command', "let j =  jobstart(['cat', '-'], g:job_opts)")
    local pid = eval('jobpid(j)')
    eq(0,os.execute('ps -p '..pid..' > /dev/null'))
    nvim('command', 'call jobstop(j)')
    eq({'notification', 'exit', {0, 0}}, next_msg())
    neq(0,os.execute('ps -p '..pid..' > /dev/null'))
  end)

  it("doesn't survive the exit of nvim", function()
    -- use sleep, which doesn't die on stdin close
    nvim('command', "let j =  jobstart(['sleep', '1000'], g:job_opts)")
    local pid = eval('jobpid(j)')
    eq(0,os.execute('ps -p '..pid..' > /dev/null'))
    clear()
    neq(0,os.execute('ps -p '..pid..' > /dev/null'))
  end)

  it('can survive the exit of nvim with "detach"', function()
    nvim('command', 'let g:job_opts.detach = 1')
    nvim('command', "let j = jobstart(['sleep', '1000'], g:job_opts)")
    local pid = eval('jobpid(j)')
    eq(0,os.execute('ps -p '..pid..' > /dev/null'))
    clear()
    eq(0,os.execute('ps -p '..pid..' > /dev/null'))
    -- clean up after ourselves
    os.execute('kill -9 '..pid..' > /dev/null')
  end)

  it('can pass user data to the callback', function()
    nvim('command', 'let g:job_opts.user = {"n": 5, "s": "str", "l": [1]}')
    nvim('command', "call jobstart(['echo'], g:job_opts)")
    local data = {n = 5, s = 'str', l = {1}}
    eq({'notification', 'stdout', {data, {'', ''}}}, next_msg())
    eq({'notification', 'exit', {data, 0}}, next_msg())
  end)

  it('can omit options', function()
    neq(0, nvim('eval', 'delete(".Xtestjob")'))
    nvim('command', "call jobstart(['touch', '.Xtestjob'])")
    nvim('command', "sleep 100m")
    eq(0, nvim('eval', 'delete(".Xtestjob")'))
  end)

  it('can omit data callbacks', function()
    nvim('command', 'unlet g:job_opts.on_stdout')
    nvim('command', 'unlet g:job_opts.on_stderr')
    nvim('command', 'let g:job_opts.user = 5')
    nvim('command', "call jobstart(['echo'], g:job_opts)")
    eq({'notification', 'exit', {5, 0}}, next_msg())
  end)

  it('can omit exit callback', function()
    nvim('command', 'unlet g:job_opts.on_exit')
    nvim('command', 'let g:job_opts.user = 5')
    nvim('command', "call jobstart(['echo'], g:job_opts)")
    eq({'notification', 'stdout', {5, {'', ''}}}, next_msg())
  end)

  it('will pass return code with the exit event', function()
    nvim('command', 'let g:job_opts.user = 5')
    nvim('command', "call jobstart([&sh, '-c', 'exit 55'], g:job_opts)")
    eq({'notification', 'exit', {5, 55}}, next_msg())
  end)

  it('can receive dictionary functions', function()
    source([[
    let g:dict = {'id': 10}
    function g:dict.on_exit(id, code, event)
      call rpcnotify(g:channel, a:event, a:code, self.id)
    endfunction
    call jobstart([&sh, '-c', 'exit 45'], g:dict)
    ]])
    eq({'notification', 'exit', {45, 10}}, next_msg())
  end)

  it('cant redefine callbacks being used by a job', function()
    local screen = Screen.new()
    screen:attach()
    local script = [[
      function! g:JobHandler(job_id, data, event)
      endfunction

      let g:callbacks = {
      \ 'on_stdout': function('g:JobHandler'),
      \ 'on_stderr': function('g:JobHandler'),
      \ 'on_exit': function('g:JobHandler')
      \ }
      let job = jobstart('cat -', g:callbacks)
    ]]
    source(script)
    feed(':function! g:JobHandler(job_id, data, event)<cr>')
    feed(':endfunction<cr>')
    screen:expect([[
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      :function! g:JobHandler(job_id, data, event)         |
      :  :endfunction                                      |
      E127: Cannot redefine function JobHandler: It is in u|
      se                                                   |
      Press ENTER or type command to continue^              |
    ]])
  end)

  describe('jobwait', function()
    it('returns a list of status codes', function()
      source([[
      call rpcnotify(g:channel, 'wait', jobwait([
      \  jobstart([&sh, '-c', 'sleep 0.10; exit 4']),
      \  jobstart([&sh, '-c', 'sleep 0.110; exit 5']),
      \  jobstart([&sh, '-c', 'sleep 0.210; exit 6']),
      \  jobstart([&sh, '-c', 'sleep 0.310; exit 7'])
      \  ]))
      ]])
      eq({'notification', 'wait', {{4, 5, 6, 7}}}, next_msg())
    end)

    it('will run callbacks while waiting', function()
      source([[
      let g:dict = {'id': 10}
      let g:exits = 0
      function g:dict.on_exit(id, code)
        if a:code != 5
          throw 'Error!'
        endif
        let g:exits += 1
      endfunction
      call jobwait([
      \  jobstart([&sh, '-c', 'sleep 0.010; exit 5'], g:dict),
      \  jobstart([&sh, '-c', 'sleep 0.030; exit 5'], g:dict),
      \  jobstart([&sh, '-c', 'sleep 0.050; exit 5'], g:dict),
      \  jobstart([&sh, '-c', 'sleep 0.070; exit 5'], g:dict)
      \  ])
      call rpcnotify(g:channel, 'wait', g:exits)
      ]])
      eq({'notification', 'wait', {4}}, next_msg())
    end)

    it('will return status codes in the order of passed ids', function()
      source([[
      call rpcnotify(g:channel, 'wait', jobwait([
      \  jobstart([&sh, '-c', 'sleep 0.070; exit 4']),
      \  jobstart([&sh, '-c', 'sleep 0.050; exit 5']),
      \  jobstart([&sh, '-c', 'sleep 0.030; exit 6']),
      \  jobstart([&sh, '-c', 'sleep 0.010; exit 7'])
      \  ]))
      ]])
      eq({'notification', 'wait', {{4, 5, 6, 7}}}, next_msg())
    end)

    it('will return -3 for invalid job ids', function()
      source([[
      call rpcnotify(g:channel, 'wait', jobwait([
      \  -10,
      \  jobstart([&sh, '-c', 'sleep 0.01; exit 5']),
      \  ]))
      ]])
      eq({'notification', 'wait', {{-3, 5}}}, next_msg())
    end)

    it('will return -2 when interrupted', function()
      execute('call rpcnotify(g:channel, "ready") | '..
              'call rpcnotify(g:channel, "wait", '..
              'jobwait([jobstart([&sh, "-c", "sleep 10; exit 55"])]))')
      eq({'notification', 'ready', {}}, next_msg())
      feed('<c-c>')
      eq({'notification', 'wait', {{-2}}}, next_msg())
    end)

    it('can be called recursively', function()
      source([[
      let g:opts = {}
      let g:counter = 0
      function g:opts.on_stdout(id, msg)
        if self.state == 0
          if self.counter < 10
            call Run()
          endif
          let self.state = 1
          call jobsend(a:id, "line1\n")
        elseif self.state == 1
          let self.state = 2
          call jobsend(a:id, "line2\n")
        elseif self.state == 2
          let self.state = 3
          call jobsend(a:id, "line3\n")
        else
          call rpcnotify(g:channel, 'w', printf('job %d closed', self.counter))
          call jobclose(a:id, 'stdin')
        endif
      endfunction
      function g:opts.on_exit()
        call rpcnotify(g:channel, 'w', printf('job %d exited', self.counter))
      endfunction
      function Run()
        let g:counter += 1
        let j = copy(g:opts)
        let j.state = 0
        let j.counter = g:counter
        call jobwait([
        \   jobstart([&sh, '-c', 'echo ready; cat -'], j),
        \ ])
      endfunction
      ]])
      execute('call Run()')
      local r
      for i = 10, 1, -1 do
        r = next_msg()
        eq('job '..i..' closed', r[3][1])
        r = next_msg()
        eq('job '..i..' exited', r[3][1])
      end
      eq(10, nvim('eval', 'g:counter'))
    end)

    describe('with timeout argument', function()
      it('will return -1 if the wait timed out', function()
        source([[
        call rpcnotify(g:channel, 'wait', jobwait([
        \  jobstart([&sh, '-c', 'exit 4']),
        \  jobstart([&sh, '-c', 'sleep 10; exit 5']),
        \  ], 100))
        ]])
        eq({'notification', 'wait', {{4, -1}}}, next_msg())
      end)

      it('can pass 0 to check if a job exists', function()
        source([[
        call rpcnotify(g:channel, 'wait', jobwait([
        \  jobstart([&sh, '-c', 'sleep 0.05; exit 4']),
        \  jobstart([&sh, '-c', 'sleep 0.3; exit 5']),
        \  ], 0))
        ]])
        eq({'notification', 'wait', {{-1, -1}}}, next_msg())
      end)
    end)
  end)

  -- FIXME need to wait until jobsend succeeds before calling jobstop
  pending('will only emit the "exit" event after "stdout" and "stderr"', function()
    nvim('command', "let j = jobstart(['cat', '-'], g:job_opts)")
    local jobid = nvim('eval', 'j')
    nvim('eval', 'jobsend(j, "abcdef")')
    nvim('eval', 'jobstop(j)')
    eq({'notification', 'j', {0, {jobid, 'stdout', {'abcdef'}}}}, next_msg())
    eq({'notification', 'j', {0, {jobid, 'exit'}}}, next_msg())
  end)

  describe('running tty-test program', function()
    local function next_chunk()
      local rv
      while true do
        local msg = next_msg()
        local data = msg[3][2]
        for i = 1, #data do
          data[i] = data[i]:gsub('\n', '\000')
        end
        rv = table.concat(data, '\n')
        rv = rv:gsub('\r\n$', ''):gsub('^\r\n', '')
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
      insert(nvim_dir .. '/tty-test')
      nvim('command', 'let g:job_opts.pty = 1')
      nvim('command', 'let exec = [expand("<cfile>:p")]')
      nvim('command', "let j = jobstart(exec, g:job_opts)")
      eq('tty ready', next_chunk())
    end)

    it('echoing input', function()
      send('test')
      eq('test', next_chunk())
    end)

    it('resizing window', function()
      nvim('command', 'call jobresize(j, 40, 10)')
      eq('rows: 10, cols: 40', next_chunk())
      nvim('command', 'call jobresize(j, 10, 40)')
      eq('rows: 40, cols: 10', next_chunk())
    end)
  end)
end)
