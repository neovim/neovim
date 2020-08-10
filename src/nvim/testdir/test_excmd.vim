" Tests for various Ex commands.

func Test_ex_delete()
  new
  call setline(1, ['a', 'b', 'c'])
  2
  " :dl is :delete with the "l" flag, not :dlist
  .dl
  call assert_equal(['a', 'c'], getline(1, 2))
endfunc

func Test_buffers_lastused()
  edit bufc " oldest

  sleep 1200m
  edit bufa " middle

  sleep 1200m
  edit bufb " newest

  enew

  let ls = split(execute('buffers t', 'silent!'), '\n')
  let bufs = []
  for line in ls
    let bufs += [split(line, '"\s*')[1:2]]
  endfor

  let names = []
  for buf in bufs
    if buf[0] !=# '[No Name]'
      let names += [buf[0]]
    endif
  endfor

  call assert_equal(['bufb', 'bufa', 'bufc'], names)
  call assert_match('[0-2] seconds ago', bufs[1][1])

  bwipeout bufa
  bwipeout bufb
  bwipeout bufc
endfunc
