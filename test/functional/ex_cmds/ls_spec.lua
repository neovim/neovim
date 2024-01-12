local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed
local api = helpers.api
local testprg = helpers.testprg
local retry = helpers.retry

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
