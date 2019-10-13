local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local shallowcopy = helpers.shallowcopy

describe('ui receives option updates', function()
  local screen

  local function reset(opts, ...)
    local defaults = {
      ambiwidth='single',
      arabicshape=true,
      emoji=true,
      guifont='',
      guifontset='',
      guifontwide='',
      linespace=0,
      pumblend=0,
      showtabline=1,
      termguicolors=false,
      ext_cmdline=false,
      ext_popupmenu=false,
      ext_tabline=false,
      ext_wildmenu=false,
      ext_linegrid=false,
      ext_hlstate=false,
      ext_multigrid=false,
      ext_messages=false,
      ext_termcolors=false,
    }

    clear(...)
    screen = Screen.new(20,5)
    screen:attach(opts)
    -- NB: UI test suite can be run in both "linegrid" and legacy grid mode.
    -- In both cases check that the received value is the one requested.
    defaults.ext_linegrid = screen._options.ext_linegrid or false
    return defaults
  end

  it("for defaults", function()
    local expected = reset()
    screen:expect(function()
      eq(expected, screen.options)
    end)
  end)

  it("when setting options", function()
    local expected = reset()
    local defaults = shallowcopy(expected)

    command("set termguicolors")
    expected.termguicolors = true
    screen:expect(function()
      eq(expected, screen.options)
    end)

    command("set guifont=Comic\\ Sans")
    expected.guifont = "Comic Sans"
    screen:expect(function()
      eq(expected, screen.options)
    end)

    command("set showtabline=0")
    expected.showtabline = 0
    screen:expect(function()
      eq(expected, screen.options)
    end)

    command("set linespace=13")
    expected.linespace = 13
    screen:expect(function()
      eq(expected, screen.options)
    end)

    command("set linespace=-11")
    expected.linespace = -11
    screen:expect(function()
      eq(expected, screen.options)
    end)

    command("set all&")
    screen:expect(function()
      eq(defaults, screen.options)
    end)
  end)

  it('with UI extensions', function()
    local expected = reset({ext_cmdline=true, ext_wildmenu=true})

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
    local expected = reset(nil, {args_rm=(headless and {} or {'--headless'}),
                                 args={'--cmd', 'set guifont=Comic\\ Sans\\ 12'}})
    expected.guifont = "Comic Sans 12"
    screen:expect(function()
      eq(expected, screen.options)
    end)
  end

  it('from startup options with --headless', function() startup_test(true) end)
  it('from startup options with --embed', function() startup_test(false) end)
end)
