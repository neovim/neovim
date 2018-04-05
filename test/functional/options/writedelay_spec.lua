local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq, feed = helpers.eq, helpers.feed
local eval = helpers.eval
local curbuf, curwin = helpers.curbuf, helpers.curwin
local getcwd = helpers.funcs.getcwd

describe("writedelay option changes", function()
  it('wd sets to 0 on <C-C><C-C>', function()
    feed(':set writedelay=10<CR>')
    feed('<c-c>')
    eq(0, curbuf('get_option','writedelay'))
  end)
end)
