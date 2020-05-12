-- Tests for complicated + argument to :edit command

local helpers = require('test.functional.helpers')(after_each)
local clear, insert = helpers.clear, helpers.insert
local command, expect = helpers.command, helpers.expect
local wait = helpers.wait

describe(':edit', function()
  setup(clear)

  it('is working', function()
    insert([[
      The result should be in Xfile1: "fooPIPEbar", in Xfile2: "fooSLASHbar"
      foo|bar
      foo/bar]])
    wait()

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
    command("s/\\//SLASH/")
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
