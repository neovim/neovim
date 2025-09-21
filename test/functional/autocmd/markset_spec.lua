local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local api = n.api
local clear = n.clear
local command = n.command
local feed = n.feed
local poke_eventloop = n.poke_eventloop
local eval = n.eval

local eq = t.eq
local neq = t.neq

--- Find an event by mark name
--- @param all_events table[] List of mark events
--- @param mark string The mark character to find
--- @return table|nil The event with the specified mark, or nil if not found
local function get_event(all_events, mark)
  return vim.iter(all_events):find(function(event)
    return event.event.name == mark
  end)
end

describe('MarkSet', function()
  before_each(function()
    clear()
  end)

  it('is called after a lowercase mark is set', function()
    command("autocmd MarkSet * let g:autocmd ..= 'M'")
    command([[let g:autocmd = '']])
    api.nvim_buf_set_lines(0, 0, -1, true, {
      'foo\0bar',
      'baz text',
    })

    feed('ma')
    feed('j')
    feed('mb')

    poke_eventloop()

    eq('MM', eval('g:autocmd'))
  end)

  it('is called after an uppercase mark is set', function()
    command("autocmd MarkSet * let g:autocmd ..= 'M'")
    command([[let g:autocmd = '']])
    api.nvim_buf_set_lines(0, 0, -1, true, {
      'foo\0bar',
      'baz text',
    })

    feed('mA')
    feed('l')
    feed('mB')
    feed('j')
    feed('mC')

    poke_eventloop()

    eq('MMM', eval('g:autocmd'))
  end)

  it('can only be called for a specific pattern (mark)', function()
    command("autocmd MarkSet a let g:autocmd ..= 'M'")
    command([[let g:autocmd = '']])
    api.nvim_buf_set_lines(0, 0, -1, true, {
      'foo\0bar',
      'baz text',
    })

    feed('ma')
    feed('l')
    feed('mb')
    feed('j')
    feed('ma')

    poke_eventloop()

    eq('MM', eval('g:autocmd'))
  end)

  it('supports glob patterns like [ab]', function()
    command("autocmd MarkSet [ab] let g:autocmd ..= 'M'")
    command([[let g:autocmd = '']])
    api.nvim_buf_set_lines(0, 0, -1, true, {
      'line 1',
      'line 2',
      'line 3',
    })

    feed('ma')
    feed('j')
    feed('mb')
    feed('j')
    feed('mc')

    poke_eventloop()

    eq('MM', eval('g:autocmd'))
  end)

  it('handles marks across multiple windows/buffers', function()
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

    command('split')
    command('vsplit')

    command('tabnew')
    command('split')

    command([[
      let g:markset_events = []
      autocmd MarkSet * call add(g:markset_events, {'bufnr': bufnr('%'), 'event': deepcopy(v:event)})
    ]])

    command('buffer ' .. orig_bufnr)
    feed('gg')
    feed('mA')

    command('wincmd w')
    command('tabnext')

    feed('mB')

    command('wincmd w')
    command('enew')

    local final_bufnr = api.nvim_get_current_buf()
    api.nvim_buf_set_lines(final_bufnr, 0, -1, true, {
      'final buffer after chaos',
      'line 2 of final buffer',
    })

    feed('j')
    feed('mC')

    command('tabclose')

    feed('mD')
    poke_eventloop()

    local mark_d_bufnr = api.nvim_get_current_buf()
    local all_events = eval('g:markset_events')
    eq(4, #all_events, 'Should have at 4 MarkSet events')

    local mark_a = get_event(all_events, 'A')
    eq(orig_bufnr, mark_a.bufnr)
    eq('A', mark_a.event.name)
    eq(1, mark_a.event.line)
    eq(0, mark_a.event.col)

    local mark_b = get_event(all_events, 'B')
    eq(third_bufnr, mark_b.bufnr)
    eq('B', mark_b.event.name)
    eq(1, mark_b.event.line)
    eq(0, mark_b.event.col)

    local mark_c = get_event(all_events, 'C')
    eq(final_bufnr, mark_c.bufnr)
    eq('C', mark_c.event.name)
    eq(2, mark_c.event.line)
    eq(0, mark_c.event.col)

    local mark_d = get_event(all_events, 'D')
    eq(mark_d_bufnr, mark_d.bufnr)
    eq('D', mark_d.event.name)
    eq(1, mark_d.event.line)
    eq(0, mark_d.event.col)
  end)

  it('handles an autocommand that calls bwipeout!', function()
    api.nvim_buf_set_lines(0, 0, -1, true, {
      'line 1',
      'line 2',
      'line 3',
    })

    local test_bufnr = api.nvim_get_current_buf()

    command("autocmd MarkSet * let g:autocmd ..= 'M' | bwipeout!")
    command([[let g:autocmd = '']])

    feed('ma')
    poke_eventloop()

    eq('M', eval('g:autocmd'))

    eq(false, api.nvim_buf_is_valid(test_bufnr))

    local current_bufnr = api.nvim_get_current_buf()
    neq(current_bufnr, test_bufnr)
  end)

  it('is called when using :mark command', function()
    api.nvim_buf_set_lines(0, 0, -1, true, {
      'line 1',
      'line 2',
      'line 3',
    })

    command([[
      let g:markset_events = []
      autocmd MarkSet * call add(g:markset_events, {'event': deepcopy(v:event)})
    ]])

    feed('j')
    command('mark a')
    poke_eventloop()

    eq(1, #eval('g:markset_events'))
    local mark_event = eval('g:markset_events')[1]
    eq('a', mark_event.event.name)
    eq(2, mark_event.event.line)
    eq(0, mark_event.event.col)
  end)

  it('is called when using nvim_buf_set_mark()', function()
    api.nvim_buf_set_lines(0, 0, -1, true, {
      'line 1',
      'line 2',
      'line 3',
    })

    command([[
      let g:markset_events = []
      autocmd MarkSet * call add(g:markset_events, {'event': deepcopy(v:event)})
    ]])

    local bufnr = api.nvim_get_current_buf()
    api.nvim_buf_set_mark(bufnr, 'a', 2, 0, {})
    poke_eventloop()

    eq(1, #eval('g:markset_events'))
    local mark_event = eval('g:markset_events')[1]
    eq('a', mark_event.event.name)
    eq(2, mark_event.event.line)
    eq(0, mark_event.event.col)
  end)

  it('handles an autocommand that switches windows and tabs', function()
    api.nvim_buf_set_lines(0, 0, -1, true, {
      'first buffer line 1',
      'first buffer line 2',
      'first buffer line 3',
    })
    local first_bufnr = api.nvim_get_current_buf()

    command('split')
    command('enew')
    api.nvim_buf_set_lines(0, 0, -1, true, {
      'second buffer line 1',
      'second buffer line 2',
    })
    local second_bufnr = api.nvim_get_current_buf()

    command('tabnew')
    api.nvim_buf_set_lines(0, 0, -1, true, {
      'third buffer line 1',
      'third buffer line 2',
      'third buffer line 3',
    })
    local third_bufnr = api.nvim_get_current_buf()

    command([[
      let g:markset_events = []
      autocmd MarkSet * call add(g:markset_events, {'bufnr': bufnr('%'), 'event': deepcopy(v:event)}) | wincmd w | tabnext
    ]])

    command('buffer ' .. second_bufnr)
    feed('j')
    feed('mA')
    poke_eventloop()

    command('buffer ' .. third_bufnr)
    feed('l')
    feed('mB')
    poke_eventloop()

    command('buffer ' .. first_bufnr)
    feed('jj')
    feed('mC')
    poke_eventloop()

    eq(3, #eval('g:markset_events'))

    local mark_a_event = get_event(eval('g:markset_events'), 'A')
    eq(second_bufnr, mark_a_event.bufnr)
    eq('A', mark_a_event.event.name)
    eq(2, mark_a_event.event.line)
    eq(0, mark_a_event.event.col)

    local mark_b_event = get_event(eval('g:markset_events'), 'B')
    eq(third_bufnr, mark_b_event.bufnr)
    eq('B', mark_b_event.event.name)
    eq(1, mark_b_event.event.line)
    eq(1, mark_b_event.event.col)

    local mark_c_event = get_event(eval('g:markset_events'), 'C')
    eq(first_bufnr, mark_c_event.bufnr)
    eq('C', mark_c_event.event.name)
    eq(3, mark_c_event.event.line)
    eq(0, mark_c_event.event.col)

    local mark_a = api.nvim_buf_get_mark(second_bufnr, 'A')
    eq(2, mark_a[1])
    eq(0, mark_a[2])

    local mark_b = api.nvim_buf_get_mark(third_bufnr, 'B')
    eq(1, mark_b[1])
    eq(1, mark_b[2])

    local mark_c = api.nvim_buf_get_mark(first_bufnr, 'C')
    eq(3, mark_c[1])
    eq(0, mark_c[2])
  end)

  -- Not yet supported
  -- it('is called after bracket marks [, ] are set', function()
  -- it('is called after angle bracket marks <, > are set', function()
  -- it('is called after the . mark is set', function()
  -- it('is called after the ^ mark is set', function()
  -- it('is called after the " mark is set', function()
  -- it('is called after the ' mark is set', function()
end)
