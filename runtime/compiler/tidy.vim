" Vim compiler file
" Compiler:	HTML Tidy
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2016 Apr 21

if exists("current_compiler")
  finish
endif
let current_compiler = "tidy"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet makeprg=tidy\ -quiet\ -errors\ --gnu-emacs\ yes\ %:S

" foo.html:8:1: Warning: inserting missing 'foobar' element
" foo.html:9:2: Error: <foobar> is not recognized!
CompilerSet errorformat=%f:%l:%c:\ %trror:%m,%f:%l:%c:\ %tarning:%m,%-G%.%#
