-- Tests for undo tree and :earlier and :later.

local helpers = require('test.functional.helpers')
local feed, insert, source, eq, eval, clear, execute, expect, wait =
  helpers.feed, helpers.insert, helpers.source, helpers.eq, helpers.eval,
  helpers.clear, helpers.execute, helpers.expect, helpers.wait

local expect_empty_buffer = function()
  -- The space will be removed by helpers.dedent but is needed as dedent will
  -- throw an error if it can not find the common indent of the given lines.
  expect(' ')
end

describe('the undo tree', function()
  setup(clear)
  teardown(function()
    os.remove('Xtest')
  end)

  it('is working', function()
    -- Assert that no undo history is present.
    eq({}, eval('undotree().entries'))
    insert([[
      
      123456789]])

    -- Clear the undo history after the insertion (see :h clear-undo)
    execute('let old_undolevels = &undolevels')
    execute('set undolevels=-1')
    feed('a <BS><Esc>') 
    execute('let &undolevels = old_undolevels')
    execute('unlet old_undolevels')
    eq({}, eval('undotree().entries'))

    -- Delete three characters and undo.
    feed('Gxxx')
    eq('456789', eval('getline(".")'))
    feed('g-')
    eq('3456789', eval('getline(".")'))
    feed('g-')
    eq('23456789', eval('getline(".")'))
    feed('g-')
    eq('123456789', eval('getline(".")'))
    feed('g-')
    eq('123456789', eval('getline(".")'))

    -- Delete three other characters and go back in time step by step.
    feed('$xxx')
    eq('123456', eval('getline(".")'))
    execute('sleep 1')
    wait()
    feed('g-')
    eq('1234567', eval('getline(".")'))
    feed('g-')
    eq('12345678', eval('getline(".")'))
    feed('g-')
    eq('456789', eval('getline(".")'))
    feed('g-')
    eq('3456789', eval('getline(".")'))
    feed('g-')
    eq('23456789', eval('getline(".")'))
    feed('g-')
    eq('123456789', eval('getline(".")'))
    feed('g-')
    eq('123456789', eval('getline(".")'))
    feed('g-')
    eq('123456789', eval('getline(".")'))
    feed('10g+')
    eq('123456', eval('getline(".")'))

    -- Delay for three seconds and go some seconds forward and backward.
    execute('sleep 2')
    wait()
    feed('Aa<esc>')
    feed('Ab<esc>')
    feed('Ac<esc>')
    eq('123456abc', eval('getline(".")'))
    execute('ear 1s')
    eq('123456', eval('getline(".")'))
    execute('ear 3s')
    eq('123456789', eval('getline(".")'))
    execute('later 1s')
    eq('123456', eval('getline(".")'))
    execute('later 1h')
    eq('123456abc', eval('getline(".")'))

    -- Test that setting 'ul' breaks change blocks, we need to use source() in
    -- order to test this, as interactive changes are not grouped.
    execute('new')
    -- First verify that scripts produce single big undo blocks.
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
    -- Verify that undo blocks can be broken inside scripts by setting 'ul'.
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
    
    -- Test undojoin.
    feed('Goaaaa<esc>')
    feed('obbbb<esc>u')
    eq('aaaa', eval('getline(".")'))
    feed('obbbb<esc>')
    execute('undojoin')
    feed('occcc<esc>u')
    -- TODO At this point the original test will write "aaaa" to test.out.
    -- Why is the line "bbbb" here?
    eq('bbbb', eval('getline(".")'))

    execute('e! Xtest')
    feed('ione one one<esc>')
    execute('w!')
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

    execute('enew!')
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
    feed('o1<esc>a2<C-R>=string(123)<cr><esc>')
    expect([[
      
      a
      b
      1
      c
      12
      d
      12123]])

    -- TODO there is a difference between the original test and this test at
    -- this point.  The original tests expects the last line to go away after
    -- the undo.  I do not know why this should be the case as the "o" and "a"
    -- above are seperate changes.  I was able to confirm this manually with
    -- vim and nvim.  Both end up in this state (treat "o" and "a" as two
    -- edits).
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
