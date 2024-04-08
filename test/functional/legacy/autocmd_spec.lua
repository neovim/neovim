local t = require('test.functional.testutil')(after_each)
local clear = t.clear
local write_file = t.write_file
local command = t.command
local feed = t.feed
local api = t.api
local eq = t.eq

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
