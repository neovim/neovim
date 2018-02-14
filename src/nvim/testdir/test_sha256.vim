" Tests for the sha256() function.

if !has('cryptv') || !exists('*sha256')
  finish
endif

function Test_sha256()
  " test for empty string:
  call assert_equal(sha256(""), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855')

  "'test for 1 char:
  call assert_equal(sha256("a"), 'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb')
  "
  "test for 3 chars:
  call assert_equal(sha256("abc"), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')

  " test for contains meta char:
  call assert_equal(sha256("foo\nbar"), '807eff6267f3f926a21d234f7b0cf867a86f47e07a532f15e8cc39ed110ca776')

  " test for contains non-ascii char:
  call assert_equal(sha256("\xde\xad\xbe\xef"), '5f78c33274e43fa9de5659265c1d917e25c03722dcb0b8d27db8d5feaa813953')
endfunction
