local t = require('test.functional.testutil')(after_each)
local clear = t.clear
local command = t.command
local eq = t.eq
local eval = t.eval
local feed = t.feed
local api = t.api
local testprg = t.testprg
local retry = t.retry

describe(':ls', function()
  before_each(function()
    clear()
  end)

  it('R, F for :terminal buffers', function()
    api.nvim_set_option_value('shell', string.format('"%s" INTERACT', testprg('shell-test')), {})

    command('edit foo')
    command('set hidden')
    command('terminal')
    command('vsplit')
    command('terminal')
    feed('iexit<cr>')
    retry(nil, 5000, function()
      local ls_output = eval('execute("ls")')
      -- Normal buffer.
      eq('\n  1  h ', string.match(ls_output, '\n *1....'))
      -- Terminal buffer [R]unning.
      eq('\n  2 #aR', string.match(ls_output, '\n *2....'))
      -- Terminal buffer [F]inished.
      eq('\n  3 %aF', string.match(ls_output, '\n *3....'))
    end)

    retry(nil, 5000, function()
      local ls_output = eval('execute("ls R")')
      -- Just the [R]unning terminal buffer.
      eq('\n  2 #aR ', string.match(ls_output, '^\n *2 ... '))
    end)

    retry(nil, 5000, function()
      local ls_output = eval('execute("ls F")')
      -- Just the [F]inished terminal buffer.
      eq('\n  3 %aF ', string.match(ls_output, '^\n *3 ... '))
    end)
  end)
end)
