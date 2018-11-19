local helpers = require('test.functional.helpers')(after_each)

local Screen = require('test.functional.ui.screen')

local meths = helpers.meths
local command = helpers.command
local clear = helpers.clear
local exc_exec = helpers.exc_exec
local eval = helpers.eval
local eq = helpers.eq
local funcs = helpers.funcs
local insert = helpers.insert
local iswin = helpers.iswin
local neq = helpers.neq
local mkdir = helpers.mkdir
local rmdir = helpers.rmdir
local alter_slashes = helpers.alter_slashes

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
    end)
  end)

  describe("'packpath'", function()
    it('defaults to &runtimepath', function()
      eq(meths.get_option('runtimepath'), meths.get_option('packpath'))
    end)

    it('does not follow modifications to runtimepath', function()
      meths.command('set runtimepath+=foo')
      neq(meths.get_option('runtimepath'), meths.get_option('packpath'))
      meths.command('set packpath+=foo')
      eq(meths.get_option('runtimepath'), meths.get_option('packpath'))
    end)
  end)

  it('v:progpath is set to the absolute path', function()
    eq(eval("fnamemodify(v:progpath, ':p')"), eval('v:progpath'))
  end)

  describe('$NVIM_LOG_FILE', function()
    local datasubdir = iswin() and 'nvim-data' or 'nvim'
    local xdgdir = 'Xtest-startup-xdg-logpath'
    local xdgdatadir = xdgdir..'/'..datasubdir
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
    it('defaults to stdpath("data")/log if empty', function()
      eq(true, mkdir(xdgdir) and mkdir(xdgdatadir))
      clear({env={
        XDG_DATA_HOME=xdgdir,
        NVIM_LOG_FILE='',  -- Empty is invalid.
      }})
      -- server_start() calls ELOG, which tickles log_path_init().
      pcall(command, 'call serverstart(serverlist()[0])')

      eq(xdgdir..'/'..datasubdir..'/log', string.gsub(eval('$NVIM_LOG_FILE'), '\\', '/'))
    end)
    it('defaults to stdpath("data")/log if invalid', function()
      eq(true, mkdir(xdgdir) and mkdir(xdgdatadir))
      clear({env={
        XDG_DATA_HOME=xdgdir,
        NVIM_LOG_FILE='.',  -- Any directory is invalid.
      }})
      -- server_start() calls ELOG, which tickles log_path_init().
      pcall(command, 'call serverstart(serverlist()[0])')

      eq(xdgdir..'/'..datasubdir..'/log', string.gsub(eval('$NVIM_LOG_FILE'), '\\', '/'))
    end)
    it('defaults to .nvimlog if stdpath("data") is invalid', function()
      clear({env={
        XDG_DATA_HOME='Xtest-missing-xdg-dir',
        NVIM_LOG_FILE='.',  -- Any directory is invalid.
      }})
      -- server_start() calls ELOG, which tickles log_path_init().
      pcall(command, 'call serverstart(serverlist()[0])')

      eq('.nvimlog', eval('$NVIM_LOG_FILE'))
    end)
  end)
end)

describe('XDG-based defaults', function()
  -- Need separate describe() blocks to not run clear() twice.
  -- Do not put before_each() here for the same reasons.

  describe('with empty/broken environment', function()
    it('sets correct defaults', function()
      clear({env={
        XDG_CONFIG_HOME=nil,
        XDG_DATA_HOME=nil,
        XDG_CACHE_HOME=nil,
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

      eq('.', meths.get_option('backupdir'))
      eq('.', meths.get_option('viewdir'))
      eq('.', meths.get_option('directory'))
      eq('.', meths.get_option('undodir'))
    end)
  end)

  -- TODO(jkeyes): tests below fail on win32 because of path separator.
  if helpers.pending_win32(pending) then return end

  describe('with too long XDG variables', function()
    before_each(function()
      clear({env={
        XDG_CONFIG_HOME=('/x'):rep(4096),
        XDG_CONFIG_DIRS=(('/a'):rep(2048)
                         .. ':' .. ('/b'):rep(2048)
                         .. (':/c'):rep(512)),
        XDG_DATA_HOME=('/X'):rep(4096),
        XDG_DATA_DIRS=(('/A'):rep(2048)
                       .. ':' .. ('/B'):rep(2048)
                       .. (':/C'):rep(512)),
      }})
    end)

    it('are correctly set', function()
      eq((('/x'):rep(4096) .. '/nvim'
          .. ',' .. ('/a'):rep(2048) .. '/nvim'
          .. ',' .. ('/b'):rep(2048) .. '/nvim'
          .. (',' .. '/c/nvim'):rep(512)
          .. ',' .. ('/X'):rep(4096) .. '/nvim/site'
          .. ',' .. ('/A'):rep(2048) .. '/nvim/site'
          .. ',' .. ('/B'):rep(2048) .. '/nvim/site'
          .. (',' .. '/C/nvim/site'):rep(512)
          .. ',' .. eval('$VIMRUNTIME')
          .. (',' .. '/C/nvim/site/after'):rep(512)
          .. ',' .. ('/B'):rep(2048) .. '/nvim/site/after'
          .. ',' .. ('/A'):rep(2048) .. '/nvim/site/after'
          .. ',' .. ('/X'):rep(4096) .. '/nvim/site/after'
          .. (',' .. '/c/nvim/after'):rep(512)
          .. ',' .. ('/b'):rep(2048) .. '/nvim/after'
          .. ',' .. ('/a'):rep(2048) .. '/nvim/after'
          .. ',' .. ('/x'):rep(4096) .. '/nvim/after'
      ), meths.get_option('runtimepath'))
      meths.command('set runtimepath&')
      meths.command('set backupdir&')
      meths.command('set directory&')
      meths.command('set undodir&')
      meths.command('set viewdir&')
      eq((('/x'):rep(4096) .. '/nvim'
          .. ',' .. ('/a'):rep(2048) .. '/nvim'
          .. ',' .. ('/b'):rep(2048) .. '/nvim'
          .. (',' .. '/c/nvim'):rep(512)
          .. ',' .. ('/X'):rep(4096) .. '/nvim/site'
          .. ',' .. ('/A'):rep(2048) .. '/nvim/site'
          .. ',' .. ('/B'):rep(2048) .. '/nvim/site'
          .. (',' .. '/C/nvim/site'):rep(512)
          .. ',' .. eval('$VIMRUNTIME')
          .. (',' .. '/C/nvim/site/after'):rep(512)
          .. ',' .. ('/B'):rep(2048) .. '/nvim/site/after'
          .. ',' .. ('/A'):rep(2048) .. '/nvim/site/after'
          .. ',' .. ('/X'):rep(4096) .. '/nvim/site/after'
          .. (',' .. '/c/nvim/after'):rep(512)
          .. ',' .. ('/b'):rep(2048) .. '/nvim/after'
          .. ',' .. ('/a'):rep(2048) .. '/nvim/after'
          .. ',' .. ('/x'):rep(4096) .. '/nvim/after'
      ), meths.get_option('runtimepath'))
      eq('.,' .. ('/X'):rep(4096) .. '/nvim/backup',
         meths.get_option('backupdir'))
      eq(('/X'):rep(4096) .. '/nvim/swap//', meths.get_option('directory'))
      eq(('/X'):rep(4096) .. '/nvim/undo', meths.get_option('undodir'))
      eq(('/X'):rep(4096) .. '/nvim/view', meths.get_option('viewdir'))
    end)
  end)

  describe('with XDG variables that can be expanded', function()
    before_each(function()
      clear({env={
        XDG_CONFIG_HOME='$XDG_DATA_HOME',
        XDG_CONFIG_DIRS='$XDG_DATA_DIRS',
        XDG_DATA_HOME='$XDG_CONFIG_HOME',
        XDG_DATA_DIRS='$XDG_CONFIG_DIRS',
      }})
    end)

    it('are not expanded', function()
      eq(('$XDG_DATA_HOME/nvim'
          .. ',$XDG_DATA_DIRS/nvim'
          .. ',$XDG_CONFIG_HOME/nvim/site'
          .. ',$XDG_CONFIG_DIRS/nvim/site'
          .. ',' .. eval('$VIMRUNTIME')
          .. ',$XDG_CONFIG_DIRS/nvim/site/after'
          .. ',$XDG_CONFIG_HOME/nvim/site/after'
          .. ',$XDG_DATA_DIRS/nvim/after'
          .. ',$XDG_DATA_HOME/nvim/after'
      ), meths.get_option('runtimepath'))
      meths.command('set runtimepath&')
      meths.command('set backupdir&')
      meths.command('set directory&')
      meths.command('set undodir&')
      meths.command('set viewdir&')
      eq(('$XDG_DATA_HOME/nvim'
          .. ',$XDG_DATA_DIRS/nvim'
          .. ',$XDG_CONFIG_HOME/nvim/site'
          .. ',$XDG_CONFIG_DIRS/nvim/site'
          .. ',' .. eval('$VIMRUNTIME')
          .. ',$XDG_CONFIG_DIRS/nvim/site/after'
          .. ',$XDG_CONFIG_HOME/nvim/site/after'
          .. ',$XDG_DATA_DIRS/nvim/after'
          .. ',$XDG_DATA_HOME/nvim/after'
      ), meths.get_option('runtimepath'))
      eq('.,$XDG_CONFIG_HOME/nvim/backup', meths.get_option('backupdir'))
      eq('$XDG_CONFIG_HOME/nvim/swap//', meths.get_option('directory'))
      eq('$XDG_CONFIG_HOME/nvim/undo', meths.get_option('undodir'))
      eq('$XDG_CONFIG_HOME/nvim/view', meths.get_option('viewdir'))
      meths.command('set all&')
      eq(('$XDG_DATA_HOME/nvim'
          .. ',$XDG_DATA_DIRS/nvim'
          .. ',$XDG_CONFIG_HOME/nvim/site'
          .. ',$XDG_CONFIG_DIRS/nvim/site'
          .. ',' .. eval('$VIMRUNTIME')
          .. ',$XDG_CONFIG_DIRS/nvim/site/after'
          .. ',$XDG_CONFIG_HOME/nvim/site/after'
          .. ',$XDG_DATA_DIRS/nvim/after'
          .. ',$XDG_DATA_HOME/nvim/after'
      ), meths.get_option('runtimepath'))
      eq('.,$XDG_CONFIG_HOME/nvim/backup', meths.get_option('backupdir'))
      eq('$XDG_CONFIG_HOME/nvim/swap//', meths.get_option('directory'))
      eq('$XDG_CONFIG_HOME/nvim/undo', meths.get_option('undodir'))
      eq('$XDG_CONFIG_HOME/nvim/view', meths.get_option('viewdir'))
    end)
  end)

  describe('with commas', function()
    before_each(function()
      clear({env={
        XDG_CONFIG_HOME=', , ,',
        XDG_CONFIG_DIRS=',-,-,:-,-,-',
        XDG_DATA_HOME=',=,=,',
        XDG_DATA_DIRS=',≡,≡,:≡,≡,≡',
      }})
    end)

    it('are escaped properly', function()
      eq(('\\, \\, \\,/nvim'
          .. ',\\,-\\,-\\,/nvim'
          .. ',-\\,-\\,-/nvim'
          .. ',\\,=\\,=\\,/nvim/site'
          .. ',\\,≡\\,≡\\,/nvim/site'
          .. ',≡\\,≡\\,≡/nvim/site'
          .. ',' .. eval('$VIMRUNTIME')
          .. ',≡\\,≡\\,≡/nvim/site/after'
          .. ',\\,≡\\,≡\\,/nvim/site/after'
          .. ',\\,=\\,=\\,/nvim/site/after'
          .. ',-\\,-\\,-/nvim/after'
          .. ',\\,-\\,-\\,/nvim/after'
          .. ',\\, \\, \\,/nvim/after'
      ), meths.get_option('runtimepath'))
      meths.command('set runtimepath&')
      meths.command('set backupdir&')
      meths.command('set directory&')
      meths.command('set undodir&')
      meths.command('set viewdir&')
      eq(('\\, \\, \\,/nvim'
          .. ',\\,-\\,-\\,/nvim'
          .. ',-\\,-\\,-/nvim'
          .. ',\\,=\\,=\\,/nvim/site'
          .. ',\\,≡\\,≡\\,/nvim/site'
          .. ',≡\\,≡\\,≡/nvim/site'
          .. ',' .. eval('$VIMRUNTIME')
          .. ',≡\\,≡\\,≡/nvim/site/after'
          .. ',\\,≡\\,≡\\,/nvim/site/after'
          .. ',\\,=\\,=\\,/nvim/site/after'
          .. ',-\\,-\\,-/nvim/after'
          .. ',\\,-\\,-\\,/nvim/after'
          .. ',\\, \\, \\,/nvim/after'
      ), meths.get_option('runtimepath'))
      eq('.,\\,=\\,=\\,/nvim/backup', meths.get_option('backupdir'))
      eq('\\,=\\,=\\,/nvim/swap//', meths.get_option('directory'))
      eq('\\,=\\,=\\,/nvim/undo', meths.get_option('undodir'))
      eq('\\,=\\,=\\,/nvim/view', meths.get_option('viewdir'))
    end)
  end)
end)


describe('stdpath()', function()
  -- Windows appends 'nvim-data' instead of just 'nvim' to prevent collisions
  -- due to XDG_CONFIG_HOME and XDG_DATA_HOME being the same.
  local datadir = iswin() and 'nvim-data' or 'nvim'

  it('acceptance', function()
    clear()  -- Do not explicitly set any env vars.

    eq('nvim', funcs.fnamemodify(funcs.stdpath('cache'), ':t'))
    eq('nvim', funcs.fnamemodify(funcs.stdpath('config'), ':t'))
    eq(datadir, funcs.fnamemodify(funcs.stdpath('data'), ':t'))
    eq('table', type(funcs.stdpath('config_dirs')))
    eq('table', type(funcs.stdpath('data_dirs')))
    -- Check for crash. #8393
    eq(2, eval('1+1'))
  end)

  context('returns a String', function()

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

  context('returns a List', function()
    -- Some OS specific variables the system would have set.
    local function base_env()
      if iswin() then
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
      env[var_name] = table.concat(paths, ':')
      clear({env=env})
    end

    local function set_paths_at_runtime(var_name, paths)
      clear({env=base_env()})
      meths.set_var('env_val', table.concat(paths, ':'))
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
      eq('Vim(call):E731: using Dictionary as a String', exc_exec('call stdpath({"eris": 23})'))
      eq('Vim(call):E730: using List as a String', exc_exec('call stdpath([23])'))
    end)
  end)
end)
