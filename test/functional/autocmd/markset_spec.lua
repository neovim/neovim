local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local api = n.api
local clear = n.clear
local command = n.command
local feed = n.feed
local poke_eventloop = n.poke_eventloop
local eval = n.eval

local eq = t.eq

--- Find an event by mark name
--- @param all_events table[] List of mark events
--- @param mark string The mark character to find
--- @return table|nil The event with the specified mark, or nil if not found
local function get_event(all_events, mark)
  return vim.iter(all_events):find(function(event)
    return event.event.mark == mark
  end)
end

describe('MarkSet', function()
  before_each(function()
    clear()
    command("autocmd MarkSet * let g:autocmd ..= 'M'")
    command([[let g:autocmd = '']])
    api.nvim_buf_set_lines(0, 0, -1, true, {
      'foo\0bar',
      'baz text',
    })
  end)

  it('is called after a lowercase mark is set', function()
    feed('ma')
    poke_eventloop()
    feed('j')
    poke_eventloop()
    feed('mb')
    poke_eventloop()

    eq('MM', eval('g:autocmd'))
  end)

  it('is called after an uppercase mark is set', function()
    feed('mA')
    poke_eventloop()
    feed('l')
    poke_eventloop()
    feed('mB')
    poke_eventloop()
    feed('j')
    poke_eventloop()
    feed('mC')
    poke_eventloop()

    eq('MMM', eval('g:autocmd'))
  end)

  it('survives multiple operations: buffer wipeout, window/tab switching', function()
    local orig_bufnr = api.nvim_get_current_buf()

    command('enew')
    local second_bufnr = api.nvim_get_current_buf()
    api.nvim_buf_set_lines(second_bufnr, 0, -1, true, {
      'second buffer line 1',
      'second buffer line 2',
    })

    command('enew')
    local third_bufnr = api.nvim_get_current_buf()
    api.nvim_buf_set_lines(third_bufnr, 0, -1, true, {
      'third buffer line 1',
      'third buffer line 2',
    })

    -- Split windows
    command('split')
    command('vsplit')

    -- Create new tabpage
    command('tabnew')
    command('split')

    -- Enhanced autocmd to capture more data
    command([[
      let g:markset_events = []
      autocmd MarkSet * call add(g:markset_events, {'bufnr': bufnr('%'), 'event': deepcopy(v:event)})
    ]])

    -- Go back to original buffer and set a mark
    command('buffer ' .. orig_bufnr)
    feed('gg')
    poke_eventloop()
    feed('mA')
    poke_eventloop()

    -- OPERATION 1: Switch to different window
    command('wincmd w')
    poke_eventloop()

    -- OPERATION 2: Switch to different tabpage
    command('tabnext')
    poke_eventloop()

    -- OPERATION 3: Set mark in current buffer
    feed('mB')
    poke_eventloop()

    -- OPERATION 4: Wipeout the original buffer (this is the nuclear option!)
    command('bwipeout! ' .. orig_bufnr)
    poke_eventloop()

    -- OPERATION 5: Switch windows while buffer is gone
    command('wincmd w')
    poke_eventloop()

    -- OPERATION 6: Create yet another buffer and set mark
    command('enew')
    local final_bufnr = api.nvim_get_current_buf()
    api.nvim_buf_set_lines(final_bufnr, 0, -1, true, {
      'final buffer after chaos',
      'line 2 of final buffer',
    })
    feed('j')
    poke_eventloop()
    feed('mC')
    poke_eventloop()

    -- OPERATION 7: Close current tabpage
    command('tabclose')
    poke_eventloop()

    -- OPERATION 8: Set one more mark after tabpage closure
    feed('mD')
    poke_eventloop()
    local mark_d_bufnr = api.nvim_get_current_buf()

    local all_events = eval('g:markset_events')

    eq(4, #all_events, 'Should have at 4 MarkSet events')

    local mark_a = get_event(all_events, 'A')
    eq(orig_bufnr, mark_a.bufnr)
    eq('A', mark_a.event.mark)
    eq(1, mark_a.event.line)
    eq(0, mark_a.event.col)

    local mark_b = get_event(all_events, 'B')
    eq(third_bufnr, mark_b.bufnr)
    eq('B', mark_b.event.mark)
    eq(1, mark_b.event.line)
    eq(0, mark_b.event.col)

    local mark_c = get_event(all_events, 'C')
    eq(final_bufnr, mark_c.bufnr)
    eq('C', mark_c.event.mark)
    eq(2, mark_c.event.line)
    eq(0, mark_c.event.col)

    local mark_d = get_event(all_events, 'D')
    eq(mark_d_bufnr, mark_d.bufnr)
    eq('D', mark_d.event.mark)
    eq(1, mark_d.event.line)
    eq(0, mark_d.event.col)
  end)
end)
