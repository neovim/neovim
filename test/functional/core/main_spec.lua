local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local describe, it, before_each, after_each, finally =
  t.describe, t.it, t.before_each, t.after_each, t.finally
local uv = vim.uv

local eq = t.eq
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
      'vim._core.run_in_terminal',
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
