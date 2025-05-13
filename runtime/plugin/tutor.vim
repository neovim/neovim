" Tutor:	New Style Tutor Plugin :h vim-tutor-mode
" Maintainer:	This runtime file is looking for a new maintainer.
" Contributors:	Phạm Bình An <phambinhanctb2004@gmail.com>
" Original Author: Felipe Morales <hel.sheep@gmail.com>
" Date: 2025 May 12

if exists('g:loaded_tutor_mode_plugin') || &compatible
    finish
endif
let g:loaded_tutor_mode_plugin = 1

command! -nargs=? -complete=custom,tutor#TutorCmdComplete Tutor call tutor#TutorCmd(<q-args>)
