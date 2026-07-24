local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local tt = require('test.functional.testterm')
local feed_data = tt.feed_data

describe('vim._core.run_in_terminal', function()
  before_each(n.clear)

  it('run() blocks until the process exits, returns its exit code', function()
    t.eq(
      0,
      n.exec_lua([[return require('vim._core.run_in_terminal').run({ 'sh', '-c', 'sleep 0.1' })]])
    )
    t.eq(
      3,
      n.exec_lua([[return require('vim._core.run_in_terminal').run({ 'sh', '-c', 'exit 3' })]])
    )
  end)

  it('run() hosts a child Nvim that edits a file and round-trips it #40407', function()
    local result = n.exec_lua([[
      local tmp = vim.fn.tempname()
      vim.fn.writefile({ 'foo' }, tmp)
      local code = require('vim._core.run_in_terminal').run({
        vim.v.progpath, '--clean', '-c',
        'lua vim.api.nvim_buf_set_lines(0,0,-1,false,{"foo bar"}); vim.cmd("write"); vim.cmd("qall")',
        tmp,
      })
      local r = code == 0 and table.concat(vim.fn.readfile(tmp), '\n') or nil
      vim.fn.delete(tmp)
      return r
    ]])
    t.eq('foo bar', result)
  end)

  -- The parent stays responsive while blocked in run()/terminal_enter: a UI client (the harness) sees
  -- the child's live output. (Guards against a "GUI freezes during the modal loop" regression.) The
  -- child here is `sh` (raw pty bytes, reliable); a *nested Nvim's* render does not surface reliably
  -- through this doubly-nested test pty, so that variant is covered indirectly by the run_nvim tests.
  it('forwards UI: client sees terminal output while blocked in run()', function()
    local screen = tt.setup_child_nvim({ '--clean' }, { env = { COLORTERM = 'xterm-256color' } })
    screen:expect({ any = '%[No Name%]' })
    feed_data(
      ":lua require('vim._core.run_in_terminal').run({ 'sh', '-c', 'echo MARKER_XYZZY; sleep 2' })\r"
    )
    screen:expect({ any = 'MARKER_XYZZY' })
  end)

  -- run_nvim's full path inside a nested child: cmdwin host (require'd with $VIMRUNTIME, which
  -- jobstart() unsets) + seeded file, edited and round-tripped. One feed, so nothing is queued while
  -- the child is in Terminal-mode.
  it('run_nvim machinery: cmdwin host + seeded file, round-trips #40407', function()
    local screen = tt.setup_child_nvim({ '--clean' }, { env = { COLORTERM = 'xterm-256color' } })
    screen:expect({ any = '%[No Name%]' })
    feed_data(
      ":lua local tmp=vim.fn.tempname(); vim.fn.writefile({'foo'},tmp); "
        .. "require('vim._core.run_in_terminal').run({vim.v.progpath,'--clean',"
        .. "'-c',[[lua require('vim._core.cmdwin').host()]],"
        .. "'-c',[[lua vim.api.nvim_set_current_line(vim.api.nvim_get_current_line()..' bar')]],"
        .. "'-c','write','-c','qall!',tmp}, {env={VIMRUNTIME=vim.env.VIMRUNTIME}}); "
        .. "vim.api.nvim_echo({{'DIAG '..table.concat(vim.fn.readfile(tmp),'|')}}, false, {})\r"
    )
    screen:expect({ any = 'DIAG foo bar' })
  end)

  -- input()'s c_CTRL-F opens the cmdwin in a child Nvim (the blocking-prompt path wired in
  -- open_cmdwin → cmdwin_run_blocking). Real keystrokes edit the grandchild; confirming returns the
  -- edited text as input()'s value. The grandchild renders once the buffer *changes* (the idle case
  -- doesn't flush through nested test ptys, but an edit does). #40407
  it('input() c_CTRL-F edits in a child Nvim and returns the result #40407', function()
    local screen = tt.setup_child_nvim({ '--clean' }, { env = { COLORTERM = 'xterm-256color' } })
    screen:expect({ any = '%[No Name%]' })
    -- input() blocks with initial text "foo", then echoes its return value (a forced flush we can
    -- observe; the grandchild's own render does not flush through the nested test pty when idle).
    feed_data(
      ":lua _G.r = vim.fn.input('p>', 'foo'); vim.api.nvim_echo({{'RESULT='.._G.r}}, false, {})\r"
    )
    screen:expect({ any = 'p>foo' })
    -- \x06 is c_CTRL-F: opens the cmdwin in a child Nvim. Append " bar" (insert mode appends at end)
    -- and confirm with <CR>; the grandchild writes+exits, input() returns, the echo above runs.
    feed_data('\x06')
    feed_data(' bar\r')
    screen:expect({ any = 'RESULT=foo bar' })
  end)

  -- run_nvim shares the parent's history with the child via the ShaDa file: it materializes history
  -- to a temp ShaDa and passes it as the child's `-i`. Tested non-interactively (child reports the
  -- inherited history via `-c`, then exits) with run_nvim's exact ShaDa wiring. #40407
  it('run_nvim: child inherits parent history via ShaDa (-i) #40407', function()
    local result = n.exec_lua([[
      vim.fn.histadd('/', 'SEARCHMARK_XYZ')
      local shada = vim.fn.tempname()
      vim.cmd('wshada ' .. vim.fn.fnameescape(shada))
      local out = vim.fn.tempname()
      require('vim._core.run_in_terminal').run({
        vim.v.progpath, '--clean', '-i', shada,
        '-c', ('lua vim.fn.writefile({vim.fn.histget("/", -1)}, %q)'):format(out),
        '-c', 'qall!',
      }, { env = { VIMRUNTIME = vim.env.VIMRUNTIME } })
      local r = table.concat(vim.fn.readfile(out), '\n')
      vim.fn.delete(shada)
      vim.fn.delete(out)
      return r
    ]])
    t.eq('SEARCHMARK_XYZ', result)
  end)

  -- cmdwin.host lays out history like the real cmdwin: one entry per line, the seed as the editable
  -- last line. Inspected non-interactively (report the buffer lines via `-c`, then exit). #40407
  it('cmdwin.host shows history as lines with the seed last #40407', function()
    local lines = n.exec_lua([[
      vim.fn.histadd('search', 'oldsearch1')
      vim.fn.histadd('search', 'oldsearch2')
      local shada = vim.fn.tempname()
      vim.cmd('wshada ' .. vim.fn.fnameescape(shada))
      local seed = vim.fn.tempname()
      vim.fn.writefile({ 'SEEDLINE' }, seed)
      local out = vim.fn.tempname()
      require('vim._core.run_in_terminal').run({
        vim.v.progpath, '--clean', '-i', shada,
        '-c', "lua require('vim._core.cmdwin').host('search')",
        '-c', ('lua vim.fn.writefile(vim.api.nvim_buf_get_lines(0,0,-1,false), %q)'):format(out),
        '-c', 'qall!', seed,
      }, { env = { VIMRUNTIME = vim.env.VIMRUNTIME } })
      local r = vim.fn.readfile(out)
      vim.fn.delete(shada)
      vim.fn.delete(seed)
      vim.fn.delete(out)
      return r
    ]])
    t.eq({ 'oldsearch1', 'oldsearch2', 'SEEDLINE' }, lines)
  end)

  -- jobstart stdin='fd': a pty/term job gets a real fd-0 pipe (separate from the tty), so chansend()
  -- feeds the program's stdin while the terminal stays the tty. The buffer is NOT the stdin. #40407
  it("jobstart stdin='fd' gives a pty job a separate stdin pipe #40407", function()
    local got = n.exec_lua([[
      local out = vim.fn.tempname()
      vim.cmd('new')
      local id = vim.fn.jobstart({ 'sh', '-c', 'cat > ' .. out }, { term = true, stdin = 'fd' })
      vim.fn.chansend(id, 'hello\nworld\n')
      vim.fn.chanclose(id, 'stdin') -- EOF on fd 0
      vim.fn.jobwait({ id })
      local r = vim.fn.readfile(out)
      vim.fn.delete(out)
      return r
    ]])
    t.eq({ 'hello', 'world' }, got)
  end)

  -- jobstart stdout='fd': a pty/term job's clean stdout (fd 1) is captured on a separate pipe
  -- (on_stdout), while what the command writes to /dev/tty still renders in the terminal. The
  -- fzf model: TUI on the tty, result on stdout. #40407
  it("jobstart stdout='fd' captures clean stdout while the tty renders #40407", function()
    local got = n.exec_lua([[
      vim.cmd('new')
      local out = {}
      local id = vim.fn.jobstart({ 'sh', '-c', 'printf TUI_ON_TTY > /dev/tty; echo THE_SELECTION' }, {
        term = true, stdout = 'fd',
        on_stdout = function(_, d)
          for _, l in ipairs(d) do if l ~= '' then out[#out + 1] = l end end
        end,
      })
      vim.fn.jobwait({ id })
      vim.wait(500, function() return #out > 0 end)
      local disp = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '')
      return {
        capture = out,
        tty_in_display = disp:find('TUI_ON_TTY') ~= nil,
        stdout_in_display = disp:find('THE_SELECTION') ~= nil,
      }
    ]])
    t.eq({ 'THE_SELECTION' }, got.capture) -- clean stdout captured
    t.eq(true, got.tty_in_display) -- the tty write rendered in the terminal
    t.eq(false, got.stdout_in_display) -- stdout did NOT leak into the display
  end)

  -- run_shell builds the 'shell' argv and returns the command's exit status. #40407
  it('run_shell runs a shell command and returns its exit code #40407', function()
    t.eq(0, n.exec_lua([[return require('vim._core.run_in_terminal').run_shell('exit 0')]]))
    t.eq(7, n.exec_lua([[return require('vim._core.run_in_terminal').run_shell('exit 7')]]))
  end)

  -- write_shell pipes the buffer lines into a command's stdin (via the stdin='fd' pipe). #40407
  it('write_shell pipes buffer lines to a command stdin #40407', function()
    local got = n.exec_lua([[
      local out = vim.fn.tempname()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'alpha', 'beta', 'gamma' })
      require('vim._core.run_in_terminal').write_shell(('cat > %s'):format(out), 1, 3)
      local r = vim.fn.readfile(out)
      vim.fn.delete(out)
      return r
    ]])
    t.eq({ 'alpha', 'beta', 'gamma' }, got)
  end)

  -- `:[range]w :term cmd` (the `:w :term sudo tee %` trick): the buffer is piped to the command's
  -- stdin while it runs in a terminal (so it could prompt on the tty). #40407
  it(':w :term cmd pipes the buffer to the command #40407', function()
    local got = n.exec_lua([[
      local out = vim.fn.tempname()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'one', 'two' })
      vim.cmd(('%%w :term cat > %s'):format(out))
      local r = vim.fn.readfile(out)
      vim.fn.delete(out)
      return r
    ]])
    t.eq({ 'one', 'two' }, got)
  end)

  -- The ":term" sigil is strict: a range/modifier prefix (e.g. ":1term") does NOT resolve to
  -- CMD_terminal, so it falls through to a classic `:w {file}` and never pipes to the command. #40407
  it(':w :1term is not treated as the :term sigil #40407', function()
    local triggered = n.exec_lua([[
      local target = vim.fn.tempname()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'x' })
      -- With strict semantics this is a classic write to a (weirdly named) file, which may error;
      -- either way the shell redirect `> target` must NOT run, so `target` stays absent.
      pcall(vim.cmd, ('1w :1term cat > %s'):format(target))
      local existed = vim.uv.fs_stat(target) ~= nil
      vim.fn.delete(target)
      return existed
    ]])
    t.eq(false, triggered)
  end)

  -- `:[range]term {cmd}`: open a terminal running {cmd} with [range] piped to its stdin (non-blocking,
  -- a normal terminal window). No-range `:term` is unchanged. #40407
  it(':[range]term pipes the range to the command stdin #40407', function()
    local got = n.exec_lua([[
      local out = vim.fn.tempname()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'r1', 'r2', 'r3' })
      vim.cmd(('%%term cat > %s'):format(out))
      vim.fn.jobwait({ vim.bo.channel }) -- non-blocking; wait for cat to drain stdin + exit
      local r = vim.fn.readfile(out)
      vim.fn.delete(out)
      return r
    ]])
    t.eq({ 'r1', 'r2', 'r3' }, got)
  end)

  -- ':[range]r :term cmd' runs cmd in a terminal, captures its stdout (stdout='fd'), and inserts it
  -- after the addressed line. Non-blocking, so wait for the async insert. #40407
  it(':r :term inserts the command output after the line #40407', function()
    local got = n.exec_lua([[
      local buf = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'line1', 'line2' })
      vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- :r inserts after the current line (line1)
      vim.cmd('r :term printf "AA\\nBB\\n"')
      vim.wait(2000, function()
        return vim.tbl_contains(vim.api.nvim_buf_get_lines(buf, 0, -1, false), 'AA')
      end)
      return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    ]])
    t.eq({ 'line1', 'AA', 'BB', 'line2' }, got)
  end)

  -- `:%w :term nvim -`: pipe the buffer into a child Nvim reading stdin (`-`). Interactive use works
  -- for real; the child is `--headless` here only because this nested-pty harness can't drive a TUI
  -- grandchild (no keystrokes, and it blocks on terminal queries the harness doesn't answer). #40407
  it(':%w :term nvim - pipes the buffer into a child Nvim #40407', function()
    local got = n.exec_lua([[
      local out = vim.fn.tempname()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'piped1', 'piped2', 'piped3' })
      -- Child reads the piped buffer from stdin, writes it out, and exits.
      local inner = ('VIMRUNTIME=%s %s --clean --headless - -c %s -c %s -c qa'):format(
        vim.fn.shellescape(vim.env.VIMRUNTIME),
        vim.fn.shellescape(vim.v.progpath),
        vim.fn.shellescape('w ' .. out),
        vim.fn.shellescape('set nomodified'))
      vim.cmd('%w :term ' .. inner)
      local r = vim.fn.readfile(out)
      vim.fn.delete(out)
      return r
    ]])
    t.eq({ 'piped1', 'piped2', 'piped3' }, got)
  end)
end)
