local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local exec = helpers.exec

before_each(clear)

describe('normal', function()
  -- oldtest: Test_normal_j_below_botline()
  it([["j" does not skip lines when scrolling below botline and 'foldmethod' is not "manual"]], function()
    local screen = Screen.new(40, 19)
    screen:attach()
    screen:set_default_attr_ids({{foreground = Screen.colors.Brown}})
    exec([[
      set number foldmethod=diff scrolloff=0
      call setline(1, map(range(1, 9), 'repeat(v:val, 200)'))
      norm Lj
    ]])
    screen:expect([[
      {1:  2 }222222222222222222222222222222222222|
      {1:    }222222222222222222222222222222222222|*4
      {1:    }22222222222222222222                |
      {1:  3 }333333333333333333333333333333333333|
      {1:    }333333333333333333333333333333333333|*4
      {1:    }33333333333333333333                |
      {1:  4 }^444444444444444444444444444444444444|
      {1:    }444444444444444444444444444444444444|*4
      {1:    }44444444444444444444                |
                                              |
    ]])
  end)
end)
