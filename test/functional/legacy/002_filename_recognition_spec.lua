-- Test if URLs are recognized as filenames by commands such as "gf". Here
-- we'll use `expand("<cfile>")` since "gf" would need to open the file.

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('filename recognition', function()
  setup(clear)

  it('is working', function()
    -- insert some lines containing URLs
    insert([[
      first test for URL://machine.name/tmp/vimtest2a and other text
      second test for URL://machine.name/tmp/vimtest2b. And other text
      third test for URL:\\machine.name\vimtest2c and other text
      fourth test for URL:\\machine.name\tmp\vimtest2d, and other text]])

    -- Go to the first URL and append it to the beginning
    execute('/^first', '/tmp', 'call append(0, expand("<cfile>"))')

    -- Repeat for the second URL
    -- this time, navigate to the word "URL" instead of "tmp"
    execute('/^second', '/URL', 'call append(1, expand("<cfile>"))')

    -- Repeat for the remaining URLs. This time, the 'isfname' option must be
    -- set to allow '\' in filenames
    execute('set isf=@,48-57,/,.,-,_,+,,,$,:,~,\\')
    execute('/^third', '/name', 'call append(2, expand("<cfile>"))')
    execute('/^fourth', '/URL', 'call append(3, expand("<cfile>"))')

    -- Delete the initial text, which now starts at line 5
    feed('5GdG')

    -- The buffer should now contain:
    expect([[
      URL://machine.name/tmp/vimtest2a
      URL://machine.name/tmp/vimtest2b
      URL:\\machine.name\vimtest2c
      URL:\\machine.name\tmp\vimtest2d]])
  end)
end)
