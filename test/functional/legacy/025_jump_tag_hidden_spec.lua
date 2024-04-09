-- Test for jumping to a tag with 'hidden' set, with symbolic link in path of tag.
-- This only works for Unix, because of the symbolic link.

local t = require('test.functional.testutil')()
local clear, feed, insert = t.clear, t.feed, t.insert
local feed_command, expect = t.feed_command, t.expect

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
    if t.is_os('win') then
      feed_command('!rd /q/s test25.dir')
      feed_command('!mklink /j test25.dir .')
    else
      feed_command('!rm -f test25.dir')
      feed_command('!ln -s . test25.dir')
    end

    -- Create tags.text, with the current directory name inserted.
    feed_command('/tags line')
    feed_command('r !' .. (t.is_os('win') and 'cd' or 'pwd'))
    feed('d$/test<cr>')
    feed('hP:.w! tags.test<cr>')

    -- Try jumping to a tag in the current file, but with a path that contains a
    -- symbolic link.  When wrong, this will give the ATTENTION message.  The next
    -- space will then be eaten by hit-return, instead of moving the cursor to 'd'.
    feed_command('set tags=tags.test')
    feed('G<C-]> x:yank a<cr>')
    feed_command("call delete('tags.test')")
    feed_command("call delete('Xxx')")
    if t.is_os('win') then
      feed_command('!rd /q test25.dir')
    else
      feed_command('!rm -f test25.dir')
    end

    -- Put @a and remove empty line
    feed_command('%d')
    feed_command('0put a')
    feed_command('$d')

    -- Assert buffer contents.
    expect('#efine  SECTION_OFF  3')
  end)
end)
