-- Tests Blockwise Visual when there are TABs before the text.
-- First test for undo working properly when executing commands from a register.
-- Also test this in an empty buffer.

local n = require('test.functional.testnvim')()
local t = require('test.testutil')

local describe, it, setup = t.describe, t.it, t.setup
local clear, feed, insert = n.clear, n.feed, n.insert
local feed_command, expect = n.feed_command, n.expect
local api, eq, command = n.api, t.eq, n.command

describe('blockwise visual', function()
  setup(clear)

  it('is working', function()
    insert([[
123456
234567
345678

test text test tex start here
		some text
		test text
test text

x	jAy kdd
Ox jAy kdd]])

    feed(":let @a = 'Ox<C-v><Esc>jAy<C-v><Esc>kdd'<cr>")
    feed('G0k@au')
    feed_command('new')
    feed('@auY')
    feed_command('quit')
    feed('GP')
    feed_command('/start here')
    feed('"by$<C-v>jjlld')
    feed_command('/456')
    feed('<C-v>jj"bP')
    feed_command('$-3,$d')

    expect([[
123start here56
234start here67
345start here78

test text test tex rt here
		somext
		tesext
test text]])
  end)

  it('uses raw columns uniformly regardless of a concealed line (#14409)', function()
    clear()
    local ns = api.nvim_create_namespace('conceal_wrap_blockvisual')
    command('set wrap conceallevel=2 concealcursor=nvic')
    api.nvim_buf_set_lines(0, 0, -1, true, {
      '0123456789',
      ('a'):rep(3) .. 'HIDDEN' .. ('b'):rep(3) .. '9',
      '0123456789',
    })
    api.nvim_buf_set_extmark(0, ns, 1, 3, { end_col = 9, conceal = '' })

    -- Block-select raw columns 2-4 across all 3 lines and delete: the concealed line's selection
    -- must use the same raw column range as the two plain lines, not a screen-adjusted one.
    api.nvim_win_set_cursor(0, { 1, 2 })
    feed('<C-v>2jll' .. 'd')
    eq({
      '0156789',
      'aaDDENbbb9',
      '0156789',
    }, api.nvim_buf_get_lines(0, 0, -1, true))
  end)
end)
