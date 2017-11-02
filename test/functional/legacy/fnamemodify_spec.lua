-- Test filename modifiers.

local helpers = require('test.functional.helpers')(after_each)
local clear, source = helpers.clear, helpers.source
local call, eq, nvim = helpers.call, helpers.eq, helpers.meths

local function expected_empty()
  eq({}, nvim.get_vvar('errors'))
end

describe('filename modifiers', function()
  before_each(function()
    clear()

    source([=[
      func Test_fnamemodify()
        if has('win32')
          let tmpdir = substitute($TMP, '\\', '/', 'g')
          set shellslash
        else
          let tmpdir = resolve('/tmp')
          set shell=sh
        endif
        execute 'cd '. tmpdir
        let $HOME=fnamemodify('.', ':p:h:h:h')
        call assert_equal('/', fnamemodify('.', ':p')[-1:])
        if has('win32')
          call assert_equal('p', fnamemodify('.', ':p:h:h')[-1:])
        else
          call assert_equal('p', fnamemodify('.', ':p:h')[-1:])
        endif
        call assert_equal('t', fnamemodify('test.out', ':p')[-1:])
        call assert_equal('test.out', fnamemodify('test.out', ':.'))
        call assert_equal('../testdir/a', fnamemodify('../testdir/a', ':.'))
        if has('win32')
          call assert_equal('test.out', fnamemodify('test.out', ':~:.'))
        else
          call assert_equal('test.out', fnamemodify('test.out', ':~'))
        endif
        call assert_equal('../testdir/a', fnamemodify('../testdir/a', ':~'))
        call assert_equal('a', fnamemodify('../testdir/a', ':t'))
        call assert_equal('', fnamemodify('.', ':p:t'))
        call assert_equal('test.out', fnamemodify('test.out', ':p:t'))
        call assert_equal('out', fnamemodify('test.out', ':p:e'))
        call assert_equal('out', fnamemodify('test.out', ':p:t:e'))
        call assert_equal('abc.fb2.tar', fnamemodify('abc.fb2.tar.gz', ':r'))
        call assert_equal('abc.fb2', fnamemodify('abc.fb2.tar.gz', ':r:r'))
        call assert_equal('abc', fnamemodify('abc.fb2.tar.gz', ':r:r:r'))
        call assert_equal(tmpdir .'/abc.fb2', substitute(fnamemodify('abc.fb2.tar.gz', ':p:r:r'), '.*\(nvim/testdir/.*\)', '\1', ''))
        call assert_equal('gz', fnamemodify('abc.fb2.tar.gz', ':e'))
        call assert_equal('tar.gz', fnamemodify('abc.fb2.tar.gz', ':e:e'))
        call assert_equal('fb2.tar.gz', fnamemodify('abc.fb2.tar.gz', ':e:e:e'))
        call assert_equal('fb2.tar.gz', fnamemodify('abc.fb2.tar.gz', ':e:e:e:e'))
        call assert_equal('tar', fnamemodify('abc.fb2.tar.gz', ':e:e:r'))
        call assert_equal('''abc def''', fnamemodify('abc def', ':S'))
        call assert_equal('''abc" "def''', fnamemodify('abc" "def', ':S'))
        call assert_equal('''abc"%"def''', fnamemodify('abc"%"def', ':S'))
        call assert_equal('''abc''\'''' ''\''''def''', fnamemodify('abc'' ''def', ':S'))
        call assert_equal('''abc''\''''%''\''''def''', fnamemodify('abc''%''def', ':S'))
        new foo.txt
        call assert_equal(expand('%:r:S'), shellescape(expand('%:r')))
        call assert_equal('foo,''foo'',foo.txt', join([expand('%:r'), expand('%:r:S'), expand('%')], ','))
        quit

        call assert_equal("'abc\ndef'", fnamemodify("abc\ndef", ':S'))
        if executable('tcsh')
          set shell=tcsh
          call assert_equal("'abc\\\ndef'", fnamemodify("abc\ndef", ':S'))
        endif
      endfunc

      func Test_expand()
        new
        call assert_equal("", expand('%:S'))
        quit
      endfunc
    ]=])
  end)

  it('is working', function()
    call('Test_fnamemodify')
    expected_empty()
  end)

  it('works for :S in an unnamed buffer', function()
    call('Test_expand')
    expected_empty()
  end)
end)
