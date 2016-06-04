-- Test for expanding file names

local helpers = require('test.functional.helpers')
local eq = helpers.eq
local call = helpers.call
local nvim = helpers.meths
local clear = helpers.clear
local source = helpers.source

local function expected_empty()
  eq({}, nvim.get_vvar('errors'))
end

describe('expand file name', function()
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
        next! Xdir?/*/nofile
        call assert_equal('Xdir?/*/nofile', expand('%'))

        call delete('Xdir1', 'rf')
        call delete('Xdir2', 'rf')
        call delete('Xdir3', 'rf')
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
end)
