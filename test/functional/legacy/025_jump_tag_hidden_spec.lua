-- Test for jumping to a tag with 'hidden' set, with symbolic link in path of tag.
-- This only works for Unix, because of the symbolic link.

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('jump to a tag with hidden set', function()
  setup(clear)

  it('is working', function()
    insert([[
      tags line:
      SECTION_OFF	/test25.dir/Xxx	/^#define  SECTION_OFF  3$/

      /*tx.c*/
      #define  SECTION_OFF  3
      #define  NUM_SECTIONS 3

      SECTION_OFF]])

    execute('w! Xxx')
    execute('set hidden')

    -- Create a link from test25.dir to the current directory.
    execute('!rm -f test25.dir')
    execute('!ln -s . test25.dir')

    -- Create tags.text, with the current directory name inserted.
    execute('/tags line')
    execute('r !pwd')
    feed('d$/test<cr>')
    feed('hP:.w! tags.test<cr>')

    -- Try jumping to a tag in the current file, but with a path that contains a
    -- symbolic link.  When wrong, this will give the ATTENTION message.  The next
    -- space will then be eaten by hit-return, instead of moving the cursor to 'd'.
    execute('set tags=tags.test')
    feed('G<C-]> x:yank a<cr>')
    execute('!rm -f Xxx test25.dir tags.test')

    -- Put @a and remove empty line
    execute('%d')
    execute('0put a')
    execute('$d')

    -- Assert buffer contents.
    expect("#efine  SECTION_OFF  3")
  end)
end)
