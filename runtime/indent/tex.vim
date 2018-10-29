" Vim indent file for TeX
" Language:             TeX
" Maintainer:           Christian Brabandt <cb@256bit.org>
" Previous Maintainer:  YiChao Zhou <broken.zhou AT gmail.com>
" Latest Revision:      2017-05-03
" Version:              0.9.3
" Repository:           https://github.com/chrisbra/vim-tex-indent
" Documention:          :h ft-tex-indent
" Created:              Sat, 16 Feb 2002 16:50:19 +0100
"   Please email me if you found something I can do.  Comments, bug report and
"   feature request are welcome.

" Last Update:  {{{1
"               25th Sep 2002, by LH :
"               (*) better support for the option
"               (*) use some regex instead of several '||'.
"               Oct 9th, 2003, by JT:
"               (*) don't change indentation of lines starting with '%'
"               2005/06/15, Moshe Kaminsky <kaminsky AT math.huji.ac.il>
"               (*) New variables:
"                   g:tex_items, g:tex_itemize_env, g:tex_noindent_env
"               2011/3/6, by Zhou YiChao <broken.zhou AT gmail.com>
"               (*) Don't change indentation of lines starting with '%'
"                   I don't see any code with '%' and it doesn't work properly
"                   so I add some code.
"               (*) New features: Add smartindent-like indent for "{}" and  "[]".
"               (*) New variables: g:tex_indent_brace
"               2011/9/25, by Zhou Yichao <broken.zhou AT gmail.com>
"               (*) Bug fix: smartindent-like indent for "[]"
"               (*) New features: Align with "&".
"               (*) New variable: g:tex_indent_and.
"               2011/10/23 by Zhou Yichao <broken.zhou AT gmail.com>
"               (*) Bug fix: improve the smartindent-like indent for "{}" and
"               "[]".
"               2012/02/27 by Zhou Yichao <broken.zhou AT gmail.com>
"               (*) Bug fix: support default folding marker.
"               (*) Indent with "&" is not very handy.  Make it not enable by
"               default.
"               2012/03/06 by Zhou Yichao <broken.zhou AT gmail.com>
"               (*) Modify "&" behavior and make it default again.  Now "&"
"               won't align when there are more then one "&" in the previous
"               line.
"               (*) Add indent "\left(" and "\right)"
"               (*) Trust user when in "verbatim" and "lstlisting"
"               2012/03/11 by Zhou Yichao <broken.zhou AT gmail.com>
"               (*) Modify "&" so that only indent when current line start with
"                   "&".
"               2012/03/12 by Zhou Yichao <broken.zhou AT gmail.com>
"               (*) Modify indentkeys.
"               2012/03/18 by Zhou Yichao <broken.zhou AT gmail.com>
"               (*) Add &cpo
"               2013/05/02 by Zhou Yichao <broken.zhou AT gmail.com>
"               (*) Fix problem about GetTeXIndent checker. Thank Albert Netymk
"                   for reporting this.
"               2014/06/23 by Zhou Yichao <broken.zhou AT gmail.com>
"               (*) Remove the feature g:tex_indent_and because it is buggy.
"               (*) If there is not any obvious indentation hints, we do not
"                   alert our user's current indentation.
"               (*) g:tex_indent_brace now only works if the open brace is the
"                   last character of that line.
"               2014/08/03 by Zhou Yichao <broken.zhou AT gmail.com>
"               (*) Indent current line if last line has larger indentation
"               2014/08/09 by Zhou Yichao <broken.zhou AT gmail.com>
"               (*) Add missing return value for s:GetEndIndentation(...)
"               2017/05/02: new maintainer Christian Brabandt
"               2017/05/02: use shiftwidth() function
"               2017/05/02: do not add indent when environment starts and ends
"                           at previous line
"               2017/05/03: release 0.9.3 submitted for inclusion with Vim
"
" }}}
" Only define the function once {{{1
if exists("b:did_indent")
    finish
endif

let s:cpo_save = &cpo
set cpo&vim
" Define global variable {{{1
let b:did_indent = 1

if !exists("g:tex_indent_items")
    let g:tex_indent_items = 1
endif
if !exists("g:tex_indent_brace")
    let g:tex_indent_brace = 1
endif
if !exists("g:tex_max_scan_line")
    let g:tex_max_scan_line = 60
endif
if g:tex_indent_items
    if !exists("g:tex_itemize_env")
        let g:tex_itemize_env = 'itemize\|description\|enumerate\|thebibliography'
    endif
    if !exists('g:tex_items')
        let g:tex_items = '\\bibitem\|\\item' 
    endif
else
    let g:tex_items = ''
endif

if !exists("g:tex_noindent_env")
    let g:tex_noindent_env = 'document\|verbatim\|lstlisting'
endif "}}}
" VIM Setting " {{{1
setlocal autoindent
setlocal nosmartindent
setlocal indentexpr=GetTeXIndent()
setlocal indentkeys&
exec 'setlocal indentkeys+=[,(,{,),},],\&' . substitute(g:tex_items, '^\|\(\\|\)', ',=', 'g')
let g:tex_items = '^\s*' . substitute(g:tex_items, '^\(\^\\s\*\)*', '', '')

let b:undo_indent = 'setlocal indentexpr< indentkeys< smartindent< autoindent<'
" }}}
function! GetTeXIndent() " {{{1
    " Find a non-blank line above the current line.
    let lnum = prevnonblank(v:lnum - 1)
    let cnum = v:lnum

    " Comment line is not what we need.
    while lnum != 0 && getline(lnum) =~ '^\s*%'
        let lnum = prevnonblank(lnum - 1)
    endwhile

    " At the start of the file use zero indent.
    if lnum == 0
        return 0 
    endif

    let line = substitute(getline(lnum), '\s*%.*', '','g')     " last line
    let cline = substitute(getline(v:lnum), '\s*%.*', '', 'g') " current line

    "  We are in verbatim, so do what our user what.
    if synIDattr(synID(v:lnum, indent(v:lnum), 1), "name") == "texZone"
        if empty(cline)
            return indent(lnum)
        else
            return indent(v:lnum)
        end
    endif
    
    if lnum == 0
        return 0 
    endif

    let ind = indent(lnum)
    let stay = 1

    " New code for comment: retain the indent of current line
    if cline =~ '^\s*%'
        return indent(v:lnum)
    endif

    " Add a 'shiftwidth' after beginning of environments
    " But don't do it for g:tex_noindent_env or when it also ends at the
    " previous line.
    if line =~ '\\begin{.*}'  && line !~ '\\end{.*}' && line !~ g:tex_noindent_env
        let ind = ind + shiftwidth()
        let stay = 0

        if g:tex_indent_items
            " Add another sw for item-environments
            if line =~ g:tex_itemize_env
                let ind = ind + shiftwidth()
                let stay = 0
            endif
        endif
    endif

    if cline =~ '\\end{.*}'
        let retn = s:GetEndIndentation(v:lnum)
        if retn != -1
            return retn
        endif
    end
    " Subtract a 'shiftwidth' when an environment ends
    if cline =~ '\\end{.*}'
                \ && cline !~ g:tex_noindent_env
                \ && cline !~ '\\begin{.*}.*\\end{.*}'
        if g:tex_indent_items
            " Remove another sw for item-environments
            if cline =~ g:tex_itemize_env
                let ind = ind - shiftwidth()
                let stay = 0
            endif
        endif

        let ind = ind - shiftwidth()
        let stay = 0
    endif

    if g:tex_indent_brace
        let char = line[strlen(line)-1]
        if char == '[' || char == '{'
            let ind += shiftwidth()
            let stay = 0
        endif

        let cind = indent(v:lnum)
        let char = cline[cind]
        if (char == ']' || char == '}') &&
                    \ s:CheckPairedIsLastCharacter(v:lnum, cind)
            let ind -= shiftwidth()
            let stay = 0
        endif

        for i in range(indent(lnum)+1, strlen(line)-1)
            let char = line[i]
            if char == ']' || char == '}'
                if s:CheckPairedIsLastCharacter(lnum, i)
                    let ind -= shiftwidth()
                    let stay = 0
                endif
            endif
        endfor
    endif

    " Special treatment for 'item'
    " ----------------------------

    if g:tex_indent_items
        " '\item' or '\bibitem' itself:
        if cline =~ g:tex_items
            let ind = ind - shiftwidth()
            let stay = 0
        endif
        " lines following to '\item' are intented once again:
        if line =~ g:tex_items
            let ind = ind + shiftwidth()
            let stay = 0
        endif
    endif

    if stay
        " If there is no obvious indentation hint, we trust our user.
        if empty(cline)
            return ind
        else
            return max([indent(v:lnum), s:GetLastBeginIndentation(v:lnum)])
        endif
    else
        return ind
    endif
endfunction "}}}
function! s:GetLastBeginIndentation(lnum) " {{{1
    let matchend = 1
    for lnum in range(a:lnum-1, max([a:lnum - g:tex_max_scan_line, 1]), -1)
        let line = getline(lnum)
        if line =~ '\\end{.*}'
            let matchend += 1
        endif
        if line =~ '\\begin{.*}'
            let matchend -= 1
        endif
        if matchend == 0
            if line =~ g:tex_itemize_env
                return indent(lnum) + 2 * shiftwidth()
            endif
            if line =~ g:tex_noindent_env
                return indent(lnum)
            endif
            return indent(lnum) + shiftwidth()
        endif
    endfor
    return -1
endfunction

function! s:GetEndIndentation(lnum) " {{{1
    if getline(a:lnum) =~ '\\begin{.*}.*\\end{.*}'
        return -1
    endif

    let min_indent = 100
    let matchend = 1
    for lnum in range(a:lnum-1, max([a:lnum-g:tex_max_scan_line, 1]), -1)
        let line = getline(lnum)
        if line =~ '\\end{.*}'
            let matchend += 1
        endif
        if line =~ '\\begin{.*}'
            let matchend -= 1
        endif
        if matchend == 0
            return indent(lnum)
        endif
        if !empty(line)
            let min_indent = min([min_indent, indent(lnum)])
        endif
    endfor
    return min_indent - shiftwidth()
endfunction

" Most of the code is from matchparen.vim
function! s:CheckPairedIsLastCharacter(lnum, col) "{{{
    " Get the character under the cursor and check if it's in 'matchpairs'.
    let c_lnum = a:lnum
    let c_col = a:col+1


    let c = getline(c_lnum)[c_col-1]
    let plist = split(&matchpairs, '.\zs[:,]')
    let i = index(plist, c)
    if i < 0
        return 0
    endif

    " Figure out the arguments for searchpairpos().
    if i % 2 == 0
        let s_flags = 'nW'
        let c2 = plist[i + 1]
    else
        let s_flags = 'nbW'
        let c2 = c
        let c = plist[i - 1]
    endif
    if c == '['
        let c = '\['
        let c2 = '\]'
    endif

    " Find the match.  When it was just before the cursor move it there for a
    " moment.
    let save_cursor = winsaveview()
    call cursor(c_lnum, c_col)

    " When not in a string or comment ignore matches inside them.
    " We match "escape" for special items, such as lispEscapeSpecial.
    let s_skip ='synIDattr(synID(line("."), col("."), 0), "name") ' .
                \ '=~?  "string\\|character\\|singlequote\\|escape\\|comment"'
    execute 'if' s_skip '| let s_skip = 0 | endif'

    let stopline = max([0, c_lnum - g:tex_max_scan_line])

    " Limit the search time to 300 msec to avoid a hang on very long lines.
    " This fails when a timeout is not supported.
    try
        let [m_lnum, m_col] = searchpairpos(c, '', c2, s_flags, s_skip, stopline, 100)
    catch /E118/
    endtry

    call winrestview(save_cursor)

    if m_lnum > 0
        let line = getline(m_lnum)
        return strlen(line) == m_col
    endif

    return 0
endfunction
" Reset cpo setting {{{1
let &cpo = s:cpo_save
unlet s:cpo_save

" vim: set sw=4 textwidth=80:
