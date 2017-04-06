" Test for v:hlsearch

function! Test_hlsearch()
  new
  call setline(1, repeat(['aaa'], 10))
  set hlsearch nolazyredraw
  let r=[]
  " redraw is needed to make hlsearch highlight the matches
  exe "normal! /aaa\<CR>" | redraw
  let r1 = screenattr(1, 1)
  nohlsearch | redraw
  call assert_notequal(r1, screenattr(1,1))
  let v:hlsearch=1 | redraw
  call assert_equal(r1, screenattr(1,1))
  let v:hlsearch=0 | redraw
  call assert_notequal(r1, screenattr(1,1))
  set hlsearch | redraw
  call assert_equal(r1, screenattr(1,1))
  let v:hlsearch=0 | redraw
  call assert_notequal(r1, screenattr(1,1))
  exe "normal! n" | redraw
  call assert_equal(r1, screenattr(1,1))
  let v:hlsearch=0 | redraw
  call assert_notequal(r1, screenattr(1,1))
  exe "normal! /\<CR>" | redraw
  call assert_equal(r1, screenattr(1,1))
  set nohls
  exe "normal! /\<CR>" | redraw
  call assert_notequal(r1, screenattr(1,1))
  call assert_fails('let v:hlsearch=[]', 'E745')
  call garbagecollect(1)
  call getchar(1)
  enew!
endfunction
