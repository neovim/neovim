-- Inserts 2 million lines with consecutive integers starting from 1
-- (essentially, the output of GNU's seq 1 2000000), writes them to Xtest
-- and calculates its cksum.
-- We need 2 million lines to trigger a call to mf_hash_grow().  If it would mess
-- up the lines the checksum would differ.
-- cksum is part of POSIX and so should be available on most Unixes.
-- If it isn't available then the test will be skipped.

local helpers = require('test.functional.helpers')(after_each)
local feed = helpers.feed
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('mf_hash_grow()', function()
  setup(clear)

  -- Check to see if cksum exists, otherwise skip the test
  if os.execute('which cksum 2>&1 > /dev/null') ~= 0 then
    pending('was not tested because cksum was not found', function() end)
  else
    it('is working', function()
      execute('set fileformat=unix undolevels=-1')

      -- Fill the buffer with numbers 1 - 2000000
      execute('let i = 1')
      execute('while i <= 2000000 | call append(i, range(i, i + 99)) | let i += 100 | endwhile')

      -- Delete empty first line, save to Xtest, and clear buffer
      feed('ggdd<cr>')
      execute('w! Xtest')
      feed('ggdG<cr>')

      -- Calculate the cksum of Xtest and delete first line
      execute('r !cksum Xtest')
      feed('ggdd<cr>')

      -- Assert correct output of cksum.
      expect([[
        3678979763 14888896 Xtest]])
    end)
  end

  teardown(function()
    os.remove('Xtest')
  end)
end)
