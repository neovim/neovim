-- Tests for complicated + argument to :edit command

local helpers = require('test.functional.helpers')
local clear, insert = helpers.clear, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe(':edit', function()
  setup(clear)

  it('is working', function()
    insert([[
      The result should be in Xfile1: "fooPIPEbar", in Xfile2: "fooSLASHbar"
      foo|bar
      foo/bar]])

    -- Prepare some test files
    execute('$-1w! Xfile1')
    execute('$w! Xfile2')
    execute('w! Xfile0')

    -- Open Xfile using '+' range
    execute('edit +1 Xfile1')
    execute('s/|/PIPE/')
    execute('yank A')
    execute('w! Xfile1')

    -- Open Xfile2 using '|' range
    execute('edit Xfile2|1')
    execute("s/\\//SLASH/")
    execute('yank A')
    execute('w! Xfile2')

    -- Clean first buffer and put @a
    execute('bf')
    execute('%d')
    execute('0put a')

    -- Remove empty line
    execute('$d')

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
