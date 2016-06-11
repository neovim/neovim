-- Test for joining lines with marks in them (and with 'joinspaces' set/reset)

local helpers = require('test.functional.helpers')(after_each)
local feed, insert = helpers.feed, helpers.insert
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('joining lines', function()
  before_each(clear)

  it("keeps marks with different 'joinspaces' settings", function()
    insert([[
      firstline
      asdfasdf.
      asdf
      asdfasdf. 
      asdf
      asdfasdf.  
      asdf
      asdfasdf.	
      asdf
      asdfasdf. 	
      asdf
      asdfasdf.	 
      asdf
      asdfasdf.		
      asdf
      asdfasdf
      asdf
      asdfasdf 
      asdf
      asdfasdf  
      asdf
      asdfasdf	
      asdf
      asdfasdf	 
      asdf
      asdfasdf 	
      asdf
      asdfasdf		
      asdf
      zx cvn.
      as dfg?
      hjkl iop!
      ert
      ]])

    -- Switch off 'joinspaces', then join some lines in the buffer using "J".
    -- Also set a few marks and record their movement when joining lines.
    execute('set nojoinspaces')
    execute('/firstline/')
    feed('j"td/^$/<cr>')
    feed('PJjJjJjJjJjJjJjJjJjJjJjJjJjJ')
    feed('j05lmx2j06lmy2k4Jy3l$p`xyl$p`yy2l$p')

    -- Do the same with 'joinspaces' on.
    execute('set joinspaces')
    feed('j"tp')
    feed('JjJjJjJjJjJjJjJjJjJjJjJjJjJ')
    feed('j05lmx2j06lmy2k4Jy3l$p`xyl$p`yy2l$po<esc>')

    execute('1d')

    expect([[
      asdfasdf. asdf
      asdfasdf. asdf
      asdfasdf.  asdf
      asdfasdf.	asdf
      asdfasdf. 	asdf
      asdfasdf.	 asdf
      asdfasdf.		asdf
      asdfasdf asdf
      asdfasdf asdf
      asdfasdf  asdf
      asdfasdf	asdf
      asdfasdf	 asdf
      asdfasdf 	asdf
      asdfasdf		asdf
      zx cvn. as dfg? hjkl iop! ert ernop
      
      asdfasdf.  asdf
      asdfasdf.  asdf
      asdfasdf.  asdf
      asdfasdf.	asdf
      asdfasdf. 	asdf
      asdfasdf.	 asdf
      asdfasdf.		asdf
      asdfasdf asdf
      asdfasdf asdf
      asdfasdf  asdf
      asdfasdf	asdf
      asdfasdf	 asdf
      asdfasdf 	asdf
      asdfasdf		asdf
      zx cvn.  as dfg?  hjkl iop!  ert  enop
      ]])
  end)

  it("removes comment leaders with 'joinspaces' off", function()
    insert([[
      {
      
      /*
       * Make sure the previous comment leader is not removed.
       */
      
      /*
       * Make sure the previous comment leader is not removed.
       */
      
      // Should the next comment leader be left alone?
      // Yes.
      
      // Should the next comment leader be left alone?
      // Yes.
      
      /* Here the comment leader should be left intact. */
      // And so should this one.
      
      /* Here the comment leader should be left intact. */
      // And so should this one.
      
      if (condition) // Remove the next comment leader!
                     // OK, I will.
          action();
      
      if (condition) // Remove the next comment leader!
                     // OK, I will.
          action();
      }
      ]])

    execute('/^{/+1')
    execute('set comments=s1:/*,mb:*,ex:*/,://')
    execute('set nojoinspaces')
    execute('set backspace=eol,start')

    -- With 'joinspaces' switched off, join lines using both "J" and :join and
    -- verify that comment leaders are stripped or kept as appropriate.
    execute('.,+3join')
    feed('j4J<cr>')
    execute('.,+2join')
    feed('j3J<cr>')
    execute('.,+2join')
    feed('j3J<cr>')
    execute('.,+2join')
    feed('jj3J<cr>')

    expect([[
      {
      /* Make sure the previous comment leader is not removed. */
      /* Make sure the previous comment leader is not removed. */
      // Should the next comment leader be left alone? Yes.
      // Should the next comment leader be left alone? Yes.
      /* Here the comment leader should be left intact. */ // And so should this one.
      /* Here the comment leader should be left intact. */ // And so should this one.
      if (condition) // Remove the next comment leader! OK, I will.
          action();
      if (condition) // Remove the next comment leader! OK, I will.
          action();
      }
      ]])
  end)

  -- This test case has nothing to do with joining lines.
  it("Ctrl-u and 'backspace' compatibility", function()
    -- Notice that the buffer text, which is intended to helpfully hint at
    -- what's being done in the test, is off by one line. (For example, "this
    -- should be deleted" should not be deleted, but the line below it should,
    -- and is.) This is likely a mistake, but was kept here for consistency.
    insert([[
      1 this shouldn't be deleted
      2 this shouldn't be deleted
      3 this shouldn't be deleted
      4 this should be deleted
      5 this shouldn't be deleted
      6 this shouldn't be deleted
      7 this shouldn't be deleted
      8 this shouldn't be deleted (not touched yet)
      ]])

    -- As mentioned above, we mimic the wrong initial cursor position in the old
    -- test by advancing one line further.
    execute([[/^\d\+ this]], '+1')

    -- Test with the default 'backspace' setting.
    feed('Avim1<c-u><esc><cr>')
    feed('Avim2<c-g>u<c-u><esc><cr>')
    execute('set cpo-=<')
    execute('inoremap <c-u> <left><c-u>')
    feed('Avim3<c-u><esc><cr>')
    execute('iunmap <c-u>')
    feed('Avim4<c-u><c-u><esc><cr>')

    -- Test with 'backspace' set to the compatible setting.
    execute('set backspace=')
    feed('A vim5<esc>A<c-u><c-u><esc><cr>')
    feed('A vim6<esc>Azwei<c-g>u<c-u><esc><cr>')
    execute('inoremap <c-u> <left><c-u>')
    feed('A vim7<c-u><c-u><esc><cr>')

    expect([[
      1 this shouldn't be deleted
      2 this shouldn't be deleted
      3 this shouldn't be deleted
      4 this should be deleted3
      
      6 this shouldn't be deleted vim5
      7 this shouldn't be deleted vim6
      8 this shouldn't be deleted (not touched yet) vim7
      ]])
  end)

  it("removes comment leaders with 'joinspaces' on", function()
    insert([[
      {
      
      /*
       * Make sure the previous comment leader is not removed.
       */
      
      /*
       * Make sure the previous comment leader is not removed.
       */
      
      /* List:
       * - item1
       *   foo bar baz
       *   foo bar baz
       * - item2
       *   foo bar baz
       *   foo bar baz
       */
      
      /* List:
       * - item1
       *   foo bar baz
       *   foo bar baz
       * - item2
       *   foo bar baz
       *   foo bar baz
       */
      
      // Should the next comment leader be left alone?
      // Yes.
      
      // Should the next comment leader be left alone?
      // Yes.
      
      /* Here the comment leader should be left intact. */
      // And so should this one.
      
      /* Here the comment leader should be left intact. */
      // And so should this one.
      
      if (condition) // Remove the next comment leader!
                     // OK, I will.
          action();
      
      if (condition) // Remove the next comment leader!
                     // OK, I will.
          action();
      
      int i = 7 /* foo *// 3
       // comment
       ;
      
      int i = 7 /* foo *// 3
       // comment
       ;
      
      ># Note that the last character of the ending comment leader (left angle
       # bracket) is a comment leader itself. Make sure that this comment leader is
       # not removed from the next line #<
      < On this line a new comment is opened which spans 2 lines. This comment should
      < retain its comment leader.
      
      ># Note that the last character of the ending comment leader (left angle
       # bracket) is a comment leader itself. Make sure that this comment leader is
       # not removed from the next line #<
      < On this line a new comment is opened which spans 2 lines. This comment should
      < retain its comment leader.
      
      }
      ]])

    execute('/^{/+1')
    execute([[set comments=sO:*\ -,mO:*\ \ ,exO:*/]])
    execute('set comments+=s1:/*,mb:*,ex:*/,://')
    execute('set comments+=s1:>#,mb:#,ex:#<,:<')
    execute('set backspace=eol,start')

    -- With 'joinspaces' on (the default setting), again join lines and verify
    -- that comment leaders are stripped or kept as appropriate.
    execute('.,+3join')
    feed('j4J<cr>')
    execute('.,+8join')
    feed('j9J<cr>')
    execute('.,+2join')
    feed('j3J<cr>')
    execute('.,+2join')
    feed('j3J<cr>')
    execute('.,+2join')
    feed('jj3J<cr>')
    feed('j')
    execute('.,+2join')
    feed('jj3J<cr>')
    feed('j')
    execute('.,+5join')
    feed('j6J<cr>')
    feed('oSome code!<cr>// Make sure backspacing does not remove this comment leader.<esc>0i<bs><esc>')

    expect([[
      {
      /* Make sure the previous comment leader is not removed.  */
      /* Make sure the previous comment leader is not removed.  */
      /* List: item1 foo bar baz foo bar baz item2 foo bar baz foo bar baz */
      /* List: item1 foo bar baz foo bar baz item2 foo bar baz foo bar baz */
      // Should the next comment leader be left alone?  Yes.
      // Should the next comment leader be left alone?  Yes.
      /* Here the comment leader should be left intact. */ // And so should this one.
      /* Here the comment leader should be left intact. */ // And so should this one.
      if (condition) // Remove the next comment leader!  OK, I will.
          action();
      if (condition) // Remove the next comment leader!  OK, I will.
          action();
      int i = 7 /* foo *// 3 // comment
       ;
      int i = 7 /* foo *// 3 // comment
       ;
      ># Note that the last character of the ending comment leader (left angle bracket) is a comment leader itself. Make sure that this comment leader is not removed from the next line #< < On this line a new comment is opened which spans 2 lines. This comment should retain its comment leader.
      ># Note that the last character of the ending comment leader (left angle bracket) is a comment leader itself. Make sure that this comment leader is not removed from the next line #< < On this line a new comment is opened which spans 2 lines. This comment should retain its comment leader.
      
      Some code!// Make sure backspacing does not remove this comment leader.
      }
      ]])
  end)
end)
