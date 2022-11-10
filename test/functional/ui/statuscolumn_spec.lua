local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local meths = helpers.meths
local pcall_err = helpers.pcall_err

describe('statuscolumn', function()
  local screen
  before_each(function()
    clear('--cmd', 'set number nuw=1 | call setline(1, repeat(["aaaaa"], 16)) | norm GM')
    screen = Screen.new()
    screen:attach()
  end)

  it('fails with invalid \'statuscolumn\'', function()
    command('set stc=%{v:relnum?v:relnum:(v:lnum==5?invalid:v:lnum)}\\ ')
    screen:expect([[
      4  aaaaa                                             |
      3  aaaaa                                             |
      2  aaaaa                                             |
      1  aaaaa                                             |
      8  ^aaaaa                                             |
      1  aaaaa                                             |
      2  aaaaa                                             |
      3  aaaaa                                             |
      4  aaaaa                                             |
      5  aaaaa                                             |
      6  aaaaa                                             |
      7  aaaaa                                             |
      8  aaaaa                                             |
                                                           |
    ]])
    command('norm 5G')
    eq('Vim(redraw):E121: Undefined variable: invalid', pcall_err(command, 'redraw!'))
    eq('', eval('&statuscolumn'))
  end)

  it('widens with irregular \'statuscolumn\' width', function()
    command('set stc=%{v:relnum?v:relnum:(v:lnum==5?\'bbbbb\':v:lnum)}')
    command('norm 5G | redraw!')
    screen:expect([[
      1    aaaaa                                           |
      bbbbba^eaaa                                           |
      1    aaaaa                                           |
      2    aaaaa                                           |
      3    aaaaa                                           |
      4    aaaaa                                           |
      5    aaaaa                                           |
      6    aaaaa                                           |
      7    aaaaa                                           |
      8    aaaaa                                           |
      9    aaaaa                                           |
      10   aaaaa                                           |
      11   aaaaa                                           |
                                                           |
    ]])
  end)

  it('works with \'statuscolumn\'', function()
    command([[set stc=%{&nu?v:lnum:''}%=%{&rnu?'\ '.v:relnum:''}│]])
    screen:expect([[
      4 │aaaaa                                             |
      5 │aaaaa                                             |
      6 │aaaaa                                             |
      7 │aaaaa                                             |
      8 │^aaaaa                                             |
      9 │aaaaa                                             |
      10│aaaaa                                             |
      11│aaaaa                                             |
      12│aaaaa                                             |
      13│aaaaa                                             |
      14│aaaaa                                             |
      15│aaaaa                                             |
      16│aaaaa                                             |
                                                           |
    ]])
    command('set relativenumber')
    screen:expect([[
      4  4│aaaaa                                           |
      5  3│aaaaa                                           |
      6  2│aaaaa                                           |
      7  1│aaaaa                                           |
      8  0│^aaaaa                                           |
      9  1│aaaaa                                           |
      10 2│aaaaa                                           |
      11 3│aaaaa                                           |
      12 4│aaaaa                                           |
      13 5│aaaaa                                           |
      14 6│aaaaa                                           |
      15 7│aaaaa                                           |
      16 8│aaaaa                                           |
                                                           |
    ]])
    command('norm 12GH')
    screen:expect([[
      4   0│^aaaaa                                          |
      5   1│aaaaa                                          |
      6   2│aaaaa                                          |
      7   3│aaaaa                                          |
      8   4│aaaaa                                          |
      9   5│aaaaa                                          |
      10  6│aaaaa                                          |
      11  7│aaaaa                                          |
      12  8│aaaaa                                          |
      13  9│aaaaa                                          |
      14 10│aaaaa                                          |
      15 11│aaaaa                                          |
      16 12│aaaaa                                          |
                                                           |
    ]])
  end)

  it('works with highlighted \'statuscolumn\'', function()
    command([[set stc=%#NonText#%{&nu?v:lnum:''}]] ..
            [[%=%{&rnu&&(v:lnum%2)?'\ '.v:relnum:''}]] ..
            [[%#LineNr#%{&rnu&&!(v:lnum%2)?'\ '.v:relnum:''}│]])
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},
      [1] = {foreground = Screen.colors.Brown},
    })
    screen:expect([[
      {0:4 }{1:│}aaaaa                                             |
      {0:5 }{1:│}aaaaa                                             |
      {0:6 }{1:│}aaaaa                                             |
      {0:7 }{1:│}aaaaa                                             |
      {0:8 }{1:│}^aaaaa                                             |
      {0:9 }{1:│}aaaaa                                             |
      {0:10}{1:│}aaaaa                                             |
      {0:11}{1:│}aaaaa                                             |
      {0:12}{1:│}aaaaa                                             |
      {0:13}{1:│}aaaaa                                             |
      {0:14}{1:│}aaaaa                                             |
      {0:15}{1:│}aaaaa                                             |
      {0:16}{1:│}aaaaa                                             |
                                                           |
    ]])
    command('set relativenumber')
    screen:expect([[
      {0:4 }{1: 4│}aaaaa                                           |
      {0:5  3}{1:│}aaaaa                                           |
      {0:6 }{1: 2│}aaaaa                                           |
      {0:7  1}{1:│}aaaaa                                           |
      {0:8 }{1: 0│}^aaaaa                                           |
      {0:9  1}{1:│}aaaaa                                           |
      {0:10}{1: 2│}aaaaa                                           |
      {0:11 3}{1:│}aaaaa                                           |
      {0:12}{1: 4│}aaaaa                                           |
      {0:13 5}{1:│}aaaaa                                           |
      {0:14}{1: 6│}aaaaa                                           |
      {0:15 7}{1:│}aaaaa                                           |
      {0:16}{1: 8│}aaaaa                                           |
                                                           |
    ]])
    command('set nonumber')
    screen:expect([[
      {1:4│}aaaaa                                              |
      {0:3}{1:│}aaaaa                                              |
      {1:2│}aaaaa                                              |
      {0:1}{1:│}aaaaa                                              |
      {1:0│}^aaaaa                                              |
      {0:1}{1:│}aaaaa                                              |
      {1:2│}aaaaa                                              |
      {0:3}{1:│}aaaaa                                              |
      {1:4│}aaaaa                                              |
      {0:5}{1:│}aaaaa                                              |
      {1:6│}aaaaa                                              |
      {0:7}{1:│}aaaaa                                              |
      {1:8│}aaaaa                                              |
                                                           |
    ]])
  end)

  it('works with wrapped lines, signs and folds', function()
    command("set stc=%C%s%=%{v:wrap?'':v:lnum}│\\ ")
    command("call setline(1,repeat([repeat('aaaaa',10)],16))")
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},
      [1] = {foreground = Screen.colors.Brown},
      [2] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.WebGrey},
      [3] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.LightGrey},
    })
    screen:expect([[
      {1: 4│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:  │ }a                                                |
      {1: 5│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:  │ }a                                                |
      {1: 6│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:  │ }a                                                |
      {1: 7│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:  │ }a                                                |
      {1: 8│ }^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:  │ }a                                                |
      {1: 9│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:  │ }a                                                |
      {1:10│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{0:@@@}|
                                                           |
    ]])
    command('set signcolumn=auto:2 foldcolumn=auto')
    command('sign define piet1 text=>> texthl=LineNr')
    command('sign define piet2 text=>! texthl=NonText')
    command('sign place 1 line=4 name=piet1 buffer=1')
    command('sign place 2 line=5 name=piet2 buffer=1')
    command('sign place 3 line=6 name=piet1 buffer=1')
    command('sign place 4 line=6 name=piet2 buffer=1')
    screen:expect([[
      {1:>>   4│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:      │ }aaaaa                                        |
      {0:>!}{1:   5│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:      │ }aaaaa                                        |
      {1:>>}{0:>!}{1: 6│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:      │ }aaaaa                                        |
      {1:     7│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:      │ }aaaaa                                        |
      {1:     8│ }^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:      │ }aaaaa                                        |
      {1:     9│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:      │ }aaaaa                                        |
      {1:    10│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{0:@@@}|
                                                           |
    ]])
    command('norm zf$')
    -- Check that alignment works properly with signs after %=
    command("set stc=%C%=%{v:wrap?'':v:lnum}│%s\\ ")
    screen:expect([[
      {2: }{1: 4│>>   }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │     }aaaaaa                                      |
      {2: }{1: 5│}{0:>!}{1:   }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │     }aaaaaa                                      |
      {2: }{1: 6│>>}{0:>!}{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │     }aaaaaa                                      |
      {2: }{1: 7│     }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │     }aaaaaa                                      |
      {2:+}{1: 8│     }{3:^+--  1 line: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {2: }{1: 9│     }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │     }aaaaaa                                      |
      {2: }{1:10│     }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │     }aaaaaa                                      |
                                                           |
    ]])
  end)

  it('works with \'statuscolumn\' clicks', function()
    command('set mousemodel=extend')
    command([[
      function! MyClickFunc(minwid, clicks, button, mods)
        let g:testvar = printf("%d %d %s %d", a:minwid, a:clicks, a:button, getmousepos().line)
        if a:mods !=# '    '
          let g:testvar ..= '(' .. a:mods .. ')'
        endif
      endfunction
      set stc=%0@MyClickFunc@%=%l%T
    ]])
    meths.input_mouse('left', 'press', '', 0, 0, 0)
    eq('0 1 l 4', eval("g:testvar"))
    meths.input_mouse('left', 'press', '', 0, 0, 0)
    eq('0 2 l 4', eval("g:testvar"))
    meths.input_mouse('left', 'press', '', 0, 0, 0)
    eq('0 3 l 4', eval("g:testvar"))
    meths.input_mouse('left', 'press', '', 0, 0, 0)
    eq('0 4 l 4', eval("g:testvar"))
    meths.input_mouse('right', 'press', '', 0, 3, 0)
    eq('0 1 r 7', eval("g:testvar"))
    meths.input_mouse('right', 'press', '', 0, 3, 0)
    eq('0 2 r 7', eval("g:testvar"))
    meths.input_mouse('right', 'press', '', 0, 3, 0)
    eq('0 3 r 7', eval("g:testvar"))
    meths.input_mouse('right', 'press', '', 0, 3, 0)
    eq('0 4 r 7', eval("g:testvar"))
  end)
end)
