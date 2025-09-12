" Tutor filetype plugin
" Language:	Tutor (the new tutor plugin)
" Maintainer:	This runtime file is looking for a new maintainer.
" Last Change:	2025 May 10
" Contributors:	Phạm Bình An <phambinhanctb2004@gmail.com>
" Original Author: Felipe Morales <hel.sheep@gmail.com>
" Last Change:
" 2025 May 10 set b:undo_ftplugin
" 2025 May 12 update b:undo_ftplugin

" Base: {{{1
call tutor#SetupVim()

" Buffer Settings: {{{1
setlocal noreadonly
setlocal noundofile

setlocal keywordprg=:help
setlocal iskeyword=@,-,_

" The user will have to enable the folds themself, but we provide the foldexpr
" function.
setlocal foldmethod=manual
setlocal foldexpr=tutor#TutorFolds()
setlocal foldlevel=4

" Load metadata if it exists: {{{1
if filereadable(expand('%').'.json')
    call tutor#LoadMetadata()
endif

" Mappings: {{{1

call tutor#SetNormalMappings()

" Checks: {{{1

sign define tutorok text=✓ texthl=tutorOK
sign define tutorbad text=✗ texthl=tutorX

let b:undo_ftplugin = "setl foldmethod< foldexpr< foldlevel< undofile< keywordprg< iskeyword< |"
    \ . "call tutor#EnableInteractive(v:false) |"

" vim: fdm=marker
