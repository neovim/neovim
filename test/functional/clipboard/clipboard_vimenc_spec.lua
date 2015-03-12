-- NB: this file could be merged with provider_spec.lua
-- separate right now for quick testing

local helpers = require('test.functional.helpers')
local clear, feed, insert, spawn = helpers.clear, helpers.feed, helpers.insert, helpers.spawn
local execute, expect, eq, eval = helpers.execute, helpers.expect, helpers.eq, helpers.eval
local nvim, run, stop, restart = helpers.nvim, helpers.run, helpers.stop, helpers.restart
local neq = helpers.neq

-- this will unavoidingly clobber local clipboard
-- could spwan a Xvfb when running locally
describe('clipboard between instances', function()
  local nvim2
  -- XXX: this could be broken out to helpers if generally useful
  local function nvim2_req(method, ...)
    local status, rv = nvim2:request(method, ...)
    if not status then
      error(rv[2])
    end
    return rv
  end

  before_each(function()
    clear()
    nvim2 = spawn()

    -- sanity check: these truly are distinct instances
    neq(eval('getpid()'), nvim2_req('vim_eval', 'getpid()'))
  end)

  after_each(function()
    nvim2:exit(0)
  end)

  it("works", function()
    insert([[
      some lines from
      first instance]])
    feed('gg"*2yywwv+e"+y')
    -- nvim sees correct data
    eq({{'some lines from', 'first instance'}, 'V'}, nvim2_req('vim_eval','[getreg("*", 0, 1), getregtype("*")]'))
    eq({{'from', 'first'}, 'v'}, nvim2_req('vim_eval','[getreg("+", 0, 1), getregtype("+")]'))

    -- non vimenc-aware apps sees NL-encoded line/char motions
    eq({'some lines from', 'first instance', ''}, eval('systemlist("xsel -o -p",[],1)'))
    eq({'from', 'first'}, eval('systemlist("xsel -o -b",[],1)'))
  end)

  it("supports vimenc motions", function()
    insert([[
      this is charwise data
      block
      selection
      ]])
    feed('ggv$"*y+<c-v>+$"+y')

    eq({{'this is charwise data', ''}, 'v'}, nvim2_req('vim_eval','[getreg("*", 0, 1), getregtype("*")]'))
    eq({{'block', 'selection'}, '\x169'}, nvim2_req('vim_eval','[getreg("+", 0, 1), getregtype("+")]'))

    -- in pure text clipboard these are ambiguous with a line-wise selection
    eq({'this is charwise data', ''}, eval('systemlist("xsel -o -p",[],1)'))
    eq({'block', 'selection', ''}, eval('systemlist("xsel -o -b",[],1)'))
  end)

  it("supports NUL in clipboard data", function()
    insert(" some very\022000NUL-ly data\022000\nin this sel\022000ection")
    feed('gg"*2yyw"+yW')
    eq({{' some very\nNUL-ly data\n', 'in this sel\nection'}, 'V'}, nvim2_req('vim_eval','[getreg("*", 0, 1), getregtype("*")]'))
    eq({{'very\nNUL-ly '}, 'v'}, nvim2_req('vim_eval','[getreg("+", 0, 1), getregtype("+")]'))

    -- IMHO NUL handling is simply not well-defined in the TEXT/UTF8 selection formats
    -- for instance xsel and xcopy handles this differently
  end)

  it("pastes correctly from text-format clipboard", function()
      eval('systemlist("xsel -i -b", ["line-wise-ish", "data", ""])')
      eval('systemlist("xsel -i -p", ["char-wise-ish", "data"])')
      insert('text')
      feed('"+P"*P')
      expect([[
        char-wise-ish
        dataline-wise-ish
        data
        text]])

    eq({{'char-wise-ish', 'data'}, 'v'}, nvim2_req('vim_eval','[getreg("*", 0, 1), getregtype("*")]'))
    eq({{'line-wise-ish', 'data'}, 'V'}, nvim2_req('vim_eval','[getreg("+", 0, 1), getregtype("+")]'))
  end)

end)
