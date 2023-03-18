local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local exec_lua = helpers.exec_lua
local feed = helpers.feed
local meths = helpers.meths
local pcall_err = helpers.pcall_err

describe('statuscolumn', function()
  local screen
  before_each(function()
    clear('--cmd', 'set number nuw=1 | call setline(1, repeat(["aaaaa"], 16)) | norm GM')
    screen = Screen.new()
    screen:attach()
  end)

  it("fails with invalid 'statuscolumn'", function()
    command([[set stc=%{v:relnum?v:relnum:(v:lnum==5?invalid:v:lnum)}\ ]])
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

  it("widens with irregular 'statuscolumn' width", function()
    command([[set stc=%{v:relnum?v:relnum:(v:lnum==5?'bbbbb':v:lnum)}]])
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

  it("works with 'number' and 'relativenumber'", function()
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
    command([[set stc=%l%=%{&rnu?'\ ':''}%r│]])
    screen:expect_unchanged()
    command([[set stc=%{&nu?v:lnum:''}%=%{&rnu?'\ '.v:relnum:''}│]])
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
    command([[set stc=%l%=%{&rnu?'\ ':''}%r│]])
    screen:expect_unchanged()
    command([[set stc=%{&nu?v:lnum:''}%=%{&rnu?'\ '.v:relnum:''}│]])
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
    command([[set stc=%l%=%{&rnu?'\ ':''}%r│]])
    screen:expect_unchanged()
    command([[set stc=%{&nu?v:lnum:''}%=%{&rnu?'\ '.v:relnum:''}│]])
  end)

  it("works with highlighted 'statuscolumn'", function()
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
    command([[set stc=%C%s%=%{v:virtnum?'':v:lnum}│\ ]])
    command("call setline(1,repeat([repeat('aaaaa',10)],16))")
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},
      [1] = {foreground = Screen.colors.Brown},
      [2] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.WebGrey},
      [3] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.LightGrey},
      [4] = {bold = true, foreground = Screen.colors.Brown},
      [5] = {background = Screen.colors.Grey90},
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
    command("set stc=%C%s%=%l│\\ ")
    screen:expect_unchanged()
    command('set signcolumn=auto:2 foldcolumn=auto')
    command('sign define piet1 text=>> texthl=LineNr')
    command('sign define piet2 text=>! texthl=NonText')
    command('sign place 1 line=4 name=piet1 buffer=1')
    command('sign place 2 line=5 name=piet2 buffer=1')
    command('sign place 3 line=6 name=piet1 buffer=1')
    command('sign place 4 line=6 name=piet2 buffer=1')
    screen:expect([[
      {1:>>}{2:  }{1: 4│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2:    }{1:  │ }aaaaa                                        |
      {0:>!}{2:  }{1: 5│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2:    }{1:  │ }aaaaa                                        |
      {1:>>}{0:>!}{1: 6│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2:    }{1:  │ }aaaaa                                        |
      {2:    }{1: 7│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2:    }{1:  │ }aaaaa                                        |
      {2:    }{1: 8│ }^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2:    }{1:  │ }aaaaa                                        |
      {2:    }{1: 9│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2:    }{1:  │ }aaaaa                                        |
      {2:    }{1:10│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{0:@@@}|
                                                           |
    ]])
    command('norm zf$')
    -- Check that alignment works properly with signs after %=
    command([[set stc=%C%=%{v:virtnum?'':v:lnum}│%s\ ]])
    screen:expect([[
      {2: }{1: 4│>>}{2:  }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:    }{1: }aaaaaa                                      |
      {2: }{1: 5│}{0:>!}{2:  }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:    }{1: }aaaaaa                                      |
      {2: }{1: 6│>>}{0:>!}{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:    }{1: }aaaaaa                                      |
      {2: }{1: 7│}{2:    }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:    }{1: }aaaaaa                                      |
      {2:+}{1: 8│}{2:    }{1: }{3:^+--  1 line: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {2: }{1: 9│}{2:    }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:    }{1: }aaaaaa                                      |
      {2: }{1:10│}{2:    }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:    }{1: }aaaaaa                                      |
                                                           |
    ]])
    command('set cursorline')
    screen:expect([[
      {2: }{1: 4│>>}{2:  }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:    }{1: }aaaaaa                                      |
      {2: }{1: 5│}{0:>!}{2:  }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:    }{1: }aaaaaa                                      |
      {2: }{1: 6│>>}{0:>!}{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:    }{1: }aaaaaa                                      |
      {2: }{1: 7│}{2:    }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:    }{1: }aaaaaa                                      |
      {2:+}{4: 8│}{2:    }{4: }{5:^+--  1 line: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {2: }{1: 9│}{2:    }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:    }{1: }aaaaaa                                      |
      {2: }{1:10│}{2:    }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:    }{1: }aaaaaa                                      |
                                                           |
    ]])
    -- v:lnum is the same value on wrapped lines
    command([[set stc=%C%=%{v:lnum}│%s\ ]])
    screen:expect([[
      {2: }{1: 4│>>}{2:  }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1: 4│}{2:    }{1: }aaaaaa                                      |
      {2: }{1: 5│}{0:>!}{2:  }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1: 5│}{2:    }{1: }aaaaaa                                      |
      {2: }{1: 6│>>}{0:>!}{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1: 6│}{2:    }{1: }aaaaaa                                      |
      {2: }{1: 7│}{2:    }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1: 7│}{2:    }{1: }aaaaaa                                      |
      {2:+}{4: 8│}{2:    }{4: }{5:^+--  1 line: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {2: }{1: 9│}{2:    }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1: 9│}{2:    }{1: }aaaaaa                                      |
      {2: }{1:10│}{2:    }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:10│}{2:    }{1: }aaaaaa                                      |
                                                           |
    ]])
    -- v:relnum is the same value on wrapped lines
    command([[set stc=%C%=\ %{v:relnum}│%s\ ]])
    screen:expect([[
      {2: }{1: 4│>>}{2:  }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1: 4│}{2:    }{1: }aaaaaa                                      |
      {2: }{1: 3│}{0:>!}{2:  }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1: 3│}{2:    }{1: }aaaaaa                                      |
      {2: }{1: 2│>>}{0:>!}{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1: 2│}{2:    }{1: }aaaaaa                                      |
      {2: }{1: 1│}{2:    }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1: 1│}{2:    }{1: }aaaaaa                                      |
      {2:+}{4: 0│}{2:    }{4: }{5:^+--  1 line: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {2: }{1: 1│}{2:    }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1: 1│}{2:    }{1: }aaaaaa                                      |
      {2: }{1: 2│}{2:    }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1: 2│}{2:    }{1: }aaaaaa                                      |
                                                           |
    ]])
    command([[set stc=%C%=\ %{v:virtnum?'':v:relnum}│%s\ ]])
    screen:expect([[
      {2: }{1: 4│>>}{2:  }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:    }{1: }aaaaaa                                      |
      {2: }{1: 3│}{0:>!}{2:  }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:    }{1: }aaaaaa                                      |
      {2: }{1: 2│>>}{0:>!}{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:    }{1: }aaaaaa                                      |
      {2: }{1: 1│}{2:    }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:    }{1: }aaaaaa                                      |
      {2:+}{4: 0│}{2:    }{4: }{5:^+--  1 line: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {2: }{1: 1│}{2:    }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:    }{1: }aaaaaa                                      |
      {2: }{1: 2│}{2:    }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:    }{1: }aaaaaa                                      |
                                                           |
    ]])
    -- Up to 9 signs in a line
    command('set signcolumn=auto:9 foldcolumn=auto')
    command('sign place 5 line=6 name=piet1 buffer=1')
    command('sign place 6 line=6 name=piet2 buffer=1')
    command('sign place 7 line=6 name=piet1 buffer=1')
    command('sign place 8 line=6 name=piet2 buffer=1')
    command('sign place 9 line=6 name=piet1 buffer=1')
    command('sign place 10 line=6 name=piet2 buffer=1')
    command('sign place 11 line=6 name=piet1 buffer=1')
    screen:expect([[
      {2: }{1: 4│>>}{2:                }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:                  }{1: }aaaaaaaaaaaaaaaaaaaa          |
      {2: }{1: 3│}{0:>!}{2:                }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:                  }{1: }aaaaaaaaaaaaaaaaaaaa          |
      {2: }{1: 2│>>}{0:>!}{1:>>}{0:>!}{1:>>}{0:>!}{1:>>}{0:>!}{1:>> }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:                  }{1: }aaaaaaaaaaaaaaaaaaaa          |
      {2: }{1: 1│}{2:                  }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:                  }{1: }aaaaaaaaaaaaaaaaaaaa          |
      {2:+}{4: 0│}{2:                  }{4: }{5:^+--  1 line: aaaaaaaaaaaaaaaaa}|
      {2: }{1: 1│}{2:                  }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:                  }{1: }aaaaaaaaaaaaaaaaaaaa          |
      {2: }{1: 2│}{2:                  }{1: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {2: }{1:  │}{2:                  }{1: }aaaaaaaaaaaaaaaaaaaa          |
                                                           |
    ]])
    -- Status column is re-evaluated for virt_lines, buffer line, and wrapped line
    exec_lua([[
      local ns = vim.api.nvim_create_namespace("ns")
      vim.api.nvim_buf_set_extmark(0, ns, 5, 0, {
        virt_lines_above = true, virt_lines = {{{"virt_line above", ""}}} })
      vim.api.nvim_buf_set_extmark(0, ns, 4, 0, { virt_lines = {{{"virt_line", ""}}} })
    ]])
    command('set foldcolumn=0 signcolumn=no')
    command([[set stc=%{v:virtnum<0?'virtual':(!v:virtnum?'buffer':'wrapped')}%=%{'\ '.v:virtnum.'\ '.v:lnum}]])
    screen:expect([[
      {1:buffer  0 4}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:wrapped 1 4}aaaaaaaa                                  |
      {1:buffer  0 5}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:wrapped 1 5}aaaaaaaa                                  |
      {1:virtual-2 5}virt_line                                 |
      {1:virtual-2 5}virt_line above                           |
      {1:buffer  0 6}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:wrapped 1 6}aaaaaaaa                                  |
      {1:buffer  0 7}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:wrapped 1 7}aaaaaaaa                                  |
      {4:buffer  0 8}{5:^+--  1 line: aaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {1:buffer  0 9}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:wrapped 1 9}aaaaaaaa                                  |
                                                           |
    ]])
    -- Also test virt_lines at the end of buffer
    exec_lua([[
      local ns = vim.api.nvim_create_namespace("ns")
      vim.api.nvim_buf_set_extmark(0, ns, 15, 0, { virt_lines = {{{"END", ""}}} })
    ]])
    feed('Gzz')
    screen:expect([[
      {1:buffer  0 13}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:wrapped 1 13}aaaaaaaaa                                |
      {1:buffer  0 14}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:wrapped 1 14}aaaaaaaaa                                |
      {1:buffer  0 15}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:wrapped 1 15}aaaaaaaaa                                |
      {4:buffer  0 16}{5:^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {4:wrapped 1 16}{5:aaaaaaaaa                                }|
      {1:virtual-1 16}END                                      |
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
                                                           |
    ]])
  end)

  it("works with 'statuscolumn' clicks", function()
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
    command('set laststatus=2 winbar=%f')
    command('let g:testvar=""')
    -- Check that winbar click doesn't register as statuscolumn click
    meths.input_mouse('right', 'press', '', 0, 0, 0)
    eq('', eval("g:testvar"))
    -- Check that statusline click doesn't register as statuscolumn click
    meths.input_mouse('right', 'press', '', 0, 12, 0)
    eq('', eval("g:testvar"))
  end)

  it('click labels do not leak memory', function()
    command([[
      set laststatus=2
      setlocal statuscolumn=%0@MyClickFunc@abcd%T
      4vsplit
      setlocal statusline=abcd
      redrawstatus
      setlocal statusline=
      only
      redraw
    ]])
  end)

  it('works with foldcolumn', function()
    -- Fits maximum multibyte foldcolumn #21759
    command([[set stc=%C%=%l\  fdc=9 fillchars=foldsep:𒀀]])
    for _ = 0,8 do command('norm zfjzo') end
    -- 'statuscolumn' is not drawn for `virt_lines_leftcol` lines
    exec_lua([[
      local ns = vim.api.nvim_create_namespace("ns")
      vim.api.nvim_buf_set_extmark(0, ns, 6, 0, {
        virt_lines_leftcol = true, virt_lines = {{{"virt", ""}}} })
      vim.api.nvim_buf_set_extmark(0, ns, 7, 0, {
        virt_lines_leftcol = true, virt_lines = {{{"virt", ""}}} })
    ]])
    screen:expect([[
                4 aaaaa                                    |
                5 aaaaa                                    |
                6 aaaaa                                    |
                7 aaaaa                                    |
      virt                                                 |
      --------- 8 ^aaaaa                                    |
      virt                                                 |
      𒀀𒀀𒀀𒀀𒀀𒀀𒀀𒀀𒀀 9 aaaaa                                    |
               10 aaaaa                                    |
               11 aaaaa                                    |
               12 aaaaa                                    |
               13 aaaaa                                    |
               14 aaaaa                                    |
                                                           |
    ]])
    command('set stc=')  -- also for the default fold column
    screen:expect_unchanged()
    -- 'statuscolumn' is not too wide with custom (bogus) fold column
    command([[set stc=%{foldlevel(v:lnum)>0?repeat('-',foldlevel(v:lnum)):''}%=%l\ ]])
    feed('Gd10Ggg<C-l>')
    screen:expect([[
               1 ^aaaaa                                     |
               2 aaaaa                                     |
               3 aaaaa                                     |
               4 aaaaa                                     |
               5 aaaaa                                     |
               6 aaaaa                                     |
               7 aaaaa                                     |
      virt                                                 |
      ---------8 aaaaa                                     |
      virt                                                 |
      ---------9 aaaaa                                     |
      ~                                                    |
      ~                                                    |
                                                           |
    ]])
  end)

  it('works with cmdwin', function()
    feed(':set stc=%l<CR>q:k$')
    screen:expect([[
      7 aaaaa                                              |
      8 aaaaa                                              |
      9 aaaaa                                              |
      10aaaaa                                              |
      [No Name] [+]                                        |
      :1set stc=%^l                                         |
      :2                                                   |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      [Command Line]                                       |
      :                                                    |
    ]])
  end)

  it("has correct width when toggling '(relative)number'", function()
    screen:try_resize(screen._width, 6)
    command('call setline(1, repeat(["aaaaa"], 100))')
    command('set relativenumber')
    command([[set stc=%{!&nu&&!&rnu?'':&rnu?v:relnum?v:relnum:&nu?v:lnum:'0':v:lnum}]])
    screen:expect([[
      1  aaaaa                                             |
      8  ^aaaaa                                             |
      1  aaaaa                                             |
      2  aaaaa                                             |
      3  aaaaa                                             |
                                                           |
    ]])
    -- width correctly estimated with "w_nrwidth_line_count" when setting 'stc'
    command([[set stc=%{!&nu&&!&rnu?'':&rnu?v:relnum?v:relnum:&nu?v:lnum:'0':v:lnum}]])
    screen:expect_unchanged()
    -- zero width when disabling 'number'
    command('set norelativenumber nonumber')
    screen:expect([[
      aaaaa                                                |
      ^aaaaa                                                |
      aaaaa                                                |
      aaaaa                                                |
      aaaaa                                                |
                                                           |
    ]])
    -- width correctly estimated with "w_nrwidth_line_count" when setting 'nu'
    command('set number')
    screen:expect([[
      7  aaaaa                                             |
      8  ^aaaaa                                             |
      9  aaaaa                                             |
      10 aaaaa                                             |
      11 aaaaa                                             |
                                                           |
    ]])
  end)

  it("has correct width with custom sign column when (un)placing signs", function()
    screen:try_resize(screen._width, 6)
    exec_lua([[
      vim.cmd.norm('gg')
      vim.o.signcolumn = 'no'
      vim.fn.sign_define('sign', { text = 'ss' })
      _G.StatusCol = function()
        local s = vim.fn.sign_getplaced(1)[1].signs
        local sign = ''
        if #s > 0 then
          sign = vim.v.lnum == 5 and 'ss' or '  '
        end
        return vim.v.lnum .. '%=' .. sign
      end
      vim.o.statuscolumn = "%!v:lua.StatusCol()"
      vim.fn.sign_place(0, '', 'sign', 1, { lnum = 5 })
    ]])
    screen:expect([[
      1   ^aaaaa                                            |
      2   aaaaa                                            |
      3   aaaaa                                            |
      4   aaaaa                                            |
      5 ssaaaaa                                            |
                                                           |
    ]])
    command('sign unplace 1')
    screen:expect([[
      1 ^aaaaa                                              |
      2 aaaaa                                              |
      3 aaaaa                                              |
      4 aaaaa                                              |
      5 aaaaa                                              |
                                                           |
    ]])
  end)
end)
