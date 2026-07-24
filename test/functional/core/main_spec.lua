local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local describe, it, before_each, after_each, finally =
  t.describe, t.it, t.before_each, t.after_each, t.finally
local uv = vim.uv

local eq = t.eq
local ok = t.ok
local matches = t.matches
local eval = n.eval
local clear = n.clear
local fn = n.fn
local write_file = t.write_file
local is_os = t.is_os

describe('command-line option', function()
  describe('-s', function()
    local fname = 'Xtest-functional-core-main-s'
    local fname_2 = fname .. '.2'
    local nonexistent_fname = fname .. '.nonexistent'
    local dollar_fname = '$' .. fname

    before_each(function()
      clear()
      os.remove(fname)
      os.remove(dollar_fname)
    end)

    after_each(function()
      os.remove(fname)
      os.remove(dollar_fname)
    end)

    it('treats - as stdin', function()
      eq(nil, uv.fs_stat(fname))
      fn.system({
        n.nvim_prog,
        '-u',
        'NONE',
        '-i',
        'NONE',
        '--headless',
        '--cmd',
        'set noswapfile shortmess+=IFW fileformats=unix',
        '-s',
        '-',
        fname,
      }, { ':call setline(1, "42")', ':wqall!', '' })
      eq(0, eval('v:shell_error'))
      local attrs = uv.fs_stat(fname)
      eq(#'42\n', attrs.size)
    end)

    it('does not expand $VAR', function()
      eq(nil, uv.fs_stat(fname))
      eq(true, not not dollar_fname:find('%$%w+'))
      write_file(dollar_fname, ':call setline(1, "100500")\n:wqall!\n')
      local p = n.spawn_wait(
        '--cmd',
        'set noswapfile shortmess+=IFW fileformats=unix',
        '-s',
        dollar_fname,
        fname
      )
      eq(0, p.status)
      local attrs = uv.fs_stat(fname)
      eq(#'100500\n', attrs.size)
    end)

    it('does not crash when running completion in Ex mode', function()
      local p =
        n.spawn_wait('--clean', '-e', '-s', '--cmd', 'exe "norm! i\\<C-X>\\<C-V>"', '--cmd', 'qa!')
      eq(0, p.status)
    end)

    it('does not crash when running completion from -l script', function()
      local lua_fname = 'Xinscompl.lua'
      write_file(lua_fname, [=[vim.cmd([[exe "norm! i\<C-X>\<C-V>"]])]=])
      finally(function()
        os.remove(lua_fname)
      end)
      local p = n.spawn_wait('--clean', '-l', lua_fname)
      eq(0, p.status)
    end)

    it('does not crash after reading from stdin in non-headless mode', function()
      -- Repro from fdfa1ed (2017): the empty `echo ""` pipe makes scriptin (`-s -`) hit EOF
      -- immediately and call closescript(); if scriptin held fd 0 directly, libuv asserts.
      --
      -- Note: can't use nvim_chan_send because pty stdin never EOFs.
      local nvim_set = 'set noswapfile shortmess+=IFW fileformats=unix notermguicolors'
      local shell_cmd = ([[echo "" | %s "%s" --clean --cmd "%s" -s -]]):format(
        is_os('win') and '&' or '',
        n.nvim_prog,
        nvim_set
      )
      if is_os('win') then
        -- Use PowerShell; cmd.exe mis-parses libuv's `\"…\"` (MSVCRT quoting).
        n.set_shell_powershell()
      end
      local screen = Screen.new(40, 8)
      fn.jobstart(shell_cmd, {
        term = true,
        env = { VIMRUNTIME = os.getenv('VIMRUNTIME') },
      })
      -- First screen confirms Nvim reached TUI (didn't crash closing scriptin).
      screen:expect(
        [[
        ^                                        |
        ~                                       |*4
        {1:[No Name]             0,0-1          All}|
                                                |*2
      ]],
        { [1] = { reverse = true } }
      )

      -- Exit with code 42 to avoid false positives.
      n.feed('i:cq 42<CR>')

      if is_os('win') then
        -- XXX: `:cq 42` isn't reaching Nvim, or Nvim exits 1 anyway?
        screen:expect({ any = '%[Process exited 1%]' })
      else
        screen:expect({ any = '%[Process exited 42%]' })
      end
      --[=[ Example of incorrect output:
      screen:expect([[
        ^nvim: /var/tmp/portage/dev-libs/libuv-1.|
        10.2/work/libuv-1.10.2/src/unix/core.c:5|
        19: uv__close: Assertion `fd > STDERR_FI|
        LENO' failed.                           |
                                                |
        [Process exited 6]                      |
                                                |*2
      ]])
      ]=]
    end)

    it('fails when trying to use nonexistent file with -s', function()
      local p = n.spawn_wait(
        '--cmd',
        'set noswapfile shortmess+=IFW fileformats=unix',
        '--cmd',
        'language C',
        '-s',
        nonexistent_fname
      )
      eq(
        'Cannot open for reading: "' .. nonexistent_fname .. '": no such file or directory\n',
        --- TODO(justinmk): using `p.output` because Nvim emits CRLF even on non-Win. Emit LF instead?
        p:output()
      )
      eq(2, p.status)
    end)

    it('errors out when trying to use -s twice', function()
      write_file(fname, ':call setline(1, "1")\n:wqall!\n')
      write_file(dollar_fname, ':call setline(1, "2")\n:wqall!\n')
      local p = n.spawn_wait(
        '--cmd',
        'set noswapfile shortmess+=IFW fileformats=unix',
        '--cmd',
        'language C',
        '-s',
        fname,
        '-s',
        dollar_fname,
        fname_2
      )
      --- TODO(justinmk): using `p.output` because Nvim emits CRLF even on non-Win. Emit LF instead?
      eq('Attempt to open script file again: "-s ' .. dollar_fname .. '"\n', p:output())
      eq(2, p.status)
      eq(nil, uv.fs_stat(fname_2))
    end)
  end)

  it('nvim -v, :version', function()
    matches('Run ":verbose version"', fn.execute(':version'))
    matches('fall%-back for %$VIM: .*Run :checkhealth', fn.execute(':verbose version'))
    matches('Run "nvim %-V1 %-v"', n.spawn_wait('-v').stdout)
    matches('fall%-back for %$VIM: .*Run :checkhealth', n.spawn_wait('-V1', '-v').stdout)
  end)
end)

describe('nvim:// URI scheme', function()
  local set_session = n.set_session
  local exec_lua = n.exec_lua
  local nvim_prog = n.nvim_prog
  local tmp_id = 0

  local function tmpname(suffix)
    tmp_id = tmp_id + 1
    return string.format('Xmain-uri-%d%s', tmp_id, suffix or '')
  end

  local function abspath(path)
    return fn.fnamemodify(path, ':p')
  end

  local function run_uri(server, ...)
    set_session(server)
    local addr = fn.serverlist()[1]
    local uris = { ... }
    for i, uri in ipairs(uris) do
      uris[i] = uri .. '&server=' .. addr
    end

    local client_starter = n.new_session(true)
    set_session(client_starter)
    eq(
      { 0 },
      exec_lua(
        [[return vim.fn.jobwait({ vim.fn.jobstart({...}, {
          stdout_buffered = true,
          stderr_buffered = true,
          on_stdout = function(_, data, _)
            _G.stdout = table.concat(data, '\n')
          end,
          on_stderr = function(_, data, _)
            _G.stderr = table.concat(data, '\n')
          end,
        }) })]],
        nvim_prog,
        '--clean',
        '--headless',
        unpack(uris)
      )
    )
    local res = exec_lua([[return { _G.stdout, _G.stderr }]])
    client_starter:close()
    set_session(server)
    return res
  end

  local function assert_no_uri_stderr(res)
    eq('', res[2] or '')
  end

  it('opens file in existing server', function()
    local server = n.clear()
    finally(function()
      server:close()
    end)

    local fname = tmpname('.txt')
    write_file(fname, 'nvim uri test content')
    finally(function()
      os.remove(fname)
    end)

    local uri = 'nvim://open?file=' .. fname
    local res = run_uri(server, uri)

    assert_no_uri_stderr(res)
    eq(abspath(fname), fn.expand('%:p'))
    eq('nvim uri test content', fn.getline(1))
  end)

  it('uses vim.ui.edit for open behavior', function()
    local server = n.clear()
    finally(function()
      server:close()
    end)

    local fname = tmpname('.txt')
    write_file(fname, 'tabedit test content')
    finally(function()
      os.remove(fname)
    end)

    exec_lua(function()
      vim.ui.edit = function(path, opts)
        vim.cmd.tabedit(path)
        if opts and opts.line then
          vim.api.nvim_win_set_cursor(0, { opts.line, (opts.column or 1) - 1 })
        end
      end
    end)

    local uri = 'nvim://open?file=' .. fname
    local res = run_uri(server, uri)

    assert_no_uri_stderr(res)
    eq(2, fn.tabpagenr('$'))
    eq(abspath(fname), fn.expand('%:p'))
  end)

  it('opens file with line number', function()
    local server = n.clear()
    finally(function()
      server:close()
    end)

    local fname = tmpname('.txt')
    write_file(fname, 'line1\nline2\nline3\nline4\nline5')
    finally(function()
      os.remove(fname)
    end)

    local uri = 'nvim://open?file=' .. fname .. '&line=3'
    local res = run_uri(server, uri)

    assert_no_uri_stderr(res)
    eq(abspath(fname), fn.expand('%:p'))
    eq(3, fn.line('.'))
  end)

  it('opens file with line and column', function()
    local server = n.clear()
    finally(function()
      server:close()
    end)

    local fname = tmpname('.txt')
    write_file(fname, 'line1\nline2\nline3 with more text\nline4')
    finally(function()
      os.remove(fname)
    end)

    local uri = 'nvim://open?file=' .. fname .. '&line=3&column=7'
    local res = run_uri(server, uri)

    assert_no_uri_stderr(res)
    eq(abspath(fname), fn.expand('%:p'))
    eq(3, fn.line('.'))
    eq(7, fn.col('.'))
  end)

  it('opens file locally when no server available', function()
    local fname = tmpname('.txt')
    write_file(fname, 'local open test')
    finally(function()
      os.remove(fname)
    end)

    -- Use isolated XDG_RUNTIME_DIR so no existing nvim sockets are discovered
    local tmp_runtime_dir = tmpname('.d')
    vim.uv.fs_mkdir(tmp_runtime_dir, 448) -- 0700
    finally(function()
      vim.uv.fs_rmdir(tmp_runtime_dir)
    end)

    local uri = 'nvim://open?file=' .. fname .. '&line=1'
    clear({
      args = { uri },
      env = {
        TMPDIR = t.paths.test_build_dir,
        VIMRUNTIME = t.paths.test_source_path .. '/runtime',
        XDG_RUNTIME_DIR = tmp_runtime_dir,
      },
    })

    -- File opening is deferred, wait for it
    t.retry(nil, 1000, function()
      eq(abspath(fname), fn.expand('%:p'))
    end)
    eq('local open test', fn.getline(1))
  end)

  it('handles percent-encoded paths', function()
    local server = n.clear()
    finally(function()
      server:close()
    end)

    local fname = tmpname(' with spaces')
    write_file(fname, 'spaces in path')
    finally(function()
      os.remove(fname)
    end)

    local encoded_fname = fname:gsub(' ', '%%20')
    local uri = 'nvim://open?file=' .. encoded_fname
    local res = run_uri(server, uri)

    assert_no_uri_stderr(res)
    eq(abspath(fname), fn.expand('%:p'))
  end)
end)

describe('vim._core', function()
  it('works with "-u NONE" and no VIMRUNTIME', function()
    clear {
      args_rm = { '-u' },
      args = { '-u', 'NONE' },
      env = { VIMRUNTIME = 'non-existent' },
    }

    -- `vim.hl` is NOT a builtin module.
    t.matches("^module 'vim%.hl' not found:", t.pcall_err(n.exec_lua, [[require('vim.hl')]]))

    -- All `vim._core.*` modules are builtin.
    t.eq(
      { 'ex_session_restart', 'rebind_after_restart', 'serverlist' },
      n.exec_lua([[local k = vim.tbl_keys(require('vim._core.server')); table.sort(k); return k]])
    )
    local expected = {
      'vim.F',
      'vim._core.cmdwin',
      'vim._core.defaults',
      'vim._core.editor',
      'vim._core.ex_cmd',
      'vim._core.exrc',
      'vim._core.help',
      'vim._core.log',
      'vim._core.marks',
      'vim._core.options',
      'vim._core.proc',
      'vim._core.server',
      'vim._core.shared',
      'vim._core.spell',
      'vim._core.stringbuffer',
      'vim._core.swapfile',
      'vim._core.system',
      'vim._core.table',
      'vim._core.tag',
      'vim._core.time',
      'vim._core.ui',
      'vim._core.ui2',
      'vim._core.uri',
      'vim._core.util',
      'vim._core.vimfn',
      'vim._init_packages',
      'vim.filetype',
      'vim.fs',
      'vim.inspect',
      'vim.keymap',
      'vim.loader',
      'vim.text',
      'vim.tty',
    }
    if n.exec_lua [[return not not _G.jit]] then
      expected = vim.list_extend({
        'ffi',
        'jit.profile',
        'jit.util',
        'string.buffer',
        'table.clear',
        'table.new',
      }, expected)
    end
    t.eq(expected, n.exec_lua([[local t = vim.tbl_keys(package.preload); table.sort(t); return t]]))
  end)
end)
