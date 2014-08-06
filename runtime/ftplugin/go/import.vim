" Copyright 2011 The Go Authors. All rights reserved.
" Use of this source code is governed by a BSD-style
" license that can be found in the LICENSE file.
"
" import.vim: Vim commands to import/drop Go packages.
"
" This filetype plugin adds three new commands for go buffers:
"
"   :Import {path}
"
"       Import ensures that the provided package {path} is imported
"       in the current Go buffer, using proper style and ordering.
"       If {path} is already being imported, an error will be
"       displayed and the buffer will be untouched.
"
"   :ImportAs {localname} {path}
"
"       Same as Import, but uses a custom local name for the package.
"
"   :Drop {path}
"
"       Remove the import line for the provided package {path}, if
"       present in the current Go buffer.  If {path} is not being
"       imported, an error will be displayed and the buffer will be
"       untouched.
"
" If you would like to add shortcuts, you can do so by doing the following:
"
"   Import fmt
"   au Filetype go nnoremap <buffer> <LocalLeader>f :Import fmt<CR>
"
"   Drop fmt
"   au Filetype go nnoremap <buffer> <LocalLeader>F :Drop fmt<CR>
"
"   Import the word under your cursor
"   au Filetype go nnoremap <buffer> <LocalLeader>k
"       \ :exe 'Import ' . expand('<cword>')<CR>
"
" The backslash '\' is the default maplocalleader, so it is possible that
" your vim is set to use a different character (:help maplocalleader).
"
" Options:
"
"   g:go_import_commands [default=1]
"
"       Flag to indicate whether to enable the commands listed above.
"
if exists("b:did_ftplugin_go_import")
    finish
endif

if !exists("g:go_import_commands")
    let g:go_import_commands = 1
endif

if g:go_import_commands
    command! -buffer -nargs=? -complete=customlist,go#complete#Package Drop call s:SwitchImport(0, '', <f-args>)
    command! -buffer -nargs=1 -complete=customlist,go#complete#Package Import call s:SwitchImport(1, '', <f-args>)
    command! -buffer -nargs=* -complete=customlist,go#complete#Package ImportAs call s:SwitchImport(1, <f-args>)
endif

function! s:SwitchImport(enabled, localname, path)
    let view = winsaveview()
    let path = a:path

    " Quotes are not necessary, so remove them if provided.
    if path[0] == '"'
        let path = strpart(path, 1)
    endif
    if path[len(path)-1] == '"'
        let path = strpart(path, 0, len(path) - 1)
    endif
    if path == ''
        call s:Error('Import path not provided')
        return
    endif

    " Extract any site prefix (e.g. github.com/).
    " If other imports with the same prefix are grouped separately,
    " we will add this new import with them.
    " Only up to and including the first slash is used.
    let siteprefix = matchstr(path, "^[^/]*/")

    let qpath = '"' . path . '"'
    if a:localname != ''
        let qlocalpath = a:localname . ' ' . qpath
    else
        let qlocalpath = qpath
    endif
    let indentstr = 0
    let packageline = -1 " Position of package name statement
    let appendline = -1  " Position to introduce new import
    let deleteline = -1  " Position of line with existing import
    let linesdelta = 0   " Lines added/removed

    " Find proper place to add/remove import.
    let line = 0
    while line <= line('$')
        let linestr = getline(line)

        if linestr =~# '^package\s'
            let packageline = line
            let appendline = line

        elseif linestr =~# '^import\s\+('
            let appendstr = qlocalpath
            let indentstr = 1
            let appendline = line
            let firstblank = -1
            let lastprefix = ""
            while line <= line("$")
                let line = line + 1
                let linestr = getline(line)
                let m = matchlist(getline(line), '^\()\|\(\s\+\)\(\S*\s*\)"\(.\+\)"\)')
                if empty(m)
                    if siteprefix == "" && a:enabled
                        " must be in the first group
                        break
                    endif
                    " record this position, but keep looking
                    if firstblank < 0
                        let firstblank = line
                    endif
                    continue
                endif
                if m[1] == ')'
                    " if there's no match, add it to the first group
                    if appendline < 0 && firstblank >= 0
                        let appendline = firstblank
                    endif
                    break
                endif
                let lastprefix = matchstr(m[4], "^[^/]*/")
                if a:localname != '' && m[3] != ''
                    let qlocalpath = printf('%-' . (len(m[3])-1) . 's %s', a:localname, qpath)
                endif
                let appendstr = m[2] . qlocalpath
                let indentstr = 0
                if m[4] == path
                    let appendline = -1
                    let deleteline = line
                    break
                elseif m[4] < path
                    " don't set candidate position if we have a site prefix,
                    " we've passed a blank line, and this doesn't share the same
                    " site prefix.
                    if siteprefix == "" || firstblank < 0 || match(m[4], "^" . siteprefix) >= 0
                        let appendline = line
                    endif
                elseif siteprefix != "" && match(m[4], "^" . siteprefix) >= 0
                    " first entry of site group
                    let appendline = line - 1
                    break
                endif
            endwhile
            break

        elseif linestr =~# '^import '
            if appendline == packageline
                let appendstr = 'import ' . qlocalpath
                let appendline = line - 1
            endif
            let m = matchlist(linestr, '^import\(\s\+\)\(\S*\s*\)"\(.\+\)"')
            if !empty(m)
                if m[3] == path
                    let appendline = -1
                    let deleteline = line
                    break
                endif
                if m[3] < path
                    let appendline = line
                endif
                if a:localname != '' && m[2] != ''
                    let qlocalpath = printf("%s %" . len(m[2])-1 . "s", a:localname, qpath)
                endif
                let appendstr = 'import' . m[1] . qlocalpath
            endif

        elseif linestr =~# '^\(var\|const\|type\|func\)\>'
            break

        endif
        let line = line + 1
    endwhile

    " Append or remove the package import, as requested.
    if a:enabled
        if deleteline != -1
            call s:Error(qpath . ' already being imported')
        elseif appendline == -1
            call s:Error('No package line found')
        else
            if appendline == packageline
                call append(appendline + 0, '')
                call append(appendline + 1, 'import (')
                call append(appendline + 2, ')')
                let appendline += 2
                let linesdelta += 3
                let appendstr = qlocalpath
                let indentstr = 1
            endif
            call append(appendline, appendstr)
            execute appendline + 1
            if indentstr
                execute 'normal >>'
            endif
            let linesdelta += 1
        endif
    else
        if deleteline == -1
            call s:Error(qpath . ' not being imported')
        else
            execute deleteline . 'd'
            let linesdelta -= 1

            if getline(deleteline-1) =~# '^import\s\+(' && getline(deleteline) =~# '^)'
                " Delete empty import block
                let deleteline -= 1
                execute deleteline . "d"
                execute deleteline . "d"
                let linesdelta -= 2
            endif

            if getline(deleteline) == '' && getline(deleteline - 1) == ''
                " Delete spacing for removed line too.
                execute deleteline . "d"
                let linesdelta -= 1
            endif
        endif
    endif

    " Adjust view for any changes.
    let view.lnum += linesdelta
    let view.topline += linesdelta
    if view.topline < 0
        let view.topline = 0
    endif

    " Put buffer back where it was.
    call winrestview(view)

endfunction

function! s:Error(s)
    echohl Error | echo a:s | echohl None
endfunction

let b:did_ftplugin_go_import = 1

" vim:ts=4:sw=4:et
