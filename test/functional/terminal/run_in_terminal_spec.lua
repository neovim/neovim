local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local tt = require('test.functional.testterm')
local feed_data = tt.feed_data

describe('vim._core.run_in_terminal', function()
  before_each(n.clear)

  it('run() blocks until the process exits, returns its exit code', function()
    t.eq(0, n.exec_lua([[return require('vim._core.run_in_terminal').run({ 'sh', '-c', 'sleep 0.1' })]]))
    t.eq(3, n.exec_lua([[return require('vim._core.run_in_terminal').run({ 'sh', '-c', 'exit 3' })]]))
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
  -- the child terminal's live output. (Guards against a "GUI freezes during the modal loop" regression.)
  it('forwards UI: client sees terminal output while blocked in run()', function()
    local screen = tt.setup_child_nvim({ '--clean' }, { env = { COLORTERM = 'xterm-256color' } })
    screen:expect({ any = '%[No Name%]' })
    feed_data(":lua require('vim._core.run_in_terminal').run({ 'sh', '-c', 'echo MARKER_XYZZY; sleep 2' })\r")
    screen:expect({ any = 'MARKER_XYZZY' })
  end)

  it('forwards UI: client sees a child Nvim render while blocked in run()', function()
    local screen = tt.setup_child_nvim({ '--clean' }, { env = { COLORTERM = 'xterm-256color' } })
    screen:expect({ any = '%[No Name%]' })
    feed_data(
      ":lua require('vim._core.run_in_terminal').run({ vim.v.progpath, '--clean', '-c',"
        .. "[[lua vim.api.nvim_buf_set_lines(0,0,-1,false,{'GRANDCHILD_RENDER'})]], '-c', 'sleep 2' })\r"
    )
    screen:expect({ any = 'GRANDCHILD_RENDER' })
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
  it("input() c_CTRL-F edits in a child Nvim and returns the result #40407", function()
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
end)
