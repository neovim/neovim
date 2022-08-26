" Vim syntax file
" Language:		indent(1) configuration file
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Nikolai Weibull <now@bitwi.se>
" Last Change:		2021 Nov 17
"   indent_is_bsd:      If exists, will change somewhat to match BSD implementation
"
" TODO:     is the deny-all (a la lilo.vim nice or no?)...
"       irritating to be wrong to the last char...
"       would be sweet if right until one char fails

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

setlocal iskeyword+=-,+

syn match   indentError   '\S\+'

syn keyword indentTodo    contained TODO FIXME XXX NOTE

syn region  indentComment start='/\*' end='\*/'
                          \ contains=indentTodo,@Spell
syn region  indentComment start='//' skip='\\$' end='$'
                          \ contains=indentTodo,@Spell

if !exists("indent_is_bsd")
  syn match indentOptions '-i\|--indent-level\|-il\|--indent-label'
                        \ nextgroup=indentNumber skipwhite skipempty
endif
syn match   indentOptions '-\%(bli\|c\%([bl]i\|[dip]\)\=\|di\=\|ip\=\|lc\=\|pp\=i\|sbi\|ts\|-\%(brace-indent\|comment-indentation\|case-brace-indentation\|declaration-comment-column\|continuation-indentation\|case-indentation\|else-endif-column\|line-comments-indentation\|declaration-indentation\|indent-level\|parameter-indentation\|line-length\|comment-line-length\|paren-indentation\|preprocessor-indentation\|struct-brace-indentation\|tab-size\)\)'
                        \ nextgroup=indentNumber skipwhite skipempty

syn match   indentNumber  display contained '\d\+\>'

syn match   indentOptions '-T'
                        \ nextgroup=indentIdent skipwhite skipempty

syn match   indentIdent   display contained '\h\w*\>'

syn keyword indentOptions -bacc --blank-lines-after-ifdefs
                        \ -bad --blank-lines-after-declarations
                        \ -badp --blank-lines-after-procedure-declarations
                        \ -bap --blank-lines-after-procedures
                        \ -bbb --blank-lines-before-block-comments
                        \ -bbo --break-before-boolean-operator
                        \ -bc --blank-lines-after-commas
                        \ -bfda --break-function-decl-args
                        \ -bfde --break-function-decl-args-end
                        \ -bl --braces-after-if-line
                        \ -blf --braces-after-func-def-line
                        \ -bls --braces-after-struct-decl-line
                        \ -br --braces-on-if-line
                        \ -brf --braces-on-func-def-line
                        \ -brs --braces-on-struct-decl-line
                        \ -bs --Bill-Shannon --blank-before-sizeof
                        \ -c++ --c-plus-plus
                        \ -cdb --comment-delimiters-on-blank-lines
                        \ -cdw --cuddle-do-while
                        \ -ce --cuddle-else
                        \ -cs --space-after-cast
                        \ -dj --left-justify-declarations
                        \ -eei --extra-expression-indentation
                        \ -fc1 --format-first-column-comments
                        \ -fca --format-all-comments
                        \ -gnu --gnu-style
                        \ -h --help --usage
                        \ -hnl --honour-newlines
                        \ -kr --k-and-r-style --kernighan-and-ritchie --kernighan-and-ritchie-style
                        \ -lp --continue-at-parentheses
                        \ -lps --leave-preprocessor-space
                        \ -nbacc --no-blank-lines-after-ifdefs
                        \ -nbad --no-blank-lines-after-declarations
                        \ -nbadp --no-blank-lines-after-procedure-declarations
                        \ -nbap --no-blank-lines-after-procedures
                        \ -nbbb --no-blank-lines-before-block-comments
                        \ -nbbo --break-after-boolean-operator
                        \ -nbc --no-blank-lines-after-commas
                        \ -nbfda --dont-break-function-decl-args
                        \ -nbfde --dont-break-function-decl-args-end
                        \ -nbs --no-Bill-Shannon --no-blank-before-sizeof
                        \ -ncdb --no-comment-delimiters-on-blank-lines
                        \ -ncdw --dont-cuddle-do-while
                        \ -nce --dont-cuddle-else
                        \ -ncs --no-space-after-casts
                        \ -ndj --dont-left-justify-declarations
                        \ -neei --no-extra-expression-indentation
                        \ -nfc1 --dont-format-first-column-comments
                        \ -nfca --dont-format-comments
                        \ -nhnl --ignore-newlines
                        \ -nip --dont-indent-parameters --no-parameter-indentation
                        \ -nlp --dont-line-up-parentheses
                        \ -nlps --remove-preprocessor-space
                        \ -npcs --no-space-after-function-call-names
                        \ -npmt
                        \ -npro --ignore-profile
                        \ -nprs --no-space-after-parentheses
                        \ -npsl --dont-break-procedure-type
                        \ -nsaf --no-space-after-for
                        \ -nsai --no-space-after-if
                        \ -nsaw --no-space-after-while
                        \ -nsc --dont-star-comments
                        \ -nsob --leave-optional-blank-lines
                        \ -nss --dont-space-special-semicolon
                        \ -nut --no-tabs
                        \ -nv --no-verbosity
                        \ -o --output
                        \ -o --output-file
                        \ -orig --berkeley --berkeley-style --original --original-style
                        \ -pcs --space-after-procedure-calls
                        \ -pmt --preserve-mtime
                        \ -prs --space-after-parentheses
                        \ -psl --procnames-start-lines
                        \ -saf --space-after-for
                        \ -sai --space-after-if
                        \ -saw --space-after-while
                        \ -sc --start-left-side-of-comments
                        \ -sob --swallow-optional-blank-lines
                        \ -ss --space-special-semicolon
                        \ -st --standard-output
                        \ -ut --use-tabs
                        \ -v --verbose
                        \ -version --version
                        \ -linux --linux-style

if exists("indent_is_bsd")
  syn keyword indentOptions -ip -ei -nei
endif

if exists("c_minlines")
  let b:c_minlines = c_minlines
else
  if !exists("c_no_if0")
    let b:c_minlines = 50       " #if 0 constructs can be long
  else
    let b:c_minlines = 15       " mostly for () constructs
  endif
endif

hi def link indentError   Error
hi def link indentComment Comment
hi def link indentTodo    Todo
hi def link indentOptions Keyword
hi def link indentNumber  Number
hi def link indentIdent   Identifier

let b:current_syntax = "indent"

let &cpo = s:cpo_save
unlet s:cpo_save
