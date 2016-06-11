local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, eval, eq  = helpers.clear, helpers.eval, helpers.eq
local execute = helpers.execute

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
  before_each(function()
    clear()
  end)

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
end)


