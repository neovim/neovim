" Test for :match, :2match, :3match, clearmatches(), getmatches(), matchadd(),
" matchaddpos(), matcharg(), matchdelete(), and setmatches().

source screendump.vim
source check.vim

function Test_match()
  highlight MyGroup1 term=bold ctermbg=red guibg=red
  highlight MyGroup2 term=italic ctermbg=green guibg=green
  highlight MyGroup3 term=underline ctermbg=blue guibg=blue

  " --- Check that "matcharg()" returns the correct group and pattern if a match
  " --- is defined.
  match MyGroup1 /TODO/
  2match MyGroup2 /FIXME/
  3match MyGroup3 /XXX/
  call assert_equal(['MyGroup1', 'TODO'], matcharg(1))
  call assert_equal(['MyGroup2', 'FIXME'], 2->matcharg())
  call assert_equal(['MyGroup3', 'XXX'], matcharg(3))

  " --- Check that "matcharg()" returns an empty list if the argument is not 1,
  " --- 2 or 3 (only 0 and 4 are tested).
  call assert_equal([], matcharg(0))
  call assert_equal([], matcharg(4))

  " --- Check that "matcharg()" returns ['', ''] if a match is not defined.
  match
  2match
  3match
  call assert_equal(['', ''], matcharg(1))
  call assert_equal(['', ''], matcharg(2))
  call assert_equal(['', ''], matcharg(3))

  " --- Check that "matchadd()" and "getmatches()" agree on added matches and
  " --- that default values apply.
  let m1 = matchadd("MyGroup1", "TODO")
  let m2 = matchadd("MyGroup2", "FIXME", 42)
  let m3 = matchadd("MyGroup3", "XXX", 60, 17)
  let ans = [{'group': 'MyGroup1', 'pattern': 'TODO', 'priority': 10, 'id': 1000},
        \    {'group': 'MyGroup2', 'pattern': 'FIXME', 'priority': 42, 'id': 1001},
        \    {'group': 'MyGroup3', 'pattern': 'XXX', 'priority': 60, 'id': 17}]
  call assert_equal(ans, getmatches())

  " --- Check that "matchdelete()" deletes the matches defined in the previous
  " --- test correctly.
  call matchdelete(m1)
  eval m2->matchdelete()
  call matchdelete(m3)
  call assert_equal([], getmatches())

  " --- Check that "matchdelete()" returns 0 if successful and otherwise -1.
  let m = matchadd("MyGroup1", "TODO")
  call assert_equal(0, matchdelete(m))
  call assert_fails('call matchdelete(42)', 'E803:')

  " --- Check that "clearmatches()" clears all matches defined by ":match" and
  " --- "matchadd()".
  let m1 = matchadd("MyGroup1", "TODO")
  let m2 = "MyGroup2"->matchadd("FIXME", 42)
  let m3 = matchadd("MyGroup3", "XXX", 60, 17)
  match MyGroup1 /COFFEE/
  2match MyGroup2 /HUMPPA/
  3match MyGroup3 /VIM/
  call clearmatches()
  call assert_equal([], getmatches())

  " --- Check that "setmatches()" restores a list of matches saved by
  " --- "getmatches()" without changes. (Matches with equal priority must also
  " --- remain in the same order.)
  let m1 = matchadd("MyGroup1", "TODO")
  let m2 = matchadd("MyGroup2", "FIXME", 42)
  let m3 = matchadd("MyGroup3", "XXX", 60, 17)
  match MyGroup1 /COFFEE/
  2match MyGroup2 /HUMPPA/
  3match MyGroup3 /VIM/
  let ml = getmatches()
  call clearmatches()
  call setmatches(ml)
  call assert_equal(ml, getmatches())
  call clearmatches()

  " --- Check that "setmatches()" will not add two matches with the same ID. The
  " --- expected behaviour (for now) is to add the first match but not the
  " --- second and to return 0 (even though it is a matter of debate whether
  " --- this can be considered successful behaviour).
  let data = [{'group': 'MyGroup1', 'pattern': 'TODO', 'priority': 10, 'id': 1},
        \    {'group': 'MyGroup2', 'pattern': 'FIXME', 'priority': 10, 'id': 1}]
  call assert_fails('call setmatches(data)', 'E801:')
  call assert_equal([data[0]], getmatches())
  call clearmatches()

  " --- Check that "setmatches()" returns 0 if successful and otherwise -1.
  " --- (A range of valid and invalid input values are tried out to generate the
  " --- return values.)
  call assert_equal(0, setmatches([]))
  call assert_equal(0, setmatches([{'group': 'MyGroup1', 'pattern': 'TODO', 'priority': 10, 'id': 1}]))
  call clearmatches()
  call assert_fails('call setmatches(0)', 'E714:')
  call assert_fails('call setmatches([0])', 'E474:')
  call assert_fails("call setmatches([{'wrong key': 'wrong value'}])", 'E474:')

  call setline(1, 'abcdefghijklmnopq')
  call matchaddpos("MyGroup1", [[1, 5], [1, 8, 3]], 10, 3)
  1
  redraw!
  let v1 = screenattr(1, 1)
  let v5 = screenattr(1, 5)
  let v6 = screenattr(1, 6)
  let v8 = screenattr(1, 8)
  let v10 = screenattr(1, 10)
  let v11 = screenattr(1, 11)
  call assert_notequal(v1, v5)
  call assert_equal(v6, v1)
  call assert_equal(v8, v5)
  call assert_equal(v10, v5)
  call assert_equal(v11, v1)
  call assert_equal([{'group': 'MyGroup1', 'id': 3, 'priority': 10, 'pos1': [1, 5, 1], 'pos2': [1, 8, 3]}], getmatches())
  call clearmatches()

  call setline(1, 'abcdΣabcdef')
  eval "MyGroup1"->matchaddpos([[1, 4, 2], [1, 9, 2]], 10, 42)
  1
  redraw!
  let v1 = screenattr(1, 1)
  let v4 = screenattr(1, 4)
  let v5 = screenattr(1, 5)
  let v6 = screenattr(1, 6)
  let v7 = screenattr(1, 7)
  let v8 = screenattr(1, 8)
  let v9 = screenattr(1, 9)
  let v10 = screenattr(1, 10)
  call assert_equal([{'group': 'MyGroup1', 'id': 42, 'priority': 10, 'pos1': [1, 4, 2], 'pos2': [1, 9, 2]}], getmatches())
  call assert_notequal(v1, v4)
  call assert_equal(v5, v4)
  call assert_equal(v6, v1)
  call assert_equal(v7, v1)
  call assert_equal(v8, v4)
  call assert_equal(v9, v4)
  call assert_equal(v10, v1)

  " Check, that setmatches() can correctly restore the matches from matchaddpos()
  call matchadd('MyGroup1', '\%2lmatchadd')
  let m=getmatches()
  call clearmatches()
  call setmatches(m)
  call assert_equal([{'group': 'MyGroup1', 'id': 42, 'priority': 10, 'pos1': [1, 4, 2], 'pos2': [1,9, 2]}, {'group': 'MyGroup1', 'pattern': '\%2lmatchadd', 'priority': 10, 'id': 1106}], getmatches())

  highlight MyGroup1 NONE
  highlight MyGroup2 NONE
  highlight MyGroup3 NONE
endfunc

func Test_match_error()
  call assert_fails('match Error', 'E475:')
  call assert_fails('match Error /', 'E475:')
  call assert_fails('4match Error /x/', 'E476:')
  call assert_fails('match Error /x/ x', 'E488:')
endfunc

func Test_matchadd_error()
  call clearmatches()
  " Nvim: not an error anymore:
  " call assert_fails("call matchadd('GroupDoesNotExist', 'X')", 'E28:')
  call matchadd('GroupDoesNotExist', 'X')
  call assert_equal([{'group': 'GroupDoesNotExist', 'pattern': 'X', 'priority': 10, 'id': 1206}], getmatches())
  call assert_fails("call matchadd('Search', '\\(')", 'E54:')
  call assert_fails("call matchadd('Search', 'XXX', 1, 123, 1)", 'E715:')
  call assert_fails("call matchadd('Error', 'XXX', 1, 3)", 'E798:')
  call assert_fails("call matchadd('Error', 'XXX', 1, 0)", 'E799:')
  call assert_fails("call matchadd('Error', 'XXX', [], 0)", 'E745:')
endfunc

func Test_matchaddpos()
  syntax on
  set hlsearch

  call setline(1, ['12345', 'NP'])
  call matchaddpos('Error', [[1,2], [1,6], [2,2]])
  redraw!
  call assert_notequal(screenattr(2,2), 0)
  call assert_equal(screenattr(2,2), screenattr(1,2))
  call assert_notequal(screenattr(2,2), screenattr(1,6))
  1
  call matchadd('Search', 'N\|\n')
  redraw!
  call assert_notequal(screenattr(2,1), 0)
  call assert_equal(screenattr(2,1), screenattr(1,6))
  exec "norm! i0\<Esc>"
  redraw!
  call assert_equal(screenattr(2,2), screenattr(1,6))

  " Check overlapping pos
  call clearmatches()
  call setline(1, ['1234567890', 'NH'])
  call matchaddpos('Error', [[1,1,5], [1,3,5], [2,2]])
  redraw!
  call assert_notequal(screenattr(2,2), 0)
  call assert_equal(screenattr(2,2), screenattr(1,5))
  call assert_equal(screenattr(2,2), screenattr(1,7))
  call assert_notequal(screenattr(2,2), screenattr(1,8))

  call clearmatches()
  call matchaddpos('Error', [[1], [2,2]])
  redraw!
  call assert_equal(screenattr(2,2), screenattr(1,1))
  call assert_equal(screenattr(2,2), screenattr(1,10))
  call assert_notequal(screenattr(2,2), screenattr(1,11))

  " Check overlapping pos
  call clearmatches()
  call setline(1, ['1234567890', 'NH'])
  call matchaddpos('Error', [[1,1,5], [1,3,5], [2,2]])
  redraw!
  call assert_notequal(screenattr(2,2), 0)
  call assert_equal(screenattr(2,2), screenattr(1,5))
  call assert_equal(screenattr(2,2), screenattr(1,7))
  call assert_notequal(screenattr(2,2), screenattr(1,8))

  nohl
  call clearmatches()
  syntax off
  set hlsearch&
endfunc

" Add 12 match positions (previously the limit was 8 positions).
func Test_matchaddpos_dump()
  CheckScreendump

  let lines =<< trim END
      call setline(1, ['1234567890123']->repeat(14))
      call matchaddpos('Search', range(1, 12)->map({i, v -> [v, v]}))
  END
  call writefile(lines, 'Xmatchaddpos', 'D')
  let buf = RunVimInTerminal('-S Xmatchaddpos', #{rows: 14})
  call VerifyScreenDump(buf, 'Test_matchaddpos_1', {})

  call StopVimInTerminal(buf)
endfunc

func Test_matchaddpos_otherwin()
  syntax on
  new
  call setline(1, ['12345', 'NP'])
  let winid = win_getid()

  wincmd w
  call matchadd('Search', '4', 10, -1, {'window': winid})
  call matchaddpos('Error', [[1,2], [2,2]], 10, -1, {'window': winid})
  redraw!
  call assert_notequal(screenattr(1,2), 0)
  call assert_notequal(screenattr(1,4), 0)
  call assert_notequal(screenattr(2,2), 0)
  call assert_equal(screenattr(1,2), screenattr(2,2))
  call assert_notequal(screenattr(1,2), screenattr(1,4))

  let savematches = getmatches(winid)
  let expect = [
        \ {'group': 'Search', 'pattern': '4', 'priority': 10, 'id': 1000},
        \ {'group': 'Error', 'id': 1001, 'priority': 10, 'pos1': [1, 2, 1], 'pos2': [2, 2, 1]},
        \]
  call assert_equal(expect, savematches)

  eval winid->clearmatches()
  call assert_equal([], getmatches(winid))

  call setmatches(savematches, winid)
  call assert_equal(expect, savematches)

  wincmd w
  bwipe!
  call clearmatches()
  syntax off
endfunc

func Test_matchaddpos_using_negative_priority()
  set hlsearch

  call clearmatches()

  call setline(1, 'x')
  let @/='x'
  redraw!
  let search_attr = screenattr(1,1)

  let @/=''
  call matchaddpos('Error', [1], 10)
  redraw!
  let error_attr = screenattr(1,1)

  call setline(2, '-1 match priority')
  call matchaddpos('Error', [2], -1)
  redraw!
  let negative_match_priority_attr = screenattr(2,1)

  call assert_notequal(negative_match_priority_attr, search_attr, "Match with negative priority is incorrectly highlighted with Search highlight.")
  call assert_equal(negative_match_priority_attr, error_attr)

  nohl
  set hlsearch&
endfunc

func Test_matchaddpos_error()
  call assert_fails("call matchaddpos('Error', 1)", 'E686:')
  call assert_fails("call matchaddpos('Error', [1], 1, 1)", 'E798:')
  call assert_fails("call matchaddpos('Error', [1], 1, 2)", 'E798:')
  call assert_fails("call matchaddpos('Error', [1], 1, 0)", 'E799:')
  call assert_fails("call matchaddpos('Error', [1], 1, 123, 1)", 'E715:')
  call assert_fails("call matchaddpos('Error', [1], 1, 5, {'window':12345})", 'E957:')
  " Why doesn't the following error have an error code E...?
  " call assert_fails("call matchaddpos('Error', [{}])", 'E290:')
  call assert_fails("call matchaddpos('Error', [{}])", 'E5031:')
  call assert_equal(-1, matchaddpos('Error', v:_null_list))
  call assert_equal(-1, matchaddpos('Error', []))
  call assert_fails("call matchaddpos('Error', [1], [], 1)", 'E745:')
endfunc

func OtherWindowCommon()
  let lines =<< trim END
    call setline(1, 'Hello Vim world')
    let mid = matchadd('Error', 'world', 1)
    let winid = win_getid()
    new
  END
  call writefile(lines, 'XscriptMatchCommon')
  let buf = RunVimInTerminal('-S XscriptMatchCommon', #{rows: 12})
  call TermWait(buf)
  return buf
endfunc

func Test_matchdelete_other_window()
  CheckScreendump

  let buf = OtherWindowCommon()
  call term_sendkeys(buf, ":call matchdelete(mid, winid)\<CR>")
  call VerifyScreenDump(buf, 'Test_matchdelete_1', {})

  call StopVimInTerminal(buf)
  call delete('XscriptMatchCommon')
endfunc

func Test_matchdelete_error()
  call assert_fails("call matchdelete(0)", 'E802:')
  call assert_fails("call matchdelete(1, -1)", 'E957:')
endfunc

func Test_matchclear_other_window()
  CheckRunVimInTerminal
  let buf = OtherWindowCommon()
  call term_sendkeys(buf, ":call clearmatches(winid)\<CR>")
  call VerifyScreenDump(buf, 'Test_matchclear_1', {})

  call StopVimInTerminal(buf)
  call delete('XscriptMatchCommon')
endfunc

func Test_matchadd_other_window()
  CheckRunVimInTerminal
  let buf = OtherWindowCommon()
  call term_sendkeys(buf, ":call matchadd('Search', 'Hello', 1, -1, #{window: winid})\<CR>")
  call term_sendkeys(buf, ":\<CR>")
  call VerifyScreenDump(buf, 'Test_matchadd_1', {})

  call StopVimInTerminal(buf)
  call delete('XscriptMatchCommon')
endfunc

func Test_match_in_linebreak()
  CheckRunVimInTerminal

  let lines =<< trim END
    set breakindent linebreak breakat+=]
    call printf('%s]%s', repeat('x', 50), repeat('x', 70))->setline(1)
    call matchaddpos('ErrorMsg', [[1, 51]])
  END
  call writefile(lines, 'XscriptMatchLinebreak')
  let buf = RunVimInTerminal('-S XscriptMatchLinebreak', #{rows: 10})
  call VerifyScreenDump(buf, 'Test_match_linebreak', {})

  call StopVimInTerminal(buf)
  call delete('XscriptMatchLinebreak')
endfunc

func Test_match_with_incsearch()
  CheckRunVimInTerminal

  let lines =<< trim END
    set incsearch
    call setline(1, range(20))
    call matchaddpos('ErrorMsg', [3])
  END
  call writefile(lines, 'XmatchWithIncsearch')
  let buf = RunVimInTerminal('-S XmatchWithIncsearch', #{rows: 6})
  call VerifyScreenDump(buf, 'Test_match_with_incsearch_1', {})

  call term_sendkeys(buf, ":s/0")
  call VerifyScreenDump(buf, 'Test_match_with_incsearch_2', {})

  call term_sendkeys(buf, "\<CR>")
  call StopVimInTerminal(buf)
  call delete('XmatchWithIncsearch')
endfunc

" Test for deleting matches outside of the screen redraw top/bottom lines
" This should cause a redraw of those lines.
func Test_matchdelete_redraw()
  new
  call setline(1, range(1, 500))
  call cursor(250, 1)
  let m1 = matchaddpos('Search', [[250]])
  let m2 = matchaddpos('Search', [[10], [450]])
  redraw!
  let m3 = matchaddpos('Search', [[240], [260]])
  call matchdelete(m2)
  let m = getmatches()
  call assert_equal(2, len(m))
  call assert_equal([250], m[0].pos1)
  redraw!
  call matchdelete(m1)
  call assert_equal(1, len(getmatches()))
  bw!
endfunc

func Test_match_tab_with_linebreak()
  CheckRunVimInTerminal

  let lines =<< trim END
    set linebreak
    call setline(1, "\tix")
    call matchadd('ErrorMsg', '\t')
  END
  call writefile(lines, 'XscriptMatchTabLinebreak', 'D')
  let buf = RunVimInTerminal('-S XscriptMatchTabLinebreak', #{rows: 10})
  call VerifyScreenDump(buf, 'Test_match_tab_linebreak', {})

  call StopVimInTerminal(buf)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
