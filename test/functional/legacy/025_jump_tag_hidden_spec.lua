-- Test for jumping to a tag with 'hidden' set, with symbolic link in path of tag.
-- This only works for Unix, because of the symbolic link.

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local feed_command, expect = helpers.feed_command, helpers.expect

if helpers.pending_win32(pending) then return end

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

    feed_command('w! Xxx')
    feed_command('set hidden')

    -- Create a link from test25.dir to the current directory.
    feed_command('!rm -f test25.dir')
    feed_command('!ln -s . test25.dir')

    -- Create tags.text, with the current directory name inserted.
    feed_command('/tags line')
    feed_command('r !pwd')
    feed('d$/test<cr>')
    feed('hP:.w! tags.test<cr>')

    -- Try jumping to a tag in the current file, but with a path that contains a
    -- symbolic link.  When wrong, this will give the ATTENTION message.  The next
    -- space will then be eaten by hit-return, instead of moving the cursor to 'd'.
    feed_command('set tags=tags.test')
    feed('G<C-]> x:yank a<cr>')
    feed_command('!rm -f Xxx test25.dir tags.test')

    -- Put @a and remove empty line
    feed_command('%d')
    feed_command('0put a')
    feed_command('$d')

    -- Assert buffer contents.
    expect("#efine  SECTION_OFF  3")
  end)
end)
