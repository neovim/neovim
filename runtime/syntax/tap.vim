" Vim syntax file
" Language:    Verbose TAP Output
" Maintainer:  Rufus Cable <rufus@threebytesfull.com>
" Remark:      Simple syntax highlighting for TAP output
" License:     Vim License (see :help license)
" Copyright:   (c) 2008-2013 Rufus Cable
" Last Change: 2020 Mar 15

if exists("b:current_syntax")
  finish
endif

syn match tapTestDiag /^ *#.*/ contains=tapTestTodo
syn match tapTestTime /^ *\[\d\d:\d\d:\d\d\].*/ contains=tapTestFile
syn match tapTestFile /\w\+\/[^. ]*/ contained
syn match tapTestFileWithDot /\w\+\/[^ ]*/ contained

syn match tapTestPlan /^ *\d\+\.\.\d\+$/

" tapTest is a line like 'ok 1', 'not ok 2', 'ok 3 - xxxx'
syn match tapTest /^ *\(not \)\?ok \d\+.*/ contains=tapTestStatusOK,tapTestStatusNotOK,tapTestLine

" tapTestLine is the line without the ok/not ok status - i.e. number and
" optional message
syn match tapTestLine /\d\+\( .*\|$\)/ contains=tapTestNumber,tapTestLoadMessage,tapTestTodo,tapTestSkip contained

" turn ok/not ok messages green/red respectively
syn match tapTestStatusOK /ok/ contained
syn match tapTestStatusNotOK /not ok/ contained

" highlight todo tests
syn match tapTestTodo /\c\(# TODO\|Failed (TODO)\) .*$/ contained contains=tapTestTodoRev
syn match tapTestTodoRev /\c\<TODO\>/ contained

" highlight skipped tests
syn match tapTestSkip /\c# skip .*$/ contained contains=tapTestSkipTag
syn match tapTestSkipTag /\c\(# \)\@<=skip\>/ contained

" look behind so "ok 123" and "not ok 124" match test number
syn match tapTestNumber /\(ok \)\@<=\d\d*/ contained
syn match tapTestLoadMessage /\*\*\*.*\*\*\*/ contained contains=tapTestThreeStars,tapTestFileWithDot
syn match tapTestThreeStars /\*\*\*/ contained

syn region tapTestRegion start=/^ *\(not \)\?ok.*$/me=e+1 end=/^\(\(not \)\?ok\|# Looks like you planned \|All tests successful\|Bailout called\)/me=s-1 fold transparent excludenl
syn region tapTestResultsOKRegion start=/^\(All tests successful\|Result: PASS\)/ end=/$/
syn region tapTestResultsNotOKRegion start=/^\(# Looks like you planned \|Bailout called\|# Looks like you failed \|Result: FAIL\)/ end=/$/
syn region tapTestResultsSummaryRegion start=/^Test Summary Report/ end=/^Files=.*$/ contains=tapTestResultsSummaryHeading,tapTestResultsSummaryNotOK

syn region tapTestResultsSummaryHeading start=/^Test Summary Report/ end=/^-\+$/ contained
syn region tapTestResultsSummaryNotOK start=/TODO passed:/ end=/$/ contained

syn region tapTestInstructionsRegion start=/\%1l/ end=/^$/

syn sync fromstart

if !exists("did_tapverboseoutput_syntax_inits")
  let did_tapverboseoutput_syntax_inits = 1

  hi      tapTestStatusOK    term=bold    ctermfg=green                 guifg=Green
  hi      tapTestStatusNotOK term=reverse ctermfg=black  ctermbg=red    guifg=Black     guibg=Red
  hi      tapTestTodo        term=bold    ctermfg=yellow ctermbg=black  guifg=Yellow    guibg=Black
  hi      tapTestTodoRev     term=reverse ctermfg=black  ctermbg=yellow guifg=Black     guibg=Yellow
  hi      tapTestSkip        term=bold    ctermfg=lightblue             guifg=LightBlue
  hi      tapTestSkipTag     term=reverse ctermfg=black  ctermbg=lightblue guifg=Black  guibg=LightBlue
  hi      tapTestTime        term=bold    ctermfg=blue                  guifg=Blue
  hi      tapTestFile        term=reverse ctermfg=black  ctermbg=yellow guibg=Black     guifg=Yellow
  hi      tapTestLoadedFile  term=bold    ctermfg=black  ctermbg=cyan   guibg=Cyan      guifg=Black
  hi      tapTestThreeStars  term=reverse ctermfg=blue                                  guifg=Blue
  hi      tapTestPlan        term=bold    ctermfg=yellow                                guifg=Yellow

  hi link tapTestFileWithDot tapTestLoadedFile
  hi link tapTestNumber      Number
  hi link tapTestDiag        Comment

  hi tapTestRegion ctermbg=green

  hi tapTestResultsOKRegion ctermbg=green ctermfg=black
  hi tapTestResultsNotOKRegion ctermbg=red ctermfg=black

  hi tapTestResultsSummaryHeading ctermbg=blue ctermfg=white
  hi tapTestResultsSummaryNotOK ctermbg=red ctermfg=black

  hi tapTestInstructionsRegion ctermbg=lightmagenta ctermfg=black
endif

let b:current_syntax="tapVerboseOutput"
