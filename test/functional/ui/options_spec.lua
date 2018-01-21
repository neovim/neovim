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
    screen:attach()
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
  }

  it("for defaults", function()
    screen:expect(function()
      eq(defaults, screen.options)
    end)
  end)

  it("when setting options", function()
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
end)
