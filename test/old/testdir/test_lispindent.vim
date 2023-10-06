" Tests for 'lispwords' settings being global-local.
" And  other lisp indent stuff.

set nocompatible viminfo+=nviminfo

func Test_global_local_lispwords()
  setglobal lispwords=foo,bar,baz
  setlocal lispwords-=foo | setlocal lispwords+=quux
  call assert_equal('foo,bar,baz', &g:lispwords)
  call assert_equal('bar,baz,quux', &l:lispwords)
  call assert_equal('bar,baz,quux', &lispwords)

  setlocal lispwords<
  call assert_equal('foo,bar,baz', &g:lispwords)
  call assert_equal('foo,bar,baz', &l:lispwords)
  call assert_equal('foo,bar,baz', &lispwords)
endfunc

func Test_lisp_indent()
  enew!

  call append(0, [
	      \ '(defun html-file (base)',
	      \ '(format nil "~(~A~).html" base))',
	      \ '',
	      \ '(defmacro page (name title &rest body)',
	      \ '(let ((ti (gensym)))',
	      \ '`(with-open-file (*standard-output*',
	      \ '(html-file ,name)',
	      \ ':direction :output',
	      \ ':if-exists :supersede)',
	      \ '(let ((,ti ,title))',
	      \ '(as title ,ti)',
	      \ '(with center ',
	      \ '(as h2 (string-upcase ,ti)))',
	      \ '(brs 3)',
	      \ ',@body))))',
	      \ '',
	      \ ';;; Utilities for generating links',
	      \ '',
	      \ '(defmacro with-link (dest &rest body)',
	      \ '`(progn',
	      \ '(format t "<a href=\"~A\">" (html-file ,dest))',
	      \ ',@body',
	      \ '(princ "</a>")))'
	      \ ])
  call assert_equal(7, lispindent(2))
  call assert_equal(5, 6->lispindent())
  call assert_equal(-1, lispindent(-1))

  set lisp
  set lispwords&
  throw 'Skipped: cpo+=p not supported'
  let save_copt = &cpoptions
  set cpoptions+=p
  normal 1G=G

  call assert_equal([
	      \ '(defun html-file (base)',
	      \ '  (format nil "~(~A~).html" base))',
	      \ '',
	      \ '(defmacro page (name title &rest body)',
	      \ '  (let ((ti (gensym)))',
	      \ '       `(with-open-file (*standard-output*',
	      \ '			 (html-file ,name)',
	      \ '			 :direction :output',
	      \ '			 :if-exists :supersede)',
	      \ '			(let ((,ti ,title))',
	      \ '			     (as title ,ti)',
	      \ '			     (with center ',
	      \ '				   (as h2 (string-upcase ,ti)))',
	      \ '			     (brs 3)',
	      \ '			     ,@body))))',
	      \ '',
	      \ ';;; Utilities for generating links',
	      \ '',
	      \ '(defmacro with-link (dest &rest body)',
	      \ '  `(progn',
	      \ '    (format t "<a href=\"~A\">" (html-file ,dest))',
	      \ '    ,@body',
	      \ '    (princ "</a>")))',
	      \ ''
	      \ ], getline(1, "$"))

  enew!
  let &cpoptions=save_copt
  set nolisp
endfunc

func Test_lispindent_negative()
  " in legacy script there is no error
  call assert_equal(-1, lispindent(-1))
endfunc

func Test_lispindent_with_indentexpr()
  enew
  setl ai lisp nocin indentexpr=11
  exe "normal a(x\<CR>1\<CR>2)\<Esc>"
  let expected = ['(x', '  1', '  2)']
  call assert_equal(expected, getline(1, 3))
  " with Lisp indenting the first line is not indented
  normal 1G=G
  call assert_equal(expected, getline(1, 3))

  %del
  setl lispoptions=expr:1 indentexpr=5
  exe "normal a(x\<CR>1\<CR>2)\<Esc>"
  let expected_expr = ['(x', '     1', '     2)']
  call assert_equal(expected_expr, getline(1, 3))
  normal 2G2<<=G
  call assert_equal(expected_expr, getline(1, 3))

  setl lispoptions=expr:0
  " with Lisp indenting the first line is not indented
  normal 1G3<<=G
  call assert_equal(expected, getline(1, 3))

  bwipe!
endfunc

func Test_lisp_indent_works()
  " This was reading beyond the end of the line
  new
  exe "norm a\tü(\<CR>="
  set lisp
  norm ==
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
