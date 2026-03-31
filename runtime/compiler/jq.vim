" Vim compiler file
" Compiler:	jq
" Maintainer:	Vito <vito.blog@gmail.com>
" Last Change:	2024 Apr 17
" Upstream: https://github.com/vito-c/jq.vim

if exists('b:current_compiler')
  finish
endif
let b:current_compiler = 'jq'

let s:save_cpoptions = &cpoptions
set cpoptions&vim

if has('unix')
  CompilerSet makeprg=jq\ -f\ %:S\ /dev/null
else
  CompilerSet makeprg=jq\ -f\ %:S\ nul
endif
CompilerSet errorformat=%E%m\ at\ \\<%o\\>\\,\ line\ %l:,
            \%Z,
            \%-G%.%#

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
