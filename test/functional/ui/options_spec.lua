local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq

describe('ui receives option updates', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(20,5)
  end)

  after_each(function()
    screen:detach()
  end)

  local defaults = {
    ambiwidth='single',
    arabicshape=true,
    emoji=true,
    guifont='',
    guifontset='',
    guifontwide='',
    linespace=0,
    showtabline=1,
    termguicolors=false,
    ext_cmdline=false,
    ext_popupmenu=false,
    ext_tabline=false,
    ext_wildmenu=false,
    ext_linegrid=false,
    ext_hlstate=false,
  }

  it("for defaults", function()
    screen:attach()
    -- NB: UI test suite can be run in both "linegrid" and legacy grid mode.
    -- In both cases check that the received value is the one requested.
    defaults.ext_linegrid = screen._options.ext_linegrid or false
    screen:expect(function()
      eq(defaults, screen.options)
    end)
  end)

  it("when setting options", function()
    screen:attach()
    defaults.ext_linegrid = screen._options.ext_linegrid or false
    local changed = {}
    for k,v in pairs(defaults) do
      changed[k] = v
    end

    command("set termguicolors")
    changed.termguicolors = true
    screen:expect(function()
      eq(changed, screen.options)
    end)

    command("set guifont=Comic\\ Sans")
    changed.guifont = "Comic Sans"
    screen:expect(function()
      eq(changed, screen.options)
    end)

    command("set showtabline=0")
    changed.showtabline = 0
    screen:expect(function()
      eq(changed, screen.options)
    end)

    command("set linespace=13")
    changed.linespace = 13
    screen:expect(function()
      eq(changed, screen.options)
    end)

    command("set linespace=-11")
    changed.linespace = -11
    screen:expect(function()
      eq(changed, screen.options)
    end)

    command("set all&")
    screen:expect(function()
      eq(defaults, screen.options)
    end)
  end)

  it('with UI extensions', function()
    local changed = {}
    for k,v in pairs(defaults) do
      changed[k] = v
    end

    screen:attach({ext_cmdline=true, ext_wildmenu=true})
    defaults.ext_linegrid = screen._options.ext_linegrid or false
    changed.ext_cmdline = true
    changed.ext_wildmenu = true
    screen:expect(function()
      eq(changed, screen.options)
    end)

    screen:set_option('ext_popupmenu', true)
    changed.ext_popupmenu = true
    screen:expect(function()
      eq(changed, screen.options)
    end)

    screen:set_option('ext_wildmenu', false)
    changed.ext_wildmenu = false
    screen:expect(function()
      eq(changed, screen.options)
    end)
  end)
end)
