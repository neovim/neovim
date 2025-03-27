-- Test for user functions.
-- Also test an <expr> mapping calling a function.
-- Also test that a builtin function cannot be replaced.
-- Also test for regression when calling arbitrary expression.

local n = require('test.functional.testnvim')()

local feed, insert, source = n.feed, n.insert, n.source
local clear, feed_command, expect = n.clear, n.feed_command, n.expect

describe(
  'user functions, expr-mappings, overwrite protected builtin functions and regression on calling expressions',
  function()
    setup(clear)

    it('are working', function()
      insert('here')

      source([[
      function Table(title, ...)
        let ret = a:title
        let idx = 1
        while idx <= a:0
          exe "let ret = ret . a:" . idx
          let idx = idx + 1
        endwhile
        return ret
      endfunction
      function Compute(n1, n2, divname)
        if a:n2 == 0
          return "fail"
        endif
        exe "let g:" . a:divname . " = ". a:n1 / a:n2
        return "ok"
      endfunction
      func Expr1()
        normal! v
        return "111"
      endfunc
      func Expr2()
        call search('XX', 'b')
        return "222"
      endfunc
      func ListItem()
        let g:counter += 1
        return g:counter . '. '
      endfunc
      func ListReset()
        let g:counter = 0
        return ''
      endfunc
      func FuncWithRef(a)
        unlet g:FuncRef
        return a:a
      endfunc
      let g:FuncRef=function("FuncWithRef")
      let counter = 0
      inoremap <expr> ( ListItem()
      inoremap <expr> [ ListReset()
      imap <expr> + Expr1()
      imap <expr> * Expr2()
      let retval = "nop"
      /^here
    ]])
      feed('C<C-R>=Table("xxx", 4, "asdf")<cr>')
      feed(' <C-R>=Compute(45, 0, "retval")<cr>')
      feed(' <C-R>=retval<cr>')
      feed(' <C-R>=Compute(45, 5, "retval")<cr>')
      feed(' <C-R>=retval<cr>')
      feed(' <C-R>=g:FuncRef(333)<cr>')
      feed('<cr>')
      feed('XX+-XX<cr>')
      feed('---*---<cr>')
      feed('(one<cr>')
      feed('(two<cr>')
      feed('[(one again<esc>')
      feed_command('call append(line("$"), max([1, 2, 3]))')
      feed_command('call extend(g:, {"max": function("min")})')
      feed_command('call append(line("$"), max([1, 2, 3]))')
      feed_command('try')
      -- Regression: the first line below used to throw "E110: Missing ')'"
      -- Second is here just to prove that this line is correct when not
      -- skipping rhs of &&.
      feed_command([[    $put =(0&&(function('tr'))(1, 2, 3))]])
      feed_command([[    $put =(1&&(function('tr'))(1, 2, 3))]])
      feed_command('catch')
      feed_command([[    $put ='!!! Unexpected exception:']])
      feed_command('    $put =v:exception')
      feed_command('endtry')

      -- Assert buffer contents.
      expect([[
      xxx4asdf fail nop ok 9 333
      XX111-XX
      ---222---
      1. one
      2. two
      1. one again
      3
      3
      0
      1]])
    end)
  end
)
