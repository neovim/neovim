" Language:	Rust
" Description:	Vim ftplugin for Rust
" Maintainer:	Chris Morgan <me@chrismorgan.info>
" Last Change:	2024 Mar 17
"		2024 May 23 by Riley Bruins <ribru17@gmail.com ('commentstring')
" For bugs, patches and license go to https://github.com/rust-lang/rust.vim

if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

" vint: -ProhibitAbbreviationOption
let s:save_cpo = &cpo
set cpo&vim
" vint: +ProhibitAbbreviationOption

if get(b:, 'current_compiler', '') ==# ''
    if strlen(findfile('Cargo.toml', '.;')) > 0
        compiler cargo
    else
        compiler rustc
    endif
endif

" Variables {{{1

" The rust source code at present seems to typically omit a leader on /*!
" comments, so we'll use that as our default, but make it easy to switch.
" This does not affect indentation at all (I tested it with and without
" leader), merely whether a leader is inserted by default or not.
if get(g:, 'rust_bang_comment_leader', 0)
    " Why is the `,s0:/*,mb:\ ,ex:*/` there, you ask? I don't understand why,
    " but without it, */ gets indented one space even if there were no
    " leaders. I'm fairly sure that's a Vim bug.
    setlocal comments=s1:/*,mb:*,ex:*/,s0:/*,mb:\ ,ex:*/,:///,://!,://
else
    setlocal comments=s0:/*!,ex:*/,s1:/*,mb:*,ex:*/,:///,://!,://
endif
setlocal commentstring=//\ %s
setlocal formatoptions-=t formatoptions+=croqnl
" j was only added in 7.3.541, so stop complaints about its nonexistence
silent! setlocal formatoptions+=j

" smartindent will be overridden by indentexpr if filetype indent is on, but
" otherwise it's better than nothing.
setlocal smartindent nocindent

if get(g:, 'rust_recommended_style', 1)
    let b:rust_set_style = 1
    setlocal shiftwidth=4 softtabstop=4 expandtab
    setlocal textwidth=99
endif

setlocal include=\\v^\\s*(pub\\s+)?use\\s+\\zs(\\f\|:)+
setlocal includeexpr=rust#IncludeExpr(v:fname)

setlocal suffixesadd=.rs

if exists("g:ftplugin_rust_source_path")
    let &l:path=g:ftplugin_rust_source_path . ',' . &l:path
endif

if exists("g:loaded_delimitMate")
    if exists("b:delimitMate_excluded_regions")
        let b:rust_original_delimitMate_excluded_regions = b:delimitMate_excluded_regions
    endif

    augroup rust.vim.DelimitMate
        autocmd!

        autocmd User delimitMate_map   :call rust#delimitmate#onMap()
        autocmd User delimitMate_unmap :call rust#delimitmate#onUnmap()
    augroup END
endif

" Integration with auto-pairs (https://github.com/jiangmiao/auto-pairs)
if exists("g:AutoPairsLoaded") && !get(g:, 'rust_keep_autopairs_default', 0)
    let b:AutoPairs = {'(':')', '[':']', '{':'}','"':'"', '`':'`'}
endif

if has("folding") && get(g:, 'rust_fold', 0)
    let b:rust_set_foldmethod=1
    setlocal foldmethod=syntax
    if g:rust_fold == 2
        setlocal foldlevel<
    else
        setlocal foldlevel=99
    endif
endif

if has('conceal') && get(g:, 'rust_conceal', 0)
    let b:rust_set_conceallevel=1
    setlocal conceallevel=2
endif

" Motion Commands {{{1
if !exists("g:no_plugin_maps") && !exists("g:no_rust_maps")
    " Bind motion commands to support hanging indents
    nnoremap <silent> <buffer> [[ :call rust#Jump('n', 'Back')<CR>
    nnoremap <silent> <buffer> ]] :call rust#Jump('n', 'Forward')<CR>
    xnoremap <silent> <buffer> [[ :call rust#Jump('v', 'Back')<CR>
    xnoremap <silent> <buffer> ]] :call rust#Jump('v', 'Forward')<CR>
    onoremap <silent> <buffer> [[ :call rust#Jump('o', 'Back')<CR>
    onoremap <silent> <buffer> ]] :call rust#Jump('o', 'Forward')<CR>
endif

" Commands {{{1

" See |:RustRun| for docs
command! -nargs=* -complete=file -bang -buffer RustRun call rust#Run(<bang>0, <q-args>)

" See |:RustExpand| for docs
command! -nargs=* -complete=customlist,rust#CompleteExpand -bang -buffer RustExpand call rust#Expand(<bang>0, <q-args>)

" See |:RustEmitIr| for docs
command! -nargs=* -buffer RustEmitIr call rust#Emit("llvm-ir", <q-args>)

" See |:RustEmitAsm| for docs
command! -nargs=* -buffer RustEmitAsm call rust#Emit("asm", <q-args>)

" See |:RustPlay| for docs
command! -range=% -buffer RustPlay :call rust#Play(<count>, <line1>, <line2>, <f-args>)

" See |:RustFmt| for docs
command! -bar -buffer RustFmt call rustfmt#Format()

" See |:RustFmtRange| for docs
command! -range -buffer RustFmtRange call rustfmt#FormatRange(<line1>, <line2>)

" See |:RustInfo| for docs
command! -bar -buffer RustInfo call rust#debugging#Info()

" See |:RustInfoToClipboard| for docs
command! -bar -buffer RustInfoToClipboard call rust#debugging#InfoToClipboard()

" See |:RustInfoToFile| for docs
command! -bar -nargs=1 -buffer RustInfoToFile call rust#debugging#InfoToFile(<f-args>)

" See |:RustTest| for docs
command! -buffer -nargs=* -count -bang RustTest call rust#Test(<q-mods>, <count>, <bang>0, <q-args>)

if !exists("b:rust_last_rustc_args") || !exists("b:rust_last_args")
    let b:rust_last_rustc_args = []
    let b:rust_last_args = []
endif

" Cleanup {{{1

let b:undo_ftplugin = "
            \ setlocal formatoptions< comments< commentstring< include< includeexpr< suffixesadd<
            \|if exists('b:rust_set_style')
                \|setlocal tabstop< shiftwidth< softtabstop< expandtab< textwidth<
                \|endif
                \|if exists('b:rust_original_delimitMate_excluded_regions')
                    \|let b:delimitMate_excluded_regions = b:rust_original_delimitMate_excluded_regions
                    \|unlet b:rust_original_delimitMate_excluded_regions
                    \|else
                        \|unlet! b:delimitMate_excluded_regions
                        \|endif
                        \|if exists('b:rust_set_foldmethod')
                            \|setlocal foldmethod< foldlevel<
                            \|unlet b:rust_set_foldmethod
                            \|endif
                            \|if exists('b:rust_set_conceallevel')
                                \|setlocal conceallevel<
                                \|unlet b:rust_set_conceallevel
                                \|endif
                                \|unlet! b:rust_last_rustc_args b:rust_last_args
                                \|delcommand -buffer RustRun
                                \|delcommand -buffer RustExpand
                                \|delcommand -buffer RustEmitIr
                                \|delcommand -buffer RustEmitAsm
                                \|delcommand -buffer RustPlay
                                \|delcommand -buffer RustFmt
                                \|delcommand -buffer RustFmtRange
                                \|delcommand -buffer RustInfo
                                \|delcommand -buffer RustInfoToClipboard
                                \|delcommand -buffer RustInfoToFile
                                \|delcommand -buffer RustTest
                                \|silent! nunmap <buffer> [[
                                \|silent! nunmap <buffer> ]]
                                \|silent! xunmap <buffer> [[
                                \|silent! xunmap <buffer> ]]
                                \|silent! ounmap <buffer> [[
                                \|silent! ounmap <buffer> ]]
                                \|setlocal matchpairs-=<:>
                                \|unlet b:match_skip
                                \"

" }}}1

" Code formatting on save
augroup rust.vim.PreWrite
    autocmd!
    autocmd BufWritePre *.rs silent! call rustfmt#PreWrite()
augroup END

setlocal matchpairs+=<:>
" For matchit.vim (rustArrow stops `Fn() -> X` messing things up)
let b:match_skip = 's:comment\|string\|rustCharacter\|rustArrow'

command! -buffer -nargs=+ Cargo call cargo#cmd(<q-args>)
command! -buffer -nargs=* Cbuild call cargo#build(<q-args>)
command! -buffer -nargs=* Ccheck call cargo#check(<q-args>)
command! -buffer -nargs=* Cclean call cargo#clean(<q-args>)
command! -buffer -nargs=* Cdoc call cargo#doc(<q-args>)
command! -buffer -nargs=+ Cnew call cargo#new(<q-args>)
command! -buffer -nargs=* Cinit call cargo#init(<q-args>)
command! -buffer -nargs=* Crun call cargo#run(<q-args>)
command! -buffer -nargs=* Ctest call cargo#test(<q-args>)
command! -buffer -nargs=* Cbench call cargo#bench(<q-args>)
command! -buffer -nargs=* Cupdate call cargo#update(<q-args>)
command! -buffer -nargs=* Csearch  call cargo#search(<q-args>)
command! -buffer -nargs=* Cpublish call cargo#publish(<q-args>)
command! -buffer -nargs=* Cinstall call cargo#install(<q-args>)
command! -buffer -nargs=* Cruntarget call cargo#runtarget(<q-args>)

let b:undo_ftplugin .= '
            \|delcommand -buffer Cargo
            \|delcommand -buffer Cbuild
            \|delcommand -buffer Ccheck
            \|delcommand -buffer Cclean
            \|delcommand -buffer Cdoc
            \|delcommand -buffer Cnew
            \|delcommand -buffer Cinit
            \|delcommand -buffer Crun
            \|delcommand -buffer Ctest
            \|delcommand -buffer Cbench
            \|delcommand -buffer Cupdate
            \|delcommand -buffer Csearch
            \|delcommand -buffer Cpublish
            \|delcommand -buffer Cinstall
            \|delcommand -buffer Cruntarget'

" vint: -ProhibitAbbreviationOption
let &cpo = s:save_cpo
unlet s:save_cpo
" vint: +ProhibitAbbreviationOption

" vim: set et sw=4 sts=4 ts=8:
