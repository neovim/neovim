local helpers = require('test.functional.helpers')(after_each)
local command = helpers.command
local insert = helpers.insert
local eq = helpers.eq
local clear = helpers.clear
local meths = helpers.meths
local feed = helpers.feed
local feed_command = helpers.feed_command
local write_file = helpers.write_file
local exec = helpers.exec
local eval = helpers.eval

describe(':source', function()
  before_each(function()
    clear()
  end)

  it('current buffer', function()
    insert('let a = 2')
    command('source')
    eq('2', meths.exec('echo a', true))
  end)

  it('selection in current buffer', function()
    insert(
      'let a = 2\n'..
      'let a = 3\n'..
      'let a = 4\n')

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

    command('source')
    eq('4', meths.exec('echo luaeval("y")', true))
  end)

  it('can source lua files', function()
    local test_file = 'test.lua'
    write_file (test_file, [[vim.g.sourced_lua = 1]])

    exec('source ' .. test_file)

    eq(1, eval('g:sourced_lua'))
    os.remove(test_file)
  end)

  it('can source selected region in lua file', function()
    local test_file = 'test.lua'

    write_file (test_file, [[
      vim.g.b = 5
      vim.g.b = 6
      vim.g.b = 7
    ]])

    command('edit '..test_file)
    feed('ggjV')
    feed_command(':source')

    eq(6, eval('g:b'))
    os.remove(test_file)
  end)

  it('can source current lua buffer without argument', function()
    local test_file = 'test.lua'

    write_file (test_file, [[
      vim.g.c = 10
      vim.g.c = 11
      vim.g.c = 12
    ]])

    command('edit '..test_file)
    feed_command(':source')

    eq(12, eval('g:c'))
    os.remove(test_file)
  end)
end)
