-- Tests Blockwise Visual when there are TABs before the text.
-- First test for undo working properly when executing commands from a register.
-- Also test this in an empty buffer.

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local feed_command, expect = helpers.feed_command, helpers.expect

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
end)
