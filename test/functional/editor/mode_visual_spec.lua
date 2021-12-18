-- Visual-mode tests.

local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local expect = helpers.expect
local feed = helpers.feed
local meths = helpers.meths

describe('visual-mode', function()
  before_each(clear)

  it("select-mode Ctrl-O doesn't cancel Ctrl-O mode when processing event #15688", function()
    feed('iHello World<esc>gh<c-o>')
    eq({mode='vs', blocking=false}, meths.get_mode()) -- fast event
    eq({mode='vs', blocking=false}, meths.get_mode()) -- again #15288
    eq(2, eval('1+1'))  -- causes K_EVENT key
    eq({mode='vs', blocking=false}, meths.get_mode()) -- still in ctrl-o mode
    feed('^')
    eq({mode='s', blocking=false}, meths.get_mode()) -- left ctrl-o mode
    feed('h')
    eq({mode='i', blocking=false}, meths.get_mode()) -- entered insert mode
    expect('h') -- selection is the whole line and is replaced
  end)
end)

