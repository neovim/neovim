local helpers = require('test.functional.helpers')(after_each)

local Screen = require('test.functional.ui.screen')

local assert_alive = helpers.assert_alive
local assert_log = helpers.assert_log
local meths = helpers.meths
local command = helpers.command
local clear = helpers.clear
local exc_exec = helpers.exc_exec
local exec_lua = helpers.exec_lua
local eval = helpers.eval
local eq = helpers.eq
local ok = helpers.ok
local funcs = helpers.funcs
local insert = helpers.insert
local neq = helpers.neq
local mkdir = helpers.mkdir
local rmdir = helpers.rmdir
local alter_slashes = helpers.alter_slashes
local tbl_contains = helpers.tbl_contains
local expect_exit = helpers.expect_exit
local is_os = helpers.is_os

local testlog = 'Xtest-defaults-log'

describe('startup defaults', function()
  describe(':filetype', function()
    local function expect_filetype(expected)
      local screen = Screen.new(50, 4)
      screen:attach()
      command('filetype')
      screen:expect([[
        ^                                                  |
        ~                                                 |
        ~                                                 |
        ]]..expected
      )
    end

    it('all ON after `-u NORC`', function()
      clear('-u', 'NORC')
      expect_filetype(
        'filetype detection:ON  plugin:ON  indent:ON       |')
    end)

    it('all ON after `:syntax …` #7765', function()
      clear('-u', 'NORC', '--cmd', 'syntax on')
      expect_filetype(
        'filetype detection:ON  plugin:ON  indent:ON       |')
      clear('-u', 'NORC', '--cmd', 'syntax off')
      expect_filetype(
        'filetype detection:ON  plugin:ON  indent:ON       |')
    end)

    it('all OFF after `-u NONE`', function()
      clear('-u', 'NONE')
      expect_filetype(
        'filetype detection:OFF  plugin:OFF  indent:OFF    |')
    end)

    it('explicit OFF stays OFF', function()
      clear('-u', 'NORC', '--cmd',
            'syntax off | filetype off | filetype plugin indent off')
      expect_filetype(
        'filetype detection:OFF  plugin:OFF  indent:OFF    |')
      clear('-u', 'NORC', '--cmd', 'syntax off | filetype plugin indent off')
      expect_filetype(
        'filetype detection:ON  plugin:OFF  indent:OFF     |')
      clear('-u', 'NORC', '--cmd', 'filetype indent off')
      expect_filetype(
        'filetype detection:ON  plugin:ON  indent:OFF      |')
      clear('-u', 'NORC', '--cmd', 'syntax off | filetype off')
      expect_filetype(
        'filetype detection:OFF  plugin:(on)  indent:(on)  |')
      -- Swap the order.
      clear('-u', 'NORC', '--cmd', 'filetype off | syntax off')
      expect_filetype(
        'filetype detection:OFF  plugin:(on)  indent:(on)  |')
    end)

    it('all ON after early `:filetype … on`', function()
      -- `:filetype … on` should not change the defaults. #7765
      -- Only an explicit `:filetype … off` sets OFF.

      clear('-u', 'NORC', '--cmd', 'filetype on')
      expect_filetype(
        'filetype detection:ON  plugin:ON  indent:ON       |')
      clear('-u', 'NORC', '--cmd', 'filetype plugin on')
      expect_filetype(
        'filetype detection:ON  plugin:ON  indent:ON       |')
      clear('-u', 'NORC', '--cmd', 'filetype indent on')
      expect_filetype(
        'filetype detection:ON  plugin:ON  indent:ON       |')
    end)

    it('late `:filetype … off` stays OFF', function()
      clear('-u', 'NORC', '-c', 'filetype off')
      expect_filetype(
        'filetype detection:OFF  plugin:(on)  indent:(on)  |')
      clear('-u', 'NORC', '-c', 'filetype plugin off')
      expect_filetype(
        'filetype detection:ON  plugin:OFF  indent:ON      |')
      clear('-u', 'NORC', '-c', 'filetype indent off')
      expect_filetype(
        'filetype detection:ON  plugin:ON  indent:OFF      |')
    end)
  end)

  describe('syntax', function()
    it('enabled by `-u NORC`', function()
      clear('-u', 'NORC')
      eq(1, eval('g:syntax_on'))
    end)

    it('disabled by `-u NONE`', function()
      clear('-u', 'NONE')
      eq(0, eval('exists("g:syntax_on")'))
    end)

    it('`:syntax off` stays off', function()
      -- early
      clear('-u', 'NORC', '--cmd', 'syntax off')
      eq(0, eval('exists("g:syntax_on")'))
      -- late
      clear('-u', 'NORC', '-c', 'syntax off')
      eq(0, eval('exists("g:syntax_on")'))
    end)

    it('":if 0|syntax on|endif" does not affect default #8728', function()
      clear('-u', 'NORC', '--cmd', ':if 0|syntax on|endif')
      eq(1, eval('exists("g:syntax_on")'))
      clear('-u', 'NORC', '--cmd', ':if 0|syntax off|endif')
      eq(1, eval('exists("g:syntax_on")'))
    end)
  end)

  describe("'fillchars'", function()
    it('vert/fold flags', function()
      clear()
      local screen = Screen.new(50, 5)
      screen:attach()
      command('set laststatus=0')
      insert([[
        1
        2
        3
        4]])
      command('normal! ggjzfj')
      command('vsp')
      screen:expect([[
        1                        │1                       |
        ^+--  2 lines: 2··········│+--  2 lines: 2·········|
        4                        │4                       |
        ~                        │~                       |
                                                          |
      ]])

      -- ambiwidth=double defaults to single-byte fillchars.
      command('set ambiwidth=double')
      screen:expect([[
        1                        |1                       |
        ^+--  2 lines: 2----------|+--  2 lines: 2---------|
        4                        |4                       |
        ~                        |~                       |
                                                          |
      ]])

      -- change "vert" character to single-cell
      funcs.setcellwidths({{0x2502, 0x2502, 1}})
      screen:expect([[
        1                        │1                       |
        ^+--  2 lines: 2----------│+--  2 lines: 2---------|
        4                        │4                       |
        ~                        │~                       |
                                                          |
      ]])

      -- change "vert" character to double-cell
      funcs.setcellwidths({{0x2502, 0x2502, 2}})
      screen:expect([[
        1                        |1                       |
        ^+--  2 lines: 2----------|+--  2 lines: 2---------|
        4                        |4                       |
        ~                        |~                       |
                                                          |
      ]])

      -- "vert" character should still default to single-byte fillchars because of setcellwidths().
      command('set ambiwidth=single')
      screen:expect([[
        1                        |1                       |
        ^+--  2 lines: 2··········|+--  2 lines: 2·········|
        4                        |4                       |
        ~                        |~                       |
                                                          |
      ]])
    end)
  end)

  it("'shadafile' ('viminfofile')", function()
    local env = {XDG_DATA_HOME='Xtest-userdata', XDG_STATE_HOME='Xtest-userstate', XDG_CONFIG_HOME='Xtest-userconfig'}
    finally(function()
      command('set shadafile=NONE')  -- Avoid writing shada file on exit
      rmdir('Xtest-userstate')
      os.remove('Xtest-foo')
    end)

    clear{args={}, args_rm={'-i'}, env=env}
    -- Default 'shadafile' is empty.
    -- This means use the default location. :help shada-file-name
    eq('', meths.get_option_value('shadafile', {}))
    eq('', meths.get_option_value('viminfofile', {}))
    -- Handles viminfo/viminfofile as alias for shada/shadafile.
    eq('\n  shadafile=', eval('execute("set shadafile?")'))
    eq('\n  shadafile=', eval('execute("set viminfofile?")'))
    eq("\n  shada=!,'100,<50,s10,h", eval('execute("set shada?")'))
    eq("\n  shada=!,'100,<50,s10,h", eval('execute("set viminfo?")'))

    -- Check that shada data (such as v:oldfiles) is saved/restored.
    command('edit Xtest-foo')
    command('write')
    local f = eval('fnamemodify(@%,":p")')
    assert(string.len(f) > 3)
    expect_exit(command, 'qall')
    clear{args={}, args_rm={'-i'}, env=env}
    eq({ f }, eval('v:oldfiles'))
  end)

  it("'packpath'", function()
    clear{
      args_rm={'runtimepath'},
    }
    -- Defaults to &runtimepath.
    eq(meths.get_option_value('runtimepath', {}), meths.get_option_value('packpath', {}))

    -- Does not follow modifications to runtimepath.
    meths.command('set runtimepath+=foo')
    neq(meths.get_option_value('runtimepath', {}), meths.get_option_value('packpath', {}))
    meths.command('set packpath+=foo')
    eq(meths.get_option_value('runtimepath', {}), meths.get_option_value('packpath', {}))
  end)

  it('v:progpath is set to the absolute path', function()
    clear()
    eq(eval("fnamemodify(v:progpath, ':p')"), eval('v:progpath'))
  end)

  describe('$NVIM_LOG_FILE', function()
    local xdgdir = 'Xtest-startup-xdg-logpath'
    local xdgstatedir = is_os('win') and xdgdir..'/nvim-data' or xdgdir..'/nvim'
    after_each(function()
      os.remove('Xtest-logpath')
      rmdir(xdgdir)
    end)

    it('is used if expansion succeeds', function()
      clear({env={
        NVIM_LOG_FILE='Xtest-logpath',
      }})
      eq('Xtest-logpath', eval('$NVIM_LOG_FILE'))
    end)
    it('defaults to stdpath("log")/log if empty', function()
      eq(true, mkdir(xdgdir) and mkdir(xdgstatedir))
      clear({env={
        XDG_STATE_HOME=xdgdir,
        NVIM_LOG_FILE='',  -- Empty is invalid.
      }})
      eq(xdgstatedir..'/log', string.gsub(eval('$NVIM_LOG_FILE'), '\\', '/'))
    end)
    it('defaults to stdpath("log")/log if invalid', function()
      eq(true, mkdir(xdgdir) and mkdir(xdgstatedir))
      clear({env={
        XDG_STATE_HOME=xdgdir,
        NVIM_LOG_FILE='.',  -- Any directory is invalid.
      }})
      eq(xdgstatedir..'/log', string.gsub(eval('$NVIM_LOG_FILE'), '\\', '/'))
    end)
  end)
end)

describe('XDG defaults', function()
  -- Need separate describe() blocks to not run clear() twice.
  -- Do not put before_each() here for the same reasons.

  after_each(function()
    os.remove(testlog)
  end)

  it("&runtimepath data-dir matches stdpath('data') #9910", function()
    clear()
    local rtp = eval('split(&runtimepath, ",")')
    local rv = {}
    local expected = (is_os('win')
                      and { [[\nvim-data\site]], [[\nvim-data\site\after]], }
                      or { '/nvim/site', '/nvim/site/after', })

    for _,v in ipairs(rtp) do
      local m = string.match(v, [=[[/\]nvim[^/\]*[/\]site.*$]=])
      if m and not tbl_contains(rv, m) then
        table.insert(rv, m)
      end
    end
    eq(expected, rv)
  end)

  describe('with empty/broken environment', function()
    it('sets correct defaults', function()
      clear({env={
        XDG_CONFIG_HOME=nil,
        XDG_DATA_HOME=nil,
        XDG_CACHE_HOME=nil,
        XDG_STATE_HOME=nil,
        XDG_RUNTIME_DIR=nil,
        XDG_CONFIG_DIRS=nil,
        XDG_DATA_DIRS=nil,
        LOCALAPPDATA=nil,
        HOMEPATH=nil,
        HOMEDRIVE=nil,
        HOME=nil,
        TEMP=nil,
        VIMRUNTIME=nil,
        USER=nil,
      }})

      eq('.', meths.get_option_value('backupdir', {}))
      eq('.', meths.get_option_value('viewdir', {}))
      eq('.', meths.get_option_value('directory', {}))
      eq('.', meths.get_option_value('undodir', {}))
      ok((funcs.tempname()):len() > 4)
    end)
  end)

  local function vimruntime_and_libdir()
    local vimruntime = eval('$VIMRUNTIME')
    -- libdir is hard to calculate reliably across various ci platforms
    -- local libdir = string.gsub(vimruntime, "share/nvim/runtime$", "lib/nvim")
    local libdir = meths._get_lib_dir()
    return vimruntime, libdir
  end

  local env_sep = is_os('win') and ';' or ':'
  local data_dir = is_os('win') and 'nvim-data' or 'nvim'
  local state_dir = is_os('win') and 'nvim-data' or 'nvim'
  local root_path = is_os('win') and 'C:' or ''

  describe('with too long XDG variables', function()
    before_each(function()
      clear({
        args_rm={'runtimepath'},
        env={
          NVIM_LOG_FILE=testlog,
          XDG_CONFIG_HOME=(root_path .. ('/x'):rep(4096)),
          XDG_CONFIG_DIRS=(root_path .. ('/a'):rep(2048)
                           .. env_sep.. root_path .. ('/b'):rep(2048)
                           .. (env_sep .. root_path .. '/c'):rep(512)),
          XDG_DATA_HOME=(root_path .. ('/X'):rep(4096)),
          XDG_RUNTIME_DIR=(root_path .. ('/X'):rep(4096)),
          XDG_STATE_HOME=(root_path .. ('/X'):rep(4096)),
          XDG_DATA_DIRS=(root_path .. ('/A'):rep(2048)
                         .. env_sep .. root_path .. ('/B'):rep(2048)
                         .. (env_sep .. root_path .. '/C'):rep(512)),
      }})
    end)

    it('are correctly set', function()
      if not is_os('win') then
        assert_log('Failed to start server: no such file or directory: /X/X/X', testlog, 10)
      end

      local vimruntime, libdir = vimruntime_and_libdir()

      eq(((root_path .. ('/x'):rep(4096) .. '/nvim'
          .. ',' .. root_path .. ('/a'):rep(2048) .. '/nvim'
          .. ',' .. root_path .. ('/b'):rep(2048) .. '/nvim'
          .. (',' .. root_path .. '/c/nvim'):rep(512)
          .. ',' .. root_path .. ('/X'):rep(4096) .. '/' .. data_dir .. '/site'
          .. ',' .. root_path .. ('/A'):rep(2048) .. '/nvim/site'
          .. ',' .. root_path .. ('/B'):rep(2048) .. '/nvim/site'
          .. (',' .. root_path .. '/C/nvim/site'):rep(512)
          .. ',' .. vimruntime
          .. ',' .. libdir
          .. (',' .. root_path .. '/C/nvim/site/after'):rep(512)
          .. ',' .. root_path .. ('/B'):rep(2048) .. '/nvim/site/after'
          .. ',' .. root_path .. ('/A'):rep(2048) .. '/nvim/site/after'
          .. ',' .. root_path .. ('/X'):rep(4096) .. '/' .. data_dir .. '/site/after'
          .. (',' .. root_path .. '/c/nvim/after'):rep(512)
          .. ',' .. root_path .. ('/b'):rep(2048) .. '/nvim/after'
          .. ',' .. root_path .. ('/a'):rep(2048) .. '/nvim/after'
          .. ',' .. root_path .. ('/x'):rep(4096) .. '/nvim/after'
      ):gsub('\\', '/')), (meths.get_option_value('runtimepath', {})):gsub('\\', '/'))
      meths.command('set runtimepath&')
      meths.command('set backupdir&')
      meths.command('set directory&')
      meths.command('set undodir&')
      meths.command('set viewdir&')
      eq(((root_path .. ('/x'):rep(4096) .. '/nvim'
          .. ',' .. root_path .. ('/a'):rep(2048) .. '/nvim'
          .. ',' .. root_path .. ('/b'):rep(2048) .. '/nvim'
          .. (',' .. root_path .. '/c/nvim'):rep(512)
          .. ',' .. root_path .. ('/X'):rep(4096) .. '/' .. data_dir .. '/site'
          .. ',' .. root_path .. ('/A'):rep(2048) .. '/nvim/site'
          .. ',' .. root_path .. ('/B'):rep(2048) .. '/nvim/site'
          .. (',' .. root_path .. '/C/nvim/site'):rep(512)
          .. ',' .. vimruntime
          .. ',' .. libdir
          .. (',' .. root_path .. '/C/nvim/site/after'):rep(512)
          .. ',' .. root_path .. ('/B'):rep(2048) .. '/nvim/site/after'
          .. ',' .. root_path .. ('/A'):rep(2048) .. '/nvim/site/after'
          .. ',' .. root_path .. ('/X'):rep(4096) .. '/' .. data_dir .. '/site/after'
          .. (',' .. root_path .. '/c/nvim/after'):rep(512)
          .. ',' .. root_path .. ('/b'):rep(2048) .. '/nvim/after'
          .. ',' .. root_path .. ('/a'):rep(2048) .. '/nvim/after'
          .. ',' .. root_path .. ('/x'):rep(4096) .. '/nvim/after'
      ):gsub('\\', '/')), (meths.get_option_value('runtimepath', {})):gsub('\\', '/'))
      eq('.,' .. root_path .. ('/X'):rep(4096).. '/' .. state_dir .. '/backup//',
         (meths.get_option_value('backupdir', {}):gsub('\\', '/')))
      eq(root_path .. ('/X'):rep(4096) .. '/' .. state_dir .. '/swap//',
         (meths.get_option_value('directory', {})):gsub('\\', '/'))
      eq(root_path .. ('/X'):rep(4096) .. '/' .. state_dir .. '/undo//',
         (meths.get_option_value('undodir', {})):gsub('\\', '/'))
      eq(root_path .. ('/X'):rep(4096) .. '/'  ..  state_dir .. '/view//',
         (meths.get_option_value('viewdir', {})):gsub('\\', '/'))
    end)
  end)

  describe('with XDG variables that can be expanded', function()
    before_each(function()
      clear({
        args_rm={'runtimepath'},
        env={
          NVIM_LOG_FILE=testlog,
          XDG_CONFIG_HOME='$XDG_DATA_HOME',
          XDG_CONFIG_DIRS='$XDG_DATA_DIRS',
          XDG_DATA_HOME='$XDG_CONFIG_HOME',
          XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR',
          XDG_STATE_HOME='$XDG_CONFIG_HOME',
          XDG_DATA_DIRS='$XDG_CONFIG_DIRS',
        }
      })
    end)

    after_each(function()
      command('set shadafile=NONE')  -- Avoid writing shada file on exit
    end)

    it('are not expanded', function()
      if not is_os('win') then
        assert_log('Failed to start server: no such file or directory: %$XDG_RUNTIME_DIR%/', testlog, 10)
      end

      local vimruntime, libdir = vimruntime_and_libdir()
      eq((('$XDG_DATA_HOME/nvim'
          .. ',$XDG_DATA_DIRS/nvim'
          .. ',$XDG_CONFIG_HOME/' .. data_dir .. '/site'
          .. ',$XDG_CONFIG_DIRS/nvim/site'
          .. ',' .. vimruntime
          .. ',' .. libdir
          .. ',$XDG_CONFIG_DIRS/nvim/site/after'
          .. ',$XDG_CONFIG_HOME/' .. data_dir .. '/site/after'
          .. ',$XDG_DATA_DIRS/nvim/after'
          .. ',$XDG_DATA_HOME/nvim/after'
      ):gsub('\\', '/')), (meths.get_option_value('runtimepath', {})):gsub('\\', '/'))
      meths.command('set runtimepath&')
      meths.command('set backupdir&')
      meths.command('set directory&')
      meths.command('set undodir&')
      meths.command('set viewdir&')
      eq((('$XDG_DATA_HOME/nvim'
          .. ',$XDG_DATA_DIRS/nvim'
          .. ',$XDG_CONFIG_HOME/' .. data_dir .. '/site'
          .. ',$XDG_CONFIG_DIRS/nvim/site'
          .. ',' .. vimruntime
          .. ',' .. libdir
          .. ',$XDG_CONFIG_DIRS/nvim/site/after'
          .. ',$XDG_CONFIG_HOME/' .. data_dir .. '/site/after'
          .. ',$XDG_DATA_DIRS/nvim/after'
          .. ',$XDG_DATA_HOME/nvim/after'
      ):gsub('\\', '/')), (meths.get_option_value('runtimepath', {})):gsub('\\', '/'))
      eq(('.,$XDG_CONFIG_HOME/' .. state_dir .. '/backup//'),
          meths.get_option_value('backupdir', {}):gsub('\\', '/'))
      eq(('$XDG_CONFIG_HOME/' .. state_dir .. '/swap//'),
          meths.get_option_value('directory', {}):gsub('\\', '/'))
      eq(('$XDG_CONFIG_HOME/' .. state_dir .. '/undo//'),
          meths.get_option_value('undodir', {}):gsub('\\', '/'))
      eq(('$XDG_CONFIG_HOME/' .. state_dir .. '/view//'),
          meths.get_option_value('viewdir', {}):gsub('\\', '/'))
      meths.command('set all&')
      eq(('$XDG_DATA_HOME/nvim'
          .. ',$XDG_DATA_DIRS/nvim'
          .. ',$XDG_CONFIG_HOME/' .. data_dir .. '/site'
          .. ',$XDG_CONFIG_DIRS/nvim/site'
          .. ',' .. vimruntime
          .. ',' .. libdir
          .. ',$XDG_CONFIG_DIRS/nvim/site/after'
          .. ',$XDG_CONFIG_HOME/' .. data_dir .. '/site/after'
          .. ',$XDG_DATA_DIRS/nvim/after'
          .. ',$XDG_DATA_HOME/nvim/after'
      ):gsub('\\', '/'), (meths.get_option_value('runtimepath', {})):gsub('\\', '/'))
      eq(('.,$XDG_CONFIG_HOME/' .. state_dir .. '/backup//'),
          meths.get_option_value('backupdir', {}):gsub('\\', '/'))
      eq(('$XDG_CONFIG_HOME/' .. state_dir .. '/swap//'),
          meths.get_option_value('directory', {}):gsub('\\', '/'))
      eq(('$XDG_CONFIG_HOME/' .. state_dir .. '/undo//'),
          meths.get_option_value('undodir', {}):gsub('\\', '/'))
      eq(('$XDG_CONFIG_HOME/' .. state_dir .. '/view//'),
          meths.get_option_value('viewdir', {}):gsub('\\', '/'))
      eq(nil, (funcs.tempname()):match('XDG_RUNTIME_DIR'))
    end)
  end)

  describe('with commas', function()
    before_each(function()
      clear({
        args_rm={'runtimepath'},
        env={
          XDG_CONFIG_HOME=', , ,',
          XDG_CONFIG_DIRS=',-,-,' .. env_sep .. '-,-,-',
          XDG_DATA_HOME=',=,=,',
          XDG_STATE_HOME=',=,=,',
          XDG_DATA_DIRS=',≡,≡,' .. env_sep .. '≡,≡,≡',
      }})
    end)

    it('are escaped properly', function()
      local vimruntime, libdir = vimruntime_and_libdir()
      local path_sep = is_os('win') and '\\' or '/'
      eq(('\\, \\, \\,' .. path_sep .. 'nvim'
          .. ',\\,-\\,-\\,' .. path_sep .. 'nvim'
          .. ',-\\,-\\,-' .. path_sep .. 'nvim'
          .. ',\\,=\\,=\\,' .. path_sep .. data_dir .. path_sep .. 'site'
          .. ',\\,≡\\,≡\\,' .. path_sep .. 'nvim'  .. path_sep .. 'site'
          .. ',≡\\,≡\\,≡' .. path_sep .. 'nvim' .. path_sep .. 'site'
          .. ',' .. vimruntime
          .. ',' .. libdir
          .. ',≡\\,≡\\,≡' .. path_sep .. 'nvim' .. path_sep .. 'site' .. path_sep .. 'after'
          .. ',\\,≡\\,≡\\,' .. path_sep .. 'nvim' .. path_sep .. 'site' .. path_sep .. 'after'
          .. ',\\,=\\,=\\,'  .. path_sep.. data_dir .. path_sep .. 'site' .. path_sep .. 'after'
          .. ',-\\,-\\,-' .. path_sep .. 'nvim' .. path_sep .. 'after'
          .. ',\\,-\\,-\\,' .. path_sep .. 'nvim' .. path_sep .. 'after'
          .. ',\\, \\, \\,' .. path_sep .. 'nvim' .. path_sep .. 'after'
      ), meths.get_option_value('runtimepath', {}))
      meths.command('set runtimepath&')
      meths.command('set backupdir&')
      meths.command('set directory&')
      meths.command('set undodir&')
      meths.command('set viewdir&')
      eq(('\\, \\, \\,' .. path_sep .. 'nvim'
          .. ',\\,-\\,-\\,' .. path_sep ..'nvim'
          .. ',-\\,-\\,-' .. path_sep ..'nvim'
          .. ',\\,=\\,=\\,' .. path_sep ..'' .. data_dir .. '' .. path_sep ..'site'
          .. ',\\,≡\\,≡\\,' .. path_sep ..'nvim' .. path_sep ..'site'
          .. ',≡\\,≡\\,≡' .. path_sep ..'nvim' .. path_sep ..'site'
          .. ',' .. vimruntime
          .. ',' .. libdir
          .. ',≡\\,≡\\,≡' .. path_sep ..'nvim' .. path_sep ..'site' .. path_sep ..'after'
          .. ',\\,≡\\,≡\\,' .. path_sep ..'nvim' .. path_sep ..'site' .. path_sep ..'after'
          .. ',\\,=\\,=\\,' .. path_sep ..'' .. data_dir .. '' .. path_sep ..'site' .. path_sep ..'after'
          .. ',-\\,-\\,-' .. path_sep ..'nvim' .. path_sep ..'after'
          .. ',\\,-\\,-\\,' .. path_sep ..'nvim' .. path_sep ..'after'
          .. ',\\, \\, \\,' .. path_sep ..'nvim' .. path_sep ..'after'
      ), meths.get_option_value('runtimepath', {}))
      eq('.,\\,=\\,=\\,' .. path_sep .. state_dir .. '' .. path_sep ..'backup' .. (path_sep):rep(2),
          meths.get_option_value('backupdir', {}))
      eq('\\,=\\,=\\,' .. path_sep ..'' .. state_dir .. '' .. path_sep ..'swap' .. (path_sep):rep(2),
          meths.get_option_value('directory', {}))
      eq('\\,=\\,=\\,' .. path_sep ..'' .. state_dir .. '' .. path_sep ..'undo' .. (path_sep):rep(2),
          meths.get_option_value('undodir', {}))
      eq('\\,=\\,=\\,' .. path_sep ..'' .. state_dir .. '' .. path_sep ..'view' .. (path_sep):rep(2),
          meths.get_option_value('viewdir', {}))
    end)
  end)
end)


describe('stdpath()', function()
  -- Windows appends 'nvim-data' instead of just 'nvim' to prevent collisions
  -- due to XDG_CONFIG_HOME, XDG_DATA_HOME and XDG_STATE_HOME being the same.
  local function maybe_data(name)
    return is_os('win') and name .. '-data' or name
  end

  local datadir = maybe_data('nvim')
  local statedir = maybe_data('nvim')
  local env_sep = is_os('win') and ';' or ':'

  it('acceptance', function()
    clear()  -- Do not explicitly set any env vars.

    eq('nvim', funcs.fnamemodify(funcs.stdpath('cache'), ':t'))
    eq('nvim', funcs.fnamemodify(funcs.stdpath('config'), ':t'))
    eq(datadir, funcs.fnamemodify(funcs.stdpath('data'), ':t'))
    eq(statedir, funcs.fnamemodify(funcs.stdpath('state'), ':t'))
    eq('table', type(funcs.stdpath('config_dirs')))
    eq('table', type(funcs.stdpath('data_dirs')))
    eq('string', type(funcs.stdpath('run')))
    assert_alive()  -- Check for crash. #8393
  end)

  it('reacts to $NVIM_APPNAME', function()
    local appname = "NVIM_APPNAME_TEST____________________________________" ..
      "______________________________________________________________________"
    clear({env={ NVIM_APPNAME=appname }})
    eq(appname, funcs.fnamemodify(funcs.stdpath('config'), ':t'))
    eq(appname, funcs.fnamemodify(funcs.stdpath('cache'), ':t'))
    eq(maybe_data(appname), funcs.fnamemodify(funcs.stdpath('log'), ':t'))
    eq(maybe_data(appname), funcs.fnamemodify(funcs.stdpath('data'), ':t'))
    eq(maybe_data(appname), funcs.fnamemodify(funcs.stdpath('state'), ':t'))
    -- config_dirs and data_dirs are empty on windows, so don't check them on
    -- that platform
    if not is_os('win') then
      eq(appname, funcs.fnamemodify(funcs.stdpath('config_dirs')[1], ':t'))
      eq(appname, funcs.fnamemodify(funcs.stdpath('data_dirs')[1], ':t'))
    end
    assert_alive()  -- Check for crash. #8393

    -- Check that Nvim rejects invalid APPNAMEs
    -- Call jobstart() and jobwait() in the same RPC request to reduce flakiness.
    eq(1, exec_lua([[
      local child = vim.fn.jobstart({ vim.v.progpath }, { env = { NVIM_APPNAME = 'a/b\\c' } })
      return vim.fn.jobwait({ child }, 3000)[1]
    ]]))
  end)

  describe('returns a String', function()

    describe('with "config"' , function ()
      it('knows XDG_CONFIG_HOME', function()
        clear({env={
          XDG_CONFIG_HOME=alter_slashes('/home/docwhat/.config'),
        }})
        eq(alter_slashes('/home/docwhat/.config/nvim'), funcs.stdpath('config'))
      end)

      it('handles changes during runtime', function()
        clear({env={
          XDG_CONFIG_HOME=alter_slashes('/home/original'),
        }})
        eq(alter_slashes('/home/original/nvim'), funcs.stdpath('config'))
        command("let $XDG_CONFIG_HOME='"..alter_slashes('/home/new').."'")
        eq(alter_slashes('/home/new/nvim'), funcs.stdpath('config'))
      end)

      it("doesn't expand $VARIABLES", function()
        clear({env={
          XDG_CONFIG_HOME='$VARIABLES',
          VARIABLES='this-should-not-happen',
        }})
        eq(alter_slashes('$VARIABLES/nvim'), funcs.stdpath('config'))
      end)

      it("doesn't expand ~/", function()
        clear({env={
          XDG_CONFIG_HOME=alter_slashes('~/frobnitz'),
        }})
        eq(alter_slashes('~/frobnitz/nvim'), funcs.stdpath('config'))
      end)
    end)

    describe('with "data"' , function ()
      it('knows XDG_DATA_HOME', function()
        clear({env={
          XDG_DATA_HOME=alter_slashes('/home/docwhat/.local'),
        }})
        eq(alter_slashes('/home/docwhat/.local/'..datadir), funcs.stdpath('data'))
      end)

      it('handles changes during runtime', function()
        clear({env={
          XDG_DATA_HOME=alter_slashes('/home/original'),
        }})
        eq(alter_slashes('/home/original/'..datadir), funcs.stdpath('data'))
        command("let $XDG_DATA_HOME='"..alter_slashes('/home/new').."'")
        eq(alter_slashes('/home/new/'..datadir), funcs.stdpath('data'))
      end)

      it("doesn't expand $VARIABLES", function()
        clear({env={
          XDG_DATA_HOME='$VARIABLES',
          VARIABLES='this-should-not-happen',
        }})
        eq(alter_slashes('$VARIABLES/'..datadir), funcs.stdpath('data'))
      end)

      it("doesn't expand ~/", function()
        clear({env={
          XDG_DATA_HOME=alter_slashes('~/frobnitz'),
        }})
        eq(alter_slashes('~/frobnitz/'..datadir), funcs.stdpath('data'))
      end)
    end)

    describe('with "state"' , function ()
      it('knows XDG_STATE_HOME', function()
        clear({env={
          XDG_STATE_HOME=alter_slashes('/home/docwhat/.local'),
        }})
        eq(alter_slashes('/home/docwhat/.local/'..statedir), funcs.stdpath('state'))
      end)

      it('handles changes during runtime', function()
        clear({env={
          XDG_STATE_HOME=alter_slashes('/home/original'),
        }})
        eq(alter_slashes('/home/original/'..statedir), funcs.stdpath('state'))
        command("let $XDG_STATE_HOME='"..alter_slashes('/home/new').."'")
        eq(alter_slashes('/home/new/'..statedir), funcs.stdpath('state'))
      end)

      it("doesn't expand $VARIABLES", function()
        clear({env={
          XDG_STATE_HOME='$VARIABLES',
          VARIABLES='this-should-not-happen',
        }})
        eq(alter_slashes('$VARIABLES/'..statedir), funcs.stdpath('state'))
      end)

      it("doesn't expand ~/", function()
        clear({env={
          XDG_STATE_HOME=alter_slashes('~/frobnitz'),
        }})
        eq(alter_slashes('~/frobnitz/'..statedir), funcs.stdpath('state'))
      end)
    end)

    describe('with "cache"' , function ()
      it('knows XDG_CACHE_HOME', function()
        clear({env={
          XDG_CACHE_HOME=alter_slashes('/home/docwhat/.cache'),
        }})
        eq(alter_slashes('/home/docwhat/.cache/nvim'), funcs.stdpath('cache'))
      end)

      it('handles changes during runtime', function()
        clear({env={
          XDG_CACHE_HOME=alter_slashes('/home/original'),
        }})
        eq(alter_slashes('/home/original/nvim'), funcs.stdpath('cache'))
        command("let $XDG_CACHE_HOME='"..alter_slashes('/home/new').."'")
        eq(alter_slashes('/home/new/nvim'), funcs.stdpath('cache'))
      end)

      it("doesn't expand $VARIABLES", function()
        clear({env={
          XDG_CACHE_HOME='$VARIABLES',
          VARIABLES='this-should-not-happen',
        }})
        eq(alter_slashes('$VARIABLES/nvim'), funcs.stdpath('cache'))
      end)

      it("doesn't expand ~/", function()
        clear({env={
          XDG_CACHE_HOME=alter_slashes('~/frobnitz'),
        }})
        eq(alter_slashes('~/frobnitz/nvim'), funcs.stdpath('cache'))
      end)
    end)
  end)

  describe('returns a List', function()
    -- Some OS specific variables the system would have set.
    local function base_env()
      if is_os('win') then
        return {
          HOME='C:\\Users\\docwhat', -- technically, is not a usual PATH
          HOMEDRIVE='C:',
          HOMEPATH='\\Users\\docwhat',
          LOCALAPPDATA='C:\\Users\\docwhat\\AppData\\Local',
          TEMP='C:\\Users\\docwhat\\AppData\\Local\\Temp',
          TMPDIR='C:\\Users\\docwhat\\AppData\\Local\\Temp',
          TMP='C:\\Users\\docwhat\\AppData\\Local\\Temp',
        }
      else
        return {
          HOME='/home/docwhat',
          HOMEDRIVE='HOMEDRIVE-should-be-ignored',
          HOMEPATH='HOMEPATH-should-be-ignored',
          LOCALAPPDATA='LOCALAPPDATA-should-be-ignored',
          TEMP='TEMP-should-be-ignored',
          TMPDIR='TMPDIR-should-be-ignored',
          TMP='TMP-should-be-ignored',
        }
      end
    end

    local function set_paths_via_system(var_name, paths)
      local env = base_env()
      env[var_name] = table.concat(paths, env_sep)
      clear({env=env})
    end

    local function set_paths_at_runtime(var_name, paths)
      clear({env=base_env()})
      meths.set_var('env_val', table.concat(paths, env_sep))
      command(('let $%s=g:env_val'):format(var_name))
    end

    local function behaves_like_dir_list_env(msg, stdpath_arg, env_var_name, paths, expected_paths)
      describe(msg, function()
        it('set via system', function()
          set_paths_via_system(env_var_name, paths)
          eq(expected_paths, funcs.stdpath(stdpath_arg))
        end)

        it('set at runtime', function()
          set_paths_at_runtime(env_var_name, paths)
          eq(expected_paths, funcs.stdpath(stdpath_arg))
        end)
      end)
    end

    describe('with "config_dirs"' , function ()
      behaves_like_dir_list_env(
        'handles XDG_CONFIG_DIRS with one path',
        'config_dirs', 'XDG_CONFIG_DIRS',
        {
          alter_slashes('/home/docwhat/.config')
        },
        {
          alter_slashes('/home/docwhat/.config/nvim')
        })

      behaves_like_dir_list_env(
        'handles XDG_CONFIG_DIRS with two paths',
        'config_dirs', 'XDG_CONFIG_DIRS',
        {
          alter_slashes('/home/docwhat/.config'),
          alter_slashes('/etc/config')
        },
        {
          alter_slashes('/home/docwhat/.config/nvim'),
          alter_slashes('/etc/config/nvim')
        })

      behaves_like_dir_list_env(
        "doesn't expand $VAR and $IBLES",
        'config_dirs', 'XDG_CONFIG_DIRS',
        { '$HOME', '$TMP' },
        {
          alter_slashes('$HOME/nvim'),
          alter_slashes('$TMP/nvim')
        })


      behaves_like_dir_list_env(
        "doesn't expand ~/",
        'config_dirs', 'XDG_CONFIG_DIRS',
        {
          alter_slashes('~/.oldconfig'),
          alter_slashes('~/.olderconfig')
        },
        {
          alter_slashes('~/.oldconfig/nvim'),
          alter_slashes('~/.olderconfig/nvim')
        })
    end)

    describe('with "data_dirs"' , function ()
      behaves_like_dir_list_env(
        'knows XDG_DATA_DIRS with one path',
        'data_dirs', 'XDG_DATA_DIRS',
        {
          alter_slashes('/home/docwhat/.data')
        },
        {
          alter_slashes('/home/docwhat/.data/nvim')
        })

      behaves_like_dir_list_env(
        'knows XDG_DATA_DIRS with two paths',
        'data_dirs', 'XDG_DATA_DIRS',
        {
          alter_slashes('/home/docwhat/.data'),
          alter_slashes('/etc/local')
        },
        {
          alter_slashes('/home/docwhat/.data/nvim'),
          alter_slashes('/etc/local/nvim'),
        })

      behaves_like_dir_list_env(
        "doesn't expand $VAR and $IBLES",
        'data_dirs', 'XDG_DATA_DIRS',
        { '$HOME', '$TMP' },
        {
          alter_slashes('$HOME/nvim'),
          alter_slashes('$TMP/nvim')
        })

      behaves_like_dir_list_env(
        "doesn't expand ~/",
        'data_dirs', 'XDG_DATA_DIRS',
        {
          alter_slashes('~/.oldconfig'),
          alter_slashes('~/.olderconfig')
        },
        {
          alter_slashes('~/.oldconfig/nvim'),
          alter_slashes('~/.olderconfig/nvim'),
        })
    end)
  end)

  describe('errors', function()
    it('on unknown strings', function()
      eq('Vim(call):E6100: "capybara" is not a valid stdpath', exc_exec('call stdpath("capybara")'))
      eq('Vim(call):E6100: "" is not a valid stdpath', exc_exec('call stdpath("")'))
      eq('Vim(call):E6100: "23" is not a valid stdpath', exc_exec('call stdpath(23)'))
    end)

    it('on non-strings', function()
      eq('Vim(call):E731: Using a Dictionary as a String', exc_exec('call stdpath({"eris": 23})'))
      eq('Vim(call):E730: Using a List as a String', exc_exec('call stdpath([23])'))
    end)
  end)
end)
