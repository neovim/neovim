-- Test filename modifiers.

local helpers = require('test.functional.helpers')
local clear = helpers.clear
local execute, expect = helpers.execute, helpers.expect

describe('filename modifiers', function()
  setup(clear)

  it('is working', function()
    local tmpdir = helpers.nvim('eval', 'resolve("/tmp")')

    execute('cd ' .. tmpdir)
    execute([=[set shell=sh]=])
    execute([=[set shellslash]=])
    execute([=[let tab="\t"]=])
    execute([=[command -nargs=1 Put :let expr=<q-args> | $put =expr.tab.strtrans(string(eval(expr)))]=])
    execute([=[let $HOME=fnamemodify('.', ':p:h:h:h')]=])
    execute([=[Put fnamemodify('.',              ':p'      )[-1:]]=])
    execute([=[Put fnamemodify('.',              ':p:h'    )[-1:]]=])
    execute([=[Put fnamemodify('test.out',       ':p'      )[-1:]]=])
    execute([=[Put fnamemodify('test.out',       ':.'      )]=])
    execute([=[Put fnamemodify('../testdir/a',   ':.'      )]=])
    execute([=[Put fnamemodify('test.out',       ':~'      )]=])
    execute([=[Put fnamemodify('../testdir/a',   ':~'      )]=])
    execute([=[Put fnamemodify('../testdir/a',   ':t'      )]=])
    execute([=[Put fnamemodify('.',              ':p:t'    )]=])
    execute([=[Put fnamemodify('test.out',       ':p:t'    )]=])
    execute([=[Put fnamemodify('test.out',       ':p:e'    )]=])
    execute([=[Put fnamemodify('test.out',       ':p:t:e'  )]=])
    execute([=[Put fnamemodify('abc.fb2.tar.gz', ':r'      )]=])
    execute([=[Put fnamemodify('abc.fb2.tar.gz', ':r:r'    )]=])
    execute([=[Put fnamemodify('abc.fb2.tar.gz', ':r:r:r'  )]=])
    execute([=[Put substitute(fnamemodify('abc.fb2.tar.gz', ':p:r:r'), '.*\(nvim/testdir/.*\)', '\1', '')]=])
    execute([=[Put fnamemodify('abc.fb2.tar.gz', ':e'      )]=])
    execute([=[Put fnamemodify('abc.fb2.tar.gz', ':e:e'    )]=])
    execute([=[Put fnamemodify('abc.fb2.tar.gz', ':e:e:e'  )]=])
    execute([=[Put fnamemodify('abc.fb2.tar.gz', ':e:e:e:e')]=])
    execute([=[Put fnamemodify('abc.fb2.tar.gz', ':e:e:r'  )]=])
    execute([=[Put fnamemodify('abc def',        ':S'      )]=])
    execute([=[Put fnamemodify('abc" "def',      ':S'      )]=])
    execute([=[Put fnamemodify('abc"%"def',      ':S'      )]=])
    execute([=[Put fnamemodify('abc'' ''def',    ':S'      )]=])
    execute([=[Put fnamemodify('abc''%''def',    ':S'      )]=])
    execute([=[Put fnamemodify("abc\ndef",       ':S'      )]=])
    execute([=[set shell=tcsh]=])
    execute([=[Put fnamemodify("abc\ndef",       ':S'      )]=])
    execute([=[1 delete _]=])

    -- Assert buffer contents.
    expect([=[
      fnamemodify('.',              ':p'      )[-1:]	'/'
      fnamemodify('.',              ':p:h'    )[-1:]	'p'
      fnamemodify('test.out',       ':p'      )[-1:]	't'
      fnamemodify('test.out',       ':.'      )	'test.out'
      fnamemodify('../testdir/a',   ':.'      )	'../testdir/a'
      fnamemodify('test.out',       ':~'      )	'test.out'
      fnamemodify('../testdir/a',   ':~'      )	'../testdir/a'
      fnamemodify('../testdir/a',   ':t'      )	'a'
      fnamemodify('.',              ':p:t'    )	''
      fnamemodify('test.out',       ':p:t'    )	'test.out'
      fnamemodify('test.out',       ':p:e'    )	'out'
      fnamemodify('test.out',       ':p:t:e'  )	'out'
      fnamemodify('abc.fb2.tar.gz', ':r'      )	'abc.fb2.tar'
      fnamemodify('abc.fb2.tar.gz', ':r:r'    )	'abc.fb2'
      fnamemodify('abc.fb2.tar.gz', ':r:r:r'  )	'abc'
      substitute(fnamemodify('abc.fb2.tar.gz', ':p:r:r'), '.*\(nvim/testdir/.*\)', '\1', '')	']=] .. tmpdir .. [=[/abc.fb2'
      fnamemodify('abc.fb2.tar.gz', ':e'      )	'gz'
      fnamemodify('abc.fb2.tar.gz', ':e:e'    )	'tar.gz'
      fnamemodify('abc.fb2.tar.gz', ':e:e:e'  )	'fb2.tar.gz'
      fnamemodify('abc.fb2.tar.gz', ':e:e:e:e')	'fb2.tar.gz'
      fnamemodify('abc.fb2.tar.gz', ':e:e:r'  )	'tar'
      fnamemodify('abc def',        ':S'      )	'''abc def'''
      fnamemodify('abc" "def',      ':S'      )	'''abc" "def'''
      fnamemodify('abc"%"def',      ':S'      )	'''abc"%"def'''
      fnamemodify('abc'' ''def',    ':S'      )	'''abc''\'''' ''\''''def'''
      fnamemodify('abc''%''def',    ':S'      )	'''abc''\''''%''\''''def'''
      fnamemodify("abc\ndef",       ':S'      )	'''abc^@def'''
      fnamemodify("abc\ndef",       ':S'      )	'''abc\^@def''']=])
  end)
end)
