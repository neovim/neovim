" Last Modified: 2023-09-11
" 2026 Oct 15 by Vim project: Fix code injection via crafted directory names

function! cargo#quickfix#CmdPre() abort
    if &filetype ==# 'rust' && get(b:, 'current_compiler', '') ==# 'cargo' &&
         \ &makeprg =~ '\V\^cargo\ \.\*'
        " Preserve the current directory, and 'lcd' to the nearest Cargo file.
        let b:rust_compiler_cargo_qf_has_lcd = haslocaldir()
        let b:rust_compiler_cargo_qf_prev_cd = getcwd()
        let b:rust_compiler_cargo_qf_prev_cd_saved = 1
        let nearest = fnamemodify(cargo#nearestRootCargo(0), ':h')
        call chdir(nearest, 'window')
    else
        let b:rust_compiler_cargo_qf_prev_cd_saved = 0
    endif
endfunction

function! cargo#quickfix#CmdPost() abort
    if exists("b:rust_compiler_cargo_qf_prev_cd_saved") && b:rust_compiler_cargo_qf_prev_cd_saved
        " Restore the current directory.
        let scope = ['global', 'window', 'tabpage']
        call chdir(b:rust_compiler_cargo_qf_prev_cd, scope[b:rust_compiler_cargo_qf_has_lcd])
        let b:rust_compiler_cargo_qf_prev_cd_saved = 0
    endif
endfunction

" vim: set et sw=4 sts=4 ts=8:
