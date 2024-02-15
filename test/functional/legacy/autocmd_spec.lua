local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local write_file = helpers.write_file
local command = helpers.command
local feed = helpers.feed
local api = helpers.api
local eq = helpers.eq

before_each(clear)

-- oldtest: Test_autocmd_invalidates_undo_on_textchanged()
it('no E440 in quickfix window when autocommand invalidates undo', function()
  write_file(
    'XTest_autocmd_invalidates_undo_on_textchanged',
    [[
    set hidden
    " create quickfix list (at least 2 lines to move line)
    vimgrep /u/j %

    " enter quickfix window
    cwindow

    " set modifiable
    setlocal modifiable

    " set autocmd to clear quickfix list

    autocmd! TextChanged <buffer> call setqflist([])
    " move line
    move+1
    ]]
  )
  finally(function()
    os.remove('XTest_autocmd_invalidates_undo_on_textchanged')
  end)
  command('edit XTest_autocmd_invalidates_undo_on_textchanged')
  command('so %')
  feed('G')
  eq('', api.nvim_get_vvar('errmsg'))
end)
