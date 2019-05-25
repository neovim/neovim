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
end)
