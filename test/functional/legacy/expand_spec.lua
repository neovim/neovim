-- Test for expanding file names

local helpers = require('test.functional.helpers')(after_each)
local eq = helpers.eq
local call = helpers.call
local nvim = helpers.meths
local clear = helpers.clear
local source = helpers.source

local function expected_empty()
  eq({}, nvim.get_vvar('errors'))
end

describe('expand file name', function()
  after_each(function()
    helpers.rmdir('Xdir1')
    helpers.rmdir('Xdir2')
    helpers.rmdir('Xdir3')
    helpers.rmdir('Xdir4')
  end)

  before_each(function()
    clear()

    source([[
      func Test_with_directories()
        call mkdir('Xdir1')
        call mkdir('Xdir2')
        call mkdir('Xdir3')
        cd Xdir3
        call mkdir('Xdir4')
        cd ..

        split Xdir1/file
        call setline(1, ['a', 'b'])
        w
        w Xdir3/Xdir4/file
        close

        next Xdir?/*/file
        call assert_equal('Xdir3/Xdir4/file', expand('%'))
				if has('unix')
					next! Xdir?/*/nofile
					call assert_equal('Xdir?/*/nofile', expand('%'))
				endif
        " Edit another file, on MS-Windows the swap file would be in use and can't
        " be deleted
        edit foo

        call assert_equal(0, delete('Xdir1', 'rf'))
        call assert_equal(0, delete('Xdir2', 'rf'))
        call assert_equal(0, delete('Xdir3', 'rf'))
      endfunc

      func Test_with_tilde()
        let dir = getcwd()
        call mkdir('Xdir ~ dir')
        call assert_true(isdirectory('Xdir ~ dir'))
        cd Xdir\ ~\ dir
        call assert_true(getcwd() =~ 'Xdir \~ dir')
        exe 'cd ' . fnameescape(dir)
        call delete('Xdir ~ dir', 'd')
        call assert_false(isdirectory('Xdir ~ dir'))
      endfunc

      func Test_expand_tilde_filename()
        split ~
        call assert_equal('~', expand('%'))
        call assert_notequal(expand('%:p'), expand('~/'))
        call assert_match('\~', expand('%:p'))
        bwipe!
      endfunc

      func Test_expandcmd()
        let $FOO = 'Test'
        call assert_equal('e x/Test/y', expandcmd('e x/$FOO/y'))
        unlet $FOO

        new
        edit Xfile1
        call assert_equal('e Xfile1', expandcmd('e %'))
        edit Xfile2
        edit Xfile1
        call assert_equal('e Xfile2', 'e #'->expandcmd())
        edit Xfile2
        edit Xfile3
        edit Xfile4
        let bnum = bufnr('Xfile2')
        call assert_equal('e Xfile2', expandcmd('e #' . bnum))
        call setline('.', 'Vim!@#')
        call assert_equal('e Vim', expandcmd('e <cword>'))
        call assert_equal('e Vim!@#', expandcmd('e <cWORD>'))
        enew!
        edit Xfile.java
        call assert_equal('e Xfile.py', expandcmd('e %:r.py'))
        call assert_equal('make abc.java', expandcmd('make abc.%:e'))
        call assert_equal('make Xabc.java', expandcmd('make %:s?file?abc?'))
        edit a1a2a3.rb
        call assert_equal('make b1b2b3.rb a1a2a3 Xfile.o', expandcmd('make %:gs?a?b? %< #<.o'))

        call assert_fails('call expandcmd("make <afile>")', 'E495:')
        call assert_fails('call expandcmd("make <afile>")', 'E495:')
        enew
        call assert_fails('call expandcmd("make %")', 'E499:')
        close
      endfunc
    ]])
  end)

  it('works with directories', function()
    call('Test_with_directories')
    expected_empty()
  end)

  it('works with tilde', function()
    call('Test_with_tilde')
    expected_empty()
  end)

  it('does not expand tilde if it is a filename', function()
    call('Test_expand_tilde_filename')
    expected_empty()
  end)

  it('works with expandcmd()', function()
    call('Test_expandcmd')
    expected_empty()
  end)
end)
