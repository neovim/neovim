" Vim filetype plugin file
" Language:     Javascript
" Maintainer:   Doug Kearns <dougkearns@gmail.com>
" Contributor:  Romain Lafourcade <romainlafourcade@gmail.com>
" Last Change:	2024 Jan 14
" 		2024 May 23 by Riley Bruins <ribru17@gmail.com> ('commentstring')

if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo-=C

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal formatoptions-=t formatoptions+=croql

" Set completion with CTRL-X CTRL-O to autoloaded function.
if exists('&ofu')
    setlocal omnifunc=javascriptcomplete#CompleteJS
endif

" Set 'comments' to format dashed lists in comments.
setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://

setlocal commentstring=//\ %s

" Change the :browse e filter to primarily show JavaScript-related files.
if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
    let b:browsefilter =
                \ "JavaScript Files (*.js)\t*.js\n"
                \ .. "JSX Files (*.jsx)\t*.jsx\n"
                \ .. "JavaScript Modules (*.es, *.es6, *.cjs, *.mjs, *.jsm)\t*.es;*.es6;*.cjs;*.mjs;*.jsm\n"
                \ .. "Vue Templates (*.vue)\t*.vue\n"
                \ .. "JSON Files (*.json)\t*.json\n"
    if has("win32")
        let b:browsefilter ..= "All Files (*.*)\t*\n"
    else
        let b:browsefilter ..= "All Files (*)\t*\n"
    endif
endif

" The following suffixes should be implied when resolving filenames
setlocal suffixesadd+=.js,.jsx,.es,.es6,.cjs,.mjs,.jsm,.vue,.json

" The following suffixes should have low priority
"   .snap    jest snapshot
setlocal suffixes+=.snap

" Remove irrelevant part of 'path'.
" User is expected to augment it with contextually-relevant paths
setlocal path-=/usr/include

" Matchit configuration
if exists("loaded_matchit")
    let b:match_ignorecase = 0
    let b:match_words =
                \ '\<do\>:\<while\>,'
                \ .. '<\@<=\([^ \t>/]\+\)\%(\s\+[^>]*\%([^/]>\|$\)\|>\|$\):<\@<=/\1>,'
                \ .. '<\@<=\%([^ \t>/]\+\)\%(\s\+[^/>]*\|$\):/>'
endif

" Set 'define' to a comprehensive value
let &l:define =
            \ '\(^\s*(*async\s\+function\|(*function\)'
            \ .. '\|^\s*\(\*\|static\|async\|get\|set\|\i\+\.\)'
            \ .. '\|^\s*\(\ze\i\+\)\(([^)]*).*{$\|\s*[:=,]\)'
            \ .. '\|^\s*\(export\s\+\|export\s\+default\s\+\)*\(var\|let\|const\|function\|class\)'
            \ .. '\|\<as\>'

let b:undo_ftplugin =
            \ "setl fo< ofu< com< cms< sua< su< def< pa<"
            \ .. "| unlet! b:browsefilter b:match_ignorecase b:match_words"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: textwidth=78 tabstop=8 shiftwidth=4 softtabstop=4 expandtab
