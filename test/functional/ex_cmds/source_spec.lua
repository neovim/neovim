local helpers = require('test.functional.helpers')(after_each)
local command = helpers.command
local insert = helpers.insert
local wait = helpers.wait
local eq = helpers.eq
local clear = helpers.clear
local meths = helpers.meths
local feed = helpers.feed
local feed_command = helpers.feed_command

describe(':source', function()
  before_each(function()
    clear()
  end)

  it('current buffer', function()
    insert('let a = 2')
    wait()
    command('source')
    eq('2', meths.exec('echo a', true))
  end)

  it('selection in current buffer', function()
    insert(
      'let a = 2\n'..
      'let a = 3\n'..
      'let a = 4\n')
    wait()

    -- Source the 2nd line only
    feed('ggjV')
    feed_command(':source')
    eq('3', meths.exec('echo a', true))

    -- Source from 2nd line to end of file
    feed('ggjVG')
    feed_command(':source')
    eq('4', meths.exec('echo a', true))
  end)

  it('multiline heredoc command', function()
    insert(
      'lua << EOF\n'..
      'y = 4\n'..
      'EOF\n')
    wait()

    command('source')
    eq('4', meths.exec('echo luaeval("y")', true))
  end)
end)
