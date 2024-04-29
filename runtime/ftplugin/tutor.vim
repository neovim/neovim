" vim: fdm=marker

" Base: {{{1
call tutor#SetupVim()

" Buffer Settings: {{{1
setlocal noreadonly
if !exists('g:tutor_debug') || g:tutor_debug == 0
    setlocal buftype=nofile
    setlocal concealcursor+=inv
    setlocal conceallevel=2
else
    setlocal buftype=
    setlocal concealcursor&
    setlocal conceallevel=0
endif
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

if !exists('g:tutor_debug') || g:tutor_debug == 0
    call tutor#ApplyMarks()
    autocmd! TextChanged,TextChangedI <buffer> call tutor#ApplyMarksOnChanged()
endif
