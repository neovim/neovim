" Vim filetype plugin file
" Language:	Org
" Previous Maintainer:  Luca Saccarola <github.e41mv@aleeas.com>
" Maintainer:	This runtime file is looking for a new maintainer.
" Last Change:	2025 Aug 05


if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

if exists('b:undo_ftplugin')
    let b:undo_ftplugin .= "|setl cms< com< fo< flp<"
else
    let b:undo_ftplugin = "setl cms< com< fo< flp<"
endif

setl commentstring=#\ %s
setl comments=fb:*,fb:-,fb:+,b:#,b:\:

setl formatoptions+=nql
setl formatlistpat=^\\s*\\(\\(\\d\\|\\a\\)\\+[.)]\\|[+-]\\)\\s\\+

function OrgFoldExpr()
    let l:depth = match(getline(v:lnum), '\(^\*\+\)\@<=\( .*$\)\@=')
    if l:depth > 0 && synIDattr(synID(v:lnum, 1, 1), 'name') =~# '\m^orgHeadline'
        return ">" . l:depth
    endif
    return "="
endfunction

if has("folding") && get(g:, 'org_folding', 0)
    setl foldexpr=OrgFoldExpr()
    setl foldmethod=expr
    let b:undo_ftplugin .= "|setl foldexpr< foldmethod<"
endif

" vim: ts=8 sts=2 sw=2 et
