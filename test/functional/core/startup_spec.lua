local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local assert_alive = helpers.assert_alive
local assert_log = helpers.assert_log
local clear = helpers.clear
local command = helpers.command
local ok = helpers.ok
local eq = helpers.eq
local matches = helpers.matches
local eval = helpers.eval
local exec_capture = helpers.exec_capture
local exec_lua = helpers.exec_lua
local feed = helpers.feed
local funcs = helpers.funcs
local pesc = helpers.pesc
local mkdir = helpers.mkdir
local mkdir_p = helpers.mkdir_p
local nvim_prog = helpers.nvim_prog
local nvim_set = helpers.nvim_set
local read_file = helpers.read_file
local retry = helpers.retry
local rmdir = helpers.rmdir
local sleep = helpers.sleep
local startswith = helpers.startswith
local write_file = helpers.write_file
local meths = helpers.meths
local alter_slashes = helpers.alter_slashes
local is_os = helpers.is_os
local dedent = helpers.dedent
local tbl_map = helpers.tbl_map
local tbl_filter = helpers.tbl_filter
local endswith = helpers.endswith

describe('startup', function()
  it('--clean', function()
    clear()
    ok(string.find(alter_slashes(meths.get_option_value('runtimepath', {})), funcs.stdpath('config'), 1, true) ~= nil)
    clear('--clean')
    ok(string.find(alter_slashes(meths.get_option_value('runtimepath', {})), funcs.stdpath('config'), 1, true) == nil)
  end)

  it('--startuptime', function()
    local testfile = 'Xtest_startuptime'
    finally(function()
      os.remove(testfile)
    end)
    clear({ args = {'--startuptime', testfile}})
    assert_log('sourcing', testfile, 100)
    assert_log("require%('vim%._editor'%)", testfile, 100)
  end)

  it('-D does not hang #12647', function()
    clear()
    local screen
    screen = Screen.new(60, 7)
    screen:attach()
    command([[let g:id = termopen('"]]..nvim_prog..
    [[" -u NONE -i NONE --cmd "set noruler" -D')]])
    screen:expect([[
      ^                                                            |
                                                                  |
      Entering Debug mode.  Type "cont" to continue.              |
      nvim_exec2()                                                |
      cmd: aunmenu *                                              |
      >                                                           |
                                                                  |
    ]])
    command([[call chansend(g:id, "cont\n")]])
    screen:expect([[
      ^                                                            |
      ~                                                           |
      ~                                                           |
      ~                                                           |
      [No Name]                                                   |
                                                                  |
                                                                  |
    ]])
  end)
end)

describe('startup', function()
  before_each(clear)

  describe('-l Lua', function()
    local function assert_l_out(expected, nvim_args, lua_args, script, input)
      local args = { nvim_prog }
      vim.list_extend(args, nvim_args or {})
      vim.list_extend(args, { '-l', (script or 'test/functional/fixtures/startup.lua') })
      vim.list_extend(args, lua_args or {})
      local out = funcs.system(args, input):gsub('\r\n', '\n')
      return eq(dedent(expected), out)
    end

    it('failure modes', function()
      -- nvim -l <empty>
      matches('nvim%.?e?x?e?: Argument missing after: "%-l"', funcs.system({ nvim_prog, '-l' }))
      eq(1, eval('v:shell_error'))
    end)

    it('os.exit() sets Nvim exitcode', function()
      -- tricky: LeakSanitizer triggers on os.exit() and disrupts the return value, disable it
      exec_lua [[
        local asan_options = os.getenv 'ASAN_OPTIONS'
        if asan_options ~= nil and asan_options ~= '' then
          vim.uv.os_setenv('ASAN_OPTIONS', asan_options..':detect_leaks=0')
        end
      ]]
      -- nvim -l foo.lua -arg1 -- a b c
      assert_l_out([[
          bufs:
          nvim args: 7
          lua args: { "-arg1", "--exitcode", "73", "--arg2",
            [0] = "test/functional/fixtures/startup.lua"
          }]],
        {},
        { '-arg1', "--exitcode", "73", '--arg2' }
      )
      eq(73, eval('v:shell_error'))
    end)

    it('Lua-error sets Nvim exitcode', function()
      eq(0, eval('v:shell_error'))
      matches('E5113: .* my pearls!!',
        funcs.system({ nvim_prog, '-l', 'test/functional/fixtures/startup-fail.lua' }))
      eq(1, eval('v:shell_error'))
      matches('E5113: .* %[string "error%("whoa"%)"%]:1: whoa',
        funcs.system({ nvim_prog, '-l', '-' }, 'error("whoa")'))
      eq(1, eval('v:shell_error'))
    end)

    it('executes stdin "-"', function()
      assert_l_out('arg0=- args=2 whoa',
        nil,
        { 'arg1', 'arg 2' },
        '-',
        "print(('arg0=%s args=%d %s'):format(_G.arg[0], #_G.arg, 'whoa'))")
      assert_l_out('biiig input: 1000042',
        nil,
        nil,
        '-',
        ('print("biiig input: "..("%s"):len())'):format(string.rep('x', (1000 * 1000) + 42)))
      eq(0, eval('v:shell_error'))
    end)

    it('sets _G.arg', function()
      -- nvim -l foo.lua
      assert_l_out([[
          bufs:
          nvim args: 3
          lua args: {
            [0] = "test/functional/fixtures/startup.lua"
          }]],
        {},
        {}
      )
      eq(0, eval('v:shell_error'))

      -- nvim -l foo.lua [args]
      assert_l_out([[
          bufs:
          nvim args: 7
          lua args: { "-arg1", "--arg2", "--", "arg3",
            [0] = "test/functional/fixtures/startup.lua"
          }]],
        {},
        { '-arg1', '--arg2', '--', 'arg3' }
      )
      eq(0, eval('v:shell_error'))

      -- nvim file1 file2 -l foo.lua -arg1 -- file3 file4
      assert_l_out([[
          bufs: file1 file2
          nvim args: 10
          lua args: { "-arg1", "arg 2", "--", "file3", "file4",
            [0] = "test/functional/fixtures/startup.lua"
          }]],
        { 'file1', 'file2', },
        { '-arg1', 'arg 2', '--', 'file3', 'file4' }
      )
      eq(0, eval('v:shell_error'))

      -- nvim -l foo.lua <vim args>
      assert_l_out([[
          bufs:
          nvim args: 5
          lua args: { "-c", "set wrap?",
            [0] = "test/functional/fixtures/startup.lua"
          }]],
        {},
        { '-c', 'set wrap?' }
      )
      eq(0, eval('v:shell_error'))

      -- nvim <vim args> -l foo.lua <vim args>
      assert_l_out(
        -- luacheck: ignore 611 (Line contains only whitespaces)
        [[
            wrap
          
          bufs:
          nvim args: 7
          lua args: { "-c", "set wrap?",
            [0] = "test/functional/fixtures/startup.lua"
          }]],
        { '-c', 'set wrap?' },
        { '-c', 'set wrap?' }
      )
      eq(0, eval('v:shell_error'))
    end)

    it('disables swapfile/shada/config/plugins', function()
      assert_l_out('updatecount=0 shadafile=NONE loadplugins=false scripts=1',
        nil,
        nil,
        '-',
        [[print(('updatecount=%d shadafile=%s loadplugins=%s scripts=%d'):format(
          vim.o.updatecount, vim.o.shadafile, tostring(vim.o.loadplugins), math.max(1, #vim.fn.getscriptinfo())))]])
    end)
  end)

  it('pipe at both ends: has("ttyin")==0 has("ttyout")==0', function()
    -- system() puts a pipe at both ends.
    local out = funcs.system({ nvim_prog, '-u', 'NONE', '-i', 'NONE', '--headless',
                               '--cmd', nvim_set,
                               '-c', [[echo has('ttyin') has('ttyout')]],
                               '+q' })
    eq('0 0', out)
  end)

  it('with --embed: has("ttyin")==0 has("ttyout")==0', function()
    local screen = Screen.new(25, 3)
    -- Remote UI connected by --embed.
    screen:attach()
    command([[echo has('ttyin') has('ttyout')]])
    screen:expect([[
      ^                         |
      ~                        |
      0 0                      |
    ]])
  end)

  it('in a TTY: has("ttyin")==1 has("ttyout")==1', function()
    local screen = Screen.new(25, 4)
    screen:attach()
    if is_os('win') then
      command([[set shellcmdflag=/s\ /c shellxquote=\"]])
    end
    -- Running in :terminal
    command([[exe printf("terminal %s -u NONE -i NONE --cmd \"]]
            ..nvim_set..[[\"]]
            ..[[ -c \"echo has('ttyin') has('ttyout')\""]]
            ..[[, shellescape(v:progpath))]])
    screen:expect([[
      ^                         |
      ~                        |
      1 1                      |
                               |
    ]])
  end)

  it('output to pipe: has("ttyin")==1 has("ttyout")==0', function()
    if is_os('win') then
      command([[set shellcmdflag=/s\ /c shellxquote=\"]])
    end
    os.remove('Xtest_startup_ttyout')
    finally(function()
      os.remove('Xtest_startup_ttyout')
    end)
    -- Running in :terminal
    command([[exe printf("terminal %s -u NONE -i NONE --cmd \"]]
            ..nvim_set..[[\"]]
            ..[[ -c \"call writefile([has('ttyin'), has('ttyout')], 'Xtest_startup_ttyout')\"]]
            ..[[ -c q | cat -v"]]  -- Output to a pipe.
            ..[[, shellescape(v:progpath))]])
    retry(nil, 3000, function()
      sleep(1)
      eq('1\n0\n',  -- stdin is a TTY, stdout is a pipe
         read_file('Xtest_startup_ttyout'))
    end)
  end)

  it('input from pipe: has("ttyin")==0 has("ttyout")==1', function()
    if is_os('win') then
      command([[set shellcmdflag=/s\ /c shellxquote=\"]])
    end
    os.remove('Xtest_startup_ttyout')
    finally(function()
      os.remove('Xtest_startup_ttyout')
    end)
    -- Running in :terminal
    command([[exe printf("terminal echo foo | ]]  -- Input from a pipe.
            ..[[%s -u NONE -i NONE --cmd \"]]
            ..nvim_set..[[\"]]
            ..[[ -c \"call writefile([has('ttyin'), has('ttyout')], 'Xtest_startup_ttyout')\"]]
            ..[[ -c q -- -"]]
            ..[[, shellescape(v:progpath))]])
    retry(nil, 3000, function()
      sleep(1)
      eq('0\n1\n',  -- stdin is a pipe, stdout is a TTY
         read_file('Xtest_startup_ttyout'))
    end)
  end)

  it('input from pipe (implicit) #7679', function()
    local screen = Screen.new(25, 4)
    screen:attach()
    if is_os('win') then
      command([[set shellcmdflag=/s\ /c shellxquote=\"]])
    end
    -- Running in :terminal
    command([[exe printf("terminal echo foo | ]]  -- Input from a pipe.
            ..[[%s -u NONE -i NONE --cmd \"]]
            ..nvim_set..[[\"]]
            ..[[ -c \"echo has('ttyin') has('ttyout')\""]]
            ..[[, shellescape(v:progpath))]])
    screen:expect([[
      ^foo                      |
      ~                        |
      0 1                      |
                               |
    ]])
  end)

  it('input from pipe + file args #7679', function()
    eq('ohyeah\r\n0 0 bufs=3',
       funcs.system({nvim_prog, '-n', '-u', 'NONE', '-i', 'NONE', '--headless',
                     '+.print',
                     "+echo has('ttyin') has('ttyout') 'bufs='.bufnr('$')",
                     '+qall!',
                     '-',
                     'test/functional/fixtures/tty-test.c',
                     'test/functional/fixtures/shell-test.c',
                    },
                    { 'ohyeah', '' }))
  end)

  it('if stdin is empty: selects buffer 2, deletes buffer 1 #8561', function()
    eq('\r\n  2 %a   "file1"                        line 0\r\n  3      "file2"                        line 0',
       funcs.system({nvim_prog, '-n', '-u', 'NONE', '-i', 'NONE', '--headless',
                     '+ls!',
                     '+qall!',
                     '-',
                     'file1',
                     'file2',
                    },
                    { '' }))
  end)

  it('stdin with -es/-Es #7679', function()
    local input = { 'append', 'line1', 'line2', '.', '%print', '' }
    local inputstr = table.concat(input, '\n')

    --
    -- -Es: read stdin as text
    --
    eq('partylikeits1999\n',
       funcs.system({nvim_prog, '-n', '-u', 'NONE', '-i', 'NONE', '-Es', '+.print', 'test/functional/fixtures/tty-test.c' },
                    { 'partylikeits1999', '' }))
    eq(inputstr,
       funcs.system({nvim_prog, '-i', 'NONE', '-Es', '+%print', '-' },
                    input))
    -- with `-u NORC`
    eq('thepartycontinues\n',
       funcs.system({nvim_prog, '-n', '-u', 'NORC', '-Es', '+.print' },
                    { 'thepartycontinues', '' }))
    -- without `-u`
    eq('thepartycontinues\n',
       funcs.system({nvim_prog, '-n', '-Es', '+.print' },
                    { 'thepartycontinues', '' }))

    --
    -- -es: read stdin as ex-commands
    --
    eq('  encoding=utf-8\n',
       funcs.system({nvim_prog, '-n', '-u', 'NONE', '-i', 'NONE', '-es', 'test/functional/fixtures/tty-test.c' },
                    { 'set encoding', '' }))
    eq('line1\nline2\n',
       funcs.system({nvim_prog, '-i', 'NONE', '-es', '-' },
                    input))
    -- with `-u NORC`
    eq('  encoding=utf-8\n',
       funcs.system({nvim_prog, '-n', '-u', 'NORC', '-es' },
                    { 'set encoding', '' }))
    -- without `-u`
    eq('  encoding=utf-8\n',
       funcs.system({nvim_prog, '-n', '-es' },
                    { 'set encoding', '' }))
  end)

  it('-es/-Es disables swapfile, user config #8540', function()
    for _,arg in ipairs({'-es', '-Es'}) do
      local out = funcs.system({nvim_prog, arg,
                                '+set swapfile? updatecount? shadafile?',
                                "+put =map(getscriptinfo(), {-> v:val.name})", '+%print'})
      local line1 = string.match(out, '^.-\n')
      -- updatecount=0 means swapfile was disabled.
      eq("  swapfile  updatecount=0  shadafile=\n", line1)
      -- Standard plugins were loaded, but not user config.
      ok(string.find(out, 'man.lua') ~= nil)
      ok(string.find(out, 'init.vim') == nil)
    end
  end)

  it('fails on --embed with -es/-Es/-l', function()
    matches('nvim[.exe]*: %-%-embed conflicts with %-es/%-Es/%-l',
      funcs.system({nvim_prog, '--embed', '-es' }))
    matches('nvim[.exe]*: %-%-embed conflicts with %-es/%-Es/%-l',
      funcs.system({nvim_prog, '--embed', '-Es' }))
    matches('nvim[.exe]*: %-%-embed conflicts with %-es/%-Es/%-l',
      funcs.system({nvim_prog, '--embed', '-l', 'foo.lua' }))
  end)

  it('ENTER dismisses early message #7967', function()
    local screen
    screen = Screen.new(60, 6)
    screen:attach()
    command([[let g:id = termopen('"]]..nvim_prog..
    [[" -u NONE -i NONE --cmd "set noruler" --cmd "let g:foo = g:bar"')]])
    screen:expect([[
      ^                                                            |
                                                                  |
      Error detected while processing pre-vimrc command line:     |
      E121: Undefined variable: g:bar                             |
      Press ENTER or type command to continue                     |
                                                                  |
    ]])
    command([[call chansend(g:id, "\n")]])
    screen:expect([[
      ^                                                            |
      ~                                                           |
      ~                                                           |
      [No Name]                                                   |
                                                                  |
                                                                  |
    ]])
  end)

  it('fixed hang issue with --headless (#11386)', function()
    local expected = ''
    local period = 100
    for i = 1, period - 1 do
      expected = expected .. i .. '\r\n'
    end
    expected = expected .. period
    eq(
      expected,
      -- FIXME(codehex): We should really set a timeout for the system function.
      -- If this test fails, there will be a waiting input state.
      funcs.system({nvim_prog, '-u', 'NONE', '-c',
        'for i in range(1, 100) | echo i | endfor | quit',
        '--headless'
      })
    )
  end)

  it("get command line arguments from v:argv", function()
    local out = funcs.system({ nvim_prog, '-u', 'NONE', '-i', 'NONE', '--headless',
                               '--cmd', nvim_set,
                               '-c', [[echo v:argv[-1:] len(v:argv) > 1]],
                               '+q' })
    eq('[\'+q\'] 1', out)
  end)
end)

describe('startup', function()
  it('-e/-E interactive #7679', function()
    clear('-e')
    local screen = Screen.new(25, 3)
    screen:attach()
    feed("put ='from -e'<CR>")
    screen:expect([[
      :put ='from -e'          |
      from -e                  |
      :^                        |
    ]])

    clear('-E')
    screen = Screen.new(25, 3)
    screen:attach()
    feed("put ='from -E'<CR>")
    screen:expect([[
      :put ='from -E'          |
      from -E                  |
      :^                        |
    ]])
  end)

  it('-e sets ex mode', function()
    local screen = Screen.new(25, 3)
    clear('-e')
    screen:attach()
    -- Verify we set the proper mode both before and after :vi.
    feed("put =mode(1)<CR>vi<CR>:put =mode(1)<CR>")
    screen:expect([[
      cv                       |
      ^n                        |
      :put =mode(1)            |
    ]])

    eq('cv\n',
       funcs.system({nvim_prog, '-n', '-es' },
                    { 'put =mode(1)', 'print', '' }))
  end)

  it('-d does not diff non-arglist windows #13720 #21289', function()
    write_file('Xdiff.vim', [[
      let bufnr = nvim_create_buf(0, 1)
      let config = {
            \   'relative': 'editor',
            \   'focusable': v:false,
            \   'width': 1,
            \   'height': 1,
            \   'row': 3,
            \   'col': 3
            \ }
      autocmd WinEnter * call nvim_open_win(bufnr, v:false, config)]])
    finally(function()
      os.remove('Xdiff.vim')
    end)
    clear{args={'-u', 'Xdiff.vim', '-d', 'Xdiff.vim', 'Xdiff.vim'}}
    eq(true, meths.get_option_value('diff', {win = funcs.win_getid(1)}))
    eq(true, meths.get_option_value('diff', {win = funcs.win_getid(2)}))
    local float_win = funcs.win_getid(3)
    eq('editor', meths.win_get_config(float_win).relative)
    eq(false, meths.get_option_value('diff', {win = float_win}))
  end)

  it('does not crash if --embed is given twice', function()
    clear{args={'--embed'}}
    assert_alive()
  end)

  it('does not crash when expanding cdpath during early_init', function()
    clear{env={CDPATH='~doesnotexist'}}
    assert_alive()
    eq(',~doesnotexist', eval('&cdpath'))
  end)

  it("sets 'shortmess' when loading other tabs", function()
    clear({args={'-p', 'a', 'b', 'c'}})
    local screen = Screen.new(25, 4)
    screen:attach()
    screen:expect({grid=[[
        {1: a }{2: b  c }{3:               }{2:X}|
        ^                         |
        {4:~                        }|
                                 |
          ]],
      attr_ids={
        [1] = {bold = true},
        [2] = {background = Screen.colors.LightGrey, underline = true},
        [3] = {reverse = true},
        [4] = {bold = true, foreground = Screen.colors.Blue1},
    }})
  end)
end)

describe('startup', function()
  local function pack_clear(cmd)
    -- add packages after config dir in rtp but before config/after
    clear{args={'--cmd', 'set packpath=test/functional/fixtures', '--cmd', 'let paths=split(&rtp, ",")', '--cmd', 'let &rtp = paths[0]..",test/functional/fixtures,test/functional/fixtures/middle,"..join(paths[1:],",")', '--cmd', cmd}, env={XDG_CONFIG_HOME='test/functional/fixtures/'},
          args_rm={'runtimepath'},
    }
  end

  it("handles &packpath during startup", function()
    pack_clear [[
      let g:x = bar#test()
      let g:y = leftpad#pad("heyya")
    ]]
    eq(-3, eval 'g:x')
    eq("  heyya", eval 'g:y')

    pack_clear [[ lua _G.y = require'bar'.doit() _G.z = require'leftpad''howdy' ]]
    eq({9003, '\thowdy'}, exec_lua [[ return { _G.y, _G.z } ]])
  end)

  it("handles require from &packpath in an async handler", function()
      -- NO! you cannot just speed things up by calling async functions during startup!
      -- It doesn't make anything actually faster! NOOOO!
    pack_clear [[ lua require'async_leftpad'('brrrr', 'async_res') ]]

    -- haha, async leftpad go brrrrr
    eq('\tbrrrr', exec_lua [[ return _G.async_res ]])
  end)

  it("handles :packadd during startup", function()
    -- control group: opt/bonus is not available by default
    pack_clear [[
      try
        let g:x = bonus#secret()
      catch
        let g:err = v:exception
      endtry
    ]]
    eq('Vim(let):E117: Unknown function: bonus#secret', eval 'g:err')

    pack_clear [[ lua _G.test = {pcall(function() require'bonus'.launch() end)} ]]
    eq({false, [[[string ":lua"]:1: module 'bonus' not found:]]},
       exec_lua [[ _G.test[2] = string.gsub(_G.test[2], '[\r\n].*', '') return _G.test ]])

    -- ok, time to launch the nukes:
    pack_clear [[ packadd! bonus | let g:x = bonus#secret() ]]
    eq('halloj', eval 'g:x')

    pack_clear [[ packadd! bonus | lua _G.y = require'bonus'.launch() ]]
    eq('CPE 1704 TKS', exec_lua [[ return _G.y ]])
  end)

  it("handles the correct order with start packages and after/", function()
    pack_clear [[ lua _G.test_loadorder = {} vim.cmd "runtime! filen.lua" ]]
    eq({'ordinary', 'FANCY', 'mittel', 'FANCY after', 'ordinary after'}, exec_lua [[ return _G.test_loadorder ]])
  end)

  it("handles the correct order with start packages and after/ after startup", function()
    pack_clear [[ lua _G.test_loadorder = {} ]]
    command [[ runtime! filen.lua ]]
    eq({'ordinary', 'FANCY', 'mittel', 'FANCY after', 'ordinary after'}, exec_lua [[ return _G.test_loadorder ]])
  end)

  it("handles the correct order with globpath(&rtp, ...)", function()
    pack_clear [[ set loadplugins | lua _G.test_loadorder = {} ]]
    command [[
      for x in globpath(&rtp, "filen.lua",1,1)
        call v:lua.dofile(x)
      endfor
    ]]
    eq({'ordinary', 'FANCY', 'mittel', 'FANCY after', 'ordinary after'}, exec_lua [[ return _G.test_loadorder ]])

    local rtp = meths.get_option_value('rtp', {})
    ok(startswith(rtp, 'test/functional/fixtures/nvim,test/functional/fixtures/pack/*/start/*,test/functional/fixtures/start/*,test/functional/fixtures,test/functional/fixtures/middle,'),
      'startswith(…)', 'rtp='..rtp)
  end)

  it("handles the correct order with opt packages and after/", function()
    pack_clear [[ lua _G.test_loadorder = {} vim.cmd "packadd! superspecial\nruntime! filen.lua" ]]
    eq({'ordinary', 'SuperSpecial', 'FANCY', 'mittel', 'FANCY after', 'SuperSpecial after', 'ordinary after'}, exec_lua [[ return _G.test_loadorder ]])
  end)

  it("handles the correct order with opt packages and after/ after startup", function()
    pack_clear [[ lua _G.test_loadorder = {} ]]
    command [[
      packadd! superspecial
      runtime! filen.lua
    ]]
    eq({'ordinary', 'SuperSpecial', 'FANCY', 'mittel', 'FANCY after', 'SuperSpecial after', 'ordinary after'}, exec_lua [[ return _G.test_loadorder ]])
  end)

  it("handles the correct order with opt packages and globpath(&rtp, ...)", function()
    pack_clear [[ set loadplugins | lua _G.test_loadorder = {} ]]
    command [[
      packadd! superspecial
      for x in globpath(&rtp, "filen.lua",1,1)
        call v:lua.dofile(x)
      endfor
    ]]
    eq({'ordinary', 'SuperSpecial', 'FANCY', 'mittel', 'SuperSpecial after', 'FANCY after', 'ordinary after'}, exec_lua [[ return _G.test_loadorder ]])
  end)

  it("handles the correct order with a package that changes packpath", function()
    pack_clear [[ lua _G.test_loadorder = {} vim.cmd "packadd! funky\nruntime! filen.lua" ]]
    eq({'ordinary', 'funky!', 'FANCY', 'mittel', 'FANCY after', 'ordinary after'}, exec_lua [[ return _G.test_loadorder ]])
    eq({'ordinary', 'funky!', 'mittel', 'ordinary after'}, exec_lua [[ return _G.nested_order ]])
  end)

  it("handles the correct order when prepending packpath", function()
    clear{args={'--cmd', 'set packpath^=test/functional/fixtures',  '--cmd', [[ lua _G.test_loadorder = {} vim.cmd "runtime! filen.lua" ]]}, env={XDG_CONFIG_HOME='test/functional/fixtures/'}}
    eq({'ordinary', 'FANCY', 'FANCY after', 'ordinary after'}, exec_lua [[ return _G.test_loadorder ]])
  end)

  it('window widths are correct when modelines set &columns with tabpages', function()
    write_file('Xtab1.noft', 'vim: columns=81')
    write_file('Xtab2.noft', 'vim: columns=81')
    finally(function()
      os.remove('Xtab1.noft')
      os.remove('Xtab2.noft')
    end)
    clear({args = {'-p', 'Xtab1.noft', 'Xtab2.noft'}})
    eq(81, meths.win_get_width(0))
    command('tabnext')
    eq(81, meths.win_get_width(0))
  end)
end)

describe('sysinit', function()
  local xdgdir = 'Xxdg'
  local vimdir = 'Xvim'
  local xhome = 'Xhome'
  local pathsep = helpers.get_pathsep()

  before_each(function()
    rmdir(xdgdir)
    rmdir(vimdir)
    rmdir(xhome)

    mkdir(xdgdir)
    mkdir(xdgdir .. pathsep .. 'nvim')
    write_file(table.concat({xdgdir, 'nvim', 'sysinit.vim'}, pathsep), [[
      let g:loaded = get(g:, "loaded", 0) + 1
      let g:xdg = 1
    ]])

    mkdir(vimdir)
    write_file(table.concat({vimdir, 'sysinit.vim'}, pathsep), [[
      let g:loaded = get(g:, "loaded", 0) + 1
      let g:vim = 1
    ]])

    mkdir(xhome)
  end)
  after_each(function()
    rmdir(xdgdir)
    rmdir(vimdir)
    rmdir(xhome)
  end)

  it('prefers XDG_CONFIG_DIRS over VIM', function()
    clear{args={'--cmd', 'set nomore undodir=. directory=. belloff='},
          args_rm={'-u', '--cmd'},
          env={ HOME=xhome,
                XDG_CONFIG_DIRS=xdgdir,
                VIM=vimdir }}
    eq('loaded 1 xdg 1 vim 0',
       eval('printf("loaded %d xdg %d vim %d", g:loaded, get(g:, "xdg", 0), get(g:, "vim", 0))'))
  end)

  it('uses VIM if XDG_CONFIG_DIRS unset', function()
    clear{args={'--cmd', 'set nomore undodir=. directory=. belloff='},
          args_rm={'-u', '--cmd'},
          env={ HOME=xhome,
                XDG_CONFIG_DIRS='',
                VIM=vimdir }}
    eq('loaded 1 xdg 0 vim 1',
       eval('printf("loaded %d xdg %d vim %d", g:loaded, get(g:, "xdg", 0), get(g:, "vim", 0))'))
  end)
end)

describe('user config init', function()
  local xhome = 'Xhome'
  local pathsep = helpers.get_pathsep()
  local xconfig = xhome .. pathsep .. 'Xconfig'
  local xdata = xhome .. pathsep .. 'Xdata'
  local init_lua_path = table.concat({xconfig, 'nvim', 'init.lua'}, pathsep)
  local xenv = { XDG_CONFIG_HOME=xconfig, XDG_DATA_HOME=xdata }

  before_each(function()
    rmdir(xhome)

    mkdir_p(xconfig .. pathsep .. 'nvim')
    mkdir_p(xdata)

    write_file(init_lua_path, [[
      vim.g.lua_rc = 1
    ]])
  end)

  after_each(function()
    rmdir(xhome)
  end)

  it('loads init.lua from XDG config home by default', function()
    clear{ args_rm={'-u'}, env=xenv }

    eq(1, eval('g:lua_rc'))
    eq(funcs.fnamemodify(init_lua_path, ':p'), eval('$MYVIMRC'))
  end)

  describe('loads existing', function()
    local exrc_path = '.exrc'
    local xstate = 'Xstate'
    local xstateenv = { XDG_CONFIG_HOME=xconfig, XDG_DATA_HOME=xdata, XDG_STATE_HOME=xstate }

    local function setup_exrc_file(filename)
      exrc_path = filename

      if string.find(exrc_path, "%.lua$") then
        write_file(exrc_path, string.format([[
          vim.g.exrc_file = "%s"
        ]], exrc_path))
      else
        write_file(exrc_path, string.format([[
          let g:exrc_file = "%s"
        ]], exrc_path))
      end
    end

    before_each(function()
      write_file(init_lua_path, [[
        vim.o.exrc = true
        vim.g.exrc_file = '---'
      ]])
      mkdir_p(xstate .. pathsep .. (is_os('win') and 'nvim-data' or 'nvim'))
    end)

    after_each(function()
      os.remove(exrc_path)
      rmdir(xstate)
    end)

    for _, filename in ipairs({ '.exrc', '.nvimrc', '.nvim.lua' }) do
      it(filename .. ' in cwd', function()
        setup_exrc_file(filename)

        clear{ args_rm={'-u'}, env=xstateenv }
        -- The 'exrc' file is not trusted, and the prompt is skipped because there is no UI.
        eq('---', eval('g:exrc_file'))

        local screen = Screen.new(50, 8)
        screen:attach()
        funcs.termopen({nvim_prog})
        screen:expect({ any = pesc('[i]gnore, (v)iew, (d)eny, (a)llow:') })
        -- `i` to enter Terminal mode, `a` to allow
        feed('ia')
        screen:expect([[
                                                            |
          ~                                                 |
          ~                                                 |
          ~                                                 |
          ~                                                 |
          [No Name]                       0,0-1          All|
                                                            |
          -- TERMINAL --                                    |
        ]])
        feed(':echo g:exrc_file<CR>')
        screen:expect(string.format([[
                                                            |
          ~                                                 |
          ~                                                 |
          ~                                                 |
          ~                                                 |
          [No Name]                       0,0-1          All|
          %s%s|
          -- TERMINAL --                                    |
        ]], filename, string.rep(' ', 50 - #filename)))

        clear{ args_rm={'-u'}, env=xstateenv }
        -- The 'exrc' file is now trusted.
        eq(filename, eval('g:exrc_file'))
      end)
    end
  end)

  describe('with explicitly provided config', function()
    local custom_lua_path = table.concat({xhome, 'custom.lua'}, pathsep)
    before_each(function()
      write_file(custom_lua_path, [[
      vim.g.custom_lua_rc = 1
      ]])
    end)

    it('loads custom lua config and does not set $MYVIMRC', function()
      clear{ args={'-u', custom_lua_path }, env=xenv }
      eq(1, eval('g:custom_lua_rc'))
      eq('', eval('$MYVIMRC'))
    end)
  end)

  describe('VIMRC also exists', function()
    before_each(function()
      write_file(table.concat({xconfig, 'nvim', 'init.vim'}, pathsep), [[
      let g:vim_rc = 1
      ]])
    end)

    it('loads default lua config, but shows an error', function()
      clear{ args_rm={'-u'}, env=xenv }
      feed('<cr><c-c>')  -- Dismiss "Conflicting config …" message.
      eq(1, eval('g:lua_rc'))
      matches('^E5422: Conflicting configs', exec_capture('messages'))
    end)
  end)
end)

describe('runtime:', function()
  local xhome = 'Xhome'
  local pathsep = helpers.get_pathsep()
  local xconfig = xhome .. pathsep .. 'Xconfig'
  local xdata = xhome .. pathsep .. 'Xdata'
  local xenv = { XDG_CONFIG_HOME=xconfig, XDG_DATA_HOME=xdata }

  setup(function()
    rmdir(xhome)
    mkdir_p(xconfig .. pathsep .. 'nvim')
    mkdir_p(xdata)
  end)

  teardown(function()
    rmdir(xhome)
  end)

  it('loads plugin/*.lua from XDG config home', function()
    local plugin_folder_path = table.concat({xconfig, 'nvim', 'plugin'}, pathsep)
    local plugin_file_path = table.concat({plugin_folder_path, 'plugin.lua'}, pathsep)
    mkdir_p(plugin_folder_path)
    write_file(plugin_file_path, [[ vim.g.lua_plugin = 1 ]])

    clear{ args_rm={'-u'}, env=xenv }

    eq(1, eval('g:lua_plugin'))
    rmdir(plugin_folder_path)
  end)

  it('loads plugin/*.lua from start packages', function()
    local plugin_path = table.concat({xconfig, 'nvim', 'pack', 'category',
    'start', 'test_plugin'}, pathsep)
    local plugin_folder_path = table.concat({plugin_path, 'plugin'}, pathsep)
    local plugin_file_path = table.concat({plugin_folder_path, 'plugin.lua'},
    pathsep)
    local profiler_file = 'test_startuptime.log'
    finally(function()
      os.remove(profiler_file)
      rmdir(plugin_path)
    end)

    mkdir_p(plugin_folder_path)
    write_file(plugin_file_path, [[vim.g.lua_plugin = 2]])

    clear{ args_rm={'-u'}, args={'--startuptime', profiler_file}, env=xenv }

    eq(2, eval('g:lua_plugin'))
    -- Check if plugin_file_path is listed in getscriptinfo()
    local scripts = tbl_map(function(s) return s.name end, funcs.getscriptinfo())
    ok(#tbl_filter(function(s) return endswith(s, plugin_file_path) end, scripts) > 0)

    -- Check if plugin_file_path is listed in startup profile
    local profile_reader = io.open(profiler_file, 'r')
    local profile_log = profile_reader:read('*a')
    profile_reader:close()
    ok(profile_log:find(plugin_file_path) ~= nil)
  end)

  it('loads plugin/*.lua from site packages', function()
    local nvimdata = is_os('win') and "nvim-data" or "nvim"
    local plugin_path = table.concat({xdata, nvimdata, 'site', 'pack', 'xa', 'start', 'yb'}, pathsep)
    local plugin_folder_path = table.concat({plugin_path, 'plugin'}, pathsep)
    local plugin_after_path = table.concat({plugin_path, 'after', 'plugin'}, pathsep)
    local plugin_file_path = table.concat({plugin_folder_path, 'plugin.lua'}, pathsep)
    local plugin_after_file_path = table.concat({plugin_after_path, 'helloo.lua'}, pathsep)

    mkdir_p(plugin_folder_path)
    write_file(plugin_file_path, [[table.insert(_G.lista, "unos")]])
    mkdir_p(plugin_after_path)
    write_file(plugin_after_file_path, [[table.insert(_G.lista, "dos")]])

    clear{ args_rm={'-u'}, args={'--cmd', 'lua _G.lista = {}'}, env=xenv }

    eq({'unos', 'dos'}, exec_lua "return _G.lista")

    rmdir(plugin_path)
  end)


  it('loads ftdetect/*.lua', function()
    local ftdetect_folder = table.concat({xconfig, 'nvim', 'ftdetect'}, pathsep)
    local ftdetect_file = table.concat({ftdetect_folder , 'new-ft.lua'}, pathsep)
    mkdir_p(ftdetect_folder)
    write_file(ftdetect_file , [[vim.g.lua_ftdetect = 1]])

    clear{ args_rm={'-u'}, env=xenv }

    eq(1, eval('g:lua_ftdetect'))
    rmdir(ftdetect_folder)
  end)
end)

describe('user session', function()
  local xhome = 'Xhome'
  local pathsep = helpers.get_pathsep()
  local session_file = table.concat({xhome, 'session.lua'}, pathsep)

  before_each(function()
    rmdir(xhome)

    mkdir(xhome)
    write_file(session_file, [[
      vim.g.lua_session = 1
    ]])
  end)

  after_each(function()
    rmdir(xhome)
  end)

  it('loads session from the provided lua file', function()
    clear{ args={'-S', session_file }, env={ HOME=xhome }}
    eq(1, eval('g:lua_session'))
  end)
end)
