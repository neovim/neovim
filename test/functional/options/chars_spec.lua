local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, command = helpers.clear, helpers.command
local eval = helpers.eval
local eq = helpers.eq
local exc_exec = helpers.exc_exec
local insert = helpers.insert
local feed = helpers.feed

describe("'fillchars'", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach()
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
        ~                        |*3
                                 |
      ]])
    end)
    it('supports whitespace', function()
      screen:expect([[
        ^                         |
        ~                        |*3
                                 |
      ]])
      command('set fillchars=eob:\\ ')
      screen:expect([[
        ^                         |
                                 |*4
      ]])
    end)
    it('supports multibyte char', function()
      command('set fillchars=eob:ñ')
      screen:expect([[
        ^                         |
        ñ                        |*3
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
  it('has global value', function()
    screen:try_resize(50, 5)
    insert("foo\nbar")
    command('set laststatus=0')
    command('1,2fold')
    command('vsplit')
    command('set fillchars=fold:x')
    screen:expect([[
      ^+--  2 lines: fooxxxxxxxx│+--  2 lines: fooxxxxxxx|
      ~                        │~                       |*3
                                                        |
    ]])
  end)
  it('has window-local value', function()
    screen:try_resize(50, 5)
    insert("foo\nbar")
    command('set laststatus=0')
    command('1,2fold')
    command('vsplit')
    command('setl fillchars=fold:x')
    screen:expect([[
      ^+--  2 lines: fooxxxxxxxx│+--  2 lines: foo·······|
      ~                        │~                       |*3
                                                        |
    ]])
  end)
  it('using :set clears window-local value', function()
    screen:try_resize(50, 5)
    insert("foo\nbar")
    command('set laststatus=0')
    command('setl fillchars=fold:x')
    command('1,2fold')
    command('vsplit')
    command('set fillchars&')
    screen:expect([[
      ^+--  2 lines: foo········│+--  2 lines: fooxxxxxxx|
      ~                        │~                       |*3
                                                        |
    ]])
  end)
end)

describe("'listchars'", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 5)
    screen:attach()
  end)

  it('has global value', function()
    feed('i<tab><tab><tab><esc>')
    command('set list laststatus=0')
    command('vsplit')
    command('set listchars=tab:<->')
    screen:expect([[
      <------><------>^<------> │<------><------><------>|
      ~                        │~                       |*3
                                                        |
    ]])
  end)
  it('has window-local value', function()
    feed('i<tab><tab><tab><esc>')
    command('set list laststatus=0')
    command('setl listchars=tab:<->')
    command('vsplit')
    command('setl listchars<')
    screen:expect([[
      >       >       ^>        │<------><------><------>|
      ~                        │~                       |*3
                                                        |
    ]])
  end)
  it('using :set clears window-local value', function()
    feed('i<tab><tab><tab><esc>')
    command('set list laststatus=0')
    command('setl listchars=tab:<->')
    command('vsplit')
    command('set listchars=tab:>-,eol:$')
    screen:expect([[
      >------->-------^>-------$│<------><------><------>|
      ~                        │~                       |*3
                                                        |
    ]])
  end)
end)
