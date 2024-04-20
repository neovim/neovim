local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local eval = n.eval
local exc_exec = n.exc_exec
local expect = n.expect
local insert = n.insert
local source = n.source
local write_file = t.write_file

describe("'tagcase' option", function()
  setup(function()
    write_file(
      'Xtags',
      [[
      Bar	Xtext	3
      Foo	Xtext	2
      foo	Xtext	4]]
    )
  end)

  before_each(function()
    clear()
    source([[
      lang mess C
      set tags=Xtags]])
  end)

  teardown(function()
    os.remove('Xtags')
  end)

  it('should have correct default values', function()
    source([[
      set ic&
      setg tc&
      setl tc&
      ]])

    eq(0, eval('&ic'))
    eq('followic', eval('&g:tc'))
    eq('followic', eval('&l:tc'))
    eq('followic', eval('&tc'))
  end)

  it('should accept <empty> only for setlocal', function()
    -- Verify that the local setting accepts <empty> but that the global setting
    -- does not.  The first of these (setting the local value to <empty>) should
    -- succeed; the other two should fail.
    eq(0, exc_exec('setl tc='))
    eq('Vim(setglobal):E474: Invalid argument: tc=', exc_exec('setg tc='))
    eq('Vim(set):E474: Invalid argument: tc=', exc_exec('set tc='))
  end)

  it("should work with 'ignorecase' correctly in all combinations", function()
    -- Verify that the correct number of matching tags is found for all values of
    -- 'ignorecase' and global and local values 'tagcase', in all combinations.
    insert([[

      Foo
      Bar
      foo

      end text]])

    source([[
      for &ic in [0, 1]
        for &g:tc in ["followic", "ignore", "match"]
          for &l:tc in ["", "followic", "ignore", "match"]
            call append('$', "ic=".&ic." g:tc=".&g:tc." l:tc=".&l:tc." tc=".&tc)
            call append('$', len(taglist("^foo$")))
            call append('$', len(taglist("^Foo$")))
          endfor
        endfor
      endfor

      1,/^end text$/d]])

    expect([[
      ic=0 g:tc=followic l:tc= tc=followic
      1
      1
      ic=0 g:tc=followic l:tc=followic tc=followic
      1
      1
      ic=0 g:tc=followic l:tc=ignore tc=ignore
      2
      2
      ic=0 g:tc=followic l:tc=match tc=match
      1
      1
      ic=0 g:tc=ignore l:tc= tc=ignore
      2
      2
      ic=0 g:tc=ignore l:tc=followic tc=followic
      1
      1
      ic=0 g:tc=ignore l:tc=ignore tc=ignore
      2
      2
      ic=0 g:tc=ignore l:tc=match tc=match
      1
      1
      ic=0 g:tc=match l:tc= tc=match
      1
      1
      ic=0 g:tc=match l:tc=followic tc=followic
      1
      1
      ic=0 g:tc=match l:tc=ignore tc=ignore
      2
      2
      ic=0 g:tc=match l:tc=match tc=match
      1
      1
      ic=1 g:tc=followic l:tc= tc=followic
      2
      2
      ic=1 g:tc=followic l:tc=followic tc=followic
      2
      2
      ic=1 g:tc=followic l:tc=ignore tc=ignore
      2
      2
      ic=1 g:tc=followic l:tc=match tc=match
      1
      1
      ic=1 g:tc=ignore l:tc= tc=ignore
      2
      2
      ic=1 g:tc=ignore l:tc=followic tc=followic
      2
      2
      ic=1 g:tc=ignore l:tc=ignore tc=ignore
      2
      2
      ic=1 g:tc=ignore l:tc=match tc=match
      1
      1
      ic=1 g:tc=match l:tc= tc=match
      1
      1
      ic=1 g:tc=match l:tc=followic tc=followic
      2
      2
      ic=1 g:tc=match l:tc=ignore tc=ignore
      2
      2
      ic=1 g:tc=match l:tc=match tc=match
      1
      1]])
  end)
end)
