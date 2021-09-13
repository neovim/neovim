" Vim indent file
" Language:     LaTeX
" Maintainer:   Yichao Zhou <broken.zhou AT gmail.com>
" Created:      Sat, 16 Feb 2002 16:50:19 +0100
" Version: 1.0.0
"   Please email me if you found something I can do.  Comments, bug report and
"   feature request are welcome.

" Last Update:  {{{
"               25th Sep 2002, by LH :
"               (*) better support for the option
"               (*) use some regex instead of several '||'.
"               Oct 9th, 2003, by JT:
"               (*) don't change indentation of lines starting with '%'
"               2005/06/15, Moshe Kaminsky <kaminsky AT math.huji.ac.il>
"               (*) New variables:
"                   g:tex_items, g:tex_itemize_env, g:tex_noindent_env
"               2011/3/6, by Yichao Zhou <broken.zhou AT gmail.com>
"               (*) Don't change indentation of lines starting with '%'
"                   I don't see any code with '%' and it doesn't work properly
"                   so I add some code.
"               (*) New features: Add smartindent-like indent for "{}" and  "[]".
"               (*) New variables: g:tex_indent_brace
"               2011/9/25, by Yichao Zhou <broken.zhou AT gmail.com>
"               (*) Bug fix: smartindent-like indent for "[]"
"               (*) New features: Align with "&".
"               (*) New variable: g:tex_indent_and.
"               2011/10/23 by Yichao Zhou <broken.zhou AT gmail.com>
"               (*) Bug fix: improve the smartindent-like indent for "{}" and
"               "[]".
"               2012/02/27 by Yichao Zhou <broken.zhou AT gmail.com>
"               (*) Bug fix: support default folding marker.
"               (*) Indent with "&" is not very handy.  Make it not enable by
"               default.
"               2012/03/06 by Yichao Zhou <broken.zhou AT gmail.com>
"               (*) Modify "&" behavior and make it default again.  Now "&"
"               won't align when there are more then one "&" in the previous
"               line.
"               (*) Add indent "\left(" and "\right)"
"               (*) Trust user when in "verbatim" and "lstlisting"
"               2012/03/11 by Yichao Zhou <broken.zhou AT gmail.com>
"               (*) Modify "&" so that only indent when current line start with
"                   "&".
"               2012/03/12 by Yichao Zhou <broken.zhou AT gmail.com>
"               (*) Modify indentkeys.
"               2012/03/18 by Yichao Zhou <broken.zhou AT gmail.com>
"               (*) Add &cpo
"               2013/05/02 by Yichao Zhou <broken.zhou AT gmail.com>
"               (*) Fix problem about GetTeXIndent checker. Thank Albert Netymk
"                   for reporting this.
"               2014/06/23 by Yichao Zhou <broken.zhou AT gmail.com>
"               (*) Remove the feature g:tex_indent_and because it is buggy.
"               (*) If there is not any obvious indentation hints, we do not
"                   alert our user's current indentation.
"               (*) g:tex_indent_brace now only works if the open brace is the
"                   last character of that line.
"               2014/08/03 by Yichao Zhou <broken.zhou AT gmail.com>
"               (*) Indent current line if last line has larger indentation
"               2016/11/08 by Yichao Zhou <broken.zhou AT gmail.com>
"               (*) Fix problems for \[ and \].  Thanks Bruno for reporting.
"               2017/04/30 by Yichao Zhou <broken.zhou AT gmail.com>
"               (*) Fix a bug between g:tex_noindent_env and g:tex_indent_items
"                   Now g:tex_noindent_env='document\|verbatim\|itemize' (Emacs
"                   style) is supported.  Thanks Miles Wheeler for reporting.
"               2018/02/07 by Yichao Zhou <broken.zhou AT gmail.com>
"               (*) Make indentation more smart in the normal mode
"               2020/04/26 by Yichao Zhou <broken.zhou AT gmail.com>
"               (*) Fix a bug related to \[ & \].  Thanks Manuel Boni for
"               reporting.
"
" }}}

" Document: {{{
"
" For proper latex experience, please put
"         let g:tex_flavor = "latex"
" into your vimrc.
"
" * g:tex_indent_brace
"
"   If this variable is unset or non-zero, it will use smartindent-like style
"   for "{}" and "[]".  Now this only works if the open brace is the last
"   character of that line.
"
"         % Example 1
"         \usetikzlibrary{
"           external
"         }
"
"         % Example 2
"         \tikzexternalize[
"           prefix=tikz]
"
" * g:tex_indent_items
"
"   If this variable is set, item-environments are indented like Emacs does
"   it, i.e., continuation lines are indented with a shiftwidth.
"
"              set                      unset
"   ------------------------------------------------------
"       \begin{itemize}            \begin{itemize}
"         \item blablabla            \item blablabla
"           bla bla bla              bla bla bla
"         \item blablabla            \item blablabla
"           bla bla bla              bla bla bla
"       \end{itemize}              \end{itemize}
"
"
" * g:tex_items
"
"   A list of tokens to be considered as commands for the beginning of an item
"   command. The tokens should be separated with '\|'. The initial '\' should
"   be escaped. The default is '\\bibitem\|\\item'.
"
" * g:tex_itemize_env
"
"   A list of environment names, separated with '\|', where the items (item
"   commands matching g:tex_items) may appear. The default is
"   'itemize\|description\|enumerate\|thebibliography'.
"
" * g:tex_noindent_env
"
"   A list of environment names. separated with '\|', where no indentation is
"   required. The default is 'document\|verbatim'.
" }}}

" Only define the function once
if exists("b:did_indent")
    finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Define global variable {{{

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

" VIM Setting " {{{
setlocal autoindent
setlocal nosmartindent
setlocal indentexpr=GetTeXIndent()
setlocal indentkeys&
exec 'setlocal indentkeys+=[,(,{,),},],\&' . substitute(g:tex_items, '^\|\(\\|\)', ',=', 'g')
let g:tex_items = '^\s*' . substitute(g:tex_items, '^\(\^\\s\*\)*', '', '')
" }}}

function! GetTeXIndent() " {{{
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

    let ccol = 1
    while cline[ccol] =~ '\s'
        let ccol += 1
    endwhile

    "  We are in verbatim, so do what our user what.
    if synIDattr(synID(v:lnum, ccol, 1), "name") == "texZone"
        if empty(cline)
            return indent(lnum)
        else
            return indent(v:lnum)
        endif
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

    " Add a 'shiftwidth' after beginning of environments.
    " Don't add it for \begin{document} and \begin{verbatim}
    " if line =~ '^\s*\\begin{\(.*\)}'  && line !~ 'verbatim'
    " LH modification : \begin does not always start a line
    " ZYC modification : \end after \begin won't cause wrong indent anymore
    if line =~ '\\begin{.*}' 
        if line !~ g:tex_noindent_env
            let ind = ind + shiftwidth()
            let stay = 0
        endif

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
        if line =~ '[[{]$'
            let ind += shiftwidth()
            let stay = 0
        endif

        if cline =~ '^\s*\\\?[\]}]' && s:CheckPairedIsLastCharacter(v:lnum, ccol)
            let ind -= shiftwidth()
            let stay = 0
        endif

        if line !~ '^\s*\\\?[\]}]'
            for i in range(1, strlen(line)-1)
                let char = line[i]
                if char == ']' || char == '}'
                    if s:CheckPairedIsLastCharacter(lnum, i)
                        let ind -= shiftwidth()
                        let stay = 0
                    endif
                endif
            endfor
        endif
    endif

    " Special treatment for 'item'
    " ----------------------------

    if g:tex_indent_items
        " '\item' or '\bibitem' itself:
        if cline =~ g:tex_items
            let ind = ind - shiftwidth()
            let stay = 0
        endif
        " lines following to '\item' are indented once again:
        if line =~ g:tex_items
            let ind = ind + shiftwidth()
            let stay = 0
        endif
    endif

    if stay && mode() == 'i'
        " If there is no obvious indentation hint, and indentation is triggered
        " in insert mode, we trust our user.
        if empty(cline)
            return ind
        else
            return max([indent(v:lnum), s:GetLastBeginIndentation(v:lnum)])
        endif
    else
        return ind
    endif
endfunction "}}}

function! s:GetLastBeginIndentation(lnum) " {{{
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
            if line =~ g:tex_noindent_env
                return indent(lnum)
            endif
            if line =~ g:tex_itemize_env
                return indent(lnum) + 2 * shiftwidth()
            endif
            return indent(lnum) + shiftwidth()
        endif
    endfor
    return -1
endfunction

function! s:GetEndIndentation(lnum) " {{{
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
    let c_lnum = a:lnum
    let c_col = a:col+1

    let line = getline(c_lnum)
    if line[c_col-1] == '\'
        let c_col = c_col + 1
    endif
    let c = line[c_col-1]

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
endfunction "}}}

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: set sw=4 textwidth=80:
