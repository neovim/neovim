-- Test filename modifiers.

local t = require('test.functional.testutil')()
local clear, source = t.clear, t.source
local call, eq, nvim = t.call, t.eq, t.api

local function expected_empty()
  eq({}, nvim.nvim_get_vvar('errors'))
end

describe('filename modifiers', function()
  before_each(function()
    clear()

    source([=[
      func Test_fnamemodify()
        if has('win32')
          set shellslash
        else
          set shell=sh
        endif
        let tmpdir = resolve($TMPDIR)
        call assert_true(isdirectory(tmpdir))
        execute 'cd '. tmpdir
        let $HOME=fnamemodify('.', ':p:h:h:h')
        call assert_equal('/', fnamemodify('.', ':p')[-1:])
        call assert_equal(tmpdir[strchars(tmpdir) - 1], fnamemodify('.', ':p:h')[-1:])
        call assert_equal('t', fnamemodify('test.out', ':p')[-1:])
        call assert_equal('test.out', fnamemodify('test.out', ':.'))
        call assert_equal('../testdir/a', fnamemodify('../testdir/a', ':.'))
        call assert_equal(fnamemodify(tmpdir, ':~').'/test.out', fnamemodify('test.out', ':~'))
        call assert_equal(fnamemodify(tmpdir, ':~').'/../testdir/a', fnamemodify('../testdir/a', ':~'))
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
    ]=])
  end)

  it('is working', function()
    call('Test_fnamemodify')
    expected_empty()
  end)
end)
