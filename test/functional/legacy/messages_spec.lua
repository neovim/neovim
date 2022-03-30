local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local exec = helpers.exec
local feed = helpers.feed

before_each(clear)

describe('messages', function()
  it('more prompt with control characters can be quit vim-patch:8.2.1844', function()
    local screen = Screen.new(40, 6)
    screen:set_default_attr_ids({
      [1] = {foreground = Screen.colors.Blue},  -- SpecialKey
      [2] = {bold = true, foreground = Screen.colors.SeaGreen},  -- MoreMsg
      [3] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
    })
    screen:attach()
    command('set more')
    feed([[:echom range(9999)->join("\x01")<CR>]])
    screen:expect([[
      0{1:^A}1{1:^A}2{1:^A}3{1:^A}4{1:^A}5{1:^A}6{1:^A}7{1:^A}8{1:^A}9{1:^A}10{1:^A}11{1:^A}12|
      {1:^A}13{1:^A}14{1:^A}15{1:^A}16{1:^A}17{1:^A}18{1:^A}19{1:^A}20{1:^A}21{1:^A}22|
      {1:^A}23{1:^A}24{1:^A}25{1:^A}26{1:^A}27{1:^A}28{1:^A}29{1:^A}30{1:^A}31{1:^A}32|
      {1:^A}33{1:^A}34{1:^A}35{1:^A}36{1:^A}37{1:^A}38{1:^A}39{1:^A}40{1:^A}41{1:^A}42|
      {1:^A}43{1:^A}44{1:^A}45{1:^A}46{1:^A}47{1:^A}48{1:^A}49{1:^A}50{1:^A}51{1:^A}52|
      {2:-- More --}^                              |
    ]])
    feed('q')
    screen:expect([[
      ^                                        |
      {3:~                                       }|
      {3:~                                       }|
      {3:~                                       }|
      {3:~                                       }|
                                              |
    ]])
  end)

  it('fileinfo does not overwrite echo message vim-patch:8.2.4156', function()
    local screen = Screen.new(40, 6)
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
    })
    screen:attach()
    exec([[
      set shortmess-=F

      file a.txt

      hide edit b.txt
      call setline(1, "hi")
      setlocal modified

      hide buffer a.txt

      autocmd CursorHold * buf b.txt | w | echo "'b' written"
    ]])
    command('set updatetime=50')
    feed('0$')
    screen:expect([[
      ^hi                                      |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      'b' written                             |
    ]])
    os.remove('b.txt')
  end)
end)
