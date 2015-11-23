local helpers = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')

local clear, eval, execute, feed, nvim, nvim_dir = helpers.clear, helpers.eval,
helpers.execute, helpers.feed, helpers.nvim, helpers.nvim_dir
local wait = helpers.wait

describe('d on attached screen', function()
  before_each(function()
    clear()
    screen = Screen.new(20, 4)
    screen:attach(false)
  end)

  it('works as expected', function()

    helpers.source([[
        set listchars=eol:$
        set list
    ]])
    feed('ia<cr>b<cr>c<cr><Esc>kkk')
    feed('d')
    wait()
    wait()
    wait()
    screen:expect([[
     ^a$                  |
     b$                  |
     c$                  |
                         |
    ]])
  end)
end)
