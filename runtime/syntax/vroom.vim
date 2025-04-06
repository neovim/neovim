" Vim syntax file
" Language:	Vroom (vim testing and executable documentation)
" Maintainer:	David Barnett (https://github.com/google/vim-ft-vroom)
" Last Change:	2014 Jul 23

" quit when a syntax file was already loaded
if exists('b:current_syntax')
  finish
endif

let s:cpo_save = &cpo
set cpo-=C


syn include @vroomVim syntax/vim.vim
syn include @vroomShell syntax/sh.vim

syntax region vroomAction
    \ matchgroup=vroomOutput
    \ start='\m^  ' end='\m$' keepend
    \ contains=vroomControlBlock

syntax region vroomAction
    \ matchgroup=vroomOutput
    \ start='\m^  & ' end='\m$' keepend
    \ contains=vroomControlBlock

syntax match vroomOutput '\m^  &$'

syntax region vroomMessageBody
    \ matchgroup=vroomMessage
    \ start='\m^  \~ ' end='\m$' keepend
    \ contains=vroomControlBlock

syntax region vroomColoredAction
    \ matchgroup=vroomInput
    \ start='\m^  > ' end='\m$' keepend
    \ contains=vimNotation,vroomControlBlock
syntax region vroomAction
    \ matchgroup=vroomInput
    \ start='\m^  % ' end='\m$' keepend
    \ contains=vimNotation,vroomControlBlock

syntax region vroomAction
    \ matchgroup=vroomContinuation
    \ start='\m^  |' end='\m$' keepend

syntax region vroomAction
    \ start='\m^  \ze:' end='\m$' keepend
    \ contains=@vroomVim,vroomControlBlock

syntax region vroomAction
    \ matchgroup=vroomDirective
    \ start='\m^  @\i\+' end='\m$' keepend
    \ contains=vroomControlBlock

syntax region vroomSystemAction
    \ matchgroup=vroomSystem
    \ start='\m^  ! ' end='\m$' keepend
    \ contains=@vroomShell,vroomControlBlock

syntax region vroomHijackAction
    \ matchgroup=vroomHijack
    \ start='\m^  \$ ' end='\m$' keepend
    \ contains=vroomControlBlock

syntax match vroomControlBlock contains=vroomControlEscape,@vroomControls
    \ '\v \([^&()][^()]*\)$'

syntax match vroomControlEscape '\m&' contained

syntax cluster vroomControls
    \ contains=vroomDelay,vroomMode,vroomBuffer,vroomRange
    \,vroomChannel,vroomBind,vroomStrictness
syntax match vroomRange '\v\.(,\+?(\d+|\$)?)?' contained
syntax match vroomRange '\v\d*,\+?(\d+|\$)?' contained
syntax match vroomBuffer '\v\d+,@!' contained
syntax match vroomDelay '\v\d+(\.\d+)?s' contained
syntax match vroomMode '\v<%(regex|glob|verbatim)' contained
syntax match vroomChannel '\v<%(stderr|stdout|command|status)>' contained
syntax match vroomBind '\v<bind>' contained
syntax match vroomStrictness '\v\<%(STRICT|RELAXED|GUESS-ERRORS)\>' contained

highlight default link vroomInput Identifier
highlight default link vroomDirective vroomInput
highlight default link vroomControlBlock vroomInput
highlight default link vroomSystem vroomInput
highlight default link vroomOutput Statement
highlight default link vroomContinuation Constant
highlight default link vroomHijack Special
highlight default link vroomColoredAction Statement
highlight default link vroomSystemAction vroomSystem
highlight default link vroomHijackAction vroomHijack
highlight default link vroomMessage vroomOutput
highlight default link vroomMessageBody Constant

highlight default link vroomControlEscape Special
highlight default link vroomBuffer vroomInput
highlight default link vroomRange Include
highlight default link vroomMode Constant
highlight default link vroomDelay Type
highlight default link vroomStrictness vroomMode
highlight default link vroomChannel vroomMode
highlight default link vroomBind vroomMode

let b:current_syntax = 'vroom'


let &cpo = s:cpo_save
unlet s:cpo_save
