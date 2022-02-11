local helpers = require('test.functional.helpers')(after_each)
local clear, source = helpers.clear, helpers.source
local call, eq, meths = helpers.call, helpers.eq, helpers.meths

local function expected_empty()
  eq({}, meths.get_vvar('errors'))
end

describe('file changed dialog', function()
  before_each(function()
    clear()
    meths.ui_attach(80, 24, {})
    meths.set_option('autoread', false)
    source([[
      func Test_file_changed_dialog()
        au! FileChangedShell

        new Xchanged_d
        call setline(1, 'reload this')
        write
        " Need to wait until the timestamp would change by at least a second.
        sleep 2
        silent !echo 'extra line' >>Xchanged_d
        call nvim_input('L')
        checktime
        call assert_match('W11:', v:warningmsg)
        call assert_equal(2, line('$'))
        call assert_equal('reload this', getline(1))
        call assert_equal('extra line', getline(2))

        " delete buffer, only shows an error, no prompt
        silent !rm Xchanged_d
        checktime
        call assert_match('E211:', v:warningmsg)
        call assert_equal(2, line('$'))
        call assert_equal('extra line', getline(2))
        let v:warningmsg = 'empty'

        " change buffer, recreate the file and reload
        call setline(1, 'buffer is changed')
        silent !echo 'new line' >Xchanged_d
        call nvim_input('L')
        checktime
        call assert_match('W12:', v:warningmsg)
        call assert_equal(1, line('$'))
        call assert_equal('new line', getline(1))

        " Only mode changed, reload
        silent !chmod +x Xchanged_d
        call nvim_input('L')
        checktime
        call assert_match('W16:', v:warningmsg)
        call assert_equal(1, line('$'))
        call assert_equal('new line', getline(1))

        " Only time changed, no prompt
        sleep 2
        silent !touch Xchanged_d
        let v:warningmsg = ''
        checktime
        call assert_equal('', v:warningmsg)
        call assert_equal(1, line('$'))
        call assert_equal('new line', getline(1))

        bwipe!
        call delete('Xchanged_d')
      endfunc
    ]])
  end)

  it('works', function()
    if helpers.pending_win32(pending) then return end
    call('Test_file_changed_dialog')
    expected_empty()
  end)
end)
