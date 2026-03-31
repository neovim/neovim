-- Tests for case-insensitive UTF-8 comparisons (utf_strnicmp() in mbyte.c)
-- Also test "g~ap".

local n = require('test.functional.testnvim')()

local feed, source = n.feed, n.source
local clear, feed_command, expect = n.clear, n.feed_command, n.expect

describe('case-insensitive string comparison in UTF-8', function()
  setup(clear)

  it('is working', function()
    feed('ggdG<cr>')
    source([[
      function! Ch(a, op, b, expected)
        if eval(printf('"%s" %s "%s"', a:a, a:op, a:b)) != a:expected
          call append(line('$'), printf('"%s" %s "%s" should return %d', a:a, a:op, a:b, a:expected))
        else
          let b:passed += 1
        endif
      endfunction

      function! Chk(a, b, result)
        if a:result == 0
          call Ch(a:a, '==?', a:b, 1)
          call Ch(a:a, '!=?', a:b, 0)
          call Ch(a:a, '<=?', a:b, 1)
          call Ch(a:a, '>=?', a:b, 1)
          call Ch(a:a, '<?', a:b, 0)
          call Ch(a:a, '>?', a:b, 0)
        elseif a:result > 0
          call Ch(a:a, '==?', a:b, 0)
          call Ch(a:a, '!=?', a:b, 1)
          call Ch(a:a, '<=?', a:b, 0)
          call Ch(a:a, '>=?', a:b, 1)
          call Ch(a:a, '<?', a:b, 0)
          call Ch(a:a, '>?', a:b, 1)
        else
          call Ch(a:a, '==?', a:b, 0)
          call Ch(a:a, '!=?', a:b, 1)
          call Ch(a:a, '<=?', a:b, 1)
          call Ch(a:a, '>=?', a:b, 0)
          call Ch(a:a, '<?', a:b, 1)
          call Ch(a:a, '>?', a:b, 0)
        endif
      endfunction

      function! Check(a, b, result)
        call Chk(a:a, a:b, a:result)
        call Chk(a:b, a:a, -a:result)
      endfunction

      function! LT(a, b)
        call Check(a:a, a:b, -1)
      endfunction

      function! GT(a, b)
        call Check(a:a, a:b, 1)
      endfunction

      function! EQ(a, b)
        call Check(a:a, a:b, 0)
      endfunction

      let b:passed=0
      call EQ('', '')
      call LT('', 'a')
      call EQ('abc', 'abc')
      call EQ('Abc', 'abC')
      call LT('ab', 'abc')
      call LT('AB', 'abc')
      call LT('ab', 'aBc')
      call EQ('\xd0\xb9\xd1\x86\xd1\x83\xd0\xba\xd0\xb5\xd0\xbd', '\xd0\xb9\xd0\xa6\xd0\xa3\xd0\xba\xd0\x95\xd0\xbd')
      call LT('\xd0\xb9\xd1\x86\xd1\x83\xd0\xba\xd0\xb5\xd0\xbd', '\xd0\xaf\xd1\x86\xd1\x83\xd0\xba\xd0\xb5\xd0\xbd')
      call EQ('\xe2\x84\xaa', 'k')
      call LT('\xe2\x84\xaa', 'kkkkkk')
      call EQ('\xe2\x84\xaa\xe2\x84\xaa\xe2\x84\xaa', 'kkk')
      call LT('kk', '\xe2\x84\xaa\xe2\x84\xaa\xe2\x84\xaa')
      call EQ('\xe2\x84\xaa\xe2\x84\xa6k\xe2\x84\xaak\xcf\x89', 'k\xcf\x89\xe2\x84\xaakk\xe2\x84\xa6')
      call EQ('Abc\x80', 'AbC\x80')
      call LT('Abc\x80', 'AbC\x81')
      call LT('Abc', 'AbC\x80')

      " Case folding stops at the first bad character.
      call LT('abc\x80DEF', 'abc\x80def')
      call LT('\xc3XYZ', '\xc3xyz')

      " FF3A (upper), FF5A (lower).
      call EQ('\xef\xbc\xba', '\xef\xbd\x9a')

      " First string is ok and equals \xef\xbd\x9a after folding, second
      " string is illegal and was left unchanged, then the strings were
      " bytewise compared.
      call GT('\xef\xbc\xba', '\xef\xbc\xff')
      call LT('\xc3', '\xc3\x83')
      call EQ('\xc3\xa3xYz', '\xc3\x83XyZ')
      for n in range(0x60, 0xFF)
        call LT(printf('xYz\x%.2X', n-1), printf('XyZ\x%.2X', n))
      endfor
      for n in range(0x80, 0xBF)
        call EQ(printf('xYz\xc2\x%.2XUvW', n), printf('XyZ\xc2\x%.2XuVw', n))
      endfor
      for n in range(0xC0, 0xFF)
        call LT(printf('xYz\xc2\x%.2XUvW', n), printf('XyZ\xc2\x%.2XuVw', n))
      endfor
      call append(0, printf('%d checks passed', b:passed))
    ]])

    -- Test that g~ap changes one paragraph only.
    feed_command('new')
    feed('iabcd<cr><cr>defg<esc>gg0g~ap')
    feed_command('let lns = getline(1,3)')
    feed_command('q!')
    feed_command([[call append(line('$'), lns)]])

    -- Assert buffer contents.
    expect([=[
      3732 checks passed

      ABCD

      defg]=])
  end)
end)
