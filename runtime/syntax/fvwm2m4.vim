" Vim syntax file
" Language: FvwmM4 preprocessed Fvwm2 configuration files
" Maintainer: David Ne\v{c}as (Yeti) <yeti@physics.muni.cz>
" Last Change: 2002-06-02
" URI: http://physics.muni.cz/~yeti/download/syntax/fvwmm4.vim

" Setup
if version >= 600
  if exists('b:current_syntax')
    finish
  endif
else
  syntax clear
endif

" Let included files know they are included
if !exists('main_syntax')
  let main_syntax = 'fvwm2m4'
endif

" Include M4 syntax
if version >= 600
  runtime! syntax/m4.vim
else
  so <sfile>:p:h/m4.vim
endif
unlet b:current_syntax

" Include Fvwm2 syntax (Fvwm1 doesn't have M4 preprocessor)
if version >= 600
  runtime! syntax/fvwm.vim
else
  so <sfile>:p:h/fvwm.vim
endif
unlet b:current_syntax

" That's all!
let b:current_syntax = 'fvwm2m4'

if main_syntax == 'fvwm2m4'
  unlet main_syntax
endif

