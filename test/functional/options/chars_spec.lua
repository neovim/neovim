local t = require('test.functional.testutil')()
local Screen = require('test.functional.ui.screen')
local clear, command = t.clear, t.command
local pcall_err = t.pcall_err
local eval = t.eval
local eq = t.eq
local insert = t.insert
local feed = t.feed
local api = t.api

describe("'fillchars'", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach()
  end)

  describe('"eob" flag', function()
    it("uses '~' by default", function()
      eq('', eval('&fillchars'))
      screen:expect([[
        ^                         |
        {1:~                        }|*3
                                 |
      ]])
    end)

    it('supports whitespace', function()
      screen:expect([[
        ^                         |
        {1:~                        }|*3
                                 |
      ]])
      command('set fillchars=eob:\\ ')
      screen:expect([[
        ^                         |
        {1:                         }|*3
                                 |
      ]])
    end)

    it('supports multibyte char', function()
      command('set fillchars=eob:ñ')
      screen:expect([[
        ^                         |
        {1:ñ                        }|*3
                                 |
      ]])
    end)

    it('supports composing multibyte char', function()
      command('set fillchars=eob:å̲')
      screen:expect([[
        ^                         |
        {1:å̲                        }|*3
                                 |
      ]])
    end)

    it('handles invalid values', function()
      eq(
        'Vim(set):E1511: Wrong number of characters for field "eob": fillchars=eob:',
        pcall_err(command, 'set fillchars=eob:') -- empty string
      )
      eq(
        'Vim(set):E1512: Wrong character width for field "eob": fillchars=eob:馬',
        pcall_err(command, 'set fillchars=eob:馬') -- doublewidth char
      )
      eq(
        'Vim(set):E1511: Wrong number of characters for field "eob": fillchars=eob:xy',
        pcall_err(command, 'set fillchars=eob:xy') -- two ascii chars
      )
      eq(
        'Vim(set):E1512: Wrong character width for field "eob": fillchars=eob:<ff>',
        pcall_err(command, 'set fillchars=eob:\255') -- invalid UTF-8
      )
    end)
  end)

  it('"diff" flag', function()
    screen:try_resize(45, 8)
    screen:set_default_attr_ids({
      [1] = { background = Screen.colors.Grey, foreground = Screen.colors.DarkBlue },
      [2] = { background = Screen.colors.LightCyan1, bold = true, foreground = Screen.colors.Blue1 },
      [3] = { background = Screen.colors.LightBlue },
      [4] = { reverse = true },
      [5] = { reverse = true, bold = true },
    })
    command('set fillchars=diff:…')
    insert('a\nb\nc\nd\ne')
    command('vnew')
    insert('a\nd\ne\nf')
    command('windo diffthis')
    screen:expect([[
      {1:  }a                   │{1:  }a                   |
      {1:  }{2:……………………………………………………}│{1:  }{3:b                   }|
      {1:  }{2:……………………………………………………}│{1:  }{3:c                   }|
      {1:  }d                   │{1:  }d                   |
      {1:  }e                   │{1:  }^e                   |
      {1:  }{3:f                   }│{1:  }{2:……………………………………………………}|
      {4:[No Name] [+]          }{5:[No Name] [+]         }|
                                                   |
    ]])
  end)

  it('has global value', function()
    screen:try_resize(50, 5)
    insert('foo\nbar')
    command('set laststatus=0')
    command('1,2fold')
    command('vsplit')
    command('set fillchars=fold:x')
    screen:expect([[
      {13:^+--  2 lines: fooxxxxxxxx}│{13:+--  2 lines: fooxxxxxxx}|
      {1:~                        }│{1:~                       }|*3
                                                        |
    ]])
  end)

  it('has window-local value', function()
    screen:try_resize(50, 5)
    insert('foo\nbar')
    command('set laststatus=0')
    command('1,2fold')
    command('vsplit')
    command('setl fillchars=fold:x')
    screen:expect([[
      {13:^+--  2 lines: fooxxxxxxxx}│{13:+--  2 lines: foo·······}|
      {1:~                        }│{1:~                       }|*3
                                                        |
    ]])
  end)

  it('using :set clears window-local value', function()
    screen:try_resize(50, 5)
    insert('foo\nbar')
    command('set laststatus=0')
    command('setl fillchars=fold:x')
    command('1,2fold')
    command('vsplit')
    command('set fillchars&')
    screen:expect([[
      {13:^+--  2 lines: foo········}│{13:+--  2 lines: fooxxxxxxx}|
      {1:~                        }│{1:~                       }|*3
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
      {1:<------><------>^<------>} │{1:<------><------><------>}|
      {1:~                        }│{1:~                       }|*3
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
      {1:>       >       ^>       } │{1:<------><------><------>}|
      {1:~                        }│{1:~                       }|*3
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
      {1:>------->-------^>-------$}│{1:<------><------><------>}|
      {1:~                        }│{1:~                       }|*3
                                                        |
    ]])
  end)

  it('supports composing chars', function()
    screen:set_default_attr_ids {
      [1] = { foreground = Screen.colors.Blue1, bold = true },
    }
    feed('i<tab><tab><tab>x<esc>')
    command('set list laststatus=0')
    -- tricky: the tab value forms three separate one-cell chars,
    -- thus it should be accepted despite being a mess.
    command('set listchars=tab:d̞̄̃̒̉̎ò́̌̌̂̐l̞̀̄̆̌̚,eol:å̲')
    screen:expect([[
      {1:d̞̄̃̒̉̎ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐l̞̀̄̆̌̚d̞̄̃̒̉̎ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐l̞̀̄̆̌̚d̞̄̃̒̉̎ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐l̞̀̄̆̌̚}^x{1:å̲}                        |
      {1:~                                                 }|*3
                                                        |
    ]])

    api.nvim__invalidate_glyph_cache()
    screen:_reset()
    screen:expect([[
      {1:d̞̄̃̒̉̎ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐l̞̀̄̆̌̚d̞̄̃̒̉̎ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐l̞̀̄̆̌̚d̞̄̃̒̉̎ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐ò́̌̌̂̐l̞̀̄̆̌̚}^x{1:å̲}                        |
      {1:~                                                 }|*3
                                                        |
    ]])
  end)
end)
