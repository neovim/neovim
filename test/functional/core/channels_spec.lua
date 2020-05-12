local helpers = require('test.functional.helpers')(after_each)
local uname = helpers.uname
local clear, eq, eval, next_msg, ok, source = helpers.clear, helpers.eq,
   helpers.eval, helpers.next_msg, helpers.ok, helpers.source
local command, funcs, meths = helpers.command, helpers.funcs, helpers.meths
local sleep = helpers.sleep
local spawn, nvim_argv = helpers.spawn, helpers.nvim_argv
local set_session = helpers.set_session
local nvim_prog = helpers.nvim_prog
local is_os = helpers.is_os
local retry = helpers.retry
local expect_twostreams = helpers.expect_twostreams

describe('channels', function()
  local init = [[
    function! Normalize(data) abort
      " Windows: remove ^M
      return type([]) == type(a:data)
        \ ? map(a:data, 'substitute(v:val, "\r", "", "g")')
        \ : a:data
    endfunction
    function! OnEvent(id, data, event) dict
      call rpcnotify(1, a:event, a:id, a:data)
    endfunction
  ]]
  before_each(function()
    clear()
    source(init)
  end)

  pending('can connect to socket', function()
    local server = spawn(nvim_argv)
    set_session(server)
    local address = funcs.serverlist()[1]
    local client = spawn(nvim_argv)
    set_session(client, true)
    source(init)

    meths.set_var('address', address)
    command("let g:id = sockconnect('pipe', address, {'on_data':'OnEvent'})")
    local id = eval("g:id")
    ok(id > 0)

    command("call chansend(g:id, msgpackdump([[2,'nvim_set_var',['code',23]]]))")
    set_session(server, true)
    retry(nil, 1000, function()
      eq(23, meths.get_var('code'))
    end)
    set_session(client, true)

    command("call chansend(g:id, msgpackdump([[0,0,'nvim_eval',['2+3']]]))")


    local res = eval("msgpackdump([[1,0,v:null,5]])")
    eq({"\148\001\n\192\005"}, res)
    eq({'notification', 'data', {id, res}}, next_msg())
    command("call chansend(g:id, msgpackdump([[2,'nvim_command',['quit']]]))")
    eq({'notification', 'data', {id, {''}}}, next_msg())
  end)

  it('can use stdio channel', function()
    source([[
      let g:job_opts = {
      \ 'on_stdout': function('OnEvent'),
      \ 'on_stderr': function('OnEvent'),
      \ 'on_exit': function('OnEvent'),
      \ }
    ]])
    meths.set_var("nvim_prog", nvim_prog)
    meths.set_var("code", [[
      function! OnEvent(id, data, event) dict
        let text = string([a:id, a:data, a:event])
        call chansend(g:x, text)

        if a:data == ['']
          call chansend(v:stderr, "*dies*")
          quit
        endif
      endfunction
      let g:x = stdioopen({'on_stdin':'OnEvent'})
      call chansend(x, "hello")
    ]])
    command("let g:id = jobstart([ g:nvim_prog, '-u', 'NONE', '-i', 'NONE', '--cmd', 'set noswapfile', '--headless', '--cmd', g:code], g:job_opts)")
    local id = eval("g:id")
    ok(id > 0)

    eq({ "notification", "stdout", {id, { "hello" } } }, next_msg())

    command("call chansend(id, 'howdy')")
    eq({"notification", "stdout", {id, {"[1, ['howdy'], 'stdin']"}}}, next_msg())

    command("call chanclose(id, 'stdin')")
    expect_twostreams({{"notification", "stdout", {id, {"[1, [''], 'stdin']"}}},
                       {'notification', 'stdout', {id, {''}}}},
                      {{"notification", "stderr", {id, {"*dies*"}}},
                       {'notification', 'stderr', {id, {''}}}})
    eq({"notification", "exit", {3,0}}, next_msg())
  end)

  local function expect_twoline(id, stream, line1, line2, nobr)
    local msg = next_msg()
    local joined = nobr and {line1..line2} or {line1, line2}
    if not pcall(eq, {"notification", stream, {id, joined}}, msg) then
      local sep = (not nobr) and "" or nil
      eq({"notification", stream, {id, {line1, sep}}}, msg)
      eq({"notification", stream, {id, {line2}}}, next_msg())
    end
  end

  it('can use stdio channel with pty', function()
    if helpers.pending_win32(pending) then return end
    source([[
      let g:job_opts = {
      \ 'on_stdout': function('OnEvent'),
      \ 'on_exit': function('OnEvent'),
      \ 'pty': v:true,
      \ }
    ]])
    meths.set_var("nvim_prog", nvim_prog)
    meths.set_var("code", [[
      function! OnEvent(id, data, event) dict
        let text = string([a:id, a:data, a:event])
        call chansend(g:x, text)
      endfunction
      let g:x = stdioopen({'on_stdin':'OnEvent'})
    ]])
    command("let g:id = jobstart([ g:nvim_prog, '-u', 'NONE', '-i', 'NONE', '--cmd', 'set noswapfile', '--headless', '--cmd', g:code], g:job_opts)")
    local id = eval("g:id")
    ok(id > 0)

    command("call chansend(id, 'TEXT\n')")
    expect_twoline(id, "stdout", "TEXT\r", "[1, ['TEXT', ''], 'stdin']")


    command("call chansend(id, 'neovan')")
    eq({"notification", "stdout", {id, {"neovan"}}}, next_msg())
    command("call chansend(id, '\127\127im\n')")
    expect_twoline(id, "stdout", "\b \b\b \bim\r", "[1, ['neovim', ''], 'stdin']")

    command("call chansend(id, 'incomplet\004')")

    local is_bsd = not not string.find(uname(), 'bsd')
    local bsdlike = is_bsd or is_os('mac')
    local extra = bsdlike and "^D\008\008" or ""
    expect_twoline(id, "stdout",
                   "incomplet"..extra, "[1, ['incomplet'], 'stdin']", true)


    command("call chansend(id, '\004')")
    if bsdlike then
      expect_twoline(id, "stdout", extra, "[1, [''], 'stdin']", true)
    else
      eq({"notification", "stdout", {id, {"[1, [''], 'stdin']"}}}, next_msg())
    end

    -- channel is still open
    command("call chansend(id, 'hi again!\n')")
    eq({"notification", "stdout", {id, {"hi again!\r", ""}}}, next_msg())
  end)


  it('stdio channel can use rpc and stderr simultaneously', function()
    if helpers.pending_win32(pending) then return end
    source([[
      let g:job_opts = {
      \ 'on_stderr': function('OnEvent'),
      \ 'on_exit': function('OnEvent'),
      \ 'rpc': v:true,
      \ }
    ]])
    meths.set_var("nvim_prog", nvim_prog)
    meths.set_var("code", [[
      let id = stdioopen({'rpc':v:true})
      call rpcnotify(id,"nvim_call_function", "rpcnotify", [1, "message", "hi there!", id])
      call chansend(v:stderr, "trouble!")
    ]])
    command("let id = jobstart([ g:nvim_prog, '-u', 'NONE', '-i', 'NONE', '--cmd', 'set noswapfile', '--headless', '--cmd', g:code], g:job_opts)")
    eq({"notification", "message", {"hi there!", 1}}, next_msg())
    eq({"notification", "stderr", {3, {"trouble!"}}}, next_msg())

    eq(30, eval("rpcrequest(id, 'nvim_eval', '[chansend(v:stderr, \"math??\"), 5*6][1]')"))
    eq({"notification", "stderr", {3, {"math??"}}}, next_msg())

    local _, err = pcall(command,"call rpcrequest(id, 'nvim_command', 'call chanclose(v:stderr, \"stdin\")')")
    ok(string.find(err,"E906: invalid stream for channel") ~= nil)

    eq(1, eval("rpcrequest(id, 'nvim_eval', 'chanclose(v:stderr, \"stderr\")')"))
    eq({"notification", "stderr", {3, {""}}}, next_msg())

    command("call rpcnotify(id, 'nvim_command', 'quit')")
    eq({"notification", "exit", {3, 0}}, next_msg())
  end)

  it('can use buffered output mode', function()
    source([[
      let g:job_opts = {
      \ 'on_stdout': function('OnEvent'),
      \ 'on_exit': function('OnEvent'),
      \ 'stdout_buffered': v:true,
      \ }
    ]])
    command("let id = jobstart(['grep', '^[0-9]'], g:job_opts)")
    local id = eval("g:id")

    command([[call chansend(id, "stuff\n10 PRINT \"NVIM\"\nxx")]])
    sleep(10)
    command([[call chansend(id, "xx\n20 GOTO 10\nzz\n")]])
    command("call chanclose(id, 'stdin')")

    eq({"notification", "stdout", {id, {'10 PRINT "NVIM"',
                                       '20 GOTO 10', ''}}}, next_msg())
    eq({"notification", "exit", {id, 0}}, next_msg())

    command("let id = jobstart(['grep', '^[0-9]'], g:job_opts)")
    id = eval("g:id")

    command([[call chansend(id, "is no number\nnot at all")]])
    command("call chanclose(id, 'stdin')")

    -- works correctly with no output
    eq({"notification", "stdout", {id, {''}}}, next_msg())
    eq({"notification", "exit", {id, 1}}, next_msg())

  end)

  it('can use buffered output mode with no stream callback', function()
    source([[
      function! OnEvent(id, data, event) dict
        call rpcnotify(1, a:event, a:id, a:data, self.stdout)
      endfunction
      let g:job_opts = {
      \ 'on_exit': function('OnEvent'),
      \ 'stdout_buffered': v:true,
      \ }
    ]])
    command("let id = jobstart(['grep', '^[0-9]'], g:job_opts)")
    local id = eval("g:id")

    command([[call chansend(id, "stuff\n10 PRINT \"NVIM\"\nxx")]])
    sleep(10)
    command([[call chansend(id, "xx\n20 GOTO 10\nzz\n")]])
    command("call chanclose(id, 'stdin')")

    eq({"notification", "exit", {id, 0, {'10 PRINT "NVIM"',
                                         '20 GOTO 10', ''}}}, next_msg())

    -- if dict is reused the new value is not stored,
    -- but nvim also does not crash
    command("let id = jobstart(['cat'], g:job_opts)")
    id = eval("g:id")

    command([[call chansend(id, "cat text\n")]])
    sleep(10)
    command("call chanclose(id, 'stdin')")

    -- old value was not overwritten
    eq({"notification", "exit", {id, 0, {'10 PRINT "NVIM"',
                                         '20 GOTO 10', ''}}}, next_msg())

    -- and an error was thrown.
    eq("E5210: dict key 'stdout' already set for buffered stream in channel "..id, eval('v:errmsg'))

    -- reset dictionary
    source([[
      let g:job_opts = {
      \ 'on_exit': function('OnEvent'),
      \ 'stdout_buffered': v:true,
      \ }
    ]])
    command("let id = jobstart(['grep', '^[0-9]'], g:job_opts)")
    id = eval("g:id")

    command([[call chansend(id, "is no number\nnot at all")]])
    command("call chanclose(id, 'stdin')")

    -- works correctly with no output
    eq({"notification", "exit", {id, 1, {''}}}, next_msg())
  end)
end)
