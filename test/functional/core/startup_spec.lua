local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear = helpers.clear
local command = helpers.command
local ok = helpers.ok
local eq = helpers.eq
local matches = helpers.matches
local eval = helpers.eval
local exec_lua = helpers.exec_lua
local feed = helpers.feed
local funcs = helpers.funcs
local mkdir = helpers.mkdir
local mkdir_p = helpers.mkdir_p
local nvim_prog = helpers.nvim_prog
local nvim_set = helpers.nvim_set
local read_file = helpers.read_file
local retry = helpers.retry
local rmdir = helpers.rmdir
local sleep = helpers.sleep
local iswin = helpers.iswin
local write_file = helpers.write_file
local meths = helpers.meths

describe('startup', function()
  before_each(function()
    clear()
    os.remove('Xtest_startup_ttyout')
  end)
  after_each(function()
    os.remove('Xtest_startup_ttyout')
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
    if iswin() then
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
    if iswin() then
      command([[set shellcmdflag=/s\ /c shellxquote=\"]])
    end
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
    if iswin() then
      command([[set shellcmdflag=/s\ /c shellxquote=\"]])
    end
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
    if iswin() then
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
                                '+set swapfile? updatecount? shada?',
                                "+put =execute('scriptnames')", '+%print'})
      local line1 = string.match(out, '^.-\n')
      -- updatecount=0 means swapfile was disabled.
      eq("  swapfile  updatecount=0  shada=!,'100,<50,s10,h\n", line1)
      -- Standard plugins were loaded, but not user config.
      eq('health.vim', string.match(out, 'health.vim'))
      eq(nil, string.match(out, 'init.vim'))
    end
  end)

  it('fails on --embed with -es/-Es', function()
    matches('nvim[.exe]*: %-%-embed conflicts with %-es/%-Es',
      funcs.system({nvim_prog, '--embed', '-es' }))
    matches('nvim[.exe]*: %-%-embed conflicts with %-es/%-Es',
      funcs.system({nvim_prog, '--embed', '-Es' }))
  end)

  it('does not crash if --embed is given twice', function()
    clear{args={'--embed'}}
    eq(2, eval('1+1'))
  end)

  it('does not crash when expanding cdpath during early_init', function()
    clear{env={CDPATH='~doesnotexist'}}
    eq(',~doesnotexist', eval('&cdpath'))
  end)

  it('ENTER dismisses early message #7967', function()
    local screen
    screen = Screen.new(60, 6)
    screen:attach()
    command([[let g:id = termopen('"]]..nvim_prog..
    [[" -u NONE -i NONE --cmd "set noruler" --cmd "let g:foo = g:bar"')]])
    screen:expect([[
      ^                                                            |
      Error detected while processing pre-vimrc command line:     |
      E121: Undefined variable: g:bar                             |
      E15: Invalid expression: g:bar                              |
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

  local function pack_clear(cmd)
    clear('--cmd', 'set packpath=test/functional/fixtures', '--cmd', cmd)
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

  it("handles :packadd during startup", function()
    -- control group: opt/bonus is not availabe by default
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

  it('fixed hang issue with -D (#12647)', function()
    local screen
    screen = Screen.new(60, 6)
    screen:attach()
    command([[let g:id = termopen('"]]..nvim_prog..
    [[" -u NONE -i NONE --cmd "set noruler" -D')]])
    screen:expect([[
      ^                                                            |
      Entering Debug mode.  Type "cont" to continue.              |
      cmd: augroup nvim_terminal                                  |
      >                                                           |
      <" -u NONE -i NONE --cmd "set noruler" -D 1,0-1          All|
                                                                  |
    ]])
    command([[call chansend(g:id, "cont\n")]])
    screen:expect([[
      ^                                                            |
      ~                                                           |
      [No Name]                                                   |
                                                                  |
      <" -u NONE -i NONE --cmd "set noruler" -D 1,0-1          All|
                                                                  |
    ]])
  end)
end)

describe('clean', function()
  clear()
  ok(string.find(meths.get_option('runtimepath'), funcs.stdpath('config'), 1, true) ~= nil)
  clear('--clean')
  ok(string.find(meths.get_option('runtimepath'), funcs.stdpath('config'), 1, true) == nil)
end)

describe('user config init', function()
  local xhome = 'Xhome'
  local pathsep = helpers.get_pathsep()
  local xconfig = xhome .. pathsep .. 'Xconfig'
  local init_lua_path = table.concat({xconfig, 'nvim', 'init.lua'}, pathsep)

  before_each(function()
    rmdir(xhome)

    mkdir_p(xconfig .. pathsep .. 'nvim')

    write_file(init_lua_path, [[
      vim.g.lua_rc = 1
    ]])
  end)

  after_each(function()
    rmdir(xhome)
  end)

  it('loads init.lua from XDG config home by default', function()
    clear{ args_rm={'-u' }, env={ XDG_CONFIG_HOME=xconfig }}

    eq(1, eval('g:lua_rc'))
    eq(init_lua_path, eval('$MYVIMRC'))
  end)

  describe 'with explicitly provided config'(function()
    local custom_lua_path = table.concat({xhome, 'custom.lua'}, pathsep)
    before_each(function()
      write_file(custom_lua_path, [[
      vim.g.custom_lua_rc = 1
      ]])
    end)

    it('loads custom lua config and does not set $MYVIMRC', function()
      clear{ args={'-u', custom_lua_path }, env={ XDG_CONFIG_HOME=xconfig }}
      eq(1, eval('g:custom_lua_rc'))
      eq('', eval('$MYVIMRC'))
    end)
  end)

  describe 'VIMRC also exists'(function()
    before_each(function()
      write_file(table.concat({xconfig, 'nvim', 'init.vim'}, pathsep), [[
      let g:vim_rc = 1
      ]])
    end)

    it('loads default lua config, but shows an error', function()
      clear{ args_rm={'-u'}, env={ XDG_CONFIG_HOME=xconfig }}
      feed('<cr>') -- TODO check this, test execution is blocked without it
      eq(1, eval('g:lua_rc'))
      matches('^E5422: Conflicting configs', meths.exec('messages', true))
    end)
  end)
end)

describe('runtime:', function()
  local xhome = 'Xhome'
  local pathsep = helpers.get_pathsep()
  local xconfig = xhome .. pathsep .. 'Xconfig'

  setup(function()
    mkdir_p(xconfig .. pathsep .. 'nvim')
  end)

  teardown(function()
    rmdir(xhome)
  end)

  it('loads plugin/*.lua from XDG config home', function()
    local plugin_folder_path = table.concat({xconfig, 'nvim', 'plugin'}, pathsep)
    local plugin_file_path = table.concat({plugin_folder_path, 'plugin.lua'}, pathsep)
    mkdir_p(plugin_folder_path)
    write_file(plugin_file_path, [[ vim.g.lua_plugin = 1 ]])

    clear{ args_rm={'-u'}, env={ XDG_CONFIG_HOME=xconfig }}

    eq(1, eval('g:lua_plugin'))
    rmdir(plugin_folder_path)
  end)

  it('loads plugin/*.lua from start plugins', function()
    local plugin_path = table.concat({xconfig, 'nvim', 'pack', 'catagory',
    'start', 'test_plugin'}, pathsep)
    local plugin_folder_path = table.concat({plugin_path, 'plugin'}, pathsep)
    local plugin_file_path = table.concat({plugin_folder_path, 'plugin.lua'},
    pathsep)
    local profiler_file = 'test_startuptime.log'

    mkdir_p(plugin_folder_path)
    write_file(plugin_file_path, [[vim.g.lua_plugin = 2]])

    clear{ args_rm={'-u'}, args={'--startuptime', profiler_file}, env={ XDG_CONFIG_HOME=xconfig }}

    eq(2, eval('g:lua_plugin'))
    -- Check if plugin_file_path is listed in :scriptname
    local scripts = meths.exec(':scriptnames', true)
    assert.Truthy(scripts:find(plugin_file_path))

    -- Check if plugin_file_path is listed in startup profile
    local profile_reader = io.open(profiler_file, 'r')
    local profile_log = profile_reader:read('*a')
    profile_reader:close()
    assert.Truthy(profile_log :find(plugin_file_path))

    os.remove(profiler_file)
    rmdir(plugin_path)
  end)

  it('loads ftdetect/*.lua', function()
    local ftdetect_folder = table.concat({xconfig, 'nvim', 'ftdetect'}, pathsep)
    local ftdetect_file = table.concat({ftdetect_folder , 'new-ft.lua'}, pathsep)
    mkdir_p(ftdetect_folder)
    write_file(ftdetect_file , [[vim.g.lua_ftdetect = 1]])

    -- TODO(shadmansaleh): Figure out why this test fails without
    --                     setting VIMRUNTIME
    clear{ args_rm={'-u'}, env={XDG_CONFIG_HOME=xconfig,
                                VIMRUNTIME='runtime/'}}

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
