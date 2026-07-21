-- Real-terminal regression coverage for conceal-aware 'wrap' (#14409).
--
-- The embedded Screen harness (ext_linegrid RPC) always renders the logically correct grid and
-- can't see bugs in the TUI's real-terminal redraw/scroll-optimisation layer, so this exercises the
-- feature through a real child Nvim TUI over a pty, like tui_spec.lua.
local n = require('test.functional.testnvim')()
local t = require('test.testutil')
local tt = require('test.functional.testterm')

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear
local feed_data = tt.feed_data

--- Starts a child TUI with 'wrap' and 'conceallevel=2' set, plus the options in "opts".
local function start_conceal(opts, cols, extra_rows)
  return tt.setup_child_nvim({ '--clean', '--cmd', 'set wrap conceallevel=2 ' .. opts }, {
    cols = cols,
    extra_rows = extra_rows or 10,
  })
end

describe('conceal-aware wrapping (#14409): real terminal', function()
  before_each(clear)

  it('reveal/conceal height-change thrash while scrolled leaves no stale cells', function()
    -- Odd lines reflow between 1 and 2 rows as their 'concealcursor' reveal state toggles
    -- (concealcursor= reveals every line while the cursor is on it); even lines are plain. Walking
    -- the cursor down through a scrolled region must not leave stale/duplicated content from the
    -- TUI's grid_scroll optimisation (this is what extconceal_line_changes_height() forces a full
    -- redraw for).
    local screen = start_conceal('concealcursor= scrolloff=0', 30)

    feed_data(
      ':lua local l={} for i=1,40 do if i%2==1 then '
        .. "l[i]='L'..i..' '..('A'):rep(10)..'HIDDEN'..('B'):rep(20) else "
        .. "l[i]='L'..i..' plain line' end end "
        .. 'vim.api.nvim_buf_set_lines(0,0,-1,true,l) '
        .. "local ns=vim.api.nvim_create_namespace('qa') "
        .. 'for i=0,39,2 do '
        .. "local c=('L'..(i+1)..' '..('A'):rep(10)):len() "
        .. "vim.api.nvim_buf_set_extmark(0,ns,i,c,{end_col=c+6,conceal=''}) end\r"
    )
    screen:expect({ any = 'L1 ' })

    feed_data(':20\r')
    for _ = 1, 10 do
      feed_data('j')
    end
    for _ = 1, 10 do
      feed_data('k')
    end
    -- Net zero vertical movement (10 down, 10 up from line 20) lands back on line 20.
    screen:expect({ any = 'L20 plain line' })
    screen:expect({ any = 'AAAAAAAAAABBBBBBBBBBBBBBBB' })
    screen:expect({ any = 'BBBB' })
    screen:expect({ none = 'AAAAAAAAAAAAA' }) -- no doubled-up 'A' run from a stale cell
  end)

  it('resizing narrower/wider around a reflowed concealed line stays correct', function()
    local screen = start_conceal('concealcursor=nvic', 40)

    feed_data(
      ":lua vim.api.nvim_buf_set_lines(0,0,-1,true,{('a'):rep(10)..'HIDDEN'..('b'):rep(60)}) "
        .. "vim.api.nvim_buf_set_extmark(0,vim.api.nvim_create_namespace('qa'),0,10,{end_col=16,conceal=''})\r"
    )
    screen:expect({ any = 'a' })

    screen:try_resize(20, 17)
    screen:expect({ any = 'aaaaaaaaaabbbbbbbbbb' })
    screen:expect({ none = 'HIDDEN' })

    screen:try_resize(60, 17)
    screen:expect({ any = 'aaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' })
    screen:expect({ none = 'HIDDEN' })

    screen:try_resize(15, 17)
    screen:expect({ any = 'aaaaaaaaaabbbbb' })
    screen:expect({ none = 'HIDDEN' })
  end)

  it('independent windows on the same buffer do not bleed conceal/cursor state', function()
    local screen = start_conceal('concealcursor=n', 30, 16)

    feed_data(
      ":lua local l={} for i=1,20 do l[i]=('a'):rep(10)..'HIDDEN'..('b'):rep(20) end "
        .. 'vim.api.nvim_buf_set_lines(0,0,-1,true,l) '
        .. "local ns=vim.api.nvim_create_namespace('qa') "
        .. "for i=0,19 do vim.api.nvim_buf_set_extmark(0,ns,i,10,{end_col=16,conceal=''}) end\r"
    )
    screen:expect({ any = 'a' })

    feed_data(':10\r')
    feed_data(':split\r')
    feed_data(':1\r')
    screen:expect({ any = 'aaaaaaaaaabbbbbbbbbbbbbbbbbbbb' }) -- top window, line 1, revealed

    -- Thrash the focused (top) window; the unfocused (bottom) window's own remembered cursor line
    -- (10) must stay exactly as-is throughout, with no cross-window corruption.
    for _ = 1, 15 do
      feed_data('j')
    end
    for _ = 1, 15 do
      feed_data('k')
    end
    screen:expect({ any = '1,1' })
    screen:expect({ any = '10,1' })
    screen:expect({ none = 'HIDDEN' }) -- neither window's visible lines are stuck revealing it
  end)
end)
