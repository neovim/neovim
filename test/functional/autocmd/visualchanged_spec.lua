local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local eq = t.eq
local clear = n.clear
local source = n.source
local feed = n.feed
local insert = n.insert
local eval = n.eval

--local command = helpers.command

describe('VisualChanged', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(10, 4)
    screen:attach()
    insert[[
      Hello
      Hello
      Hello]]

    feed("gg0")

    source[[
      let g:visual_count = 0
      au VisualChanged * let g:event = copy(v:event)
      au VisualChanged * let g:visual_count += 1
    ]]
  end)

  local function event()
    return eval("g:event")
  end
  local function count()
    return eval("g:visual_count")
  end
  local function ui_count()
    return screen.visual_change.count
  end

  it("fires when visual mode changes or starts", function ()
    feed "v"
    eq(1, count())
    screen:expect(function()
      eq(1, ui_count())
      eq("char", screen.visual_change.mode)
    end)

    feed "iw"
    eq(2, count())
    screen:expect(function()
      eq(2, ui_count())
    end)

    feed "V"
    eq(3, count())
    screen:expect(function()
      eq(3, ui_count())
      eq("line", screen.visual_change.mode)
    end)

    feed "<c-v>"
    eq(4, count())
    screen:expect(function()
      eq(4, ui_count())
      eq("block", screen.visual_change.mode)
    end)

    feed "v"
    eq(5, count())
    screen:expect(function()
      eq(5, ui_count())
    end)

    feed "<esc>v"
    eq(6, count())
    screen:expect(function()
      eq(6, ui_count())
    end)

    feed "<esc>V"
    eq(7, count())
    screen:expect(function()
      eq(7, ui_count())
    end)

    feed "<esc><c-v>"
    eq(8, count())
    screen:expect(function()
      eq(8, ui_count())
    end)
  end)

  it("fires when visual area changes", function()
    feed "v"
    eq(1, count())
    local byte_range = {
      start_row = 1,
      start_col = 1,
      end_row = 1,
      end_col = 1,
    }
    eq(byte_range, event())
    screen:expect(function()
      eq(byte_range, screen.visual_change.byte)
    end)

    feed "iw"
    eq(2, count())
    byte_range = {
      start_row = 1,
      start_col = 1,
      end_row = 1,
      end_col = 5,
    }
    eq(byte_range, event())
    screen:expect(function()
      eq(byte_range, screen.visual_change.byte)
    end)

    feed "Vj0"
    eq(4, count())
    byte_range = {
      start_row = 1,
      start_col = 1,
      end_row = 2,
      end_col = 5
    }
    eq(byte_range, event())
    screen:expect(function()
      eq(5, ui_count())
      eq(byte_range, screen.visual_change.byte)
    end)

    feed "<esc>Vjl"
    eq(6, count())
    byte_range = {
      start_row = 2,
      start_col = 1,
      end_row = 3,
      end_col = 5 --eval("v:maxcol"),
    }
    eq(byte_range, event())
    screen:expect(function()
      eq(8, ui_count())
      eq(byte_range, screen.visual_change.byte)
    end)

    feed "<esc>gg<c-v>ejh"
    eq(10, count())
    byte_range = {
      start_row = 1,
      start_col = 1,
      end_row = 2,
      end_col = 4,
    }
    eq(byte_range, event())
    screen:expect(function()
      eq(byte_range, screen.visual_change.byte)
    end)
  end)

  it("autocmd doesn't fire when cursor moves without changing visual area", function()
    -- charwise
    feed "viw"
    eq(2, count())
    feed "oOoO"
    eq(2, count())

    -- linewise
    screen.visual_change.count = 0
    feed "<esc>0V"
    eq(3, count())
    feed "$h0l$h"
    eq(3, count())

    feed "j"
    eq(4, count())
    feed "oOoOo"
    eq(4, count())

    -- blockwise
    feed "<esc>gg<c-v>$j"
    eq(7, count())
    feed "oOoOo"
    eq(7, count())
  end)

  it("ui event fires when cursor moves or visual area changes", function()
    -- charwise
    feed "viw"
    screen:expect(function() eq(2, ui_count()) end)
    feed "oOoO"
    screen:expect(function() eq(6, ui_count()) end)

    -- linewise
    screen.visual_change.count = 0
    feed "<esc>0V"
    screen:expect(function() eq(1, ui_count()) end)
    feed "$h0l$h"
    screen:expect(function() eq(7, ui_count()) end)

    screen.visual_change.count = 0
    feed "j"
    screen:expect(function() eq(1, ui_count()) end)
    feed "oOoOo"
    screen:expect(function() eq(6, ui_count()) end)

    -- blockwise
    screen.visual_change.count = 0
    feed "<esc>gg<c-v>$j"
    screen:expect(function() eq(3, ui_count()) end)
    feed "oOoOo"
    screen:expect(function() eq(8, ui_count()) end)
  end)

  it("works with gv", function()
    feed "vjl"
    eq(3, count())
    local old_event = event()

    feed "<esc>Ggv"
    eq(4, count())
    eq(old_event, event())
  end)

  -- it("works with empty buffer", function()
  --   command "new"
  --   feed "vjjkkhhll"
  --   eq(1, count())
  -- end)

end)
