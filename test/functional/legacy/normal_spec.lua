local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local exec = helpers.exec

before_each(clear)

describe('normal', function()
  -- oldtest: Test_normal_j_below_botline()
  it(
    [["j" does not skip lines when scrolling below botline and 'foldmethod' is not "manual"]],
    function()
      local screen = Screen.new(40, 19)
      screen:attach()
      exec([[
      set number foldmethod=diff scrolloff=0
      call setline(1, map(range(1, 9), 'repeat(v:val, 200)'))
      norm Lj
    ]])
      screen:expect([[
      {8:  2 }222222222222222222222222222222222222|
      {8:    }222222222222222222222222222222222222|*4
      {8:    }22222222222222222222                |
      {8:  3 }333333333333333333333333333333333333|
      {8:    }333333333333333333333333333333333333|*4
      {8:    }33333333333333333333                |
      {8:  4 }^444444444444444444444444444444444444|
      {8:    }444444444444444444444444444444444444|*4
      {8:    }44444444444444444444                |
                                              |
    ]])
    end
  )
end)
