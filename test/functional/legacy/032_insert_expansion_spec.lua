-- Test for insert expansion
-- :se cpt=.,w
-- * add-expands (word from next line) from other window
-- * add-expands (current buffer first)
-- * Local expansion, ends in an empty line (unless it becomes a global expansion)
-- * starts Local and switches to global add-expansion
-- :se cpt=.,w,i
-- * i-add-expands and switches to local
-- * add-expands lines (it would end in an empty line if it didn't ignored it self)
-- :se cpt=kXtestfile
-- * checks k-expansion, and file expansion (use Xtest11 instead of test11,
-- * because TEST11.OUT may match first on DOS)
-- :se cpt=w
-- * checks make_cyclic in other window
-- :se cpt=u nohid
-- * checks unloaded buffer expansion
-- * checks adding mode abortion
-- :se cpt=t,d
-- * tag expansion, define add-expansion interrupted
-- * t-expansion

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect
local write_file = helpers.write_file
local eq, eval = helpers.eq, helpers.eval

describe('insert expansion', function()
  local text1 = [[
    test11	36Gepeto	/Tag/
    asd	test11file	36G
    Makefile	to	run
    ]]
  local text2 = [[
    #include "Xtestfile"
    run1 run3
    run3 run3
    
    Makefile	to	run3
    Makefile	to	run3
    Makefile	to	run3
    run1 run2
    
    ]]
  setup(function()
    clear()
    write_file('Xtestfile', text1)
    -- Dummy files for file name completion.
    write_file('Xtest11.one', text2)
    write_file('Xtest11.two', text2)
  end)
  teardown(function()
    os.remove('Xtest11.one')
    os.remove('Xtest11.two')
    os.remove('Xtestfile')
  end)

  it('is working', function()
--    insert([[
--      start of testfile
--      run1
--      run2
--      end of testfile
--      
--      test11	36Gepeto	/Tag/
--      asd	test11file	36G
--      Makefile	to	run]])

    eq('', eval('buffer_name("%")'))
    eq(1, eval('bufnr("%")'))
    execute('set cpt=.,w')
    execute('set ff&')
    execute('set cot=')
    execute('e! Xtestfile')
    execute('e! test/functional/fixtures/test32.in')
    --eq('src/nvim/testdir/test32.in', eval('buffer_name("%")'))
    eq(2, eval('bufnr("%")'))

    feed('<C-W>n')
    eq('', eval('buffer_name("%")'))
    eq(3, eval('bufnr("%")'))
    feed('O#include "Xtestfile"<cr>')
    expect([[
      #include "Xtestfile"
      
      ]])
    feed('ru<C-N><C-N><C-X><C-N><esc><C-A><cr>')
    expect([[
      #include "Xtestfile"
      run1 run3
      ]])
    feed('O<C-P><C-X><C-N><cr>')
    expect([[
      #include "Xtestfile"
      run1 run3
      run3 run3
      
      ]])
    feed('<C-X><C-P><C-P><C-P><C-P><C-P><cr>')
    expect([[
      #include "Xtestfile"
      run1 run3
      run3 run3
      
      
      ]])
    feed('<C-X><C-P><C-P><C-X><C-X><C-N><C-X><C-N><C-N><esc><CR>')
    expect([[
      #include "Xtestfile"
      run1 run3
      run3 run3
      
      run1 run2
      ]])
    execute('set cpt=.,w,i')
    feed('kOM<C-N><C-X><C-N><C-X><C-N><C-X><C-X><C-X><C-P><cr>')
    expect([[
      #include "Xtestfile"
      run1 run3
      run3 run3
      
      Makefile	to	run3
      
      run1 run2
      ]])
    feed('<C-X><C-L><C-X><C-L><C-P><C-P><esc><CR>')
    expect([[
      #include "Xtestfile"
      run1 run3
      run3 run3
      
      Makefile	to	run3
      Makefile	to	run3
      Makefile	to	run3
      run1 run2
      ]])
    execute('set cpt=kXtestfile')
    feed('O<C-N><esc>IX<esc>A<C-X><C-F><C-N><esc><CR>')
    expect([[
      #include "Xtestfile"
      run1 run3
      run3 run3
      
      Makefile	to	run3
      Makefile	to	run3
      Makefile	to	run3
      Xtest11.two
      run1 run2
      ]])
    -- Use CTRL-X CTRL-F to complete Xtest11.one, remove it and then use.
    -- CTRL-X CTRL-F again to verify this doesn't cause trouble.
    feed('OX<C-X><C-F><C-H><C-H><C-H><C-H><C-H><C-H><C-H><C-H><C-X><C-F><esc>ddk<cr>')
    expect([[
      #include "Xtestfile"
      run1 run3
      run3 run3
      
      Makefile	to	run3
      Makefile	to	run3
      Makefile	to	run3
      Xtest11.two
      run1 run2
      ]])
    execute('set cpt=w')
    feed('OST<C-N><C-P><C-P><C-P><C-P><esc><CR>')
    expect([[
      #include "Xtestfile"
      run1 run3
      run3 run3
      
      Makefile	to	run3
      Makefile	to	run3
      Makefile	to	run3
      Xtest11.two
      STARTTEST
      run1 run2
      ]])
    execute('set cpt=u nohid')
    eq(3, eval('bufnr("%")'))
    eq(2, eval('winnr("$")'))
    feed('<C-W>o')
    eq(1, eval('winnr("$")'))

    -- Check all buffer names.
    local b = {}
    for i = 1, eval('bufnr("$")') do
      b[i] = eval('bufname('..i..')')
    end
    eq({'Xtestfile', 'test/functional/fixtures/test32.in', ''}, b)

    feed('OEN<C-N><cr>')
    feed('unl<C-N><C-X><C-X><C-P><esc><CR>')
    expect([[
      #include "Xtestfile"
      run1 run3
      run3 run3
      
      Makefile	to	run3
      Makefile	to	run3
      Makefile	to	run3
      Xtest11.two
      STARTTEST
      ENDTEST
      unless
      run1 run2
      ]])
    execute([[set cpt=t,d def=^\\k* tags=Xtestfile notagbsearch]])
    feed('O<C-X><ESC><C-X><C-D><C-X><C-D><C-X><C-X><C-D><C-X><C-D><C-X><C-D><C-X><C-D><cr>')
    feed('a<C-N><esc>')

    -- Assert buffer contents.
    expect([[
      #include "Xtestfile"
      run1 run3
      run3 run3
      
      Makefile	to	run3
      Makefile	to	run3
      Makefile	to	run3
      Xtest11.two
      STARTTEST
      ENDTEST
      unless
      test11file	36Gepeto	/Tag/ asd
      asd
      run1 run2
      ]])
  end)
end)
