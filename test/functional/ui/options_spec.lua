local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local command = n.command
local eq = t.eq
local shallowcopy = t.shallowcopy
local eval = n.eval

describe('UI receives option updates', function()
  local screen

  local function reset(screen_opts, clear_opts)
    local defaults = {
      ambiwidth = 'single',
      arabicshape = true,
      emoji = true,
      guifont = '',
      guifontwide = '',
      linespace = 0,
      pumblend = 0,
      mousefocus = false,
      mousehide = true,
      mousemoveevent = false,
      showtabline = 1,
      termguicolors = false,
      termsync = true,
      ttimeout = true,
      ttimeoutlen = 50,
      verbose = 0,
      ext_cmdline = false,
      ext_popupmenu = false,
      ext_tabline = false,
      ext_wildmenu = false,
      ext_linegrid = false,
      ext_hlstate = false,
      ext_multigrid = false,
      ext_messages = false,
      ext_termcolors = false,
    }

    clear_opts = shallowcopy(clear_opts or {})
    clear_opts.args_rm = clear_opts.args_rm or {}
    table.insert(clear_opts.args_rm or {}, '--cmd')
    clear(clear_opts)
    screen = Screen.new(20, 5, screen_opts)
    -- NB: UI test suite can be run in both "linegrid" and legacy grid mode.
    -- In both cases check that the received value is the one requested.
    defaults.ext_linegrid = screen._options.ext_linegrid or false
    return defaults
  end

  it('for defaults', function()
    local expected = reset()
    screen:expect(function()
      eq(expected, screen.options)
    end)
  end)

  it('on attach #11372', function()
    clear { args_rm = { '--headless' } }
    local evs = {}
    screen = Screen.new(20, 5)
    -- Override mouse_on/mouse_off handlers.
    function screen:_handle_mouse_on()
      table.insert(evs, 'mouse_on')
    end
    function screen:_handle_mouse_off()
      table.insert(evs, 'mouse_off')
    end
    screen:expect(function()
      eq({ 'mouse_on' }, evs)
    end)
    command('set mouse=')
    screen:expect(function()
      eq({ 'mouse_on', 'mouse_off' }, evs)
    end)
    command('set mouse&')
    screen:expect(function()
      eq({ 'mouse_on', 'mouse_off', 'mouse_on' }, evs)
    end)
    screen:detach()
    eq({ 'mouse_on', 'mouse_off', 'mouse_on' }, evs)
    screen:attach()
    screen:expect(function()
      eq({ 'mouse_on', 'mouse_off', 'mouse_on', 'mouse_on' }, evs)
    end)
  end)

  it('when setting options', function()
    local expected = reset()
    local defaults = shallowcopy(expected)

    command('set termguicolors')
    expected.termguicolors = true
    screen:expect(function()
      eq(expected, screen.options)
    end)

    command('set pumblend=50')
    expected.pumblend = 50
    screen:expect(function()
      eq(expected, screen.options)
    end)

    -- check handling of out-of-bounds value
    command('set pumblend=-1')
    expected.pumblend = 0
    screen:expect(function()
      eq(expected, screen.options)
    end)

    command('set guifont=Comic\\ Sans')
    expected.guifont = 'Comic Sans'
    screen:expect(function()
      eq(expected, screen.options)
    end)

    command('set showtabline=0')
    expected.showtabline = 0
    screen:expect(function()
      eq(expected, screen.options)
    end)

    command('set linespace=13')
    expected.linespace = 13
    screen:expect(function()
      eq(expected, screen.options)
    end)

    command('set linespace=-11')
    expected.linespace = -11
    screen:expect(function()
      eq(expected, screen.options)
    end)

    command('set mousefocus')
    expected.mousefocus = true
    screen:expect(function()
      eq(expected, screen.options)
    end)

    command('set nomousehide')
    expected.mousehide = false
    screen:expect(function()
      eq(expected, screen.options)
    end)

    command('set mousemoveevent')
    expected.mousemoveevent = true
    screen:expect(function()
      eq(expected, screen.options)
    end)

    command('set nottimeout')
    expected.ttimeout = false
    screen:expect(function()
      eq(expected, screen.options)
    end)

    command('set ttimeoutlen=100')
    expected.ttimeoutlen = 100
    screen:expect(function()
      eq(expected, screen.options)
    end)

    command('set all&')
    screen:expect(function()
      eq(defaults, screen.options)
    end)
  end)

  it('with UI extensions', function()
    local expected = reset({ ext_cmdline = true, ext_wildmenu = true })

    expected.ext_cmdline = true
    expected.ext_wildmenu = true
    screen:expect(function()
      eq(expected, screen.options)
    end)

    screen:set_option('ext_popupmenu', true)
    expected.ext_popupmenu = true
    screen:expect(function()
      eq(expected, screen.options)
    end)

    screen:set_option('ext_wildmenu', false)
    expected.ext_wildmenu = false
    screen:expect(function()
      eq(expected, screen.options)
    end)
  end)

  local function startup_test(headless)
    local expected = reset(nil, {
      args_rm = (headless and {} or { '--headless' }),
      args = { '--cmd', 'set guifont=Comic\\ Sans\\ 12' },
    })
    expected.guifont = 'Comic Sans 12'
    screen:expect(function()
      eq(expected, screen.options)
    end)
  end

  it('from startup options with --headless', function()
    startup_test(true)
  end)
  it('from startup options with --embed', function()
    startup_test(false)
  end)
end)

describe('UI can set terminal option', function()
  before_each(function()
    -- by default we implicitly "--cmd 'set bg=light'" which ruins everything
    clear { args_rm = { '--cmd' } }
  end)

  it('term_name', function()
    eq('nvim', eval '&term')

    local _ = Screen.new(20, 5, { term_name = 'xterm' })
    eq('xterm', eval '&term')
  end)

  it('term_colors', function()
    eq('256', eval '&t_Co')

    local _ = Screen.new(20, 5, { term_colors = 8 })
    eq('8', eval '&t_Co')
  end)
end)
