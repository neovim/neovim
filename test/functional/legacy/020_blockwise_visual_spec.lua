-- vim: set foldmethod=marker foldmarker=[[,]] :
-- Tests Blockwise Visual when there are TABs before the text.
-- First test for undo working properly when executing commands from a register.
-- Also test this in an empty buffer.

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

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
    execute('new')
    feed('@auY')
    execute('quit')
    feed('GP')
    execute('/start here')
    feed('"by$<C-v>jjlld')
    execute('/456')
    feed('<C-v>jj"bP')
    execute('$-3,$d')

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
