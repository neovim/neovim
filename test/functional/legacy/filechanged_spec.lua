local helpers = require('test.functional.helpers')(after_each)
local clear, source = helpers.clear, helpers.source
local call, eq, api = helpers.call, helpers.eq, helpers.api
local is_os = helpers.is_os
local skip = helpers.skip

local function expected_empty()
  eq({}, api.nvim_get_vvar('errors'))
end

describe('file changed dialog', function()
  before_each(function()
    clear()
    api.nvim_ui_attach(80, 24, {})
    api.nvim_set_option_value('autoread', false, {})
    api.nvim_set_option_value('fsync', true, {})
  end)

  it('works', function()
    skip(is_os('win'))
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
        checktime Xchanged_d
        call assert_equal('', v:warningmsg)
        call assert_equal(1, line('$'))
        call assert_equal('new line', getline(1))

        " File created after starting to edit it
        call delete('Xchanged_d')
        new Xchanged_d
        call writefile(['one'], 'Xchanged_d')
        call nvim_input('L')
        checktime Xchanged_d
        call assert_equal(['one'], getline(1, '$'))
        close!

        bwipe!
        call delete('Xchanged_d')
      endfunc
    ]])
    call('Test_file_changed_dialog')
    expected_empty()
  end)

  it('works with FileChangedShell', function()
    source([[
      func Test_FileChangedShell_edit_dialog()
        new Xchanged_r
        call setline(1, 'reload this')
        set fileformat=unix
        silent write  " Use :silent to prevent a hit-enter prompt

        " File format changed, reload (content only) via prompt
        augroup testreload
          au!
          au FileChangedShell Xchanged_r let g:reason = v:fcs_reason | let v:fcs_choice = 'ask'
        augroup END
        call assert_equal(&fileformat, 'unix')
        sleep 10m  " make the test less flaky in Nvim
        call writefile(["line1\r", "line2\r"], 'Xchanged_r')
        let g:reason = ''
        call nvim_input('L') " load file content only
        checktime
        call assert_equal('changed', g:reason)
        call assert_equal(&fileformat, 'unix')
        call assert_equal("line1\r", getline(1))
        call assert_equal("line2\r", getline(2))
        %s/\r
        silent write  " Use :silent to prevent a hit-enter prompt

        " File format changed, reload (file and options) via prompt
        augroup testreload
          au!
          au FileChangedShell Xchanged_r let g:reason = v:fcs_reason | let v:fcs_choice = 'ask'
        augroup END
        call assert_equal(&fileformat, 'unix')
        sleep 10m  " make the test less flaky in Nvim
        call writefile(["line1\r", "line2\r"], 'Xchanged_r')
        let g:reason = ''
        call nvim_input('a') " load file content and options
        checktime
        call assert_equal('changed', g:reason)
        call assert_equal(&fileformat, 'dos')
        call assert_equal("line1", getline(1))
        call assert_equal("line2", getline(2))
        set fileformat=unix
        silent write  " Use :silent to prevent a hit-enter prompt

        au! testreload
        bwipe!
        call delete(undofile('Xchanged_r'))
        call delete('Xchanged_r')
      endfunc
    ]])
    call('Test_FileChangedShell_edit_dialog')
    expected_empty()
  end)
end)
