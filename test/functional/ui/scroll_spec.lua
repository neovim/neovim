local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed = helpers.clear, helpers.feed
local feed_command = helpers.feed_command

-- Insert <count> lines consisting of <length> occurrences of each
-- consecutive digit, followed by newlines if with_nl is set.
-- e.g. feed_lines(3, 2, true) inserts '00\n11\n22\n33\n'
local function feed_lines(count, length, with_nl)
  local ending = (with_nl and 'a\n<Esc>' or '')
  for i = 0, count do
    feed(length .. 'a' .. (i % 10) .. '<Esc>' .. ending)
  end
end

describe('scrolling', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(20,5)
    screen:attach()
    screen:set_default_attr_ids({
      [0] = {bold=true, foreground=Screen.colors.Blue},
    })
    feed_command('set wrap')
  end)

  after_each(function()
    screen:detach()
  end)

  describe('with three wrapped lines', function()
    before_each(function()
      feed_lines(2, 30, true)
      screen:expect([[
        22222222222222222222|
        2222222222          |
        ^                    |
        {0:~                   }|
                            |
      ]])
    end)

    it('<C-E> and <C-Y> work by lines', function()
      feed('<C-Y>')
      screen:expect([[
        11111111111111111111|
        1111111111          |
        ^22222222222222222222|
        2222222222          |
                            |
      ]])
      feed('<C-Y><C-Y>')
      screen:expect([[
        00000000000000000000|
        0000000000          |
        ^11111111111111111111|
        1111111111          |
                            |
      ]])

      feed('<C-E>')
      screen:expect([[
        ^11111111111111111111|
        1111111111          |
        22222222222222222222|
        2222222222          |
                            |
      ]])
      feed('<C-E>')
      screen:expect([[
        ^22222222222222222222|
        2222222222          |
                            |
        {0:~                   }|
                            |
      ]])
      feed('<C-E>')
      screen:expect([[
        ^                    |
        {0:~                   }|
        {0:~                   }|
        {0:~                   }|
                            |
      ]])
    end)

    it('<C-E> and <C-Y> work by rows in rowwise mode', function()
      feed_command('set scrollrowwise')
      feed_command('set listchars=precedes:< list')
      feed('<C-Y>')
      screen:expect([[
        {0:<}111111111          |
        22222222222222222222|
        2222222222          |
        ^                    |
                            |
      ]])
      feed('<C-Y><C-Y>')
      screen:expect([[
        {0:<}000000000          |
        ^11111111111111111111|
        1111111111          |
        22222222222222222{0:@@@}|
                            |
      ]])

      feed('<C-E>')
      screen:expect([[
        ^11111111111111111111|
        1111111111          |
        22222222222222222222|
        2222222222          |
                            |
      ]])
      feed('<C-E>')
      screen:expect([[
        {0:^<}111111111          |
        22222222222222222222|
        2222222222          |
                            |
                            |
      ]])
    end)
  end)

  describe('with a very long line in rowwise mode', function()
    before_each(function()
      feed_command('set scrollrowwise')
      feed_lines(20, 20, false)
      -- Needed for nondeterminism? For some reason, we get the "Screen
      -- changes were received after the expected state" error here, and
      -- this redraw seems to help...
      feed('<C-L>')
      screen:expect([[
        88888888888888888888|
        99999999999999999999|
        0000000000000000000^0|
        {0:~                   }|
                            |
      ]])
    end)

    it('cursor works', function()
      feed('gg')
      screen:expect([[
        ^00000000000000000000|
        11111111111111111111|
        22222222222222222222|
        33333333333333333333|
                            |
      ]])

      -- Cursor should move one row forward in the line
      feed('<C-E>rx')
      screen:expect([[
        ^x1111111111111111111|
        22222222222222222222|
        33333333333333333333|
        44444444444444444444|
                            |
      ]])

      feed('<C-E>')
      screen:expect([[
        ^22222222222222222222|
        33333333333333333333|
        44444444444444444444|
        55555555555555555555|
                            |
      ]])
    end)
  end)
end)
