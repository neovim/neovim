" Vim syntax file
" Language: FvwmM4 preprocessed Fvwm2 configuration files
" Maintainer: David Ne\v{c}as (Yeti) <yeti@physics.muni.cz>
" Last Change: 2002-06-02
" URI: http://physics.muni.cz/~yeti/download/syntax/fvwmm4.vim

" Setup
" quit when a syntax file was already loaded
if exists('b:current_syntax')
  finish
endif

" Let included files know they are included
if !exists('main_syntax')
  let main_syntax = 'fvwm2m4'
endif

" Include M4 syntax
runtime! syntax/m4.vim
unlet b:current_syntax

" Include Fvwm2 syntax (Fvwm1 doesn't have M4 preprocessor)
runtime! syntax/fvwm.vim
unlet b:current_syntax

" That's all!
let b:current_syntax = 'fvwm2m4'

if main_syntax == 'fvwm2m4'
  unlet main_syntax
endif

