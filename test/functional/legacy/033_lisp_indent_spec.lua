-- Test for 'lisp'
-- If the lisp feature is not enabled, this will fail!

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local command, expect = helpers.command, helpers.expect
local wait = helpers.wait

describe('lisp indent', function()
  setup(clear)

  -- luacheck: ignore 621 (Indentation)
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

    command('set lisp')
    command('/^(defun')
    feed('=G:/^(defun/,$yank A<cr>')
    wait()

    -- Put @a and clean empty line
    command('%d')
    command('0put a')
    command('$d')

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
