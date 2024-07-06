" Tests for using Ctrl-A/Ctrl-X

func SetUp()
  new dummy
  set nrformats&vim
  set nrformats+=octal
endfunc

func TearDown()
  bwipe!
endfunc

" 1) Ctrl-A on visually selected number
" Text:
" foobar-10
"     Expected:
"     1)    Ctrl-A on start of line:
"     foobar-9
"     2)    Ctrl-A on visually selected "-10":
"     foobar-9
"     3)    Ctrl-A on visually selected "10":
"     foobar-11
"     4)    Ctrl-X on visually selected "-10"
"     foobar-11
"     5)    Ctrl-X on visually selected "10"
"     foobar-9
func Test_visual_increment_01()
  call setline(1, repeat(["foobaar-10"], 5))

  call cursor(1, 1)
  exec "norm! \<C-A>"
  call assert_equal("foobaar-9", getline('.'))
  call assert_equal([0, 1, 9, 0], getpos('.'))

  call cursor(2, 1)
  exec "norm! f-v$\<C-A>"
  call assert_equal("foobaar-9", getline('.'))
  call assert_equal([0, 2, 8, 0], getpos('.'))

  call cursor(3, 1)
  exec "norm! f1v$\<C-A>"
  call assert_equal("foobaar-11", getline('.'))
  call assert_equal([0, 3, 9, 0], getpos('.'))

  call cursor(4, 1)
  exec "norm! f-v$\<C-X>"
  call assert_equal("foobaar-11", getline('.'))
  call assert_equal([0, 4, 8, 0], getpos('.'))

  call cursor(5, 1)
  exec "norm! f1v$\<C-X>"
  call assert_equal("foobaar-9", getline('.'))
  call assert_equal([0, 5, 9, 0], getpos('.'))
endfunc

" 2) Ctrl-A on visually selected lines
" Text:
" 10
" 20
" 30
" 40
"
"     Expected:
"     1) Ctrl-A on visually selected lines:
" 11
" 21
" 31
" 41
"
"     2) Ctrl-X on visually selected lines:
" 9
" 19
" 29
" 39
func Test_visual_increment_02()
  call setline(1, ["10", "20", "30", "40"])
  exec "norm! GV3k$\<C-A>"
  call assert_equal(["11", "21", "31", "41"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))

  call setline(1, ["10", "20", "30", "40"])
  exec "norm! GV3k$\<C-X>"
  call assert_equal(["9", "19", "29", "39"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" 3) g Ctrl-A on visually selected lines, with non-numbers in between
" Text:
" 10
"
" 20
"
" 30
"
" 40
"
"     Expected:
"     1) 2 g Ctrl-A on visually selected lines:
" 12
"
" 24
"
" 36
"
" 48
"     2) 2 g Ctrl-X on visually selected lines
" 8
"
" 16
"
" 24
"
" 32
func Test_visual_increment_03()
  call setline(1, ["10", "", "20", "", "30", "", "40"])
  exec "norm! GV6k2g\<C-A>"
  call assert_equal(["12", "", "24", "", "36", "", "48"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))

  call setline(1, ["10", "", "20", "", "30", "", "40"])
  exec "norm! GV6k2g\<C-X>"
  call assert_equal(["8", "", "16", "", "24", "", "32"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" 4) Ctrl-A on non-number
" Text:
" foobar-10
"     Expected:
"     1) visually select foobar:
"     foobar-10
func Test_visual_increment_04()
  call setline(1, ["foobar-10"])
  exec "norm! vf-\<C-A>"
  call assert_equal(["foobar-10"], getline(1, '$'))
  " NOTE: I think this is correct behavior...
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" 5) g<Ctrl-A> on letter
" Test:
" a
" a
" a
" a
"     Expected:
"     1) g Ctrl-A on visually selected lines
"     b
"     c
"     d
"     e
func Test_visual_increment_05()
  set nrformats+=alpha
  call setline(1, repeat(["a"], 4))
  exec "norm! GV3kg\<C-A>"
  call assert_equal(["b", "c", "d", "e"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" 6) g<Ctrl-A> on letter
" Test:
" z
" z
" z
" z
"     Expected:
"     1) g Ctrl-X on visually selected lines
"     y
"     x
"     w
"     v
func Test_visual_increment_06()
  set nrformats+=alpha
  call setline(1, repeat(["z"], 4))
  exec "norm! GV3kg\<C-X>"
  call assert_equal(["y", "x", "w", "v"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" 7) <Ctrl-A> on letter
" Test:
" 2
" 1
" 0
" -1
" -2
"
"     Expected:
"     1) Ctrl-A on visually selected lines
"     3
"     2
"     1
"     0
"     -1
"
"     2) Ctrl-X on visually selected lines
"     1
"     0
"     -1
"     -2
"     -3
func Test_visual_increment_07()
  call setline(1, ["2", "1", "0", "-1", "-2"])
  exec "norm! GV4k\<C-A>"
  call assert_equal(["3", "2", "1", "0", "-1"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))

  call setline(1, ["2", "1", "0", "-1", "-2"])
  exec "norm! GV4k\<C-X>"
  call assert_equal(["1", "0", "-1", "-2", "-3"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" 8) Block increment on 0x9
" Text:
" 0x9
" 0x9
"     Expected:
"     1) Ctrl-A on visually block selected region (cursor at beginning):
"     0xa
"     0xa
"     2) Ctrl-A on visually block selected region (cursor at end)
"     0xa
"     0xa
func Test_visual_increment_08()
  call setline(1, repeat(["0x9"], 2))
  exec "norm! \<C-V>j$\<C-A>"
  call assert_equal(["0xa", "0xa"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))

  call setline(1, repeat(["0x9"], 2))
  exec "norm! gg$\<C-V>+\<C-A>"
  call assert_equal(["0xa", "0xa"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" 9) Increment and redo
" Text:
" 2
" 2
"
" 3
" 3
"
"     Expected:
"     1) 2 Ctrl-A on first 2 visually selected lines
"     4
"     4
"     2) redo (.) on 3
"     5
"     5
func Test_visual_increment_09()
  call setline(1, ["2", "2", "", "3", "3", ""])
  exec "norm! ggVj2\<C-A>"
  call assert_equal(["4", "4", "", "3", "3", ""], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))

  exec "norm! 3j."
  call assert_equal(["4", "4", "", "5", "5", ""], getline(1, '$'))
  call assert_equal([0, 4, 1, 0], getpos('.'))
endfunc

" 10) sequentially decrement 1
" Text:
" 1
" 1
" 1
" 1
"     Expected:
"     1) g Ctrl-X on visually selected lines
"     0
"     -1
"     -2
"     -3
func Test_visual_increment_10()
  call setline(1, repeat(["1"], 4))
  exec "norm! GV3kg\<C-X>"
  call assert_equal(["0", "-1", "-2", "-3"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" 11) visually block selected indented lines
" Text:
"     1
" 1
"     1
"     1
"     Expected:
"     1) g Ctrl-A on block selected indented lines
"     2
" 1
"     3
"     4
func Test_visual_increment_11()
  call setline(1, ["    1", "1", "    1", "    1"])
  exec "norm! f1\<C-V>3jg\<C-A>"
  call assert_equal(["    2", "1", "    3", "    4"], getline(1, '$'))
  call assert_equal([0, 1, 5, 0], getpos('.'))
endfunc

" 12) visually selected several columns
" Text:
" 0 0
" 0 0
" 0 0
"     Expected:
"     1) 'v' select last zero and first zeroes
"     0 1
"     1 0
"     1 0
func Test_visual_increment_12()
  call setline(1, repeat(["0 0"], 3))
  exec "norm! $v++\<C-A>"
  call assert_equal(["0 1", "1 0", "1 0"], getline(1, '$'))
  call assert_equal([0, 1, 3, 0], getpos('.'))
endfunc

" 13) visually selected part of columns
" Text:
" max: 100px
" max: 200px
" max: 300px
" max: 400px
"     Expected:
"     1) 'v' on first two numbers Ctrl-A
"     max: 110px
"     max: 220px
"     max: 330px
"     max: 400px
"     2) 'v' on first two numbers Ctrl-X
"     max: 90px
"     max: 190px
"     max: 290px
"     max: 400px
func Test_visual_increment_13()
  call setline(1, ["max: 100px", "max: 200px", "max: 300px", "max: 400px"])
  exec "norm! f1\<C-V>l2j\<C-A>"
  call assert_equal(["max: 110px", "max: 210px", "max: 310px", "max: 400px"], getline(1, '$'))
  call assert_equal([0, 1, 6, 0], getpos('.'))

  call setline(1, ["max: 100px", "max: 200px", "max: 300px", "max: 400px"])
  exec "norm! ggf1\<C-V>l2j\<C-X>"
  call assert_equal(["max: 90px", "max: 190px", "max: 290px", "max: 400px"], getline(1, '$'))
  call assert_equal([0, 1, 6, 0], getpos('.'))
endfunc

" 14) redo in block mode
" Text:
" 1 1
" 1 1
"     Expected:
"     1) Ctrl-a on first column, redo on second column
"     2 2
"     2 2
func Test_visual_increment_14()
  call setline(1, repeat(["1 1"], 2))
  exec "norm! G\<C-V>k\<C-A>w."
  call assert_equal(["2 2", "2 2"], getline(1, '$'))
  call assert_equal([0, 1, 3, 0], getpos('.'))
endfunc

" 15) block select single numbers
" Text:
" 101
"     Expected:
"     1) Ctrl-a on visually selected zero
"     111
"
" Also: 019 with "01" selected increments to "029".
func Test_visual_increment_15()
  call setline(1, ["101"])
  exec "norm! lv\<C-A>"
  call assert_equal(["111"], getline(1, '$'))
  call assert_equal([0, 1, 2, 0], getpos('.'))

  call setline(1, ["019"])
  exec "norm! 0vl\<C-A>"
  call assert_equal("029", getline(1))

  call setline(1, ["01239"])
  exec "norm! 0vlll\<C-A>"
  call assert_equal("01249", getline(1))

  call setline(1, ["01299"])
  exec "norm! 0vlll\<C-A>"
  call assert_equal("1309", getline(1))
endfunc

" 16) increment right aligned numbers
" Text:
"    1
"   19
"  119
"     Expected:
"     1) Ctrl-a on line selected region
"        2
"       20
"      120
func Test_visual_increment_16()
  call setline(1, ["   1", "  19", " 119"])
  exec "norm! VG\<C-A>"
  call assert_equal(["   2", "  20", " 120"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" 17) block-wise increment and redo
" Text:
"   100
"   1
"
"   100
"   1
"
"   Expected:
"   1) Ctrl-V j $ on first block, afterwards '.' on second
"   101
"   2
"
"   101
"   2
func Test_visual_increment_17()
  call setline(1, [" 100", " 1", "", " 100", " 1"])
  exec "norm! \<C-V>j$\<C-A>2j."
  call assert_equal([" 101", " 2", "", " 101", " 1"], getline(1, '$'))
  call assert_equal([0, 3, 1, 0], getpos('.'))
endfunc

" 18) repeat of g<Ctrl-a>
" Text:
"   0
"   0
"   0
"   0
"
"   Expected:
"   1) V 4j g<ctrl-a>, repeat twice afterwards with .
"   3
"   6
"   9
"   12
func Test_visual_increment_18()
  call setline(1, repeat(["0"], 4))
  exec "norm! GV3kg\<C-A>"
  exec "norm! .."
  call assert_equal(["3", "6", "9", "12"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" 19) increment on number with nrformat including alpha
" Text:
"  1
"  1a
"
"  Expected:
"  1) <Ctrl-V>j$ <ctrl-a>
"  2
"  2a
func Test_visual_increment_19()
  set nrformats+=alpha
  call setline(1, ["1", "1a"])
  exec "norm! \<C-V>G$\<C-A>"
  call assert_equal(["2", "2a"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" 20) increment a single letter
" Text:
"  a
"
"  Expected:
"  1) <Ctrl-a> and cursor is on a
"  b
func Test_visual_increment_20()
  set nrformats+=alpha
  call setline(1, ["a"])
  exec "norm! \<C-A>"
  call assert_equal(["b"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
  " decrement a and A and increment z and Z
  call setline(1, ['a', 'A', 'z', 'Z'])
  exe "normal 1G\<C-X>2G\<C-X>3G\<C-A>4G\<C-A>"
  call assert_equal(['a', 'A', 'z', 'Z'], getline(1, '$'))
endfunc

" 21) block-wise increment on part of hexadecimal
" Text:
" 0x123456
"
"   Expected:
"   1) Ctrl-V f3 <ctrl-a>
" 0x124456
func Test_visual_increment_21()
  call setline(1, ["0x123456"])
  exec "norm! \<C-V>f3\<C-A>"
  call assert_equal(["0x124456"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" 22) Block increment on 0b0
" Text:
" 0b1
" 0b1
"     Expected:
"     1) Ctrl-A on visually block selected region (cursor at beginning):
"     0b10
"     0b10
"     2) Ctrl-A on visually block selected region (cursor at end)
"     0b10
"     0b10
func Test_visual_increment_22()
  call setline(1, repeat(["0b1"], 2))
  exec "norm! \<C-V>j$\<C-A>"
  call assert_equal(repeat(["0b10"], 2), getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))

  call setline(1, repeat(["0b1"], 2))
  exec "norm! $\<C-V>+\<C-A>"
  call assert_equal(repeat(["0b10"], 2), getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" 23) block-wise increment on part of binary
" Text:
" 0b1001
"
"   Expected:
"   1) Ctrl-V 5l <ctrl-a>
" 0b1011
func Test_visual_increment_23()
  call setline(1, ["0b1001"])
  exec "norm! \<C-V>4l\<C-A>"
  call assert_equal(["0b1011"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" 24) increment hexadecimal
" Text:
" 0x0b1001
"
"   Expected:
"   1) <ctrl-a>
" 0x0b1002
func Test_visual_increment_24()
  call setline(1, ["0x0b1001"])
  exec "norm! \<C-V>$\<C-A>"
  call assert_equal(["0x0b1002"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" 25) increment binary with nrformats including alpha
" Text:
" 0b1001a
"
"   Expected:
"   1) <ctrl-a>
" 0b1010a
func Test_visual_increment_25()
  set nrformats+=alpha
  call setline(1, ["0b1001a"])
  exec "norm! \<C-V>$\<C-A>"
  call assert_equal(["0b1010a"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" 26) increment binary with 32 bits
" Text:
" 0b11111111111111111111111111111110
"
"   Expected:
"   1) <ctrl-a>
" 0b11111111111111111111111111111111
func Test_visual_increment_26()
  set nrformats+=bin
  call setline(1, ["0b11111111111111111111111111111110"])
  exec "norm! \<C-V>$\<C-A>"
  call assert_equal(["0b11111111111111111111111111111111"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
  exec "norm! \<C-V>$\<C-X>"
  call assert_equal(["0b11111111111111111111111111111110"], getline(1, '$'))
  set nrformats-=bin
endfunc

" 27) increment with 'rightreft', if supported
func Test_visual_increment_27()
  if exists('+rightleft')
    set rightleft
    call setline(1, ["1234 56"])

    exec "norm! $\<C-A>"
    call assert_equal(["1234 57"], getline(1, '$'))
    call assert_equal([0, 1, 7, 0], getpos('.'))

    exec "norm! \<C-A>"
    call assert_equal(["1234 58"], getline(1, '$'))
    call assert_equal([0, 1, 7, 0], getpos('.'))
    set norightleft
  endif
endfunc

" Tab code and linewise-visual inc/dec
func Test_visual_increment_28()
  call setline(1, ["x\<TAB>10", "\<TAB>-1"])
  exec "norm! Vj\<C-A>"
  call assert_equal(["x\<TAB>11", "\<TAB>0"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))

  call setline(1, ["x\<TAB>10", "\<TAB>-1"])
  exec "norm! ggVj\<C-X>"
  call assert_equal(["x\<TAB>9", "\<TAB>-2"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" Tab code and linewise-visual inc/dec with 'nrformats'+=alpha
func Test_visual_increment_29()
  set nrformats+=alpha
  call setline(1, ["x\<TAB>10", "\<TAB>-1"])
  exec "norm! Vj\<C-A>"
  call assert_equal(["y\<TAB>10", "\<TAB>0"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))

  call setline(1, ["x\<TAB>10", "\<TAB>-1"])
  exec "norm! ggVj\<C-X>"
  call assert_equal(["w\<TAB>10", "\<TAB>-2"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" Tab code and character-visual inc/dec
func Test_visual_increment_30()
  call setline(1, ["x\<TAB>10", "\<TAB>-1"])
  exec "norm! f1vjf1\<C-A>"
  call assert_equal(["x\<TAB>11", "\<TAB>0"], getline(1, '$'))
  call assert_equal([0, 1, 3, 0], getpos('.'))

  call setline(1, ["x\<TAB>10", "\<TAB>-1"])
  exec "norm! ggf1vjf1\<C-X>"
  call assert_equal(["x\<TAB>9", "\<TAB>-2"], getline(1, '$'))
  call assert_equal([0, 1, 3, 0], getpos('.'))
endfunc

" Tab code and blockwise-visual inc/dec
func Test_visual_increment_31()
  call setline(1, ["x\<TAB>10", "\<TAB>-1"])
  exec "norm! f1\<C-V>jl\<C-A>"
  call assert_equal(["x\<TAB>11", "\<TAB>0"], getline(1, '$'))
  call assert_equal([0, 1, 3, 0], getpos('.'))

  call setline(1, ["x\<TAB>10", "\<TAB>-1"])
  exec "norm! ggf1\<C-V>jl\<C-X>"
  call assert_equal(["x\<TAB>9", "\<TAB>-2"], getline(1, '$'))
  call assert_equal([0, 1, 3, 0], getpos('.'))
endfunc

" Tab code and blockwise-visual decrement with 'linebreak' and 'showbreak'
func Test_visual_increment_32()
  28vnew dummy_31
  set linebreak showbreak=+
  call setline(1, ["x\<TAB>\<TAB>\<TAB>10", "\<TAB>\<TAB>\<TAB>\<TAB>-1"])
  exec "norm! ggf0\<C-V>jg_\<C-X>"
  call assert_equal(["x\<TAB>\<TAB>\<TAB>1-1", "\<TAB>\<TAB>\<TAB>\<TAB>-2"], getline(1, '$'))
  call assert_equal([0, 1, 6, 0], getpos('.'))
  bwipe!
endfunc

" Tab code and blockwise-visual increment with $
func Test_visual_increment_33()
  call setline(1, ["\<TAB>123", "456"])
  exec "norm! gg0\<C-V>j$\<C-A>"
  call assert_equal(["\<TAB>124", "457"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" Tab code and blockwise-visual increment and redo
func Test_visual_increment_34()
  call setline(1, ["\<TAB>123", "     456789"])
  exec "norm! gg0\<C-V>j\<C-A>"
  call assert_equal(["\<TAB>123", "     457789"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))

  exec "norm! .."
  call assert_equal(["\<TAB>123", "     459789"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" Tab code, spaces and character-visual increment and redo
func Test_visual_increment_35()
  call setline(1, ["\<TAB>123", "        123", "\<TAB>123", "\<TAB>123"])
  exec "norm! ggvjf3\<C-A>..."
  call assert_equal(["\<TAB>127", "        127", "\<TAB>123", "\<TAB>123"], getline(1, '$'))
  call assert_equal([0, 1, 2, 0], getpos('.'))
endfunc

" Tab code, spaces and blockwise-visual increment and redo
func Test_visual_increment_36()
  call setline(1, ["           123", "\<TAB>456789"])
  exec "norm! G0\<C-V>kl\<C-A>"
  call assert_equal(["           123", "\<TAB>556789"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))

  exec "norm! ..."
  call assert_equal(["           123", "\<TAB>856789"], getline(1, '$'))
  call assert_equal([0, 1, 1, 0], getpos('.'))
endfunc

" block-wise increment and dot-repeat
" Text:
"   1 23
"   4 56
" 
" Expected:
"   1) f2 Ctrl-V jl <ctrl-a>, repeat twice afterwards with .
"   1 26
"   4 59
"
" Try with and without indent.
func Test_visual_increment_37()
  call setline(1, ["  1 23", "  4 56"])
  exec "norm! ggf2\<C-V>jl\<C-A>.."
  call assert_equal(["  1 26", "  4 59"], getline(1, 2))

  call setline(1, ["1 23", "4 56"])
  exec "norm! ggf2\<C-V>jl\<C-A>.."
  call assert_equal(["1 26", "4 59"], getline(1, 2))
endfunc

" Check redo after the normal mode increment
func Test_visual_increment_38()
  exec "norm! i10\<ESC>5\<C-A>."
  call assert_equal(["20"], getline(1, '$'))
  call assert_equal([0, 1, 2, 0], getpos('.'))
endfunc

" Test what patch 7.3.414 fixed. Ctrl-A on "000" drops the leading zeros.
func Test_normal_increment_01()
  call setline(1, "000")
  exec "norm! gg0\<C-A>"
  call assert_equal("001", getline(1))

  call setline(1, "000")
  exec "norm! gg$\<C-A>"
  call assert_equal("001", getline(1))

  call setline(1, "001")
  exec "norm! gg0\<C-A>"
  call assert_equal("002", getline(1))

  call setline(1, "001")
  exec "norm! gg$\<C-A>"
  call assert_equal("002", getline(1))
endfunc

" Test a regression of patch 7.4.1087 fixed.
func Test_normal_increment_02()
  call setline(1, ["hello 10", "world"])
  exec "norm! ggl\<C-A>jx"
  call assert_equal(["hello 11", "worl"], getline(1, '$'))
  call assert_equal([0, 2, 4, 0], getpos('.'))
endfunc

" The test35 unified to this file.
func Test_normal_increment_03()
  call setline(1, ["100     0x100     077     0",
        \          "100     0x100     077     ",
        \          "100     0x100     077     0xfF     0xFf",
        \          "100     0x100     077     "])
  set nrformats=octal,hex
  exec "norm! gg\<C-A>102\<C-X>\<C-A>l\<C-X>l\<C-A>64\<C-A>128\<C-X>$\<C-X>"
  set nrformats=octal
  exec "norm! j0\<C-A>102\<C-X>\<C-A>l\<C-X>2\<C-A>w65\<C-A>129\<C-X>blx6lD"
  set nrformats=hex
  exec "norm! j0101\<C-X>l257\<C-X>\<C-A>Txldt \<C-A> \<C-X> \<C-X>"
  set nrformats=
  exec "norm! j0200\<C-X>l100\<C-X>w78\<C-X>\<C-A>k"
  call assert_equal(["0     0x0ff     0000     -1",
        \            "0     1x100     0777777",
        \            "-1     0x0     078     0xFE     0xfe",
        \            "-100     -100x100     000     "], getline(1, '$'))
  call assert_equal([0, 3, 25, 0], getpos('.'))
endfunc

func Test_increment_empty_line()
  call setline(1, ['0', '0', '0', '0', '0', '0', ''])
  exe "normal Gvgg\<C-A>"
  call assert_equal(['1', '1', '1', '1', '1', '1', ''], getline(1, 7))

  " Ctrl-A/Ctrl-X should do nothing in operator pending mode
  %d
  call setline(1, 'one two')
  exe "normal! c\<C-A>l"
  exe "normal! c\<C-X>l"
  call assert_equal('one two', getline(1))
endfunc

" Try incrementing/decrementing a non-digit/alpha character
func Test_increment_special_char()
  call setline(1, '!')
  call assert_beeps("normal \<C-A>")
  call assert_beeps("normal \<C-X>")
endfunc

" Try incrementing/decrementing a number when nrformats contains unsigned
func Test_increment_unsigned()
  set nrformats+=unsigned

  call setline(1, '0')
  exec "norm! gg0\<C-X>"
  call assert_equal('0', getline(1))

  call setline(1, '3')
  exec "norm! gg010\<C-X>"
  call assert_equal('0', getline(1))

  call setline(1, '-0')
  exec "norm! gg0\<C-X>"
  call assert_equal("-0", getline(1))

  call setline(1, '-11')
  exec "norm! gg08\<C-X>"
  call assert_equal('-3', getline(1))

  " NOTE: 18446744073709551615 == 2^64 - 1
  call setline(1, '18446744073709551615')
  exec "norm! gg0\<C-A>"
  call assert_equal('18446744073709551615', getline(1))

  call setline(1, '-18446744073709551615')
  exec "norm! gg0\<C-A>"
  call assert_equal('-18446744073709551615', getline(1))

  call setline(1, '-18446744073709551614')
  exec "norm! gg08\<C-A>"
  call assert_equal('-18446744073709551615', getline(1))

  call setline(1, '-1')
  exec "norm! gg0\<C-A>"
  call assert_equal('-2', getline(1))

  call setline(1, '-3')
  exec "norm! gg08\<C-A>"
  call assert_equal('-11', getline(1))

  set nrformats-=unsigned
endfunc

" Try incrementing/decrementing a number when nrformats contains blank
func Test_increment_blank()
  set nrformats+=blank

  " Signed
  call setline(1, '0')
  exec "norm! gg0\<C-X>"
  call assert_equal('-1', getline(1))

  call setline(1, '3')
  exec "norm! gg010\<C-X>"
  call assert_equal('-7', getline(1))

  call setline(1, '-0')
  exec "norm! gg0\<C-X>"
  call assert_equal("-1", getline(1))

  " Unsigned
  " NOTE: 18446744073709551615 == 2^64 - 1
  call setline(1, 'a-18446744073709551615')
  exec "norm! gg0\<C-A>"
  call assert_equal('a-18446744073709551615', getline(1))

  call setline(1, 'a-18446744073709551615')
  exec "norm! gg0\<C-A>"
  call assert_equal('a-18446744073709551615', getline(1))

  call setline(1, 'a-18446744073709551614')
  exec "norm! gg08\<C-A>"
  call assert_equal('a-18446744073709551615', getline(1))

  call setline(1, 'a-1')
  exec "norm! gg0\<C-A>"
  call assert_equal('a-2', getline(1))

  set nrformats-=blank
endfunc

func Test_in_decrement_large_number()
  " NOTE: 18446744073709551616 == 2^64
  call setline(1, '18446744073709551616')
  exec "norm! gg0\<C-X>"
  call assert_equal('18446744073709551615', getline(1))

  exec "norm! gg0\<C-X>"
  call assert_equal('18446744073709551614', getline(1))

  exec "norm! gg0\<C-A>"
  call assert_equal('18446744073709551615', getline(1))

  exec "norm! gg0\<C-A>"
  call assert_equal('-18446744073709551615', getline(1))
endfunc

func Test_normal_increment_with_virtualedit()
  set virtualedit=all

  call setline(1, ["\<TAB>1"])
  exec "norm! 0\<C-A>"
  call assert_equal("\<TAB>2", getline(1))
  call assert_equal([0, 1, 2, 0], getpos('.'))

  call setline(1, ["\<TAB>1"])
  exec "norm! 0l\<C-A>"
  call assert_equal("\<TAB>2", getline(1))
  call assert_equal([0, 1, 2, 0], getpos('.'))

  call setline(1, ["\<TAB>1"])
  exec "norm! 07l\<C-A>"
  call assert_equal("\<TAB>2", getline(1))
  call assert_equal([0, 1, 2, 0], getpos('.'))

  call setline(1, ["\<TAB>1"])
  exec "norm! 0w\<C-A>"
  call assert_equal("\<TAB>2", getline(1))
  call assert_equal([0, 1, 2, 0], getpos('.'))

  call setline(1, ["\<TAB>1"])
  exec "norm! 0wl\<C-A>"
  call assert_equal("\<TAB>1", getline(1))
  call assert_equal([0, 1, 3, 0], getpos('.'))

  call setline(1, ["\<TAB>1"])
  exec "norm! 0w30l\<C-A>"
  call assert_equal("\<TAB>1", getline(1))
  call assert_equal([0, 1, 3, 29], getpos('.'))

  set virtualedit&
endfunc

" Test for incrementing a signed hexadecimal and octal number
func Test_normal_increment_signed_hexoct_nr()
  new
  " negative sign before a hex number should be ignored
  call setline(1, ["-0x9"])
  exe "norm \<C-A>"
  call assert_equal(["-0xa"], getline(1, '$'))
  exe "norm \<C-X>"
  call assert_equal(["-0x9"], getline(1, '$'))
  call setline(1, ["-007"])
  exe "norm \<C-A>"
  call assert_equal(["-010"], getline(1, '$'))
  exe "norm \<C-X>"
  call assert_equal(["-007"], getline(1, '$'))
  bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
