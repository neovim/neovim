" FUNCTIONS IN THIS FILE ARE MEANT TO BE USED BY NETRW.VIM AND NETRW.VIM ONLY.
" THESE FUNCTIONS DON'T COMMIT TO ANY BACKWARDS COMPATIBILITY. SO CHANGES AND
" BREAKAGES IF USED OUTSIDE OF NETRW.VIM ARE EXPECTED.


" netrw#fs#PathJoin: Appends a new part to a path taking different systems into consideration {{{

function! netrw#fs#PathJoin(...)
    const slash = !exists('+shellslash') || &shellslash ? '/' : '\'
    let path = ""

    for arg in a:000
        if empty(path)
            let path = arg
        else
            let path .= slash . arg
        endif
    endfor

    return path
endfunction

" }}}
" netrw#fs#ComposePath: Appends a new part to a path taking different systems into consideration {{{

function! netrw#fs#ComposePath(base, subdir)
    if has('amiga')
        let ec = a:base[strdisplaywidth(a:base)-1]
        if ec != '/' && ec != ':'
            let ret = a:base . '/' . a:subdir
        else
            let ret = a:base.a:subdir
        endif

        " COMBAK: test on windows with changing to root directory: :e C:/
    elseif a:subdir =~ '^\a:[/\\]\([^/\\]\|$\)' && has('win32')
        let ret = a:subdir

    elseif a:base =~ '^\a:[/\\]\([^/\\]\|$\)' && has('win32')
        if a:base =~ '[/\\]$'
            let ret = a:base . a:subdir
        else
            let ret = a:base . '/' . a:subdir
        endif

    elseif a:base =~ '^\a\{3,}://'
        let urlbase = substitute(a:base, '^\(\a\+://.\{-}/\)\(.*\)$', '\1', '')
        let curpath = substitute(a:base, '^\(\a\+://.\{-}/\)\(.*\)$', '\2', '')
        if a:subdir == '../'
            if curpath =~ '[^/]/[^/]\+/$'
                let curpath = substitute(curpath, '[^/]\+/$', '', '')
            else
                let curpath = ''
            endif
            let ret = urlbase.curpath
        else
            let ret = urlbase.curpath.a:subdir
        endif

    else
        let ret = substitute(a:base . '/' .a:subdir, '//', '/', 'g')
        if a:base =~ '^//'
            " keeping initial '//' for the benefit of network share listing support
            let ret = '/' . ret
        endif
        let ret = simplify(ret)
    endif

    return ret
endfunction

" }}}
" netrw#fs#AbsPath: returns the full path to a directory and/or file {{{

function! netrw#fs#AbsPath(path)
    let path = a:path->substitute('[\/]$', '', 'e')

    " Nothing to do
    if isabsolutepath(path)
        return path
    endif

    return path->fnamemodify(':p')->substitute('[\/]$', '', 'e')
endfunction

" }}}
" netrw#fs#Cwd: get the current directory. {{{
"   Change backslashes to forward slashes, if any.
"   If doesc is true, escape certain troublesome characters

function! netrw#fs#Cwd(doesc)
    let curdir = substitute(getcwd(), '\\', '/', 'ge')

    if curdir !~ '[\/]$'
        let curdir .= '/'
    endif

    if a:doesc
        let curdir = fnameescape(curdir)
    endif

    return curdir
endfunction

" }}}
" netrw#fs#Glob: does glob() if local, remote listing otherwise {{{
"     direntry: this is the name of the directory.  Will be fnameescape'd to prevent wildcard handling by glob()
"     expr    : this is the expression to follow the directory.  Will use netrw#fs#ComposePath()
"     pare    =1: remove the current directory from the resulting glob() filelist
"             =0: leave  the current directory   in the resulting glob() filelist

function! netrw#fs#Glob(direntry, expr, pare)
    if netrw#CheckIfRemote()
        keepalt 1sp
        keepalt enew
        let keep_liststyle = w:netrw_liststyle
        let w:netrw_liststyle = s:THINLIST
        if s:NetrwRemoteListing() == 0
            keepj keepalt %s@/@@
            let filelist = getline(1,$)
            q!
        else
            " remote listing error -- leave treedict unchanged
            let filelist = w:netrw_treedict[a:direntry]
        endif
        let w:netrw_liststyle = keep_liststyle
    else
        let path= netrw#fs#ComposePath(fnameescape(a:direntry), a:expr)
        if has("win32")
            " escape [ so it is not detected as wildcard character, see :h wildcard
            let path = substitute(path, '[', '[[]', 'g')
        endif
        let filelist = glob(path, 0, 1, 1)
        if a:pare
            let filelist = map(filelist,'substitute(v:val, "^.*/", "", "")')
        endif
    endif

    return filelist
endfunction

" }}}
" netrw#fs#WinPath: tries to insure that the path is windows-acceptable, whether cygwin is used or not {{{

function! netrw#fs#WinPath(path)
    if (!g:netrw_cygwin || &shell !~ '\%(\<bash\>\|\<zsh\>\)\%(\.exe\)\=$') && has("win32")
        " remove cygdrive prefix, if present
        let path = substitute(a:path, g:netrw_cygdrive . '/\(.\)', '\1:', '')
        " remove trailing slash (Win95)
        let path = substitute(path, '\(\\\|/\)$', '', 'g')
        " remove escaped spaces
        let path = substitute(path, '\ ', ' ', 'g')
        " convert slashes to backslashes
        let path = substitute(path, '/', '\', 'g')
    else
        let path = a:path
    endif

    return path
endfunction

" }}}
" netrw#fs#Remove: deletes a file. {{{
"           Uses Steve Hall's idea to insure that Windows paths stay
"           acceptable.  No effect on Unix paths.

function! netrw#fs#Remove(path)
    let path = netrw#fs#WinPath(a:path)

    if !g:netrw_cygwin && has("win32") && exists("+shellslash")
        let sskeep = &shellslash
        setl noshellslash
        let result = delete(path)
        let &shellslash = sskeep
    else
        let result = delete(path)
    endif

    if result < 0
        call netrw#msg#Notify('WARNING', printf('delete("%s") failed!', path))
    endif

    return result
endfunction

" }}}

" vim:ts=8 sts=4 sw=4 et fdm=marker
