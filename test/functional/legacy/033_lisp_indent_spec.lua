-- vim: set foldmethod=marker foldmarker=[[,]] :
-- Test for 'lisp'
-- If the lisp feature is not enabled, this will fail!

local helpers = require('test.functional.helpers')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('lisp indent', function()
  setup(clear)

  it('is working', function()
    insert([[
      (defun html-file (base)
      (format nil "~(~A~).html" base))
      
      (defmacro page (name title &rest body)
      (let ((ti (gensym)))
      `(with-open-file (*standard-output*
      (html-file ,name)
      :direction :output
      :if-exists :supersede)
      (let ((,ti ,title))
      (as title ,ti)
      (with center 
      (as h2 (string-upcase ,ti)))
      (brs 3)
      ,@body))))
      
      ;;; Utilities for generating links
      
      (defmacro with-link (dest &rest body)
      `(progn
      (format t "<a href=\"~A\">" (html-file ,dest))
      ,@body
      (princ "</a>")))]])

    execute('set lisp')
    execute('/^(defun')
    feed('=G:/^(defun/,$yank A<cr>')

    -- Put @a and clean empty line
    execute('%d')
    execute('0put a')
    execute('$d')

    -- Assert buffer contents.
    expect([[
      (defun html-file (base)
        (format nil "~(~A~).html" base))
      
      (defmacro page (name title &rest body)
        (let ((ti (gensym)))
          `(with-open-file (*standard-output*
      		       (html-file ,name)
      		       :direction :output
      		       :if-exists :supersede)
             (let ((,ti ,title))
      	 (as title ,ti)
      	 (with center 
      	       (as h2 (string-upcase ,ti)))
      	 (brs 3)
      	 ,@body))))
      
      ;;; Utilities for generating links
      
      (defmacro with-link (dest &rest body)
        `(progn
           (format t "<a href=\"~A\">" (html-file ,dest))
           ,@body
           (princ "</a>")))]])
  end)
end)
