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

describe('MarkSet', function()
  -- TODO(justinmk): support other marks?: [, ] <, > . ^ " '

  before_each(function()
    clear()
  end)

  it('emits when lowercase/uppercase/[/] marks are set', function()
    command([[
      let g:mark_names = ''
      let g:mark_events = []
      autocmd MarkSet * call add(g:mark_events, {'event': deepcopy(v:event)}) | let g:mark_names ..= expand('<amatch>')
      " TODO: there is a bug lurking here.
      " autocmd MarkSet * let g:mark_names ..= expand('<amatch>')
    ]])

    api.nvim_buf_set_lines(0, 0, -1, true, {
      'foo\0bar',
      'baz text',
      'line 3',
    })

    feed('ma')
    feed('j')
    command('mark b')

    poke_eventloop()
    eq('ab', eval('g:mark_names'))

    -- event-data is copied to `v:event`.
    eq({
      {
        event = {
          col = 0,
          line = 1,
          name = 'a',
        },
      },
      {
        event = {
          col = 0,
          line = 2,
          name = 'b',
        },
      },
    }, eval('g:mark_events'))

    feed('mA')
    feed('l')
    feed('mB')
    feed('j')
    feed('mC')

    feed('x') -- TODO(justinmk): Sets [,] marks but does not emit MarkSet event (yet).
    feed('0vll<esc>') -- TODO(justinmk): Sets <,> marks but does not emit MarkSet event (yet).
    -- XXX: set these marks manually to exercise these cases.
    api.nvim_buf_set_mark(0, '[', 2, 0, {})
    api.nvim_buf_set_mark(0, ']', 2, 0, {})
    api.nvim_buf_set_mark(0, '<', 2, 0, {})
    api.nvim_buf_set_mark(0, '>', 2, 0, {})
    api.nvim_buf_set_mark(0, '"', 2, 0, {})

    poke_eventloop()
    eq('abABC[]<>"', eval('g:mark_names'))
  end)

  it('can subscribe to specific marks by pattern', function()
    command([[
      let g:mark_names = ''
      autocmd MarkSet [ab] let g:mark_names ..= expand('<amatch>')
    ]])

    api.nvim_buf_set_lines(0, 0, -1, true, {
      'foo\0bar',
      'baz text',
    })

    feed('md')
    feed('mc')
    feed('l')
    feed('mb')
    feed('j')
    feed('ma')

    poke_eventloop()
    eq('ba', eval('g:mark_names'))
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
      autocmd MarkSet * call add(g:markset_events, { 'buf': 0 + expand('<abuf>'), 'event': deepcopy(v:event) })
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
    eq({
      {
        buf = 1,
        event = {
          col = 0,
          line = 1,
          name = 'A',
        },
      },
      {
        buf = 2,
        event = {
          col = 0,
          line = 1,
          name = 'B',
        },
      },
      {
        buf = 4,
        event = {
          col = 0,
          line = 2,
          name = 'C',
        },
      },
      {
        buf = 3,
        event = {
          col = 0,
          line = 1,
          name = 'D',
        },
      },
    }, eval('g:markset_events'))
  end)

  it('handles an autocommand that calls bwipeout!', function()
    api.nvim_buf_set_lines(0, 0, -1, true, {
      'line 1',
      'line 2',
      'line 3',
    })

    local test_bufnr = api.nvim_get_current_buf()

    command("autocmd MarkSet * let g:autocmd ..= expand('<amatch>') | bwipeout!")
    command([[let g:autocmd = '']])

    feed('ma')
    poke_eventloop()

    eq('a', eval('g:autocmd'))

    eq(false, api.nvim_buf_is_valid(test_bufnr))

    local current_bufnr = api.nvim_get_current_buf()
    neq(current_bufnr, test_bufnr)
  end)

  it('when autocommand switches windows and tabs', function()
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
      autocmd MarkSet * call add(g:markset_events, {'buf': 0 + expand('<abuf>'), 'event': deepcopy(v:event)}) | wincmd w | tabnext
    ]])

    command('buffer ' .. second_bufnr)
    feed('j')
    feed('mA')
    command('buffer ' .. third_bufnr)
    feed('l')
    feed('mB')
    command('buffer ' .. first_bufnr)
    feed('jj')
    feed('mC')
    poke_eventloop()

    eq({
      {
        buf = 2,
        event = {
          col = 0,
          line = 2,
          name = 'A',
        },
      },
      {
        buf = 3,
        event = {
          col = 1,
          line = 1,
          name = 'B',
        },
      },
      {
        buf = 1,
        event = {
          col = 0,
          line = 3,
          name = 'C',
        },
      },
    }, eval('g:markset_events'))

    eq({ 2, 0 }, api.nvim_buf_get_mark(second_bufnr, 'A'))
    eq({ 1, 1 }, api.nvim_buf_get_mark(third_bufnr, 'B'))
    eq({ 3, 0 }, api.nvim_buf_get_mark(first_bufnr, 'C'))
  end)
end)
