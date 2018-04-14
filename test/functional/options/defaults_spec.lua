local helpers = require('test.functional.helpers')(after_each)

local Screen = require('test.functional.ui.screen')

local meths = helpers.meths
local command = helpers.command
local clear = helpers.clear
local eval = helpers.eval
local eq = helpers.eq
local insert = helpers.insert
local neq = helpers.neq
local mkdir = helpers.mkdir
local rmdir = helpers.rmdir

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
    -- TODO(jkeyes): use stdpath('data') instead.
    local datasubdir = helpers.iswin() and 'nvim-data' or 'nvim'
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
