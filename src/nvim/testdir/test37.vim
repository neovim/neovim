
let s:_test_number = 1
function! Write_Test_Data(...)
  execute 'redir! > Ytestdata.'.s:_test_number
    silent echo 'args:' a:000
    silent echo 'cursor:' getpos('.')
    silent echo 'wintop:' getpos('w0')
    silent echo 'winbot:' getpos('w$')
    silent echo 'winnr:' winnr()
    silent echo 'line:' getline('.')
  redir end
  let s:_test_number += 1
endfunction
