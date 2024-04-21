" Vim filetype plugin file
" Language:     Astro
" Maintainer:   Romain Lafourcade <romainlafourcade@gmail.com>
" Last Change:  2024 Apr 21

if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo-=C

function! s:IdentifyScope(start, end) abort
    let pos_start = searchpairpos(a:start, '', a:end, 'bnW')
    let pos_end = searchpairpos(a:start, '', a:end, 'nW')

    return pos_start != [0, 0]
                \ && pos_end != [0, 0]
                \ && pos_start[0] != getpos('.')[1]
endfunction

function! s:AstroComments() abort
    if s:IdentifyScope('^---\n\s*\S', '^---\n\n')
                \ || s:IdentifyScope('^\s*<script', '^\s*<\/script>')
        " ECMAScript comments
        setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://
        setlocal commentstring=//%s

    elseif s:IdentifyScope('^\s*<style', '^\s*<\/style>')
        " CSS comments
        setlocal comments=s1:/*,mb:*,ex:*/
        setlocal commentstring=/*%s*/

    else
        " HTML comments
        setlocal comments=s:<!--,m:\ \ \ \ ,e:-->
        setlocal commentstring=<!--%s-->
    endif
endfunction

" https://code.visualstudio.com/docs/languages/jsconfig
function! s:CollectPathsFromConfig() abort
    let config_json = findfile('tsconfig.json', '.;')

    if empty(config_json)
        let config_json = findfile('jsconfig.json', '.;')

        if empty(config_json)
            return
        endif
    endif

    let paths_from_config = config_json
                \ ->readfile()
                \ ->filter({ _, val -> val =~ '^\s*[\[\]{}"0-9]' })
                \ ->join()
                \ ->json_decode()
                \ ->get('compilerOptions', {})
                \ ->get('paths', {})

    if !empty(paths_from_config)
        let b:astro_paths = paths_from_config
                    \ ->map({key, val -> [
                    \     key->glob2regpat(),
                    \     val[0]->substitute('\/\*$', '', '')
                    \   ]})
                    \ ->values()
    endif

    let b:undo_ftplugin ..= " | unlet! b:astro_paths"
endfunction

function! s:AstroInclude(filename) abort
    let decorated_filename = a:filename
                \ ->substitute("^", "@", "")

    let found_path = b:
                \ ->get("astro_paths", [])
                \ ->indexof({ key, val -> decorated_filename =~ val[0]})

    if found_path != -1
        let alias = b:astro_paths[found_path][0]
        let path  = b:astro_paths[found_path][1]
                    \ ->substitute('\(\/\)*$', '/', '')

        return decorated_filename
                    \ ->substitute(alias, path, '')
    endif

    return a:filename
endfunction

let b:undo_ftplugin = "setlocal"
            \ .. " formatoptions<"
            \ .. " path<"
            \ .. " suffixesadd<"
            \ .. " matchpairs<"
            \ .. " comments<"
            \ .. " commentstring<"
            \ .. " iskeyword<"
            \ .. " define<"
            \ .. " include<"
            \ .. " includeexpr<"

" Create self-resetting autocommand group
augroup Astro
    autocmd! * <buffer>
augroup END

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal formatoptions-=t
setlocal formatoptions+=croql

" Remove irrelevant part of 'path'.
setlocal path-=/usr/include

" Seed 'path' with default directories for :find, gf, etc.
setlocal path+=src/**
setlocal path+=public/**

" Help Vim find extension-less filenames
let &l:suffixesadd =
            \ ".astro"
            \ .. ",.js,.jsx,.es,.es6,.cjs,.mjs,.jsm"
            \ .. ",.json"
            \ .. ",.scss,.sass,.css"
            \ .. ",.svelte"
            \ .. ",.ts,.tsx,.d.ts"
            \ .. ",.vue"

" From $VIMRUNTIME/ftplugin/html.vim
setlocal matchpairs+=<:>

" Matchit configuration
if exists("loaded_matchit")
    let b:match_ignorecase = 0

    " From $VIMRUNTIME/ftplugin/javascript.vim
    let b:match_words =
                \ '\<do\>:\<while\>,'
                \ .. '<\@<=\([^ \t>/]\+\)\%(\s\+[^>]*\%([^/]>\|$\)\|>\|$\):<\@<=/\1>,'
                \ .. '<\@<=\%([^ \t>/]\+\)\%(\s\+[^/>]*\|$\):/>'

    " From $VIMRUNTIME/ftplugin/html.vim
    let b:match_words ..=
                \ '<!--:-->,'
                \ .. '<:>,'
                \ .. '<\@<=[ou]l\>[^>]*\%(>\|$\):<\@<=li\>:<\@<=/[ou]l>,'
                \ .. '<\@<=dl\>[^>]*\%(>\|$\):<\@<=d[td]\>:<\@<=/dl>,'
                \ .. '<\@<=\([^/!][^ \t>]*\)[^>]*\%(>\|$\):<\@<=/\1>'

    let b:undo_ftplugin ..= " | unlet! b:match_ignorecase b:match_words"
endif

" Change what constitutes a word, mainly useful for CSS/SASS
setlocal iskeyword+=-
setlocal iskeyword+=$
setlocal iskeyword+=%

" Define paths/aliases for module resolution
call s:CollectPathsFromConfig()

" Find ESM imports
setlocal include=^\\s*\\(import\\\|import\\s\\+[^\/]\\+from\\)\\s\\+['\"]

" Process aliases if file can't be found
setlocal includeexpr=s:AstroInclude(v:fname)

" Set 'define' to a comprehensive value
" From $VIMRUNTIME/ftplugin/javascript.vim and
" $VIMRUNTIME/ftplugin/sass.vim
let &l:define =
            \ '\(^\s*(*async\s\+function\|(*function\)'
            \ .. '\|^\s*\(\*\|static\|async\|get\|set\|\i\+\.\)'
            \ .. '\|^\s*\(\ze\i\+\)\(([^)]*).*{$\|\s*[:=,]\)'


" Set &comments and &commentstring according to current scope
autocmd Astro CursorMoved <buffer> call s:AstroComments()

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: textwidth=78 tabstop=8 shiftwidth=4 softtabstop=4 expandtab
