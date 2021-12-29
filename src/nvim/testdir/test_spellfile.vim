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

" Test CHECKCOMPOUNDPATTERN (see :help spell-CHECKCOMPOUNDPATTERN)
func Test_spellfile_CHECKCOMPOUNDPATTERN()
  call writefile(['4',
        \         'one/c',
        \         'two/c',
        \         'three/c',
        \         'four'], 'XtestCHECKCOMPOUNDPATTERN.dic')
  " Forbid compound words where first word ends with 'wo' and second starts with 'on'.
  call writefile(['CHECKCOMPOUNDPATTERN 1',
        \         'CHECKCOMPOUNDPATTERN wo on',
        \         'COMPOUNDFLAG c'], 'XtestCHECKCOMPOUNDPATTERN.aff')

  let output = execute('mkspell! XtestCHECKCOMPOUNDPATTERN-utf8.spl XtestCHECKCOMPOUNDPATTERN')
  set spell spelllang=XtestCHECKCOMPOUNDPATTERN-utf8.spl

  " Check valid words with and without valid compounds.
  for goodword in ['one', 'two', 'three', 'four',
        \          'oneone', 'onetwo',  'onethree',
        \          'twotwo', 'twothree',
        \          'threeone', 'threetwo', 'threethree',
        \          'onetwothree', 'onethreetwo', 'twothreeone', 'oneoneone']
    call assert_equal(['', ''], spellbadword(goodword), goodword)
  endfor

  " Compounds 'twoone' or 'threetwoone' should be forbidden by CHECKCOMPOUNPATTERN.
  " 'four' does not have the 'c' flag in *.aff file so no compound.
  " 'five' is not in the *.dic file.
  for badword in ['five', 'onetwox',
        \         'twoone', 'threetwoone',
        \         'fourone', 'onefour']
    call assert_equal([badword, 'bad'], spellbadword(badword))
  endfor

  set spell& spelllang&
  call delete('XtestCHECKCOMPOUNDPATTERN.dic')
  call delete('XtestCHECKCOMPOUNDPATTERN.aff')
  call delete('XtestCHECKCOMPOUNDPATTERN-utf8.spl')
endfunc

" Test NOCOMPOUNDSUGS (see :help spell-NOCOMPOUNDSUGS)
func Test_spellfile_NOCOMPOUNDSUGS()
  call writefile(['3',
        \         'one/c',
        \         'two/c',
        \         'three/c'], 'XtestNOCOMPOUNDSUGS.dic')

  " pass 0 tests without NOCOMPOUNDSUGS, pass 1 tests with NOCOMPOUNDSUGS
  for pass in [0, 1]
    if pass == 0
      call writefile(['COMPOUNDFLAG c'], 'XtestNOCOMPOUNDSUGS.aff')
    else
      call writefile(['NOCOMPOUNDSUGS',
          \           'COMPOUNDFLAG c'], 'XtestNOCOMPOUNDSUGS.aff')
    endif

    mkspell! XtestNOCOMPOUNDSUGS-utf8.spl XtestNOCOMPOUNDSUGS
    set spell spelllang=XtestNOCOMPOUNDSUGS-utf8.spl

    for goodword in ['one', 'two', 'three',
          \          'oneone', 'onetwo',  'onethree',
          \          'twoone', 'twotwo', 'twothree',
          \          'threeone', 'threetwo', 'threethree',
          \          'onetwothree', 'onethreetwo', 'twothreeone', 'oneoneone']
      call assert_equal(['', ''], spellbadword(goodword), goodword)
    endfor

    for badword in ['four', 'onetwox', 'onexone']
      call assert_equal([badword, 'bad'], spellbadword(badword))
    endfor

    if pass == 0
      call assert_equal(['one', 'oneone'], spellsuggest('onne', 2))
      call assert_equal(['onethree', 'one three'], spellsuggest('onethre', 2))
    else
      call assert_equal(['one', 'one one'], spellsuggest('onne', 2))
      call assert_equal(['one three'], spellsuggest('onethre', 2))
    endif
  endfor

  set spell& spelllang&
  call delete('XtestNOCOMPOUNDSUGS.dic')
  call delete('XtestNOCOMPOUNDSUGS.aff')
  call delete('XtestNOCOMPOUNDSUGS-utf8.spl')
endfunc

" Test COMMON (better suggestions with common words, see :help spell-COMMON)
func Test_spellfile_COMMON()
  call writefile(['7',
        \         'and',
        \         'ant',
        \         'end',
        \         'any',
        \         'tee',
        \         'the',
        \         'ted'], 'XtestCOMMON.dic')
  call writefile(['COMMON the and'], 'XtestCOMMON.aff')

  let output = execute('mkspell! XtestCOMMON-utf8.spl XtestCOMMON')
  set spell spelllang=XtestCOMMON-utf8.spl

  " COMMON words 'and' and 'the' should be the top suggestions.
  call assert_equal(['and', 'ant'], spellsuggest('anr', 2))
  call assert_equal(['and', 'end'], spellsuggest('ond', 2))
  call assert_equal(['the', 'ted'], spellsuggest('tha', 2))
  call assert_equal(['the', 'tee'], spellsuggest('dhe', 2))

  set spell& spelllang&
  call delete('XtestCOMMON.dic')
  call delete('XtestCOMMON.aff')
  call delete('XtestCOMMON-utf8.spl')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
