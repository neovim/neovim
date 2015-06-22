-- Tests for undo tree and :earlier and :later.

local helpers = require('test.functional.helpers')
local feed, insert, source, eq, eval, clear, execute, expect, wait =
  helpers.feed, helpers.insert, helpers.source, helpers.eq, helpers.eval,
  helpers.clear, helpers.execute, helpers.expect, helpers.wait

local function expect_empty_buffer()
  -- The space will be removed by helpers.dedent but is needed as dedent will
  -- throw an error if it can not find the common indent of the given lines.
  return expect(' ')
end
local function expect_line(line)
  return eq(line, eval('getline(".")'))
end
local function write_file(name, text)
  local file = io.open(name, 'w')
  file:write(text)
  file:flush()
  file:close()
end

describe('undo:', function()
  before_each(clear)
  teardown(function()
    os.remove('Xtest.source')
  end)

  describe(':earlier and :later', function()
    before_each(function()
      os.remove('Xtest')
    end)
    teardown(function()
      os.remove('Xtest')
    end)

    it('work with time specifications and g- and g+', function()
      -- We write the test text to a file in order to prevent nvim to record
      -- the inserting of the text into the undo history.
      write_file('Xtest', '\n123456789\n')
      execute('e Xtest')
      -- Assert that no undo history is present.
      eq({}, eval('undotree().entries'))
      -- Delete three characters and undo.
      feed('Gxxx')
      expect_line('456789')
      feed('g-')
      expect_line('3456789')
      feed('g-')
      expect_line('23456789')
      feed('g-')
      expect_line('123456789')
      feed('g-')
      expect_line('123456789')

      -- Delete three other characters and go back in time step by step.
      feed('$xxx')
      expect_line('123456')
      execute('sleep 1')
      wait()
      feed('g-')
      expect_line('1234567')
      feed('g-')
      expect_line('12345678')
      feed('g-')
      expect_line('456789')
      feed('g-')
      expect_line('3456789')
      feed('g-')
      expect_line('23456789')
      feed('g-')
      expect_line('123456789')
      feed('g-')
      expect_line('123456789')
      feed('g-')
      expect_line('123456789')
      feed('10g+')
      expect_line('123456')

      -- Delay for two seconds and go some seconds forward and backward.
      execute('sleep 2')
      wait()
      feed('Aa<esc>')
      feed('Ab<esc>')
      feed('Ac<esc>')
      expect_line('123456abc')
      execute('earlier 1s')
      expect_line('123456')
      execute('earlier 3s')
      expect_line('123456789')
      execute('later 1s')
      expect_line('123456')
      execute('later 1h')
      expect_line('123456abc')
    end)

    it('work with file write specifications', function()
      feed('ione one one<esc>')
      execute('w Xtest')
      feed('otwo<esc>')
      feed('otwo<esc>')
      execute('w')
      feed('othree<esc>')
      execute('earlier 1f')
      expect([[
	one one one
	two
	two]])
      execute('earlier 1f')
      expect('one one one')
      execute('earlier 1f')
      expect_empty_buffer()
      execute('later 1f')
      expect('one one one')
      execute('later 1f')
      expect([[
	one one one
	two
	two]])
      execute('later 1f')
      expect([[
	one one one
	two
	two
	three]])
    end)
  end)

  it('scripts produce one undo block for all changes by default', function()
    source([[
      normal Aaaaa
      normal obbbb
      normal occcc
    ]])
    expect([[
      aaaa
      bbbb
      cccc]])
    feed('u')
    expect_empty_buffer()
  end)

  it('setting undolevel can break change blocks (inside scripts)', function()
    -- We need to use source() in order to test this, as interactive changes
    -- are not grouped.
    source([[
      normal Aaaaa
      set ul=100
      normal obbbb
      set ul=100
      normal occcc
    ]])
    expect([[
      aaaa
      bbbb
      cccc]])
    feed('u')
    expect([[
      aaaa
      bbbb]])
    feed('u')
    expect('aaaa')
    feed('u')
    expect_empty_buffer()
  end)

  it(':undojoin can join change blocks inside scripts', function()
    feed('Goaaaa<esc>')
    feed('obbbb<esc>u')
    expect_line('aaaa')
    source([[
      normal obbbb
      set ul=100
      undojoin
      normal occcc
    ]])
    feed('u')
    expect_line('aaaa')
  end)

  it('undoing pastes from the expression register is working', function()
    local normal_commands = 'o1\x1ba2\x12=string(123)\n\x1b'
    write_file('Xtest.source', normal_commands)

    feed('oa<esc>')
    feed('ob<esc>')
    feed([[o1<esc>a2<C-R>=setline('.','1234')<cr><esc>]])
    expect([[
      
      a
      b
      12034]])
    feed('uu')
    expect([[
      
      a
      b
      1]])
    feed('oc<esc>')
    feed([[o1<esc>a2<C-R>=setline('.','1234')<cr><esc>]])
    expect([[
      
      a
      b
      1
      c
      12034]])
    feed('u')
    expect([[
      
      a
      b
      1
      c
      12]])
    feed('od<esc>')
    execute('so! Xtest.source')
    expect([[
      
      a
      b
      1
      c
      12
      d
      12123]])
    feed('u')
    expect([[
      
      a
      b
      1
      c
      12
      d]])
    -- The above behaviour was tested in the legacy vim test because the
    -- legacy tests were executed with ':so!'.  The behavior differs for
    -- interactive use (even in vim, where the result was the same):
    feed(normal_commands)
    expect([[
      
      a
      b
      1
      c
      12
      d
      12123]])
    feed('u')
    expect([[
      
      a
      b
      1
      c
      12
      d
      1]])
  end)
end)
