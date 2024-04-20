-- Tests for sha256() function.

local n = require('test.functional.testnvim')()

local insert, source = n.insert, n.source
local clear, expect = n.clear, n.expect

describe('sha256()', function()
  setup(clear)

  it('is working', function()
    insert('start:')

    source([[
      let testcase='test for empty string: '
      if sha256("") ==# 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
       let res='ok'
      else
       let res='ng'
      endif
      $put =testcase.res

      let testcase='test for 1 char: '
      if sha256("a") ==# 'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb'
       let res='ok'
      else
       let res='ng'
      endif
      $put =testcase.res

      let testcase='test for 3 chars: '
      if sha256("abc") ==# 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
       let res='ok'
      else
       let res='ng'
      endif
      $put =testcase.res

      let testcase='test for contains meta char: '
      if sha256("foo\nbar") ==# '807eff6267f3f926a21d234f7b0cf867a86f47e07a532f15e8cc39ed110ca776'
       let res='ok'
      else
       let res='ng'
      endif
      $put =testcase.res

      let testcase='test for contains non-ascii char: '
      if sha256("\xde\xad\xbe\xef") ==# '5f78c33274e43fa9de5659265c1d917e25c03722dcb0b8d27db8d5feaa813953'
       let res='ok'
      else
       let res='ng'
      endif
      $put =testcase.res
    ]])

    -- Assert buffer contents.
    expect([[
      start:
      test for empty string: ok
      test for 1 char: ok
      test for 3 chars: ok
      test for contains meta char: ok
      test for contains non-ascii char: ok]])
  end)
end)
