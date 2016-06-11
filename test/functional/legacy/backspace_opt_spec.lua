local helpers = require('test.functional.helpers')(after_each)
local call, clear = helpers.call, helpers.clear
local source, eq, nvim = helpers.source, helpers.eq, helpers.meths

describe("test 'backspace' settings", function()
  before_each(function()
    clear()

    source([[
      func Exec(expr)
        let str=''
        try
          exec a:expr
        catch /.*/
          let str=v:exception
        endtry
        return str
      endfunc

      func Test_backspace_option()
        set backspace=
        call assert_equal('', &backspace)
        set backspace=indent
        call assert_equal('indent', &backspace)
        set backspace=eol
        call assert_equal('eol', &backspace)
        set backspace=start
        call assert_equal('start', &backspace)
        " Add the value
        set backspace=
        set backspace=indent
        call assert_equal('indent', &backspace)
        set backspace+=eol
        call assert_equal('indent,eol', &backspace)
        set backspace+=start
        call assert_equal('indent,eol,start', &backspace)
        " Delete the value
        set backspace-=indent
        call assert_equal('eol,start', &backspace)
        set backspace-=start
        call assert_equal('eol', &backspace)
        set backspace-=eol
        call assert_equal('', &backspace)
        " Check the error
        call assert_equal(0, match(Exec('set backspace=ABC'), '.*E474'))
        call assert_equal(0, match(Exec('set backspace+=def'), '.*E474'))
        " NOTE: Vim doesn't check following error...
        "call assert_equal(0, match(Exec('set backspace-=ghi'), '.*E474'))

        " Check backwards compatibility with version 5.4 and earlier
        set backspace=0
        call assert_equal('0', &backspace)
        set backspace=1
        call assert_equal('1', &backspace)
        set backspace=2
        call assert_equal('2', &backspace)
        call assert_false(match(Exec('set backspace=3'), '.*E474'))
        call assert_false(match(Exec('set backspace=10'), '.*E474'))
      endfunc
    ]])
  end)

  it('works', function()
    call('Test_backspace_option')
    eq({}, nvim.get_vvar('errors'))
  end)
end)
