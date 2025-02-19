" Last Modified: 2023-09-11

" For debugging, inspired by https://github.com/w0rp/rust/blob/master/autoload/rust/debugging.vim

let s:global_variable_list = [
            \ '_rustfmt_autosave_because_of_config',
            \ 'ftplugin_rust_source_path',
            \ 'loaded_syntastic_rust_cargo_checker',
            \ 'loaded_syntastic_rust_filetype',
            \ 'loaded_syntastic_rust_rustc_checker',
            \ 'rust_bang_comment_leader',
            \ 'rust_cargo_avoid_whole_workspace',
            \ 'rust_clip_command',
            \ 'rust_conceal',
            \ 'rust_conceal_mod_path',
            \ 'rust_conceal_pub',
            \ 'rust_fold',
            \ 'rust_last_args',
            \ 'rust_last_rustc_args',
            \ 'rust_original_delimitMate_excluded_regions',
            \ 'rust_playpen_url',
            \ 'rust_prev_delimitMate_quotes',
            \ 'rust_recent_nearest_cargo_tol',
            \ 'rust_recent_root_cargo_toml',
            \ 'rust_recommended_style',
            \ 'rust_set_conceallevel',
            \ 'rust_set_conceallevel=1',
            \ 'rust_set_foldmethod',
            \ 'rust_set_foldmethod=1',
            \ 'rust_shortener_url',
            \ 'rustc_makeprg_no_percent',
            \ 'rustc_path',
            \ 'rustfmt_autosave',
            \ 'rustfmt_autosave_if_config_present',
            \ 'rustfmt_command',
            \ 'rustfmt_emit_files',
            \ 'rustfmt_fail_silently',
            \ 'rustfmt_options',
            \ 'syntastic_extra_filetypes',
            \ 'syntastic_rust_cargo_fname',
            \]

function! s:Echo(message) abort
    execute 'echo a:message'
endfunction

function! s:EchoGlobalVariables() abort
    for l:key in s:global_variable_list
        if l:key !~# '^_'
            call s:Echo('let g:' . l:key . ' = ' . string(get(g:, l:key, v:null)))
        endif

        if has_key(b:, l:key)
            call s:Echo('let b:' . l:key . ' = ' . string(b:[l:key]))
        endif
    endfor
endfunction

function! rust#debugging#Info() abort
    call cargo#Load()
    call rust#Load()
    call rustfmt#Load()
    call s:Echo('rust.vim Global Variables:')
    call s:Echo('')
    call s:EchoGlobalVariables()

    silent let l:output = system(g:rustfmt_command . ' --version')
    echo l:output

    let l:rustc = exists("g:rustc_path") ? g:rustc_path : "rustc"
    silent let l:output = system(l:rustc . ' --version')
    echo l:output

    silent let l:output = system('cargo --version')
    echo l:output

    version

    if exists(":SyntasticInfo")
        echo "----"
        echo "Info from Syntastic:"
        execute "SyntasticInfo"
    endif
endfunction

function! rust#debugging#InfoToClipboard() abort
    redir @"
    silent call rust#debugging#Info()
    redir END

    call s:Echo('RustInfo copied to your clipboard')
endfunction

function! rust#debugging#InfoToFile(filename) abort
    let l:expanded_filename = expand(a:filename)

    redir => l:output
    silent call rust#debugging#Info()
    redir END

    call writefile(split(l:output, "\n"), l:expanded_filename)
    call s:Echo('RustInfo written to ' . l:expanded_filename)
endfunction

" vim: set et sw=4 sts=4 ts=8:
