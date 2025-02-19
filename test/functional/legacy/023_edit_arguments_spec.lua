-- Tests for complicated + argument to :edit command

local n = require('test.functional.testnvim')()

local clear, insert = n.clear, n.insert
local command, expect = n.command, n.expect
local poke_eventloop = n.poke_eventloop

describe(':edit', function()
  setup(clear)

  it('is working', function()
    insert([[
      The result should be in Xfile1: "fooPIPEbar", in Xfile2: "fooSLASHbar"
      foo|bar
      foo/bar]])
    poke_eventloop()

    -- Prepare some test files
    command('$-1w! Xfile1')
    command('$w! Xfile2')
    command('w! Xfile0')

    -- Open Xfile using '+' range
    command('edit +1 Xfile1')
    command('s/|/PIPE/')
    command('yank A')
    command('w! Xfile1')

    -- Open Xfile2 using '|' range
    command('edit Xfile2|1')
    command('s/\\//SLASH/')
    command('yank A')
    command('w! Xfile2')

    -- Clean first buffer and put @a
    command('bf')
    command('%d')
    command('0put a')

    -- Remove empty line
    command('$d')

    -- The buffer should now contain
    expect([[
      fooPIPEbar
      fooSLASHbar]])
  end)

  teardown(function()
    os.remove('Xfile0')
    os.remove('Xfile1')
    os.remove('Xfile2')
  end)
end)
