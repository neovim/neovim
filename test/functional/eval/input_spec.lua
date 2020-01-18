local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local eq = helpers.eq
local feed = helpers.feed
local meths = helpers.meths
local clear = helpers.clear
local source = helpers.source
local command = helpers.command
local exc_exec = helpers.exc_exec
local nvim_async = helpers.nvim_async

local screen

before_each(function()
  clear()
  screen = Screen.new(25, 5)
  screen:attach()
  source([[
    hi Test ctermfg=Red guifg=Red term=bold
    function CustomCompl(...)
      return 'TEST'
    endfunction
    function CustomListCompl(...)
      return ['FOO']
    endfunction

    highlight RBP1 guibg=Red
    highlight RBP2 guibg=Yellow
    highlight RBP3 guibg=Green
    highlight RBP4 guibg=Blue
    let g:NUM_LVLS = 4
    function Redraw()
      redraw!
      return ''
    endfunction
    cnoremap <expr> {REDRAW} Redraw()
    function RainBowParens(cmdline)
      let ret = []
      let i = 0
      let lvl = 0
      while i < len(a:cmdline)
        if a:cmdline[i] is# '('
          call add(ret, [i, i + 1, 'RBP' . ((lvl % g:NUM_LVLS) + 1)])
          let lvl += 1
        elseif a:cmdline[i] is# ')'
          let lvl -= 1
          call add(ret, [i, i + 1, 'RBP' . ((lvl % g:NUM_LVLS) + 1)])
        endif
        let i += 1
      endwhile
      return ret
    endfunction
  ]])
  screen:set_default_attr_ids({
    EOB={bold = true, foreground = Screen.colors.Blue1},
    T={foreground=Screen.colors.Red},
    RBP1={background=Screen.colors.Red},
    RBP2={background=Screen.colors.Yellow},
    RBP3={background=Screen.colors.Green},
    RBP4={background=Screen.colors.Blue},
    SEP={bold = true, reverse = true},
    CONFIRM={bold = true, foreground = Screen.colors.SeaGreen4},
  })
end)

describe('input()', function()
  it('works with multiline prompts', function()
    feed([[:call input("Test\nFoo")<CR>]])
    screen:expect([[
                               |
      {EOB:~                        }|
      {SEP:                         }|
      Test                     |
      Foo^                      |
    ]])
  end)
  it('works with multiline prompts and :echohl', function()
    feed([[:echohl Test | call input("Test\nFoo")<CR>]])
    screen:expect([[
                               |
      {EOB:~                        }|
      {SEP:                         }|
      {T:Test}                     |
      {T:Foo}^                      |
    ]])
    command('redraw!')
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:Foo}^                      |
    ]])
  end)
  it('allows unequal numeric arguments when using multiple args', function()
    command('echohl Test')
    feed([[:call input(1, 2)<CR>]])
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:1}2^                       |
    ]])
    feed('<BS>')
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:1}^                        |
    ]])
  end)
  it('allows unequal numeric values when using {opts} dictionary', function()
    command('echohl Test')
    meths.set_var('opts', {prompt=1, default=2, cancelreturn=3})
    feed([[:echo input(opts)<CR>]])
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:1}2^                       |
    ]])
    feed('<BS>')
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:1}^                        |
    ]])
    feed('<Esc>')
    screen:expect([[
      ^                         |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:3}                        |
    ]])
  end)
  it('works with redraw', function()
    command('echohl Test')
    meths.set_var('opts', {prompt='Foo>', default='Bar'})
    feed([[:echo inputdialog(opts)<CR>]])
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:Foo>}Bar^                  |
    ]])
    command('mode')
    screen:expect{grid=[[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:Foo>}Bar^                  |
    ]], reset=true}
    feed('<BS>')
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:Foo>}Ba^                   |
    ]])
    command('mode')
    screen:expect{grid=[[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:Foo>}Ba^                   |
    ]], reset=true}
  end)
  it('allows omitting everything with dictionary argument', function()
    command('echohl Test')
    feed([[:call input({})<CR>]])
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      ^                         |
    ]])
  end)
  it('supports completion', function()
    feed(':let var = input("", "", "custom,CustomCompl")<CR>')
    feed('<Tab><CR>')
    eq('TEST', meths.get_var('var'))

    feed(':let var = input({"completion": "customlist,CustomListCompl"})<CR>')
    feed('<Tab><CR>')
    eq('FOO', meths.get_var('var'))
  end)
  it('supports cancelreturn', function()
    feed(':let var = input({"cancelreturn": "BAR"})<CR>')
    feed('<Esc>')
    eq('BAR', meths.get_var('var'))
  end)
  it('supports default string', function()
    feed(':let var = input("", "DEF1")<CR>')
    feed('<CR>')
    eq('DEF1', meths.get_var('var'))

    feed(':let var = input({"default": "DEF2"})<CR>')
    feed('<CR>')
    eq('DEF2', meths.get_var('var'))
  end)
  it('errors out on invalid inputs', function()
    eq('Vim(call):E730: using List as a String',
       exc_exec('call input([])'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call input("", [])'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call input("", "", [])'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call input({"prompt": []})'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call input({"cancelreturn": []})'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call input({"default": []})'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call input({"completion": []})'))
    eq('Vim(call):E5050: {opts} must be the only argument',
       exc_exec('call input({}, "default")'))
    eq('Vim(call):E118: Too many arguments for function: input',
       exc_exec('call input("prompt> ", "default", "file", "extra")'))
  end)
  it('supports highlighting', function()
    command('nnoremap <expr> X input({"highlight": "RainBowParens"})[-1]')
    feed([[X]])
    feed('(())')
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {RBP1:(}{RBP2:()}{RBP1:)}^                     |
    ]])
  end)
  it('is not hidden by :silent', function()
    feed([[:silent call input('Foo: ')<CR>]])
    screen:expect([[
                               |
      {EOB:~                        }|
      {SEP:                         }|
      Foo: ^                    |
                               |
    ]])
    feed('Bar')
    screen:expect([[
                               |
      {EOB:~                        }|
      {SEP:                         }|
      Foo: Bar^                 |
                               |
    ]])
    feed('<CR>')
  end)
end)
describe('inputdialog()', function()
  it('works with multiline prompts', function()
    feed([[:call inputdialog("Test\nFoo")<CR>]])
    screen:expect([[
                               |
      {EOB:~                        }|
      {SEP:                         }|
      Test                     |
      Foo^                      |
    ]])
  end)
  it('works with multiline prompts and :echohl', function()
    feed([[:echohl Test | call inputdialog("Test\nFoo")<CR>]])
    screen:expect([[
                               |
      {EOB:~                        }|
      {SEP:                         }|
      {T:Test}                     |
      {T:Foo}^                      |
    ]])
    command('redraw!')
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:Foo}^                      |
    ]])
  end)
  it('allows unequal numeric arguments when using multiple args', function()
    command('echohl Test')
    feed([[:call inputdialog(1, 2)<CR>]])
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:1}2^                       |
    ]])
    feed('<BS>')
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:1}^                        |
    ]])
  end)
  it('allows unequal numeric values when using {opts} dictionary', function()
    command('echohl Test')
    meths.set_var('opts', {prompt=1, default=2, cancelreturn=3})
    feed([[:echo input(opts)<CR>]])
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:1}2^                       |
    ]])
    feed('<BS>')
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:1}^                        |
    ]])
    feed('<Esc>')
    screen:expect([[
      ^                         |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:3}                        |
    ]])
  end)
  it('works with redraw', function()
    command('echohl Test')
    meths.set_var('opts', {prompt='Foo>', default='Bar'})
    feed([[:echo input(opts)<CR>]])
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:Foo>}Bar^                  |
    ]])
    command('mode')
    screen:expect{grid=[[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:Foo>}Bar^                  |
    ]], reset=true}
    feed('<BS>')
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:Foo>}Ba^                   |
    ]])
    command('mode')
    screen:expect{grid=[[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:Foo>}Ba^                   |
    ]], reset=true}
  end)
  it('allows omitting everything with dictionary argument', function()
    command('echohl Test')
    feed(':echo inputdialog({})<CR>')
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      ^                         |
    ]])
  end)
  it('supports completion', function()
    feed(':let var = inputdialog({"completion": "customlist,CustomListCompl"})<CR>')
    feed('<Tab><CR>')
    eq('FOO', meths.get_var('var'))
  end)
  it('supports cancelreturn', function()
    feed(':let var = inputdialog("", "", "CR1")<CR>')
    feed('<Esc>')
    eq('CR1', meths.get_var('var'))

    feed(':let var = inputdialog({"cancelreturn": "BAR"})<CR>')
    feed('<Esc>')
    eq('BAR', meths.get_var('var'))
  end)
  it('supports default string', function()
    feed(':let var = inputdialog("", "DEF1")<CR>')
    feed('<CR>')
    eq('DEF1', meths.get_var('var'))

    feed(':let var = inputdialog({"default": "DEF2"})<CR>')
    feed('<CR>')
    eq('DEF2', meths.get_var('var'))
  end)
  it('errors out on invalid inputs', function()
    eq('Vim(call):E730: using List as a String',
       exc_exec('call inputdialog([])'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call inputdialog("", [])'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call inputdialog("", "", [])'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call inputdialog({"prompt": []})'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call inputdialog({"cancelreturn": []})'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call inputdialog({"default": []})'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call inputdialog({"completion": []})'))
    eq('Vim(call):E5050: {opts} must be the only argument',
       exc_exec('call inputdialog({}, "default")'))
    eq('Vim(call):E118: Too many arguments for function: inputdialog',
       exc_exec('call inputdialog("prompt> ", "default", "file", "extra")'))
  end)
  it('supports highlighting', function()
    command('nnoremap <expr> X inputdialog({"highlight": "RainBowParens"})[-1]')
    feed([[X]])
    feed('(())')
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {RBP1:(}{RBP2:()}{RBP1:)}^                     |
    ]])
  end)
end)

describe('confirm()', function()
  it("shows dialog even if :silent #8788", function()
    command("autocmd BufNewFile * call confirm('test')")

    local function check_and_clear(edit_line)
      screen:expect([[
                                 |
        {SEP:                         }|
        ]]..edit_line..[[
        {CONFIRM:test}                     |
        {CONFIRM:[O]k: }^                   |
      ]])
      feed('<cr>')
      command('redraw')
      command('bdelete!')
    end

    -- With shortmess-=F
    command('set shortmess-=F')
    feed(':edit foo<cr>')
    check_and_clear('"foo" [New File]         |\n')

    -- With shortmess+=F
    command('set shortmess+=F')
    feed(':edit foo<cr>')
    check_and_clear(':edit foo                |\n')

    -- With :silent
    feed(':silent edit foo<cr>')
    check_and_clear(':silent edit foo         |\n')

    -- With API (via eval/VimL) call and shortmess+=F
    feed(':call nvim_command("edit x")<cr>')
    check_and_clear(':call nvim_command("edit |\n')

    nvim_async('command', 'edit x')
    check_and_clear('                         |\n')
  end)
end)
