local helpers = require('test.functional.helpers')(after_each)

local Screen = require('test.functional.ui.screen')

local meths = helpers.meths
local execute = helpers.execute
local clear = helpers.clear
local eval = helpers.eval
local eq = helpers.eq
local neq = helpers.neq

if helpers.pending_win32(pending) then return end

local function init_session(...)
  local args = { helpers.nvim_prog, '-i', 'NONE', '--embed',
    '--cmd', 'set shortmess+=I background=light noswapfile noautoindent',
    '--cmd', 'set laststatus=1 undodir=. directory=. viewdir=. backupdir=.'
    }
  for _, v in ipairs({...}) do
    table.insert(args, v)
  end
  helpers.set_session(helpers.spawn(args))
end

describe('startup defaults', function()
  describe(':filetype', function()
    local function expect_filetype(expected)
      local screen = Screen.new(48, 4)
      screen:attach()
      execute('filetype')
      screen:expect([[
        ^                                                |
        ~                                               |
        ~                                               |
        ]]..expected
      )
    end

    it('enabled by `-u NORC`', function()
      init_session('-u', 'NORC')
      expect_filetype(
        'filetype detection:ON  plugin:ON  indent:ON     |')
    end)

    it('disabled by `-u NONE`', function()
      init_session('-u', 'NONE')
      expect_filetype(
        'filetype detection:OFF  plugin:OFF  indent:OFF  |')
    end)

    it('overridden by early `filetype on`', function()
      init_session('-u', 'NORC', '--cmd', 'filetype on')
      expect_filetype(
        'filetype detection:ON  plugin:OFF  indent:OFF   |')
    end)

    it('overridden by early `filetype plugin on`', function()
      init_session('-u', 'NORC', '--cmd', 'filetype plugin on')
      expect_filetype(
        'filetype detection:ON  plugin:ON  indent:OFF    |')
    end)

    it('overridden by early `filetype indent on`', function()
      init_session('-u', 'NORC', '--cmd', 'filetype indent on')
      expect_filetype(
        'filetype detection:ON  plugin:OFF  indent:ON    |')
    end)
  end)

  describe('syntax', function()
    it('enabled by `-u NORC`', function()
      init_session('-u', 'NORC')
      eq(1, eval('g:syntax_on'))
    end)

    it('disabled by `-u NONE`', function()
      init_session('-u', 'NONE')
      eq(0, eval('exists("g:syntax_on")'))
    end)

    it('overridden by early `syntax off`', function()
      init_session('-u', 'NORC', '--cmd', 'syntax off')
      eq(0, eval('exists("g:syntax_on")'))
    end)
  end)

  describe('packpath', function()
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
end)

describe('XDG-based defaults', function()
  -- Need to be in separate describe() block to not run clear() twice.
  -- Do not put before_each() here for the same reasons.
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
