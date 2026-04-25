" Vim filetype plugin file
" Original Author: Maxim Kim <habamax@gmail.com>
" Previous Maintainer:  Luca Saccarola <github.e41mv@aleeas.com>
" Maintainer:      This runtime file is looking for a new maintainer.
" Language:        asciidoc
" Last Change:     2025 Aug 05

if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

if exists('b:undo_ftplugin')
    let b:undo_ftplugin .= "|setl cms< com< fo< flp< inex< efm< cfu< fde< fdm<"
else
    let b:undo_ftplugin = "setl cms< com< fo< flp< inex< efm< cfu< fde< fdm<"
endif

" gf to open include::file.ext[] and link:file.ext[] files
setlocal includeexpr=substitute(v:fname,'\\(link:\\\|include::\\)\\(.\\{-}\\)\\[.*','\\2','g')

setlocal comments=
setlocal commentstring=//\ %s

setlocal formatoptions+=cqn
setlocal formatlistpat=^\\s*[\\[({]\\?\\([0-9]\\+
setlocal formatlistpat+=\\\|[a-zA-Z]\\)[\\]:.)}]\\s\\+
setlocal formatlistpat+=\\\|^\\s*-\\s\\+
setlocal formatlistpat+=\\\|^\\s*[*]\\+\\s\\+
setlocal formatlistpat+=\\\|^\\s*[.]\\+\\s\\+

function AsciidocFold()
    let line = getline(v:lnum)

    if (v:lnum == 1) && (line =~ '^----*$')
       return ">1"
    endif

    let nested = get(g:, "asciidoc_foldnested", 1)

    " Regular headers
    let depth = match(line, '\(^=\+\)\@<=\( .*$\)\@=')

    " Do not fold nested regular headers
    if depth > 1 && !nested
        let depth = 1
    endif

    if depth > 0
        " fold all sections under title
        if depth > 1 && !get(g:, "asciidoc_fold_under_title", 1)
            let depth -= 1
        endif
        " check syntax, it should be asciidocTitle or asciidocH
        let syncode = synstack(v:lnum, 1)
        if len(syncode) > 0 && synIDattr(syncode[0], 'name') =~ 'asciidoc\%(H[1-6]\)\|Title'
            return ">" . depth
        endif
    endif

    return "="
endfunction

if has("folding") && get(g:, 'asciidoc_folding', 0)
    setlocal foldexpr=AsciidocFold()
    setlocal foldmethod=expr
    let b:undo_ftplugin .= "|setl foldexpr< foldmethod< foldtext<"
endif
