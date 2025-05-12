" Tutor:	New Style Tutor Plugin :h vim-tutor-mode
" Maintainer:	This runtime file is looking for a new maintainer.
" Contributors:	Phạm Bình An <phambinhanctb2004@gmail.com>
" Original Author: Felipe Morales <hel.sheep@gmail.com>
" Date: 2025 May 10

if exists('g:loaded_tutor_mode_plugin') || &compatible
    finish
endif
let g:loaded_tutor_mode_plugin = 1

" Define this variable so that users get cmdline completion.
if !exists('g:tutor_debug')
  let g:tutor_debug = 0
endif

command! -nargs=? -complete=custom,tutor#TutorCmdComplete Tutor call tutor#TutorCmd(<q-args>)
