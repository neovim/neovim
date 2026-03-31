" Test for joining lines.

func Test_join_with_count()
  new
  call setline(1, ['one', 'two', 'three', 'four'])
  normal J
  call assert_equal('one two', getline(1))
  %del
  call setline(1, ['one', 'two', 'three', 'four'])
  normal 10J
  call assert_equal('one two three four', getline(1))

  call setline(1, ['one', '', 'two'])
  normal J
  call assert_equal('one', getline(1))

  call setline(1, ['one', ' ', 'two'])
  normal J
  call assert_equal('one', getline(1))

  call setline(1, ['one', '', '', 'two'])
  normal JJ
  call assert_equal('one', getline(1))

  call setline(1, ['one', ' ', ' ', 'two'])
  normal JJ
  call assert_equal('one', getline(1))

  call setline(1, ['one', '', '', 'two'])
  normal 2J
  call assert_equal('one', getline(1))

  quit!
endfunc

" Tests for setting the '[,'] marks when joining lines.
func Test_join_marks()
  enew
  call append(0, [
	      \ "\t\tO sodales, ludite, vos qui",
	      \ "attamen consulite per voster honur. Tua pulchra " .
	      \ "facies me fay planszer milies",
	      \ "",
	      \ "This line.",
	      \ "Should be joined with the next line",
	      \ "and with this line"])

  normal gg0gqj
  call assert_equal([0, 1, 1, 0], getpos("'["))
  call assert_equal([0, 2, 1, 0], getpos("']"))

  /^This line/;'}-join
  call assert_equal([0, 4, 11, 0], getpos("'["))
  call assert_equal([0, 4, 67, 0], getpos("']"))
  enew!
endfunc

" Test for joining lines and marks in them
"   in compatible and nocompatible modes
"   and with 'joinspaces' set or not
"   and with 'cpoptions' flag 'j' set or not
func Test_join_spaces_marks()
  new
  " Text used for the test
  insert
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
zx cvn.
as dfg?
hjkl iop!
ert
.
  let text = getline(1, '$')
  normal gg

  set nojoinspaces
  set cpoptions-=j
  normal JjJjJjJjJjJjJjJjJjJjJjJjJjJ
  normal j05lmx
  normal 2j06lmy
  normal 2k4Jy3l$p
  normal `xyl$p
  normal `yy2l$p

  " set cpoptions+=j
  normal j05lmx
  normal 2j06lmy
  normal 2k4Jy3l$p
  normal `xyl$p
  normal `yy2l$p

  " Expected output
  let expected =<< trim [DATA]
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
    zx cvn. as dfg? hjkl iop! ert ernop
  [DATA]

  call assert_equal(expected, getline(1, '$'))
  throw 'skipped: Nvim does not support "set compatible" or "set cpoptions+=j"'

  enew!
  call append(0, text)
  normal gg

  set cpoptions-=j
  set joinspaces
  normal JjJjJjJjJjJjJjJjJjJjJjJjJjJ
  normal j05lmx
  normal 2j06lmy
  normal 2k4Jy3l$p
  normal `xyl$p
  normal `yy2l$p

  set cpoptions+=j
  normal j05lmx
  normal 2j06lmy
  normal 2k4Jy3l$p
  normal `xyl$p
  normal `yy2l$p

  " Expected output
  let expected =<< trim [DATA]
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
    zx cvn.  as dfg? hjkl iop! ert ernop

  [DATA]

  call assert_equal(expected, getline(1, '$'))

  enew!
  call append(0, text)
  normal gg

  set cpoptions-=j
  set nojoinspaces
  set compatible

  normal JjJjJjJjJjJjJjJjJjJjJjJjJjJ
  normal j4Jy3l$pjdG

  " Expected output
  let expected =<< trim [DATA]
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
    zx cvn.  as dfg? hjkl iop! ert  a
  [DATA]

  call assert_equal(expected, getline(1, '$'))

  set nocompatible
  set cpoptions&vim
  set joinspaces&vim
  close!
endfunc

" Test for joining lines with comments
func Test_join_lines_with_comments()
  new

  " Text used by the test
  insert
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
.

  call cursor(2, 1)
  set comments=s1:/*,mb:*,ex:*/,://
  set nojoinspaces fo=j
  set backspace=eol,start

  .,+3join
  exe "normal j4J\<CR>"
  .,+2join
  exe "normal j3J\<CR>"
  .,+2join
  exe "normal j3J\<CR>"
  .,+2join
  exe "normal jj3J\<CR>"

  " Expected output
  let expected =<< trim [CODE]
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
  [CODE]

  call assert_equal(expected, getline(1, '$'))

  set comments&vim
  set joinspaces&vim
  set fo&vim
  set backspace&vim
  close!
endfunc

" Test for joining lines with different comment leaders
func Test_join_comments_2()
  new

  insert
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
.

  call cursor(2, 1)
  set comments=sO:*\ -,mO:*\ \ ,exO:*/
  set comments+=s1:/*,mb:*,ex:*/,://
  set comments+=s1:>#,mb:#,ex:#<,:<
  set cpoptions-=j joinspaces fo=j
  set backspace=eol,start

  .,+3join
  exe "normal j4J\<CR>"
  .,+8join
  exe "normal j9J\<CR>"
  .,+2join
  exe "normal j3J\<CR>"
  .,+2join
  exe "normal j3J\<CR>"
  .,+2join
  exe "normal jj3J\<CR>j"
  .,+2join
  exe "normal jj3J\<CR>j"
  .,+5join
  exe "normal j6J\<CR>"
  exe "normal oSome code!\<CR>// Make sure backspacing does not remove this comment leader.\<Esc>0i\<C-H>\<Esc>"

  " Expected output
  let expected =<< trim [CODE]
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
  [CODE]

  call assert_equal(expected, getline(1, '$'))
  close!
endfunc

func Test_join_lines()
  new
  call setline(1, ['a', 'b', '', 'c', 'd'])
  %join
  call assert_equal('a b c d', getline(1))
  call setline(1, ['a', 'b', '', 'c', 'd'])
  normal 5J
  call assert_equal('a b c d', getline(1))
  call setline(1, ['a', 'b', 'c'])
  2,2join
  call assert_equal(['a', 'b', 'c'], getline(1, '$'))
  call assert_equal(2, line('.'))
  2join
  call assert_equal(['a', 'b c'], getline(1, '$'))
  bwipe!
endfunc
