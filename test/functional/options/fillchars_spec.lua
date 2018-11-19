local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, command = helpers.clear, helpers.command
local eval = helpers.eval
local eq = helpers.eq
local exc_exec = helpers.exc_exec

describe("'fillchars'", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach()
  end)

  after_each(function()
    screen:detach()
  end)

  local function shouldfail(val,errval)
    errval = errval or val
    eq('Vim(set):E474: Invalid argument: fillchars='..errval,
       exc_exec('set fillchars='..val))
  end

  describe('"eob" flag', function()
    it("uses '~' by default", function()
      eq('', eval('&fillchars'))
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
                                 |
      ]])
    end)
    it('supports whitespace', function()
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
                                 |
      ]])
      command('set fillchars=eob:\\ ')
      screen:expect([[
        ^                         |
                                 |
                                 |
                                 |
                                 |
      ]])
    end)
    it('supports multibyte char', function()
      command('set fillchars=eob:ñ')
      screen:expect([[
        ^                         |
        ñ                        |
        ñ                        |
        ñ                        |
                                 |
      ]])
    end)
    it('handles invalid values', function()
      shouldfail('eob:') -- empty string
      shouldfail('eob:馬') -- doublewidth char
      shouldfail('eob:å̲') -- composing chars
      shouldfail('eob:xy') -- two ascii chars
      shouldfail('eob:\255', 'eob:<ff>') -- invalid UTF-8
    end)
  end)
end)
