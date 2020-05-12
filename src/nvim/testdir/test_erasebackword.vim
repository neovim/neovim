
func Test_erasebackword()
  enew

  exe "normal o wwwこんにちわ世界ワールドvim \<C-W>"
  call assert_equal(' wwwこんにちわ世界ワールド', getline('.'))
  exe "normal o wwwこんにちわ世界ワールドvim \<C-W>\<C-W>"
  call assert_equal(' wwwこんにちわ世界', getline('.'))
  exe "normal o wwwこんにちわ世界ワールドvim \<C-W>\<C-W>\<C-W>"
  call assert_equal(' wwwこんにちわ', getline('.'))
  exe "normal o wwwこんにちわ世界ワールドvim \<C-W>\<C-W>\<C-W>\<C-W>"
  call assert_equal(' www', getline('.'))
  exe "normal o wwwこんにちわ世界ワールドvim \<C-W>\<C-W>\<C-W>\<C-W>\<C-W>"
  call assert_equal(' ', getline('.'))
  exe "normal o wwwこんにちわ世界ワールドvim \<C-W>\<C-W>\<C-W>\<C-W>\<C-W>\<C-W>"
  call assert_equal('', getline('.'))

  enew!
endfunc
