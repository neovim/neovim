local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local api = n.api
local clear = n.clear
local command = n.command
local feed = n.feed
local poke_eventloop = n.poke_eventloop
local eval = n.eval

local eq = t.eq

describe('MarkDeleted', function()
  before_each(function()
    clear()
  end)

  it('emits when lowercase marks are deleted', function()
    command([[
      let g:mark_names = ''
      let g:mark_events = []
      autocmd MarkDeleted * call add(g:mark_events, {'event': deepcopy(v:event)}) | let g:mark_names ..= v:event.name
    ]])

    api.nvim_buf_set_lines(0, 0, -1, true, {
      'foo bar',
      'baz text',
      'line 3',
    })

    feed('ma')
    feed('j')
    feed('mb')
    feed('j')
    feed('mc')

    poke_eventloop()
    eq('', eval('g:mark_names'))

    command('delmarks a')
    poke_eventloop()
    eq('a', eval('g:mark_names'))

    eq({
      {
        event = {
          name = 'a',
        },
      },
    }, eval('g:mark_events'))

    command('delmarks b-c')
    poke_eventloop()
    eq('abc', eval('g:mark_names'))

    eq({
      {
        event = {
          name = 'a',
        },
      },
      {
        event = {
          name = 'b',
        },
      },
      {
        event = {
          name = 'c',
        },
      },
    }, eval('g:mark_events'))
  end)

  it('emits when uppercase marks are deleted', function()
    command([[
      let g:mark_names = ''
      autocmd MarkDeleted * let g:mark_names ..= v:event.name
    ]])

    api.nvim_buf_set_lines(0, 0, -1, true, {
      'foo bar',
      'baz text',
    })

    feed('mA')
    feed('j')
    feed('mB')

    poke_eventloop()
    eq('', eval('g:mark_names'))

    command('delmarks A')
    poke_eventloop()
    eq('A', eval('g:mark_names'))

    command('delmarks B')
    poke_eventloop()
    eq('AB', eval('g:mark_names'))
  end)

  it('emits when special marks are deleted', function()
    command([[
      let g:mark_names = ''
      autocmd MarkDeleted * let g:mark_names ..= v:event.name
    ]])

    api.nvim_buf_set_lines(0, 0, -1, true, {
      'foo bar',
      'baz text',
    })

    -- Set some special marks
    api.nvim_buf_set_mark(0, '"', 1, 0, {})
    api.nvim_buf_set_mark(0, '[', 1, 0, {})
    api.nvim_buf_set_mark(0, ']', 1, 0, {})
    -- The '.' mark is set by making a change
    feed('ix<Esc>')

    poke_eventloop()
    eq('', eval('g:mark_names'))

    command([[delmarks "]])
    poke_eventloop()
    eq('"', eval('g:mark_names'))

    command('delmarks .')
    poke_eventloop()
    eq('".', eval('g:mark_names'))

    command('delmarks [')
    command('delmarks ]')
    poke_eventloop()
    eq('".[]', eval('g:mark_names'))
  end)

  it('can subscribe to specific marks by pattern', function()
    command([[
      let g:mark_names = ''
      autocmd MarkDeleted [ab] let g:mark_names ..= v:event.name
    ]])

    api.nvim_buf_set_lines(0, 0, -1, true, {
      'foo bar',
      'baz text',
    })

    feed('ma')
    feed('mb')
    feed('mc')
    feed('md')

    poke_eventloop()
    eq('', eval('g:mark_names'))

    command('delmarks d')
    poke_eventloop()
    eq('', eval('g:mark_names'))

    command('delmarks c')
    poke_eventloop()
    eq('', eval('g:mark_names'))

    command('delmarks b')
    poke_eventloop()
    eq('b', eval('g:mark_names'))

    command('delmarks a')
    poke_eventloop()
    eq('ba', eval('g:mark_names'))
  end)

  it('does not emit when deleting non-existent marks', function()
    command([[
      let g:mark_names = ''
      autocmd MarkDeleted * let g:mark_names ..= v:event.name
    ]])

    api.nvim_buf_set_lines(0, 0, -1, true, {
      'foo bar',
      'baz text',
    })

    -- Delete a mark that doesn't exist
    command('delmarks a')
    poke_eventloop()
    eq('', eval('g:mark_names'))

    -- Set a mark and then delete it
    feed('ma')
    poke_eventloop()
    command('delmarks a')
    poke_eventloop()
    eq('a', eval('g:mark_names'))

    -- Try to delete it again (should not emit)
    command('delmarks a')
    poke_eventloop()
    eq('a', eval('g:mark_names'))
  end)

  it('handles marks across multiple buffers', function()
    local first_bufnr = api.nvim_get_current_buf()
    api.nvim_buf_set_lines(first_bufnr, 0, -1, true, {
      'first buffer line 1',
      'first buffer line 2',
    })

    command('enew')
    local second_bufnr = api.nvim_get_current_buf()
    api.nvim_buf_set_lines(second_bufnr, 0, -1, true, {
      'second buffer line 1',
      'second buffer line 2',
    })

    command([[
      let g:markdeleted_events = []
      autocmd MarkDeleted * call add(g:markdeleted_events, { 'buf': 0 + expand('<abuf>'), 'event': deepcopy(v:event) })
    ]])

    command('buffer ' .. first_bufnr)
    feed('ma')
    feed('mA')

    command('buffer ' .. second_bufnr)
    feed('mb')

    poke_eventloop()
    eq({}, eval('g:markdeleted_events'))

    command('buffer ' .. first_bufnr)
    command('delmarks a')
    poke_eventloop()

    eq({
      {
        buf = first_bufnr,
        event = {
          name = 'a',
        },
      },
    }, eval('g:markdeleted_events'))

    command('buffer ' .. second_bufnr)
    command('delmarks b')
    poke_eventloop()

    eq({
      {
        buf = first_bufnr,
        event = {
          name = 'a',
        },
      },
      {
        buf = second_bufnr,
        event = {
          name = 'b',
        },
      },
    }, eval('g:markdeleted_events'))

    -- Delete global mark
    command('delmarks A')
    poke_eventloop()

    eq({
      {
        buf = first_bufnr,
        event = {
          name = 'a',
        },
      },
      {
        buf = second_bufnr,
        event = {
          name = 'b',
        },
      },
      {
        buf = first_bufnr,
        event = {
          name = 'A',
        },
      },
    }, eval('g:markdeleted_events'))
  end)
end)
