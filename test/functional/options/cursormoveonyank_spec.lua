local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local exec = helpers.exec
local feed = helpers.feed
local eval = helpers.eval

describe("The cursor position, when 'cursormvonyank' is false", function()
  before_each(clear)

  it("remains the same after a yank operation", function()
    exec([[
      call setline(1, 'aa bb cc dd ee ff gg hh ii jj kk ll mm.')
      call setline(2, 'aa bb cc dd ee ff gg hh ii jj kk ll mm.')
      call setline(3, 'aa bb cc dd ee ff gg hh ii jj kk ll mm.')
      call setline(4, 'aa bb cc dd ee ff gg hh ii jj kk ll mm.')
      call cursor(3, 14)
      set nocursormvonyank
    ]])
    feed('yip')
    feed('yis')
    feed('yiw')
    feed('yap')
    feed('yas')
    feed('yaw')
    eq({3, 13}, eval('nvim_win_get_cursor(0)'))
  end)

  it("remains the same after a yank in visual mode", function()
    exec([[
      call setline(1, 'aa bb cc dd ee ff gg hh ii jj kk ll mm.')
      call setline(2, 'aa bb cc dd ee ff gg hh ii jj kk ll mm.')
      call setline(3, 'aa bb cc dd ee ff gg hh ii jj kk ll mm.')
      call setline(4, 'aa bb cc dd ee ff gg hh ii jj kk ll mm.')
      call cursor(1, 10)
      set nocursormvonyank
    ]])
    feed('vjjj')
    eq({4, 9}, eval('nvim_win_get_cursor(0)'))
  end)
end)
