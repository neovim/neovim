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

setlocal foldmethod=expr
setlocal foldexpr=tutor#TutorFolds()
setlocal foldcolumn=1
setlocal foldlevel=4
setlocal nowrap

setlocal statusline=%{toupper(expand('%:t:r'))}\ tutorial%=
setlocal statusline+=%{tutor#InfoText()}

" Mappings: {{{1

call tutor#SetNormalMappings()
call tutor#SetSampleTextMappings()

" Checks: {{{1

sign define tutorok text=✓ texthl=tutorOK
sign define tutorbad text=✗ texthl=tutorX

if  !exists('g:tutor_debug') || g:tutor_debug == 0
    call tutor#PlaceXMarks()
    autocmd! TextChanged <buffer> call tutor#OnTextChanged()
    autocmd! TextChangedI <buffer> call tutor#OnTextChanged()
endif
