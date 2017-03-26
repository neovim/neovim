local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local feed = helpers.feed
local clear = helpers.clear
local meths = helpers.meths
local source = helpers.source

local screen

before_each(function()
  clear()
  screen = Screen.new(40, 2)
  screen:attach()
  source([[
    highlight RBP1 guifg=Red
    highlight RBP2 guifg=Yellow
    highlight RBP3 guifg=Green
    highlight RBP4 guifg=Blue
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
    RBP1={foreground = Screen.colors.Red},
    RBP2={foreground = Screen.colors.Yellow},
    RBP3={foreground = Screen.colors.Green},
    RBP4={foreground = Screen.colors.Blue},
  })
end)

describe('Command-line coloring', function()
  it('works', function()
    meths.set_var('Nvim_color_cmdline', 'RainBowParens')
    meths.set_option('more', false)
    feed(':')
    screen:expect([[
                                              |
      :^                                       |
    ]])
    feed('e')
    screen:expect([[
                                              |
      :e^                                      |
    ]])
    feed('cho ')
    screen:expect([[
                                              |
      :echo ^                                  |
    ]])
    feed('(')
    screen:expect([[
                                              |
      :echo {RBP1:(}^                                 |
    ]])
    feed('(')
    screen:expect([[
                                              |
      :echo {RBP1:(}{RBP2:(}^                                |
    ]])
    feed('42')
    screen:expect([[
                                              |
      :echo {RBP1:(}{RBP2:(}42^                              |
    ]])
    feed('))')
    screen:expect([[
                                              |
      :echo {RBP1:(}{RBP2:(}42{RBP2:)}{RBP1:)}^                            |
    ]])
    feed('<BS>')
    screen:expect([[
                                              |
      :echo {RBP1:(}{RBP2:(}42{RBP2:)}^                             |
    ]])
    feed('{REDRAW}')
    screen:expect([[
                                              |
      :echo {RBP1:(}{RBP2:(}42{RBP2:)}^                             |
    ]])
  end)
end)
