" Test for commands that operate on the spellfile.

source shared.vim
source check.vim

CheckFeature spell
CheckFeature syntax

func Test_spell_normal()
  new
  call append(0, ['1 good', '2 goood', '3 goood'])
  set spell spellfile=./Xspellfile.add spelllang=en
  let oldlang=v:lang
  lang C

  " Test for zg
  1
  norm! ]s
  call assert_equal('2 goood', getline('.'))
  norm! zg
  1
  let a=execute('unsilent :norm! ]s')
  call assert_equal('1 good', getline('.'))
  call assert_equal('search hit BOTTOM, continuing at TOP', a[1:])
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('goood', cnt[0])

  " Test for zw
  2
  norm! $zw
  1
  norm! ]s
  call assert_equal('2 goood', getline('.'))
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('#oood', cnt[0])
  call assert_equal('goood/!', cnt[1])

  " Test for :spellrare
  spellrare rare
  let cnt=readfile('./Xspellfile.add')
  call assert_equal(['#oood', 'goood/!', 'rare/?'], cnt)

  " Make sure :spellundo works for rare words.
  spellundo rare
  let cnt=readfile('./Xspellfile.add')
  call assert_equal(['#oood', 'goood/!', '#are/?'], cnt)

  " Test for zg in visual mode
  let a=execute('unsilent :norm! V$zg')
  call assert_equal("Word '2 goood' added to ./Xspellfile.add", a[1:])
  1
  norm! ]s
  call assert_equal('3 goood', getline('.'))
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('2 goood', cnt[3])
  " Remove "2 good" from spellfile
  2
  let a=execute('unsilent norm! V$zw')
  call assert_equal("Word '2 goood' added to ./Xspellfile.add", a[1:])
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('2 goood/!', cnt[4])

  " Test for zG
  let a=execute('unsilent norm! V$zG')
  call assert_match("Word '2 goood' added to .*", a)
  let fname=matchstr(a, 'to\s\+\zs\f\+$')
  let cnt=readfile(fname)
  call assert_equal('2 goood', cnt[0])

  " Test for zW
  let a=execute('unsilent norm! V$zW')
  call assert_match("Word '2 goood' added to .*", a)
  let cnt=readfile(fname)
  call assert_equal('# goood', cnt[0])
  call assert_equal('2 goood/!', cnt[1])

  " Test for zuW
  let a=execute('unsilent norm! V$zuW')
  call assert_match("Word '2 goood' removed from .*", a)
  let cnt=readfile(fname)
  call assert_equal('# goood', cnt[0])
  call assert_equal('# goood/!', cnt[1])

  " Test for zuG
  let a=execute('unsilent norm! $zG')
  call assert_match("Word 'goood' added to .*", a)
  let cnt=readfile(fname)
  call assert_equal('# goood', cnt[0])
  call assert_equal('# goood/!', cnt[1])
  call assert_equal('goood', cnt[2])
  let a=execute('unsilent norm! $zuG')
  let cnt=readfile(fname)
  call assert_match("Word 'goood' removed from .*", a)
  call assert_equal('# goood', cnt[0])
  call assert_equal('# goood/!', cnt[1])
  call assert_equal('#oood', cnt[2])
  " word not found in wordlist
  let a=execute('unsilent norm! V$zuG')
  let cnt=readfile(fname)
  call assert_match("", a)
  call assert_equal('# goood', cnt[0])
  call assert_equal('# goood/!', cnt[1])
  call assert_equal('#oood', cnt[2])

  " Test for zug
  call delete('./Xspellfile.add')
  2
  let a=execute('unsilent norm! $zg')
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('goood', cnt[0])
  let a=execute('unsilent norm! $zug')
  call assert_match("Word 'goood' removed from \./Xspellfile.add", a)
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('#oood', cnt[0])
  " word not in wordlist
  let a=execute('unsilent norm! V$zug')
  call assert_match('', a)
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('#oood', cnt[0])

  " Test for zuw
  call delete('./Xspellfile.add')
  2
  let a=execute('unsilent norm! Vzw')
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('2 goood/!', cnt[0])
  let a=execute('unsilent norm! Vzuw')
  call assert_match("Word '2 goood' removed from \./Xspellfile.add", a)
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('# goood/!', cnt[0])
  " word not in wordlist
  let a=execute('unsilent norm! $zug')
  call assert_match('', a)
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('# goood/!', cnt[0])

  " add second entry to spellfile setting
  set spellfile=./Xspellfile.add,./Xspellfile2.add
  call delete('./Xspellfile.add')
  2
  let a=execute('unsilent norm! $2zg')
  let cnt=readfile('./Xspellfile2.add')
  call assert_match("Word 'goood' added to ./Xspellfile2.add", a)
  call assert_equal('goood', cnt[0])

  " Test for :spellgood!
  let temp = execute(':spe!0/0')
  call assert_match('Invalid region', temp)
  let spellfile = matchstr(temp, 'Invalid region nr in \zs.*\ze line \d: 0')
  call assert_equal(['# goood', '# goood/!', '#oood', '0/0'], readfile(spellfile))

  " Test for :spellrare!
  :spellrare! raare
  call assert_equal(['# goood', '# goood/!', '#oood', '0/0', 'raare/?'], readfile(spellfile))
  call delete(spellfile)

  " clean up
  exe "lang" oldlang
  call delete("./Xspellfile.add")
  call delete("./Xspellfile2.add")
  call delete("./Xspellfile.add.spl")
  call delete("./Xspellfile2.add.spl")

  " zux -> no-op
  2
  norm! $zux
  call assert_equal([], glob('Xspellfile.add',0,1))
  call assert_equal([], glob('Xspellfile2.add',0,1))

  set spellfile=
  bw!
endfunc
