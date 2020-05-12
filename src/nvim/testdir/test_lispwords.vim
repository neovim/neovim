" Tests for 'lispwords' settings being global-local

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
  set lisp
  set lispwords&
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
