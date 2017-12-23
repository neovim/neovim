local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local execute = helpers.execute
local expect = helpers.expect
local feed = helpers.feed
local insert = helpers.insert
local redir_exec = helpers.redir_exec
local curwinmeths = helpers.curwinmeths
local eq = helpers.eq

local nvim_current_line = function()
  return curwinmeths.get_cursor()[1]
end

describe('jump', function()
  before_each(function()
    clear()
    for i = 1, 4 do
      insert(('func%d\n\ttest\n\tone\n\ttwo\n'):format(i))
    end
  end)

  local function feed_check(cmd, line)
    feed(cmd)
    eq(line, nvim_current_line())
  end

  it('jumps without jumporder', function()
    feed('gg')
    feed_check('j^*n', 10)
    feed_check('<C-o>', 6)
    feed_check('j^*', 11)
    feed_check('<C-o>', 7)
    feed_check('<C-o>', 10)
    feed_check('<C-o>', 6)
  end)
  
  it('jumps with jumporder', function()
    execute('set jumporder')
    feed('gg')
    feed_check('j^*n', 10)
    feed_check('<C-o>', 6)
    feed_check('j^*', 11)
    feed_check('<C-o>', 7)
    feed_check('<C-o>', 2)
    feed_check('<C-i>', 7)
    feed_check('j^*', 12)
    feed_check('<C-o>', 8)
    feed_check('<C-o>', 2)
  end)

  it('keepjumps with jumporder', function()
    execute('set jumporder')
    feed('gg')
    feed_check('j^*n', 10)
    feed_check('<C-o>', 6)
    -- in the middle of jumplist
    feed_check(':keepjumps normal j^*<CR>', 11)
    feed_check('<C-i>', 10)
    feed_check('<C-o>', 6)
    feed_check('<C-i>', 10)
    -- in the end of jumplist
    feed_check(':keepjumps normal j^*<CR>', 15)
    feed_check('<C-o>', 6)
    feed_check('<C-i>', 10)
    feed_check('<C-i>', 10)
    feed_check('<C-o>', 6)
    feed_check('j^*', 11)
    -- in the empty end of jumplist
    feed_check(':keepjumps normal j^*<CR>', 16)
    feed_check('<C-i>', 16)
    feed_check('<C-o>', 7)
  end)
  
end)
