" Vim syntax file.
" Language:    Haredoc (Hare documentation format)
" Maintainer:  Amelia Clarke <selene@perilune.dev>
" Last Change: 2024-05-10
" Upstream:    https://git.sr.ht/~selene/hare.vim

if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'haredoc'

" Syntax {{{1
syn case match
syn iskeyword @,48-57,_

" Code samples.
syn region haredocCodeSample excludenl start='\t\zs' end='$' contains=@NoSpell display

" References to other declarations and modules.
syn region haredocRef start='\[\[' end=']]' contains=haredocRefValid,@NoSpell display keepend oneline
syn match haredocRefValid '\v\[\[\h\w*%(::\h\w*)*%(::)?]]' contained contains=@NoSpell display

" Miscellaneous.
syn keyword haredocTodo FIXME TODO XXX

" Default highlighting {{{1
hi def link haredocCodeSample Comment
hi def link haredocRef Error
hi def link haredocRefValid Special
hi def link haredocTodo Todo

" vim: et sts=2 sw=2 ts=8
