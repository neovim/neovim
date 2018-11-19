" Test for v:hlsearch

function! Test_hlsearch()
  new
  call setline(1, repeat(['aaa'], 10))
  set hlsearch nolazyredraw
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

func Test_hlsearch_eol_highlight()
  new
  call append(1, repeat([''], 9))
  set hlsearch nolazyredraw
  exe "normal! /$\<CR>" | redraw
  let attr = screenattr(1, 1)
  for row in range(2, 10)
    call assert_equal(attr, screenattr(row, 1), 'in line ' . row)
  endfor
  set nohlsearch
  bwipe!
endfunc
