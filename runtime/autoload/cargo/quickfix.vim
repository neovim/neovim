" Last Modified: 2023-09-11

function! cargo#quickfix#CmdPre() abort
    if &filetype ==# 'rust' && get(b:, 'current_compiler', '') ==# 'cargo' &&
         \ &makeprg =~ '\V\^cargo\ \.\*'
        " Preserve the current directory, and 'lcd' to the nearest Cargo file.
        let b:rust_compiler_cargo_qf_has_lcd = haslocaldir()
        let b:rust_compiler_cargo_qf_prev_cd = getcwd()
        let b:rust_compiler_cargo_qf_prev_cd_saved = 1
        let l:nearest = fnamemodify(cargo#nearestRootCargo(0), ':h')
        execute 'lchdir! '.l:nearest
    else
        let b:rust_compiler_cargo_qf_prev_cd_saved = 0
    endif
endfunction

function! cargo#quickfix#CmdPost() abort
    if exists("b:rust_compiler_cargo_qf_prev_cd_saved") && b:rust_compiler_cargo_qf_prev_cd_saved
        " Restore the current directory.
        if b:rust_compiler_cargo_qf_has_lcd
            execute 'lchdir! '.b:rust_compiler_cargo_qf_prev_cd
        else
            execute 'chdir! '.b:rust_compiler_cargo_qf_prev_cd
        endif
        let b:rust_compiler_cargo_qf_prev_cd_saved = 0
    endif
endfunction

" vim: set et sw=4 sts=4 ts=8:
