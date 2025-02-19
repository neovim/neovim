" Test shifting lines with :> and :<

source check.vim

func Test_ex_shift_right()
  set shiftwidth=2

  " shift right current line.
  call setline(1, range(1, 5))
  2
  >
  3
  >>
  call assert_equal(['1',
        \            '  2',
        \            '    3',
        \            '4',
        \            '5'], getline(1, '$'))

  " shift right with range.
  call setline(1, range(1, 4))
  2,3>>
  call assert_equal(['1',
        \            '    2',
        \            '    3',
        \            '4',
        \            '5'], getline(1, '$'))

  " shift right with range and count.
  call setline(1, range(1, 4))
  2>3
  call assert_equal(['1',
        \            '  2',
        \            '  3',
        \            '  4',
        \            '5'], getline(1, '$'))

  bw!
  set shiftwidth&
endfunc

func Test_ex_shift_left()
  set shiftwidth=2

  call setline(1, range(1, 5))
  %>>>

  " left shift current line.
  2<
  3<<
  4<<<<<
  call assert_equal(['      1',
        \            '    2',
        \            '  3',
        \            '4',
        \            '      5'], getline(1, '$'))

  " shift right with range.
  call setline(1, range(1, 5))
  %>>>
  2,3<<
  call assert_equal(['      1',
        \            '  2',
        \            '  3',
        \            '      4',
        \            '      5'], getline(1, '$'))

  " shift right with range and count.
  call setline(1, range(1, 5))
  %>>>
  2<<3
  call assert_equal(['      1',
     \               '  2',
     \               '  3',
     \               '  4',
     \               '      5'], getline(1, '$'))

  bw!
  set shiftwidth&
endfunc

func Test_ex_shift_rightleft()
  CheckFeature rightleft

  set shiftwidth=2 rightleft

  call setline(1, range(1, 4))
  2,3<<
  call assert_equal(['1',
        \             '    2',
        \             '    3',
        \             '4'], getline(1, '$'))

  3,4>
  call assert_equal(['1',
        \            '    2',
        \            '  3',
        \            '4'], getline(1, '$'))

  bw!
  set rightleft& shiftwidth&
endfunc

func Test_ex_shift_errors()
  call assert_fails('><', 'E488:')
  call assert_fails('<>', 'E488:')

  call assert_fails('>!', 'E477:')
  call assert_fails('<!', 'E477:')

  call assert_fails('2,1>', 'E493:')
  call assert_fails('2,1<', 'E493:')
endfunc

" Test inserting a backspace at the start of a line.
"
" This is to verify the proper behavior of tabstop_start() as called from
" ins_bs().
"
func Test_shift_ins_bs()
  set backspace=indent,start
  set softtabstop=11

  call setline(1, repeat(" ", 33) . "word")
  exe "norm! I\<BS>"
  call assert_equal(repeat(" ", 22) . "word", getline(1))
  call setline(1, repeat(" ", 23) . "word")
  exe "norm! I\<BS>"
  call assert_equal(repeat(" ", 22) . "word", getline(1))
  exe "norm! I\<BS>"
  call assert_equal(repeat(" ", 11) . "word", getline(1))

  set backspace& softtabstop&
  bw!
endfunc

" Test inserting a backspace at the start of a line, with 'varsofttabstop'.
"
func Test_shift_ins_bs_vartabs()
  CheckFeature vartabs
  set backspace=indent,start
  set varsofttabstop=13,11,7

  call setline(1, repeat(" ", 44) . "word")
  exe "norm! I\<BS>"
  call assert_equal(repeat(" ", 38) . "word", getline(1))
  call setline(1, repeat(" ", 39) . "word")
  exe "norm! I\<BS>"
  call assert_equal(repeat(" ", 38) . "word", getline(1))
  exe "norm! I\<BS>"
  call assert_equal(repeat(" ", 31) . "word", getline(1))
  exe "norm! I\<BS>"
  call assert_equal(repeat(" ", 24) . "word", getline(1))
  exe "norm! I\<BS>"
  call assert_equal(repeat(" ", 13) . "word", getline(1))
  exe "norm! I\<BS>"
  call assert_equal(                  "word", getline(1))
  exe "norm! I\<BS>"
  call assert_equal(                  "word", getline(1))

  set backspace& varsofttabstop&
  bw!
endfunc

" Test the >> and << normal-mode commands.
"
func Test_shift_norm()
  set expandtab                 " Don't want to worry about tabs vs. spaces in
                                " results.

  set shiftwidth=5
  set tabstop=7

  call setline(1, "  word")

  " Shift by 'shiftwidth' right and left.

  norm! >>
  call assert_equal(repeat(" ",  7) . "word", getline(1))
  norm! >>
  call assert_equal(repeat(" ",  12) . "word", getline(1))
  norm! >>
  call assert_equal(repeat(" ",  17) . "word", getline(1))

  norm! <<
  call assert_equal(repeat(" ",  12) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  7) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  2) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  0) . "word", getline(1))

  " Shift by 'tabstop' right and left.

  set shiftwidth=0
  call setline(1, "  word")

  norm! >>
  call assert_equal(repeat(" ",  9) . "word", getline(1))
  norm! >>
  call assert_equal(repeat(" ",  16) . "word", getline(1))
  norm! >>
  call assert_equal(repeat(" ",  23) . "word", getline(1))

  norm! <<
  call assert_equal(repeat(" ",  16) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  9) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  2) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  0) . "word", getline(1))

  set expandtab& shiftwidth& tabstop&
  bw!
endfunc

" Test the >> and << normal-mode commands, with 'vartabstop'.
"
func Test_shift_norm_vartabs()
  CheckFeature vartabs
  set expandtab                 " Don't want to worry about tabs vs. spaces in
                                " results.

  set shiftwidth=0
  set vartabstop=19,17,11

  " Shift by 'vartabstop' right and left.

  call setline(1, "  word")

  norm! >>
  call assert_equal(repeat(" ",  21) . "word", getline(1))
  norm! >>
  call assert_equal(repeat(" ",  38) . "word", getline(1))
  norm! >>
  call assert_equal(repeat(" ",  49) . "word", getline(1))
  norm! >>
  call assert_equal(repeat(" ",  60) . "word", getline(1))

  norm! <<
  call assert_equal(repeat(" ",  49) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  38) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  21) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  2) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  0) . "word", getline(1))

  set expandtab& shiftwidth& vartabstop&
  bw!
endfunc

" Test the >> and << normal-mode commands with 'shiftround'.
"
func Test_shift_norm_round()
  set expandtab                 " Don't want to worry about tabs vs. spaces in
                                " results.

  set shiftround
  set shiftwidth=5
  set tabstop=7

  call setline(1, "word")

  " Shift by 'shiftwidth' right and left.

  exe "norm! I  "
  norm! >>
  call assert_equal(repeat(" ",  5) . "word", getline(1))
  exe "norm! I  "
  norm! >>
  call assert_equal(repeat(" ",  10) . "word", getline(1))
  exe "norm! I  "
  norm! >>
  call assert_equal(repeat(" ",  15) . "word", getline(1))
  norm! >>
  call assert_equal(repeat(" ",  20) . "word", getline(1))
  norm! >>
  call assert_equal(repeat(" ",  25) . "word", getline(1))

  norm! <<
  call assert_equal(repeat(" ",  20) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  15) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  10) . "word", getline(1))
  exe "norm! I  "
  norm! <<
  call assert_equal(repeat(" ",  10) . "word", getline(1))

  call setline(1, repeat(" ", 7) . "word")
  norm! <<
  call assert_equal(repeat(" ",  5) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  0) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  0) . "word", getline(1))
  call setline(1, repeat(" ", 2) . "word")
  norm! <<
  call assert_equal(repeat(" ",  0) . "word", getline(1))

  " Shift by 'tabstop' right and left.

  set shiftwidth=0
  call setline(1, "word")

  exe "norm! I  "
  norm! >>
  call assert_equal(repeat(" ",  7) . "word", getline(1))
  exe "norm! I  "
  norm! >>
  call assert_equal(repeat(" ",  14) . "word", getline(1))
  exe "norm! I  "
  norm! >>
  call assert_equal(repeat(" ",  21) . "word", getline(1))
  norm! >>
  call assert_equal(repeat(" ",  28) . "word", getline(1))
  norm! >>
  call assert_equal(repeat(" ",  35) . "word", getline(1))

  norm! <<
  call assert_equal(repeat(" ",  28) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  21) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  14) . "word", getline(1))
  exe "norm! I  "
  norm! <<
  call assert_equal(repeat(" ",  14) . "word", getline(1))

  call setline(1, repeat(" ", 9) . "word")
  norm! <<
  call assert_equal(repeat(" ",  7) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  0) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  0) . "word", getline(1))
  call setline(1, repeat(" ", 2) . "word")
  norm! <<
  call assert_equal(repeat(" ",  0) . "word", getline(1))

  set expandtab& shiftround& shiftwidth& tabstop&
  bw!
endfunc

" Test the >> and << normal-mode commands with 'shiftround' and 'vartabstop'.
"
func Test_shift_norm_round_vartabs()
  CheckFeature vartabs
  set expandtab                 " Don't want to worry about tabs vs. spaces in
                                " results.

  set shiftround
  set shiftwidth=0
  set vartabstop=19,17,11

  " Shift by 'vartabstop' right and left.

  call setline(1, "word")

  exe "norm! I  "
  norm! >>
  call assert_equal(repeat(" ",  19) . "word", getline(1))
  exe "norm! I  "
  norm! >>
  call assert_equal(repeat(" ",  36) . "word", getline(1))
  exe "norm! I  "
  norm! >>
  call assert_equal(repeat(" ",  47) . "word", getline(1))
  exe "norm! I  "
  norm! >>
  call assert_equal(repeat(" ",  58) . "word", getline(1))

  exe "norm! I  "
  norm! <<
  call assert_equal(repeat(" ",  58) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  47) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  36) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  19) . "word", getline(1))
  exe "norm! I  "
  norm! <<
  call assert_equal(repeat(" ",  19) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  0) . "word", getline(1))
  exe "norm! I  "
  call assert_equal(repeat(" ",  2) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  0) . "word", getline(1))
  norm! <<
  call assert_equal(repeat(" ",  0) . "word", getline(1))

  set expandtab& shiftround& shiftwidth& vartabstop&
  bw!
endfunc

" Test the V> and V< visual-mode commands.
"
" See ":help v_<" and ":help v_>".  See also the last paragraph of "3. Simple
" changes", ":help simple-change", immediately above "4. Complex changes",
" ":help complex-change".
"
func Test_shift_vis()
  set expandtab                 " Don't want to worry about tabs vs. spaces in
                                " results.

  set shiftwidth=5
  set tabstop=7

  call setline(1, "  word")

  " Shift by 'shiftwidth' right and left.

  norm! V>
  call assert_equal(repeat(" ",  7) . "word", getline(1))
  norm! V2>
  call assert_equal(repeat(" ",  17) . "word", getline(1))
  norm! V3>
  call assert_equal(repeat(" ",  32) . "word", getline(1))

  norm! V<
  call assert_equal(repeat(" ",  27) . "word", getline(1))
  norm! V2<
  call assert_equal(repeat(" ",  17) . "word", getline(1))
  norm! V3<
  call assert_equal(repeat(" ",  2) . "word", getline(1))
  norm! V<
  call assert_equal(repeat(" ",  0) . "word", getline(1))
  norm! V3<
  call assert_equal(repeat(" ",  0) . "word", getline(1))

  " Shift by 'tabstop' right and left.

  set shiftwidth=0
  call setline(1, "  word")

  norm! V>
  call assert_equal(repeat(" ",  9) . "word", getline(1))
  norm! V2>
  call assert_equal(repeat(" ",  23) . "word", getline(1))
  norm! V3>
  call assert_equal(repeat(" ",  44) . "word", getline(1))

  norm! V<
  call assert_equal(repeat(" ",  37) . "word", getline(1))
  norm! V2<
  call assert_equal(repeat(" ",  23) . "word", getline(1))
  norm! V3<
  call assert_equal(repeat(" ",  2) . "word", getline(1))
  norm! V<
  call assert_equal(repeat(" ",  0) . "word", getline(1))
  norm! V3<
  call assert_equal(repeat(" ",  0) . "word", getline(1))

  set expandtab& shiftwidth& tabstop&
  bw!
endfunc

" Test the V> and V< visual-mode commands, with 'vartabstop'.
"
" See ":help v_<" and ":help v_>".  See also the last paragraph of "3. Simple
" changes", ":help simple-change", immediately above "4. Complex changes",
" ":help complex-change".
"
func Test_shift_vis_vartabs()
  CheckFeature vartabs
  set expandtab                 " Don't want to worry about tabs vs. spaces in
                                " results.

  set shiftwidth=0
  set vartabstop=19,17,11

  " Shift by 'vartabstop' right and left.

  call setline(1, "  word")

  norm! V>
  call assert_equal(repeat(" ",  21) . "word", getline(1))
  norm! V2>
  call assert_equal(repeat(" ",  49) . "word", getline(1))
  norm! V3>
  call assert_equal(repeat(" ",  82) . "word", getline(1))

  norm! V<
  call assert_equal(repeat(" ",  71) . "word", getline(1))
  norm! V2<
  call assert_equal(repeat(" ",  49) . "word", getline(1))
  norm! V3<
  call assert_equal(repeat(" ",  2) . "word", getline(1))
  norm! V<
  call assert_equal(repeat(" ",  0) . "word", getline(1))
  norm! V3<
  call assert_equal(repeat(" ",  0) . "word", getline(1))

  set expandtab& shiftwidth& vartabstop&
  bw!
endfunc

" Test the V> and V< visual-mode commands with 'shiftround'.
"
func Test_shift_vis_round()
  set expandtab                 " Don't want to worry about tabs vs. spaces in
                                " results.

  set shiftround
  set shiftwidth=5
  set tabstop=7

  call setline(1, "word")

  " Shift by 'shiftwidth' right and left.

  exe "norm! I  "
  norm! V>
  call assert_equal(repeat(" ",  5) . "word", getline(1))
  exe "norm! I  "
  norm! V2>
  call assert_equal(repeat(" ",  15) . "word", getline(1))
  exe "norm! I  "
  norm! V3>
  call assert_equal(repeat(" ",  30) . "word", getline(1))

  exe "norm! I  "
  norm! V2<
  call assert_equal(repeat(" ",  25) . "word", getline(1))
  norm! V3<
  call assert_equal(repeat(" ",  10) . "word", getline(1))
  norm! V<
  call assert_equal(repeat(" ",  5) . "word", getline(1))
  norm! V<
  call assert_equal(repeat(" ",  0) . "word", getline(1))
  norm! V3<
  call assert_equal(repeat(" ",  0) . "word", getline(1))

  " Shift by 'tabstop' right and left.

  set shiftwidth=0
  call setline(1, "word")

  exe "norm! I  "
  norm! V>
  call assert_equal(repeat(" ",  7) . "word", getline(1))
  exe "norm! I  "
  norm! V2>
  call assert_equal(repeat(" ",  21) . "word", getline(1))
  exe "norm! I  "
  norm! V3>
  call assert_equal(repeat(" ",  42) . "word", getline(1))

  exe "norm! I  "
  norm! V<
  call assert_equal(repeat(" ",  42) . "word", getline(1))
  norm! V<
  call assert_equal(repeat(" ",  35) . "word", getline(1))
  norm! V2<
  call assert_equal(repeat(" ",  21) . "word", getline(1))
  norm! V3<
  call assert_equal(repeat(" ",  0) . "word", getline(1))
  norm! V<
  call assert_equal(repeat(" ",  0) . "word", getline(1))
  norm! V3<
  call assert_equal(repeat(" ",  0) . "word", getline(1))

  call setline(1, "  word")
  norm! V<
  call assert_equal(repeat(" ",  0) . "word", getline(1))


  set expandtab& shiftround& shiftwidth& tabstop&
  bw!
endfunc

" Test the V> and V< visual-mode commands with 'shiftround' and 'vartabstop'.
"
func Test_shift_vis_round_vartabs()
  CheckFeature vartabs
  set expandtab                 " Don't want to worry about tabs vs. spaces in
                                " results.

  set shiftround
  set shiftwidth=0
  set vartabstop=19,17,11

  " Shift by 'vartabstop' right and left.

  call setline(1, "word")

  exe "norm! I  "
  norm! V>
  call assert_equal(repeat(" ",  19) . "word", getline(1))
  exe "norm! I  "
  norm! V3>
  call assert_equal(repeat(" ",  58) . "word", getline(1))

  exe "norm! I  "
  norm! V2<
  call assert_equal(repeat(" ",  47) . "word", getline(1))
  exe "norm! I  "
  norm! V3<
  call assert_equal(repeat(" ",  19) . "word", getline(1))
  exe "norm! I  "
  norm! V3<
  call assert_equal(repeat(" ",  0) . "word", getline(1))
  exe "norm! I  "
  norm! V<
  call assert_equal(repeat(" ",  0) . "word", getline(1))

  set expandtab& shiftround& shiftwidth& vartabstop&
  bw!
endfunc

" Test the :> and :< ex-mode commands.
"
func Test_shift_ex()
  set expandtab                 " Don't want to worry about tabs vs. spaces in
                                " results.

  set shiftwidth=5
  set tabstop=7

  call setline(1, "  word")

  " Shift by 'shiftwidth' right and left.

  >
  call assert_equal(repeat(" ",  7) . "word", getline(1))
  >>
  call assert_equal(repeat(" ",  17) . "word", getline(1))
  >>>
  call assert_equal(repeat(" ",  32) . "word", getline(1))

  <<<<
  call assert_equal(repeat(" ",  12) . "word", getline(1))
  <
  call assert_equal(repeat(" ",  7) . "word", getline(1))
  <
  call assert_equal(repeat(" ",  2) . "word", getline(1))
  <
  call assert_equal(repeat(" ",  0) . "word", getline(1))

  " Shift by 'tabstop' right and left.

  set shiftwidth=0
  call setline(1, "  word")

  >
  call assert_equal(repeat(" ",  9) . "word", getline(1))
  >>
  call assert_equal(repeat(" ",  23) . "word", getline(1))
  >>>
  call assert_equal(repeat(" ",  44) . "word", getline(1))

  <<<<
  call assert_equal(repeat(" ",  16) . "word", getline(1))
  <<
  call assert_equal(repeat(" ",  2) . "word", getline(1))
  <
  call assert_equal(repeat(" ",  0) . "word", getline(1))

  set expandtab& shiftwidth& tabstop&
  bw!
endfunc

" Test the :> and :< ex-mode commands, with vartabstop.
"
func Test_shift_ex_vartabs()
  CheckFeature vartabs
  set expandtab                 " Don't want to worry about tabs vs. spaces in
                                " results.

  set shiftwidth=0
  set vartabstop=19,17,11

  " Shift by 'vartabstop' right and left.

  call setline(1, "  word")

  >
  call assert_equal(repeat(" ",  21) . "word", getline(1))
  >>
  call assert_equal(repeat(" ",  49) . "word", getline(1))
  >>>
  call assert_equal(repeat(" ",  82) . "word", getline(1))

  <<<<
  call assert_equal(repeat(" ",  38) . "word", getline(1))
  <<
  call assert_equal(repeat(" ",  2) . "word", getline(1))
  <
  call assert_equal(repeat(" ",  0) . "word", getline(1))

  set expandtab& shiftwidth& vartabstop&
  bw!
endfunc

" Test the :> and :< ex-mode commands with 'shiftround'.
"
func Test_shift_ex_round()
  set expandtab                 " Don't want to worry about tabs vs. spaces in
                                " results.

  set shiftround
  set shiftwidth=5
  set tabstop=7

  call setline(1, "word")

  " Shift by 'shiftwidth' right and left.

  exe "norm! I  "
  >
  call assert_equal(repeat(" ",  5) . "word", getline(1))
  exe "norm! I  "
  >>
  call assert_equal(repeat(" ",  15) . "word", getline(1))
  exe "norm! I  "
  >>>
  call assert_equal(repeat(" ",  30) . "word", getline(1))

  exe "norm! I  "
  <<<<
  call assert_equal(repeat(" ",  15) . "word", getline(1))
  exe "norm! I  "
  <<
  call assert_equal(repeat(" ",  10) . "word", getline(1))
  <<
  call assert_equal(repeat(" ",  0) . "word", getline(1))
  >>
  <<<
  call assert_equal(repeat(" ",  0) . "word", getline(1))

  " Shift by 'tabstop' right and left.

  set shiftwidth=0
  call setline(1, "word")

  exe "norm! I  "
  >
  call assert_equal(repeat(" ",  7) . "word", getline(1))
  exe "norm! I  "
  >>
  call assert_equal(repeat(" ",  21) . "word", getline(1))
  exe "norm! I  "
  >>>
  call assert_equal(repeat(" ",  42) . "word", getline(1))

  exe "norm! I  "
  <<<<
  call assert_equal(repeat(" ",  21) . "word", getline(1))
  exe "norm! I  "
  <<
  call assert_equal(repeat(" ",  14) . "word", getline(1))
  exe "norm! I  "
  <<<
  call assert_equal(repeat(" ",  0) . "word", getline(1))
  >>
  <<<
  call assert_equal(repeat(" ",  0) . "word", getline(1))

  set expandtab& shiftround& shiftwidth& tabstop&
  bw!
endfunc

" Test the :> and :< ex-mode commands with 'shiftround' and 'vartabstop'.
"
func Test_shift_ex_round_vartabs()
  CheckFeature vartabs
  set expandtab                 " Don't want to worry about tabs vs. spaces in
                                " results.

  set shiftround
  set shiftwidth=0
  set vartabstop=19,17,11

  " Shift by 'vartabstop' right and left.

  call setline(1, "word")

  exe "norm! I  "
  >
  call assert_equal(repeat(" ",  19) . "word", getline(1))
  exe "norm! I  "
  >>
  call assert_equal(repeat(" ",  47) . "word", getline(1))
  >>>
  call assert_equal(repeat(" ",  80) . "word", getline(1))

  <<<<
  call assert_equal(repeat(" ",  36) . "word", getline(1))
  exe "norm! I  "
  <<
  call assert_equal(repeat(" ",  19) . "word", getline(1))
  exe "norm! I  "
  <<
  call assert_equal(repeat(" ",  0) . "word", getline(1))
  <
  call assert_equal(repeat(" ",  0) . "word", getline(1))

  set expandtab& shiftround& shiftwidth& vartabstop&
  bw!
endfunc

" Test shifting lines with <C-T> and <C-D>.
"
func Test_shift_ins()
  set expandtab                 " Don't want to worry about tabs vs. spaces in
                                " results.

  set shiftwidth=5
  set tabstop=7

  " Shift by 'shiftwidth' right and left.

  call setline(1, repeat(" ", 7) . "word")
  exe "norm! 9|i\<C-T>"
  call assert_equal(repeat(" ", 10) . "word", getline(1))
  exe "norm! A\<C-T>"
  call assert_equal(repeat(" ", 15) . "word", getline(1))
  exe "norm! I  \<C-T>"
  call assert_equal(repeat(" ", 20) . "word", getline(1))

  exe "norm! I  \<C-D>"
  call assert_equal(repeat(" ", 20) . "word", getline(1))
  exe "norm! I  "
  exe "norm! 24|i\<C-D>"
  call assert_equal(repeat(" ", 20) . "word", getline(1))
  exe "norm! A\<C-D>"
  call assert_equal(repeat(" ", 15) . "word", getline(1))
  exe "norm! I  "
  exe "norm! A\<C-D>\<C-D>"
  call assert_equal(repeat(" ", 10) . "word", getline(1))
  exe "norm! I\<C-D>\<C-D>\<C-D>"
  call assert_equal(repeat(" ", 0) . "word", getline(1))
  exe "norm! I\<C-D>"
  call assert_equal(repeat(" ", 0) . "word", getline(1))

  " Shift by 'tabstop' right and left.

  set shiftwidth=0
  call setline(1, "word")

  call setline(1, repeat(" ", 9) . "word")
  exe "norm! 11|i\<C-T>"
  call assert_equal(repeat(" ", 14) . "word", getline(1))
  exe "norm! A\<C-T>"
  call assert_equal(repeat(" ", 21) . "word", getline(1))
  exe "norm! I  \<C-T>"
  call assert_equal(repeat(" ", 28) . "word", getline(1))

  exe "norm! I  \<C-D>"
  call assert_equal(repeat(" ", 28) . "word", getline(1))
  exe "norm! I  "
  exe "norm! 32|i\<C-D>"
  call assert_equal(repeat(" ", 28) . "word", getline(1))
  exe "norm! A\<C-D>"
  call assert_equal(repeat(" ", 21) . "word", getline(1))
  exe "norm! I  "
  exe "norm! A\<C-D>\<C-D>"
  call assert_equal(repeat(" ", 14) . "word", getline(1))
  exe "norm! I\<C-D>\<C-D>\<C-D>"
  call assert_equal(repeat(" ", 0) . "word", getline(1))
  exe "norm! I\<C-D>"
  call assert_equal(repeat(" ", 0) . "word", getline(1))

  set expandtab& shiftwidth& tabstop&
  bw!
endfunc

" Test shifting lines with <C-T> and <C-D>, with 'vartabstop'.
"
func Test_shift_ins_vartabs()
  CheckFeature vartabs
  set expandtab                 " Don't want to worry about tabs vs. spaces in
                                " results.

  set shiftwidth=0
  set vartabstop=19,17,11

  " Shift by 'vartabstop' right and left.

  call setline(1, "word")

  call setline(1, repeat(" ", 9) . "word")
  exe "norm! 11|i\<C-T>"
  call assert_equal(repeat(" ", 19) . "word", getline(1))
  exe "norm! A\<C-T>"
  call assert_equal(repeat(" ", 36) . "word", getline(1))
  exe "norm! I  \<C-T>"
  call assert_equal(repeat(" ", 47) . "word", getline(1))

  exe "norm! I  \<C-D>"
  call assert_equal(repeat(" ", 47) . "word", getline(1))
  exe "norm! I  "
  exe "norm! 51|i\<C-D>"
  call assert_equal(repeat(" ", 47) . "word", getline(1))
  exe "norm! A\<C-D>"
  call assert_equal(repeat(" ", 36) . "word", getline(1))
  exe "norm! I  "
  exe "norm! A\<C-D>\<C-D>"
  call assert_equal(repeat(" ", 19) . "word", getline(1))
  exe "norm! I\<C-D>\<C-D>\<C-D>"
  call assert_equal(repeat(" ", 0) . "word", getline(1))
  exe "norm! I\<C-D>"
  call assert_equal(repeat(" ", 0) . "word", getline(1))

  set expandtab& shiftwidth& vartabstop&
  bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
